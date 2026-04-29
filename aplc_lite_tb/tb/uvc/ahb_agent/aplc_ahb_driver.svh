// =============================================================================
// File: aplc_ahb_driver.svh
// Description: APLC-Lite AHB slave driver
//              Responds to DUT's AHB master requests
//              Handles AHB 2-phase pipeline (address phase then data phase)
//
// AHB Pipeline Protocol:
//   - Address phase and data phase are pipelined with 1-cycle skew
//   - On clock N: master drives address/control signals (address phase)
//   - On clock N+1: master drives hwdata for writes, slave drives hrdata for reads
//   - During a burst, address phase of beat N+1 overlaps with data phase of beat N
//   - When hreadyout is LOW, both address and data phases are extended
// =============================================================================

class aplc_ahb_driver extends uvm_driver #(aplc_ahb_txn);

    // -------------------------------------------------------------------------
    // Member variables
    // -------------------------------------------------------------------------
    virtual aplc_ahb_if m_vif;
    aplc_ahb_config     m_config;

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
    `uvm_component_utils(aplc_ahb_driver)

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

        if (!uvm_config_db #(aplc_ahb_config)::get(this, "", "m_config", m_config)) begin
            `uvm_fatal("APLC_AHB_DRV", "Failed to get m_config from config db")
        end

        m_vif = m_config.m_vif;
        if (m_vif == null) begin
            `uvm_fatal("APLC_AHB_DRV", "Virtual interface handle is null")
        end
    endfunction: build_phase

    // -------------------------------------------------------------------------
    // run_phase - main driver loop
    // -------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        forever begin
            // Wait for reset deassertion
            wait (m_vif.hresetn === 1'b1);
            @(m_vif.sdrv_cb);

            // Initialize slave outputs to idle
            m_vif.sdrv_cb.hrdata    <= 32'h0;
            m_vif.sdrv_cb.hreadyout <= 1'b1;
            m_vif.sdrv_cb.hresp     <= RSP_OKAY;

            // Process transfers one by one
            process_transfer();
        end
    endtask: run_phase

    // -------------------------------------------------------------------------
    // Task: process_transfer
    //   Process AHB transfer(s) - handles SINGLE and INCR4/8/16 bursts
    //
    //   AHB 2-phase pipeline for a write burst:
    //     Cycle 0: Master: haddr[0], htrans=NONSEQ, hwrite=1 (addr phase beat0)
    //     Cycle 1: Master: haddr[1], htrans=SEQ, hwdata[0]  (addr phase beat1, data phase beat0)
    //     Cycle 2: Master: hwdata[1]                          (data phase beat1)
    //              Slave:  hrdata, hresp for beat0 valid at cycle1, beat1 at cycle2
    //
    //   For reads:
    //     Cycle 0: Master: haddr[0], htrans=NONSEQ, hwrite=0 (addr phase beat0)
    //     Cycle 1: Slave:  hrdata[0], hresp for beat0        (data phase beat0)
    //              Master: haddr[1], htrans=SEQ               (addr phase beat1)
    //     Cycle 2: Slave:  hrdata[1], hresp for beat1        (data phase beat1)
    // -------------------------------------------------------------------------
    task process_transfer();
        aplc_ahb_txn txn;
        aplc_ahb_txn resp_txn;
        bit [31:0]   addr;
        bit [2:0]    burst;
        bit [2:0]    size;
        bit          is_write;
        bit          resp;
        int          burst_len;
        int          byte_count;
        int          beat_idx;

        // -----------------------------------------------------------------
        // Wait for a valid address phase (htrans == NONSEQ with hsel)
        // -----------------------------------------------------------------
        wait_for_addr_phase();

        // Capture address phase information
        addr     = m_vif.sdrv_cb.haddr;
        burst    = m_vif.sdrv_cb.hburst;
        size     = m_vif.sdrv_cb.hsize;
        is_write = m_vif.sdrv_cb.hwrite;

        // Determine burst length
        case (burst)
            BT_SINGLE: burst_len = 1;
            BT_INCR4:  burst_len = 4;
            BT_INCR8:  burst_len = 8;
            BT_INCR16: burst_len = 16;
            default:   burst_len = 1;
        endcase

        byte_count = (1 << size);

        // Create response transaction
        txn = aplc_ahb_txn::type_id::create("txn");
        txn.m_addr     = addr;
        txn.m_write    = is_write;
        txn.m_burst    = burst;
        txn.m_size     = size;
        txn.m_trans    = TT_NONSEQ;
        txn.m_data     = new[burst_len];

        // Try to get a response item from the sequencer (non-blocking)
        // If no item available, use default OKAY response with zero data
        seq_item_port.try_next_item(resp_txn);
        if (resp_txn != null) begin
            txn.m_response = resp_txn.m_response;
            // If sequencer provides data for reads, use it
            if (!is_write && resp_txn.m_data.size() > 0) begin
                foreach (resp_txn.m_data[i]) begin
                    if (i < burst_len) begin
                        txn.m_data[i] = resp_txn.m_data[i];
                    end
                end
            end
            seq_item_port.item_done();
        end else begin
            txn.m_response = RSP_OKAY;
        end

        resp = txn.m_response;

        // -----------------------------------------------------------------
        // Process each beat of the burst
        // -----------------------------------------------------------------
        for (beat_idx = 0; beat_idx < burst_len; beat_idx++) begin
            // For the first beat, we already captured the address phase above
            // For subsequent beats, the address phase occurred during the
            // previous beat's data phase (pipeline overlap)

            if (beat_idx > 0) begin
                // At this point, we are at the clock edge where:
                //   - Previous beat's data phase is completing
                //   - Current beat's address phase is being sampled
                // Check for SEQ transfer from master
                if (m_vif.sdrv_cb.htrans !== TT_SEQ &&
                    m_vif.sdrv_cb.htrans !== TT_NONSEQ) begin
                    // Master terminated the burst early
                    `uvm_info("APLC_AHB_DRV",
                        $sformatf("Burst terminated early at beat %0d of %0d",
                                  beat_idx, burst_len),
                        UVM_MEDIUM)
                    // Resize the data array
                    begin
                        bit [31:0] tmp_data[];
                        tmp_data = new[beat_idx](txn.m_data);
                        txn.m_data = tmp_data;
                    end
                    break;
                end

                // Capture new address for this beat
                addr = m_vif.sdrv_cb.haddr;
            end

            // Apply hready delay (back-pressure simulation)
            // During delay, hreadyout is LOW, which extends both address
            // and data phases of the current transfer
            if (m_config.m_ready_delay > 0) begin
                m_vif.sdrv_cb.hreadyout <= 1'b0;
                repeat (m_config.m_ready_delay) begin
                    @(m_vif.sdrv_cb);
                    m_vif.sdrv_cb.hreadyout <= 1'b0;
                end
            end

            // Data phase: drive/collect data and response
            if (is_write) begin
                // Write: sample hwdata from master on this clock edge
                txn.m_data[beat_idx] = m_vif.sdrv_cb.hwdata;
                `uvm_info("APLC_AHB_DRV",
                    $sformatf("Write beat[%0d/%0d] addr=0x%08h data=0x%08h resp=%0s",
                              beat_idx, burst_len-1, addr, txn.m_data[beat_idx],
                              resp ? "ERROR" : "OKAY"),
                    UVM_HIGH)
            end else begin
                // Read: drive hrdata to master (valid next clock edge)
                m_vif.sdrv_cb.hrdata <= txn.m_data[beat_idx];
                `uvm_info("APLC_AHB_DRV",
                    $sformatf("Read beat[%0d/%0d] addr=0x%08h data=0x%08h resp=%0s",
                              beat_idx, burst_len-1, addr, txn.m_data[beat_idx],
                              resp ? "ERROR" : "OKAY"),
                    UVM_HIGH)
            end

            // Drive response and ready signals
            m_vif.sdrv_cb.hresp     <= resp;
            m_vif.sdrv_cb.hreadyout <= 1'b1;

            // If ERROR response: two-cycle error response required by AHB
            // First cycle: hresp=ERROR, hreadyout=0 (wait state)
            // Second cycle: hresp=ERROR, hreadyout=1 (data phase completes)
            if (resp == RSP_ERROR) begin
                @(m_vif.sdrv_cb);
                // Second cycle of two-cycle ERROR response
                m_vif.sdrv_cb.hresp     <= RSP_ERROR;
                m_vif.sdrv_cb.hreadyout <= 1'b1;
                // After error, master will cancel remaining burst beats
                break;
            end

            // Wait for next clock edge (where data phase completes and
            // next address phase is sampled for pipelined bursts)
            if (beat_idx < burst_len - 1) begin
                @(m_vif.sdrv_cb);
            end
        end

        // After burst completion, wait one more cycle to ensure
        // the last data phase is complete, then reset outputs
        @(m_vif.sdrv_cb);
        m_vif.sdrv_cb.hrdata    <= 32'h0;
        m_vif.sdrv_cb.hreadyout <= 1'b1;
        m_vif.sdrv_cb.hresp     <= RSP_OKAY;

    endtask: process_transfer

    // -------------------------------------------------------------------------
    // Task: wait_for_addr_phase
    //   Wait until the AHB master drives a valid address phase
    // -------------------------------------------------------------------------
    task wait_for_addr_phase();
        forever begin
            @(m_vif.sdrv_cb);
            if (m_vif.sdrv_cb.hsel === 1'b1 &&
                m_vif.sdrv_cb.htrans inside {TT_NONSEQ}) begin
                return;
            end
        end
    endtask: wait_for_addr_phase

endclass: aplc_ahb_driver
