// =============================================================================
// File: aplc_ahb_monitor.svh
// Description: APLC-Lite AHB monitor
//              Monitors AHB bus transactions and sends via analysis port
//
// AHB Pipeline Protocol (monitor perspective):
//   - Address phase on clock N: sample haddr, htrans, hwrite, hsize, hburst
//   - Data phase on clock N+1: sample hwdata (write) or hrdata (read), hresp
//   - When hreadyout=0, data phase is extended; wait until hreadyout=1
//   - During bursts, address phase of beat N+1 coincides with data phase of beat N
// =============================================================================

class aplc_ahb_monitor extends uvm_monitor;

    // -------------------------------------------------------------------------
    // Member variables
    // -------------------------------------------------------------------------
    virtual aplc_ahb_if                 m_vif;
    aplc_ahb_config                     m_config;
    uvm_analysis_port #(aplc_ahb_txn)   m_analysis_port;

    // -------------------------------------------------------------------------
    // AHB burst type constants
    // -------------------------------------------------------------------------
    localparam BT_SINGLE = 3'b000;
    localparam BT_INCR4  = 3'b011;
    localparam BT_INCR8  = 3'b101;
    localparam BT_INCR16 = 3'b111;

    // -------------------------------------------------------------------------
    // AHB transfer type constants
    // -------------------------------------------------------------------------
    localparam TT_IDLE   = 2'b00;
    localparam TT_NONSEQ = 2'b10;
    localparam TT_SEQ    = 2'b11;

    // -------------------------------------------------------------------------
    // AHB response constants
    // -------------------------------------------------------------------------
    localparam RSP_OKAY  = 1'b0;
    localparam RSP_ERROR = 1'b1;

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_ahb_monitor)

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    // -------------------------------------------------------------------------
    // build_phase
    // -------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_analysis_port = new("m_analysis_port", this);

        if (!uvm_config_db #(aplc_ahb_config)::get(this, "", "m_config", m_config)) begin
            `uvm_fatal("APLC_AHB_MON", "Failed to get m_config from config db")
        end

        m_vif = m_config.m_vif;
        if (m_vif == null) begin
            `uvm_fatal("APLC_AHB_MON", "Virtual interface handle is null")
        end
    endfunction: build_phase

    // -------------------------------------------------------------------------
    // run_phase - main monitor loop
    // -------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        forever begin
            // Wait for reset deassertion
            wait (m_vif.hresetn === 1'b1);
            @(m_vif.mon_cb);

            // Look for a valid address phase start (NONSEQ with hsel)
            if (m_vif.mon_cb.hsel === 1'b1 &&
                m_vif.mon_cb.htrans inside {TT_NONSEQ}) begin
                collect_transfer();
            end
        end
    endtask: run_phase

    // -------------------------------------------------------------------------
    // Task: collect_transfer
    //   Collect an AHB transfer (SINGLE or burst) from the bus
    //   Tracks address phase and data phase separately to handle pipelining
    // -------------------------------------------------------------------------
    task collect_transfer();
        aplc_ahb_txn txn;
        bit [31:0]   addr;
        bit [2:0]    burst;
        bit [2:0]    size;
        bit          is_write;
        bit          resp;
        int          burst_len;
        int          byte_count;
        int          beat_idx;
        int          data_count;

        // Capture address phase of the first beat (NONSEQ)
        addr     = m_vif.mon_cb.haddr;
        burst    = m_vif.mon_cb.hburst;
        size     = m_vif.mon_cb.hsize;
        is_write = m_vif.mon_cb.hwrite;

        // Determine burst length
        case (burst)
            BT_SINGLE: burst_len = 1;
            BT_INCR4:  burst_len = 4;
            BT_INCR8:  burst_len = 8;
            BT_INCR16: burst_len = 16;
            default:   burst_len = 1;
        endcase

        byte_count = (1 << size);

        // Create transaction
        txn = aplc_ahb_txn::type_id::create("txn");
        txn.m_addr  = addr;
        txn.m_write = is_write;
        txn.m_burst = burst;
        txn.m_size  = size;
        txn.m_trans = TT_NONSEQ;
        txn.m_data  = new[burst_len];

        // -----------------------------------------------------------------
        // Collect data for each beat of the burst
        // -----------------------------------------------------------------
        data_count = 0;
        for (beat_idx = 0; beat_idx < burst_len; beat_idx++) begin
            // Wait for data phase to complete (hreadyout must be high)
            wait_for_ready();

            // Data phase: capture data and response
            if (is_write) begin
                txn.m_data[beat_idx] = m_vif.mon_cb.hwdata;
            end else begin
                txn.m_data[beat_idx] = m_vif.mon_cb.hrdata;
            end

            resp = m_vif.mon_cb.hresp;
            txn.m_response = resp;

            data_count++;

            `uvm_info("APLC_AHB_MON",
                $sformatf("Beat[%0d/%0d] addr=0x%08h data=0x%08h write=%0d resp=%0s",
                          beat_idx, burst_len-1, addr, txn.m_data[beat_idx],
                          is_write, resp ? "ERROR" : "OKAY"),
                UVM_HIGH)

            // If ERROR response, burst terminates (two-cycle error)
            if (resp == RSP_ERROR) begin
                // Wait for the second cycle of the two-cycle error response
                @(m_vif.mon_cb);
                wait_for_ready();
                break;
            end

            // Update address for next beat
            addr = addr + byte_count;

            // Advance to next clock edge for next beat's address/data phase
            if (beat_idx < burst_len - 1) begin
                @(m_vif.mon_cb);
            end
        end

        // If burst was terminated early, resize the data array
        if (data_count < burst_len) begin
            begin
                bit [31:0] tmp_data[];
                tmp_data = new[data_count](txn.m_data);
                txn.m_data = tmp_data;
            end
        end

        `uvm_info("APLC_AHB_MON",
            $sformatf("Collected: %s", txn.convert2string()),
            UVM_MEDIUM)

        // Send transaction via analysis port
        m_analysis_port.write(txn);

    endtask: collect_transfer

    // -------------------------------------------------------------------------
    // Task: wait_for_ready
    //   Wait until hreadyout is asserted (data phase completes)
    // -------------------------------------------------------------------------
    task wait_for_ready();
        while (m_vif.mon_cb.hreadyout !== 1'b1) begin
            @(m_vif.mon_cb);
        end
    endtask: wait_for_ready

endclass: aplc_ahb_monitor
