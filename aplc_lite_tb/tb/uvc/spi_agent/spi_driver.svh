// SPI Driver for APLC_LITE
// Converts spi_xtn commands into bit-serial SPI frames on the ATE serial interface
// Uses direct signal drives (not clocking block) to avoid output #0 timing races
// DUT CAXIS: next_shift = {rx_shift_q[78:0], pdi_i[0]} (1-bit mode)
// Frame sent MSB-first: first-sent bit maps to highest position after shift

class spi_driver extends uvm_driver#(spi_xtn);

    `uvm_component_utils(spi_driver)

    virtual spi_intf m_vif;
    spi_config m_cfg;

    localparam int MAX_RESP_WAIT_CYCLES = 10000;

    function new(string name = "spi_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(spi_config)::get(this, "", "spi_config", m_cfg)) begin
            `uvm_fatal(get_type_name(), "Cannot get spi_config from config_db")
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        m_vif = m_cfg.m_vif;
    endfunction

    task run_phase(uvm_phase phase);
        m_vif.pcs_n     <= 1'b1;
        m_vif.pdi       <= '0;
        m_vif.lane_mode <= 2'b00;
        @(posedge m_vif.clk_i);

        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done(req);
        end
    endtask

    task drive_transaction(spi_xtn txn);
        int tx_bit_count;
        int lane_width;
        int num_cycles;

        lane_width = (1 << txn.m_lane_mode);
        tx_bit_count = txn.get_tx_bit_count();
        num_cycles = (tx_bit_count + lane_width - 1) / lane_width;

        `uvm_info(get_type_name(), $sformatf("Driving frame: opcode=0x%02h reg_addr=0x%02h lane=%0d bits=%0d cycles=%0d",
                  txn.m_opcode, txn.m_reg_addr, lane_width, tx_bit_count, num_cycles), UVM_HIGH)

        // Set lane_mode and assert pcs_n along with first data chunk
        m_vif.lane_mode <= txn.m_lane_mode;
        m_vif.pcs_n     <= 1'b0;
        drive_pdi(txn, 0, lane_width, tx_bit_count);
        @(posedge m_vif.clk_i);

        // Drive remaining data chunks
        for (int i = 1; i < num_cycles; i++) begin
            drive_pdi(txn, i, lane_width, tx_bit_count);
            @(posedge m_vif.clk_i);
        end

        // De-assert pcs_n to end frame
        m_vif.pcs_n <= 1'b1;
        m_vif.pdi   <= '0;
        @(posedge m_vif.clk_i);

        // Wait for and capture DUT response
        capture_response(txn);
    endtask

    task drive_pdi(spi_xtn txn, int cycle, int lane_width, int total_bits);
        logic [15:0] pdi_data;
        pdi_data = get_pdi_chunk(txn, cycle, lane_width, total_bits);
        case (lane_width)
            1:  m_vif.pdi <= {15'b0, pdi_data[0]};
            4:  m_vif.pdi <= {12'b0, pdi_data[3:0]};
            8:  m_vif.pdi <= {8'b0, pdi_data[7:0]};
            16: m_vif.pdi <= pdi_data;
        endcase
    endtask

    // Get the pdi chunk for cycle i
    // DUT shift register: next_shift = {rx_shift_q[78:0], pdi_i[0]} for 1-bit
    // First-sent bit ends up at highest position of received byte
    // So we send MSB-first: opcode[7] first, opcode[0] last
    function logic [15:0] get_pdi_chunk(spi_xtn txn, int cycle, int lw, int total_bits);
        logic [15:0] chunk;
        int bit_offset;

        chunk = '0;
        bit_offset = cycle * lw;

        for (int b = 0; b < lw && (bit_offset + b) < total_bits; b++) begin
            logic frame_bit;
            frame_bit = get_frame_bit(txn, bit_offset + b);
            chunk[b] = frame_bit;
        end
        return chunk;
    endfunction

    // Get frame bit at position pos (0 = MSB of frame, first sent)
    function logic get_frame_bit(spi_xtn txn, int pos);
        logic [7:0] opcode_byte;

        opcode_byte = txn.m_opcode;

        case (txn.m_opcode)
            8'h10: begin // WR_CSR: opcode[7:0], reg_addr[7:0], wdata[31:0]
                if (pos < 8)
                    return opcode_byte[7 - pos];
                else if (pos < 16)
                    return txn.m_reg_addr[7 - (pos - 8)];
                else if (pos < 48)
                    return txn.m_wdata[31 - (pos - 16)];
                else
                    return 1'b0;
            end
            8'h11: begin // RD_CSR: opcode[7:0], reg_addr[7:0]
                if (pos < 8)
                    return opcode_byte[7 - pos];
                else if (pos < 16)
                    return txn.m_reg_addr[7 - (pos - 8)];
                else
                    return 1'b0;
            end
            8'h20: begin // AHB_WR32: opcode[7:0], addr[31:0], wdata[31:0]
                if (pos < 8)
                    return opcode_byte[7 - pos];
                else if (pos < 40)
                    return txn.m_addr[31 - (pos - 8)];
                else if (pos < 72)
                    return txn.m_wdata[31 - (pos - 40)];
                else
                    return 1'b0;
            end
            8'h21: begin // AHB_RD32: opcode[7:0], addr[31:0]
                if (pos < 8)
                    return opcode_byte[7 - pos];
                else if (pos < 40)
                    return txn.m_addr[31 - (pos - 8)];
                else
                    return 1'b0;
            end
            8'h22, 8'h23: begin // BURST: opcode[7:0], burst_len[4:0], 3'b000, addr[31:0]
                if (pos < 8)
                    return opcode_byte[7 - pos];
                else if (pos < 13)
                    return txn.m_burst_len[4 - (pos - 8)];
                else if (pos < 16)
                    return 1'b0; // reserved
                else if (pos < 48)
                    return txn.m_addr[31 - (pos - 16)];
                else
                    return 1'b0;
            end
            default: return 1'b0;
        endcase
    endfunction

    task capture_response(spi_xtn txn);
        int rx_bit_count;
        int lane_width;
        logic [39:0] resp_shift;
        int resp_bits_captured;
        int wait_cycles;

        rx_bit_count = txn.get_rx_bit_count();
        if (rx_bit_count == 0) return;

        lane_width = (1 << txn.m_lane_mode);
        resp_shift = '0;
        resp_bits_captured = 0;

        // Wait for DUT to assert pdo_oe (response phase)
        wait_cycles = 0;
        while (!m_vif.pdo_oe && wait_cycles < MAX_RESP_WAIT_CYCLES) begin
            @(posedge m_vif.clk_i);
            wait_cycles++;
        end

        if (!m_vif.pdo_oe) begin
            `uvm_error(get_type_name(), "Timeout waiting for DUT pdo_oe response")
            return;
        end

        // SCTRL_FRONT asserts pdo_oe=1 when entering TX_SINGLE, but SAXIS
        // needs 1 TURNAROUND cycle before it starts driving data. So there are
        // 2 cycles of pdo_oe=1 with no valid data before the first response bit.
        // Skip both turnaround cycles.
        @(posedge m_vif.clk_i);
        @(posedge m_vif.clk_i);

        // DUT SAXIS shifts response MSB-first from tx_shift_q[39]
        // Capture response bits while pdo_oe is high
        while (m_vif.pdo_oe && resp_bits_captured < rx_bit_count) begin
            logic [15:0] pdo_data;
            logic resp_bit;

            pdo_data = m_vif.pdo;

            for (int b = 0; b < lane_width && resp_bits_captured < rx_bit_count; b++) begin
                resp_bit = pdo_data[b];
                resp_shift = (resp_shift << 1) | resp_bit;
                resp_bits_captured++;
            end

            @(posedge m_vif.clk_i);
        end

        // Parse response: status at [39:32], rdata at [31:0]
        txn.m_resp_status = resp_shift[39:32];
        if (rx_bit_count > 8) begin
            txn.m_resp_rdata = resp_shift[31:0];
            txn.m_resp_has_rdata = 1'b1;
        end else begin
            txn.m_resp_rdata = '0;
            txn.m_resp_has_rdata = 1'b0;
        end

        `uvm_info(get_type_name(), $sformatf("Response: status=0x%02h rdata=0x%08h has_rdata=%0b",
                  txn.m_resp_status, txn.m_resp_rdata, txn.m_resp_has_rdata), UVM_LOW)
    endtask

endclass
