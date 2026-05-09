// APLC Smoke Test Virtual Sequence
class aplc_smoke_vseq extends aplc_base_vseq;

    `uvm_object_utils(aplc_smoke_vseq)

    aplc_spi_agent m_spi_agent;

    function new(string name = "aplc_smoke_vseq");
        super.new(name);
    endfunction

    task body();
        aplc_spi_transaction req;

        // Step 1: WR_CSR to CTRL (0x04) with en=1, lane_mode=11, test_mode=1
        req = aplc_spi_transaction::type_id::create("wr_ctrl");
        req.m_opcode    = 8'h10;
        req.m_reg_addr  = 8'h04;
        req.m_wdata     = new[1];
        req.m_wdata[0]  = 32'h0000_000F; // en=1, lane=11, test_mode=1
        req.m_burst_len = 5'd0;
        req.m_lane_mode = 2'b11;
        req.m_en        = 1;
        req.m_test_mode = 1;
        req.m_is_write  = 1;
        `uvm_info(get_type_name(), "Smoke: WR_CSR CTRL=0x0F", UVM_LOW)
        start_item(req);
        finish_item(req);

        // Step 2: RD_CSR VERSION (0x00) - expect 0x00000220
        req = aplc_spi_transaction::type_id::create("rd_version");
        req.m_opcode    = 8'h11;
        req.m_reg_addr  = 8'h00;
        req.m_burst_len = 5'd0;
        req.m_lane_mode = 2'b11;
        req.m_en        = 1;
        req.m_test_mode = 1;
        req.m_is_write  = 0;
        `uvm_info(get_type_name(), "Smoke: RD_CSR VERSION", UVM_LOW)
        start_item(req);
        finish_item(req);

        // Step 3: RD_CSR CTRL (0x04) - expect mirror of port inputs
        req = aplc_spi_transaction::type_id::create("rd_ctrl");
        req.m_opcode    = 8'h11;
        req.m_reg_addr  = 8'h04;
        req.m_burst_len = 5'd0;
        req.m_lane_mode = 2'b11;
        req.m_en        = 1;
        req.m_test_mode = 1;
        req.m_is_write  = 0;
        `uvm_info(get_type_name(), "Smoke: RD_CSR CTRL", UVM_LOW)
        start_item(req);
        finish_item(req);

        // Step 4: RD_CSR STATUS (0x08)
        req = aplc_spi_transaction::type_id::create("rd_status");
        req.m_opcode    = 8'h11;
        req.m_reg_addr  = 8'h08;
        req.m_burst_len = 5'd0;
        req.m_lane_mode = 2'b11;
        req.m_en        = 1;
        req.m_test_mode = 1;
        req.m_is_write  = 0;
        `uvm_info(get_type_name(), "Smoke: RD_CSR STATUS", UVM_LOW)
        start_item(req);
        finish_item(req);

        // Step 5: AHB_WR32 addr=0x00010000, data=0xDEADBEEF
        req = aplc_spi_transaction::type_id::create("ahb_wr");
        req.m_opcode    = 8'h20;
        req.m_ahb_addr  = 32'h0001_0000;
        req.m_wdata     = new[1];
        req.m_wdata[0]  = 32'hDEAD_BEEF;
        req.m_burst_len = 5'd0;
        req.m_lane_mode = 2'b11;
        req.m_en        = 1;
        req.m_test_mode = 1;
        req.m_is_write  = 1;
        `uvm_info(get_type_name(), "Smoke: AHB_WR32 addr=0x10000 data=0xDEADBEEF", UVM_LOW)
        start_item(req);
        finish_item(req);

        // Step 6: AHB_RD32 addr=0x00010000 - expect 0xDEADBEEF
        req = aplc_spi_transaction::type_id::create("ahb_rd");
        req.m_opcode    = 8'h21;
        req.m_ahb_addr  = 32'h0001_0000;
        req.m_burst_len = 5'd0;
        req.m_lane_mode = 2'b11;
        req.m_en        = 1;
        req.m_test_mode = 1;
        req.m_is_write  = 0;
        `uvm_info(get_type_name(), "Smoke: AHB_RD32 addr=0x10000", UVM_LOW)
        start_item(req);
        finish_item(req);

        // Step 7: WR_CSR BURST_CNT (0x10) - WC clear
        req = aplc_spi_transaction::type_id::create("wr_burst_cnt");
        req.m_opcode    = 8'h10;
        req.m_reg_addr  = 8'h10;
        req.m_wdata     = new[1];
        req.m_wdata[0]  = 32'h0000_0001;
        req.m_burst_len = 5'd0;
        req.m_lane_mode = 2'b11;
        req.m_en        = 1;
        req.m_test_mode = 1;
        req.m_is_write  = 1;
        `uvm_info(get_type_name(), "Smoke: WR_CSR BURST_CNT (WC clear)", UVM_LOW)
        start_item(req);
        finish_item(req);

        // Step 8: RD_CSR BURST_CNT (0x10) - expect 0 after WC clear
        req = aplc_spi_transaction::type_id::create("rd_burst_cnt");
        req.m_opcode    = 8'h11;
        req.m_reg_addr  = 8'h10;
        req.m_burst_len = 5'd0;
        req.m_lane_mode = 2'b11;
        req.m_en        = 1;
        req.m_test_mode = 1;
        req.m_is_write  = 0;
        `uvm_info(get_type_name(), "Smoke: RD_CSR BURST_CNT", UVM_LOW)
        start_item(req);
        finish_item(req);

        `uvm_info(get_type_name(), "Smoke test sequence completed", UVM_LOW)
    endtask

endclass
