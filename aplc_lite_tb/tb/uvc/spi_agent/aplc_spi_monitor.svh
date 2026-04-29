// =============================================================================
// File: aplc_spi_monitor.svh
// Description: APLC-Lite SPI monitor - passively observes the SPI-like
//              interface and publishes transactions on analysis port
// =============================================================================

class aplc_spi_monitor extends uvm_monitor;

    // -------------------------------------------------------------------------
    // Bit-level state for continuous request data collection
    // -------------------------------------------------------------------------
    logic [15:0] m_cur_beat;
    int unsigned m_bit_offset; // bits consumed in current beat

    // -------------------------------------------------------------------------
    // Utility and registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_spi_monitor)

    // -------------------------------------------------------------------------
    // Member variables
    // -------------------------------------------------------------------------
    virtual aplc_spi_if                      m_vif;
    uvm_analysis_port #(aplc_spi_txn)        m_analysis_port;

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

        if (!uvm_config_db #(virtual aplc_spi_if)::get(this, "", "m_vif", m_vif)) begin
            `uvm_fatal(get_type_name(), "Failed to get m_vif from config db")
        end
    endfunction: build_phase

    // -------------------------------------------------------------------------
    // run_phase - main monitoring loop
    // -------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        aplc_spi_txn txn;

        // Wait for reset deassertion
        wait (m_vif.rst_n === 1'b1);

        forever begin
            @(m_vif.mon_cb);

            // Detect start of frame: pcs_n asserted (active-low)
            if (m_vif.mon_cb.pcs_n === 1'b0) begin
                // First data beat is already on pdi at this posedge
                // (driver drives pcs_n and data in the same cycle)
                txn = aplc_spi_txn::type_id::create("txn");
                collect_frame(txn);
                m_analysis_port.write(txn);
                `uvm_info(get_type_name(), $sformatf("Observed transaction: %s", txn.convert2string()), UVM_HIGH)

                // Wait for pcs_n to return high before detecting next frame
                wait (m_vif.pcs_n === 1'b1);
                @(m_vif.mon_cb);
            end
        end
    endtask: run_phase

    // -------------------------------------------------------------------------
    // collect_frame - collect a complete request + response frame
    // -------------------------------------------------------------------------
    task collect_frame(aplc_spi_txn txn);
        logic [7:0]  opcode;
        logic [4:0]  burst_len;
        logic [7:0]  reg_addr;
        logic [31:0] addr;
        logic [7:0]  status_val;
        longint unsigned raw_data;

        // Reset bit-level state for new frame
        m_bit_offset = 0;

        // Capture lane_mode at start of frame
        txn.m_lane_mode = m_vif.mon_cb.lane_mode;

        // Collect opcode (8 bits) first to determine command type
        collect_request_bits(8, raw_data);
        opcode = raw_data[7:0];
        txn.m_opcode = opcode;

        // Determine command type and collect remaining request fields
        case (opcode)
            8'h10: begin // WR_CSR: opcode(8) + reg_addr(8) + wdata(32) = 48 bits
                txn.m_is_read  = 1'b0;
                txn.m_is_burst = 1'b0;
                txn.m_burst_len = 5'd1;
                collect_request_bits(8, raw_data);
                reg_addr = raw_data[7:0];
                txn.m_reg_addr = reg_addr;
                txn.m_wdata = new[1];
                collect_request_bits(32, raw_data);
                txn.m_wdata[0] = raw_data[31:0];
            end

            8'h11: begin // RD_CSR: opcode(8) + reg_addr(8) = 16 bits
                txn.m_is_read  = 1'b1;
                txn.m_is_burst = 1'b0;
                txn.m_burst_len = 5'd1;
                collect_request_bits(8, raw_data);
                reg_addr = raw_data[7:0];
                txn.m_reg_addr = reg_addr;
            end

            8'h20: begin // AHB_WR32: opcode(8) + addr(32) + wdata(32) = 72 bits
                txn.m_is_read  = 1'b0;
                txn.m_is_burst = 1'b0;
                txn.m_burst_len = 5'd1;
                collect_request_bits(32, raw_data);
                txn.m_addr = raw_data[31:0];
                txn.m_wdata = new[1];
                collect_request_bits(32, raw_data);
                txn.m_wdata[0] = raw_data[31:0];
            end

            8'h21: begin // AHB_RD32: opcode(8) + addr(32) = 40 bits
                txn.m_is_read  = 1'b1;
                txn.m_is_burst = 1'b0;
                txn.m_burst_len = 5'd1;
                collect_request_bits(32, raw_data);
                txn.m_addr = raw_data[31:0];
            end

            8'h22: begin // AHB_WR_BURST
                txn.m_is_read  = 1'b0;
                txn.m_is_burst = 1'b1;
                collect_request_bits(40, raw_data);
                burst_len       = raw_data[39:35];
                txn.m_burst_len = burst_len;
                txn.m_addr      = raw_data[31:0];
                txn.m_wdata = new[burst_len];
                for (int i = 0; i < burst_len; i++) begin
                    collect_request_bits(32, raw_data);
                    txn.m_wdata[i] = raw_data[31:0];
                end
            end

            8'h23: begin // AHB_RD_BURST
                txn.m_is_read  = 1'b1;
                txn.m_is_burst = 1'b1;
                collect_request_bits(40, raw_data);
                burst_len       = raw_data[39:35];
                txn.m_burst_len = burst_len;
                txn.m_addr      = raw_data[31:0];
            end

            default: begin
                `uvm_warning(get_type_name(), $sformatf("Unknown opcode detected: 0x%02h", opcode))
            end
        endcase

        // Wait for turnaround: pdo_oe should transition to 1
        // Timeout protection
        fork
            begin
                wait (m_vif.pdo_oe === 1'b1);
                @(m_vif.mon_cb);

                // Collect status byte (8 bits)
                collect_response_data(8, status_val);
                txn.m_status = status_val;

                // Collect read data for read commands
                if (txn.m_is_read && !txn.m_is_burst) begin
                    // Single read (RD_CSR, AHB_RD32)
                    txn.m_rdata = new[1];
                    collect_response_data(32, txn.m_rdata[0]);
                end
                else if (txn.m_is_read && txn.m_is_burst) begin
                    // Burst read (AHB_RD_BURST)
                    txn.m_rdata = new[txn.m_burst_len];
                    for (int i = 0; i < txn.m_burst_len; i++) begin
                        collect_response_data(32, txn.m_rdata[i]);
                    end
                end
            end
            begin
                // Timeout watchdog
                repeat (1000) @(m_vif.mon_cb);
                `uvm_error(get_type_name(), "Timeout waiting for DUT response (pdo_oe not asserted)")
            end
        join_any
        disable fork;

    endtask: collect_frame

    // -------------------------------------------------------------------------
    // collect_request_data - collect request data bits MSB-first from pdi
    //   Convention: MSB of data is at highest bit of pdi (pdi[N-1]=MSB)
    // -------------------------------------------------------------------------
    task collect_request_bits(input int unsigned num_bits, output longint unsigned data);
        int unsigned bits_per_beat;
        int unsigned bit_idx;

        data = 0;

        case (m_vif.mon_cb.lane_mode)
            2'b00: bits_per_beat = 1;
            2'b01: bits_per_beat = 4;
            2'b10: bits_per_beat = 8;
            2'b11: bits_per_beat = 16;
            default: bits_per_beat = 1;
        endcase

        for (int i = 0; i < num_bits; i++) begin
            if (m_bit_offset == 0) begin
                m_cur_beat = m_vif.mon_cb.pdi;
            end

            bit_idx = bits_per_beat - 1 - m_bit_offset;
            data[num_bits - 1 - i] = m_cur_beat[bit_idx];

            m_bit_offset++;
            if (m_bit_offset >= bits_per_beat) begin
                m_bit_offset = 0;
                @(m_vif.mon_cb);
            end
        end
    endtask: collect_request_bits

    // -------------------------------------------------------------------------
    // collect_response_data - collect response data bits MSB-first from pdo
    //   Convention: MSB of data is at highest bit of pdo (pdo[N-1]=MSB)
    // -------------------------------------------------------------------------
    task collect_response_data(input int unsigned num_bits, output logic [31:0] data);
        int unsigned bits_per_beat;
        int unsigned num_beats;
        int unsigned beat_idx;
        int unsigned bit_idx;
        logic [15:0] pdo_val;

        data = 32'h0;

        case (m_vif.lane_mode)
            2'b00: bits_per_beat = 1;
            2'b01: bits_per_beat = 4;
            2'b10: bits_per_beat = 8;
            2'b11: bits_per_beat = 16;
            default: bits_per_beat = 1;
        endcase

        num_beats = (num_bits + bits_per_beat - 1) / bits_per_beat;

        for (beat_idx = 0; beat_idx < num_beats; beat_idx++) begin
            pdo_val = m_vif.mon_cb.pdo;

            for (int lane = 0; lane < bits_per_beat; lane++) begin
                bit_idx = num_bits - 1 - (beat_idx * bits_per_beat) - lane;
                if (bit_idx >= 0 && bit_idx < num_bits) begin
                    data[bit_idx] = pdo_val[bits_per_beat - 1 - lane];
                end
            end

            if (beat_idx < num_beats - 1) begin
                @(m_vif.mon_cb);
            end
        end
    endtask: collect_response_data

    // -------------------------------------------------------------------------
    // Protocol violation detection (checked inline during monitoring)
    // -------------------------------------------------------------------------
    // Protocol checks are handled by concurrent assertions in the interface.
    // Additional behavioral checks can be added here if needed.

endclass: aplc_spi_monitor
