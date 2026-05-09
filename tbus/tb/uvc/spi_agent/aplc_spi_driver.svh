// APLC SPI Driver - Frame-level driving of SPI protocol
class aplc_spi_driver extends uvm_driver #(aplc_spi_transaction);

    `uvm_component_utils(aplc_spi_driver)

    virtual aplc_spi_if m_vif;
    static string msg_id = "APLC_SPI_DRV";

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual aplc_spi_if)::get(this, "", "vif", m_vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        fork
            drive_transactions();
        join_none
    endtask

    task drive_transactions();
        forever begin
            aplc_spi_transaction req;
            seq_item_port.try_next_item(req);
            if (req == null) begin
                @(m_vif.drv_cb);
                continue;
            end
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_transaction(aplc_spi_transaction req);
        logic [559:0] frame;
        int           frame_len;
        int           bpc;

        bpc = get_bpc(req.m_lane_mode);

        // Drive control signals
        m_vif.drv_cb.en_i        <= req.m_en;
        m_vif.drv_cb.test_mode_i <= req.m_test_mode;
        m_vif.drv_cb.lane_mode_i <= req.m_lane_mode;
        @(m_vif.drv_cb);

        // Build frame
        frame     = '0;
        frame_len = 0;
        build_frame(req, frame, frame_len);

        // Assert pcs_n (frame start)
        m_vif.drv_cb.pcs_n_i <= 1'b0;
        @(m_vif.drv_cb);

        // Shift out data MSB-first
        send_frame(frame, frame_len, bpc);

        // Deassert pcs_n (frame end)
        m_vif.drv_cb.pcs_n_i <= 1'b1;
        m_vif.drv_cb.pdi_i   <= '0;
        @(m_vif.drv_cb);
    endtask

    function void build_frame(aplc_spi_transaction req, output logic [559:0] frame, output int frame_len);
        case (req.m_opcode)
            8'h10: begin // WR_CSR: opcode(8) + reg_addr(8) + wdata(32) = 48 bits
                frame     = {req.m_opcode, req.m_reg_addr, req.m_wdata[0]};
                frame_len = 48;
            end
            8'h11: begin // RD_CSR: opcode(8) + reg_addr(8) = 16 bits
                frame     = {req.m_opcode, req.m_reg_addr, 480'b0};
                frame_len = 16;
            end
            8'h20: begin // AHB_WR32: opcode(8) + addr(32) + wdata(32) = 72 bits
                frame     = {req.m_opcode, req.m_ahb_addr, req.m_wdata[0], 456'b0};
                frame_len = 72;
            end
            8'h21: begin // AHB_RD32: opcode(8) + addr(32) = 40 bits
                frame     = {req.m_opcode, req.m_ahb_addr, 488'b0};
                frame_len = 40;
            end
            8'h22: begin // AHB_WR_BURST: opcode(8) + burst_len(5) + rsvd(3) + addr(32) + wdata*N(32*N)
                frame     = {req.m_opcode, req.m_burst_len, 3'b000, req.m_ahb_addr};
                frame_len = 48;
                for (int i = 0; i < req.m_wdata.size(); i++) begin
                    frame = {frame, req.m_wdata[i]};
                    frame_len += 32;
                end
            end
            8'h23: begin // AHB_RD_BURST: opcode(8) + burst_len(5) + rsvd(3) + addr(32) = 48 bits
                frame     = {req.m_opcode, req.m_burst_len, 3'b000, req.m_ahb_addr, 480'b0};
                frame_len = 48;
            end
            default: begin
                frame     = '0;
                frame_len = 0;
            end
        endcase
    endfunction

    task send_frame(logic [559:0] frame, int frame_len, int bpc);
        int bits_remaining = frame_len;
        logic [559:0] shift_reg = frame;

        while (bits_remaining > 0) begin
            int shift_amount;
            int i;
            logic [15:0] pdi_val;

            shift_amount = (bits_remaining >= bpc) ? bpc : bits_remaining;
            pdi_val = '0;

            // Extract top shift_amount bits from shift_reg MSB
            for (i = 0; i < shift_amount; i++) begin
                pdi_val[shift_amount-1-i] = shift_reg[559-i];
            end
            m_vif.drv_cb.pdi_i <= pdi_val;

            shift_reg    = shift_reg << shift_amount;
            bits_remaining -= shift_amount;
            @(m_vif.drv_cb);
        end
    endtask

    function int get_bpc(logic [1:0] lane_mode);
        case (lane_mode)
            2'b00: return 1;
            2'b01: return 4;
            2'b10: return 8;
            2'b11: return 16;
        endcase
    endfunction

endclass
