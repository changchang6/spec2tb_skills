// =============================================================================
// File: aplc_spi_driver.svh
// Description: APLC-Lite SPI driver - drives request frames and collects
//              responses via the SPI-like half-duplex interface
// =============================================================================

class aplc_spi_driver extends uvm_driver #(aplc_spi_txn);

    // -------------------------------------------------------------------------
    // Utility and registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_spi_driver)

    // -------------------------------------------------------------------------
    // Member variables
    // -------------------------------------------------------------------------
    virtual aplc_spi_if             m_vif;
    uvm_active_passive_enum         m_is_active;

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

        if (!uvm_config_db #(virtual aplc_spi_if)::get(this, "", "m_vif", m_vif)) begin
            `uvm_fatal(get_type_name(), "Failed to get m_vif from config db")
        end
    endfunction: build_phase

    // -------------------------------------------------------------------------
    // get_bits_per_beat - return number of data bits per clock cycle
    // -------------------------------------------------------------------------
    function int unsigned get_bits_per_beat(input bit [1:0] lane_mode);
        case (lane_mode)
            2'b00: return 1;
            2'b01: return 4;
            2'b10: return 8;
            2'b11: return 16;
            default: return 1;
        endcase
    endfunction: get_bits_per_beat

    // -------------------------------------------------------------------------
    // run_phase - main driver loop
    // -------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        // Initialize interface to idle
        m_vif.drive_idle();

        // Wait for reset deassertion before driving
        wait (m_vif.rst_n === 1'b1);
        @(m_vif.drv_cb);

        forever begin
            seq_item_port.try_next_item(req);
            if (req != null) begin
                drive_transaction(req);
                seq_item_port.item_done();
            end else begin
                @(m_vif.drv_cb);
            end
        end
    endtask: run_phase

    // -------------------------------------------------------------------------
    // drive_transaction - top-level driving task
    //   Drives pcs_n and the first data beat in the same clock cycle so the
    //   DUT sees both together on the next posedge (avoids a zero-data gap).
    // -------------------------------------------------------------------------
    task drive_transaction(aplc_spi_txn txn);
        `uvm_info(get_type_name(), $sformatf("Driving transaction: %s", txn.convert2string()), UVM_HIGH)

        // Assert pcs_n (active-low) and set up interface - drive in same
        // time step as first data beat so DUT sees both together.
        m_vif.drv_cb.pcs_n     <= 1'b0;
        m_vif.drv_cb.lane_mode <= txn.m_lane_mode;
        m_vif.drv_cb.en        <= 1'b1;
        m_vif.drv_cb.test_mode <= 1'b1;

        // Drive the request phase based on opcode (first beat shares
        // the same clock edge as pcs_n assertion)
        case (txn.m_opcode)
            8'h10: drive_wr_csr(txn);
            8'h11: drive_rd_csr(txn);
            8'h20: drive_ahb_wr32(txn);
            8'h21: drive_ahb_rd32(txn);
            8'h22: drive_ahb_wr_burst(txn);
            8'h23: drive_ahb_rd_burst(txn);
            default: begin
                `uvm_error(get_type_name(), $sformatf("Unknown opcode: 0x%02h", txn.m_opcode))
            end
        endcase

        // Collect response from DUT
        collect_response(txn);

        // Wait for DUT to finish driving response before deasserting pcs_n
        wait (m_vif.pdo_oe === 1'b0);

        // Deassert pcs_n to end frame
        m_vif.drv_cb.pcs_n <= 1'b1;
        m_vif.drv_cb.pdi   <= 16'h0;
        @(m_vif.drv_cb);
        // Extra idle cycle to allow monitor resynchronization
        @(m_vif.drv_cb);

        `uvm_info(get_type_name(), $sformatf("Transaction complete: %s", txn.convert2string()), UVM_HIGH)
    endtask: drive_transaction

    // -------------------------------------------------------------------------
    // drive_data_msb_first - drive data bits MSB-first across lane_mode
    //   Convention: MSB of data goes to highest bit of pdi
    //     lane_mode 00: pdi[0] carries the bit
    //     lane_mode 01: pdi[3:0] carries 4 bits, pdi[3]=MSB
    //     lane_mode 10: pdi[7:0] carries 8 bits, pdi[7]=MSB
    //     lane_mode 11: pdi[15:0] carries 16 bits, pdi[15]=MSB
    // -------------------------------------------------------------------------
    task drive_data_msb_first(input bit [1:0] lane_mode,
                              input logic [127:0] data,
                              input int unsigned num_bits);
        int unsigned bits_per_beat;
        int unsigned num_beats;
        int unsigned beat_idx;
        int unsigned bit_idx;
        logic [15:0] beat_data;

        bits_per_beat = get_bits_per_beat(lane_mode);
        num_beats     = (num_bits + bits_per_beat - 1) / bits_per_beat;

        for (beat_idx = 0; beat_idx < num_beats; beat_idx++) begin
            beat_data = 16'h0;

            // Extract bits for this beat, MSB-first
            // MSB of data goes to highest bit of pdi (pdi[N-1]=MSB convention)
            for (int lane = 0; lane < bits_per_beat; lane++) begin
                bit_idx = num_bits - 1 - (beat_idx * bits_per_beat) - lane;
                if (bit_idx >= 0 && bit_idx < num_bits) begin
                    beat_data[bits_per_beat - 1 - lane] = data[bit_idx];
                end
            end

            m_vif.drv_cb.pdi <= beat_data;
            @(m_vif.drv_cb);
        end
    endtask: drive_data_msb_first

    // -------------------------------------------------------------------------
    // Command-specific drive tasks
    // -------------------------------------------------------------------------

    // WR_CSR(0x10): [opcode(8) | reg_addr(8) | wdata(32)] = 48-bit request
    task drive_wr_csr(aplc_spi_txn txn);
        drive_data_msb_first(txn.m_lane_mode, {txn.m_opcode, txn.m_reg_addr, txn.m_wdata[0]}, 48);
    endtask: drive_wr_csr

    // RD_CSR(0x11): [opcode(8) | reg_addr(8)] = 16-bit request
    task drive_rd_csr(aplc_spi_txn txn);
        drive_data_msb_first(txn.m_lane_mode, {txn.m_opcode, txn.m_reg_addr}, 16);
    endtask: drive_rd_csr

    // AHB_WR32(0x20): [opcode(8) | addr(32) | wdata(32)] = 72-bit request
    task drive_ahb_wr32(aplc_spi_txn txn);
        drive_data_msb_first(txn.m_lane_mode, {txn.m_opcode, txn.m_addr, txn.m_wdata[0]}, 72);
    endtask: drive_ahb_wr32

    // AHB_RD32(0x21): [opcode(8) | addr(32)] = 40-bit request
    task drive_ahb_rd32(aplc_spi_txn txn);
        drive_data_msb_first(txn.m_lane_mode, {txn.m_opcode, txn.m_addr}, 40);
    endtask: drive_ahb_rd32

    // AHB_WR_BURST(0x22): [opcode(8)|burst_len(5)|rsvd(3)|addr(32)|wdata*N]
    task drive_ahb_wr_burst(aplc_spi_txn txn);
        // Drive header: opcode(8) + burst_len(5) + rsvd(3) + addr(32) = 48 bits
        drive_data_msb_first(txn.m_lane_mode, {txn.m_opcode, txn.m_burst_len, 3'b000, txn.m_addr}, 48);

        // Drive payload: N x 32-bit data words
        for (int i = 0; i < txn.m_wdata.size(); i++) begin
            drive_data_msb_first(txn.m_lane_mode, txn.m_wdata[i], 32);
        end
    endtask: drive_ahb_wr_burst

    // AHB_RD_BURST(0x23): [opcode(8)|burst_len(5)|rsvd(3)|addr(32)] = 48-bit request
    task drive_ahb_rd_burst(aplc_spi_txn txn);
        drive_data_msb_first(txn.m_lane_mode, {txn.m_opcode, txn.m_burst_len, 3'b000, txn.m_addr}, 48);
    endtask: drive_ahb_rd_burst

    // -------------------------------------------------------------------------
    // collect_response - monitor DUT response after request
    // -------------------------------------------------------------------------
    task collect_response(aplc_spi_txn txn);
        // Wait for turnaround cycle (pdo_oe transitions to 1)
        // The DUT asserts pdo_oe when it starts driving the response
        wait (m_vif.pdo_oe === 1'b1);
        @(m_vif.mon_cb);

        // Collect status byte (8 bits) - always first response
        collect_response_data(txn.m_lane_mode, 8, txn.m_status);

        // Collect read data based on command type
        if (txn.m_opcode == 8'h11) begin
            // RD_CSR: status(8) + rdata(32)
            txn.m_rdata = new[1];
            collect_response_data(txn.m_lane_mode, 32, txn.m_rdata[0]);
        end
        else if (txn.m_opcode == 8'h21) begin
            // AHB_RD32: status(8) + rdata(32)
            txn.m_rdata = new[1];
            collect_response_data(txn.m_lane_mode, 32, txn.m_rdata[0]);
        end
        else if (txn.m_opcode == 8'h23) begin
            // AHB_RD_BURST: status(8) + N*32-bit rdata
            txn.m_rdata = new[txn.m_burst_len];
            for (int i = 0; i < txn.m_burst_len; i++) begin
                collect_response_data(txn.m_lane_mode, 32, txn.m_rdata[i]);
            end
        end

        `uvm_info(get_type_name(), $sformatf("Collected response: status=0x%02h", txn.m_status), UVM_HIGH)
    endtask: collect_response

    // -------------------------------------------------------------------------
    // collect_response_data - collect data bits MSB-first from pdo
    //   Uses mon_cb to sample DUT output. Advances clock after each beat
    //   except the last one (caller controls overall timing).
    // -------------------------------------------------------------------------
    task collect_response_data(input bit [1:0] lane_mode,
                               input int unsigned num_bits,
                               output logic [31:0] data);
        int unsigned bits_per_beat;
        int unsigned num_beats;
        int unsigned beat_idx;
        int unsigned bit_idx;
        logic [15:0] pdo_val;

        data = 32'h0;

        bits_per_beat = get_bits_per_beat(lane_mode);
        num_beats     = (num_bits + bits_per_beat - 1) / bits_per_beat;

        for (beat_idx = 0; beat_idx < num_beats; beat_idx++) begin
            pdo_val = m_vif.mon_cb.pdo;

            for (int lane = 0; lane < bits_per_beat; lane++) begin
                bit_idx = num_bits - 1 - (beat_idx * bits_per_beat) - lane;
                if (bit_idx >= 0 && bit_idx < num_bits) begin
                    data[bit_idx] = pdo_val[bits_per_beat - 1 - lane];
                end
            end

            // Advance clock after each beat except the last
            if (beat_idx < num_beats - 1) begin
                @(m_vif.mon_cb);
            end
        end
    endtask: collect_response_data

endclass: aplc_spi_driver
