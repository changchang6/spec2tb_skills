class aplc_smoke_vseq extends aplc_base_vseq;

    `uvm_object_utils(aplc_smoke_vseq)

    function new(string name = "aplc_smoke_vseq");
        super.new(name);
    endfunction

    task body();
        // Wait for reset to complete
        #200ns;

        // 1. Read VERSION register (addr=0x00), expect 0x0000_0220
        `uvm_info(get_type_name(), "Smoke: RD_CSR VERSION (0x00)", UVM_LOW)
        send_rd_csr(8'h00);
        #500ns;

        // 2. Write CTRL register (addr=0x04), then read back
        `uvm_info(get_type_name(), "Smoke: WR_CSR CTRL (0x04) = 0x0000_0007", UVM_LOW)
        send_wr_csr(8'h04, 32'h0000_0007);
        #500ns;

        `uvm_info(get_type_name(), "Smoke: RD_CSR CTRL (0x04)", UVM_LOW)
        send_rd_csr(8'h04);
        #500ns;

        // 3. Read STATUS register (addr=0x08)
        `uvm_info(get_type_name(), "Smoke: RD_CSR STATUS (0x08)", UVM_LOW)
        send_rd_csr(8'h08);
        #500ns;

        // 4. Read LAST_ERR register (addr=0x0C)
        `uvm_info(get_type_name(), "Smoke: RD_CSR LAST_ERR (0x0C)", UVM_LOW)
        send_rd_csr(8'h0C);
        #500ns;

        // 5. Test error: send WR_CSR with bad addr (>= 0x40)
        `uvm_info(get_type_name(), "Smoke: WR_CSR bad addr (0x40) -> expect STS_BAD_REG", UVM_LOW)
        begin
            spi_xtn req;
            req = spi_xtn::type_id::create("req");
            req.opcode    = 8'h10;
            req.reg_addr  = 8'h40;
            req.wdata     = new[1];
            req.wdata[0]  = 32'hAAAA_BBBB;
            req.lane_mode = 2'b11;
            req.en        = 1'b1;
            req.test_mode = 1'b1;
            req.burst_len = 0;
            `uvm_send(req)
        end
        #500ns;

        // 6. Test AHB_WR32 to a valid address
        `uvm_info(get_type_name(), "Smoke: AHB_WR32 addr=0x1000_0000", UVM_LOW)
        send_ahb_wr32(32'h1000_0000, 32'h1234_5678);
        #500ns;

        // 7. Test AHB_RD32 from same address
        `uvm_info(get_type_name(), "Smoke: AHB_RD32 addr=0x1000_0000", UVM_LOW)
        send_ahb_rd32(32'h1000_0000);
        #500ns;

        // 8. Test error: AHB command with unaligned address
        `uvm_info(get_type_name(), "Smoke: AHB_WR32 unaligned addr -> expect STS_ALIGN_ERR", UVM_LOW)
        begin
            spi_xtn req;
            req = spi_xtn::type_id::create("req");
            req.opcode    = 8'h20;
            req.addr      = 32'h1000_0001; // not 4-byte aligned
            req.wdata     = new[1];
            req.wdata[0]  = 32'hDEAD_BEEF;
            req.lane_mode = 2'b11;
            req.en        = 1'b1;
            req.test_mode = 1'b1;
            req.burst_len = 0;
            `uvm_send(req)
        end
        #500ns;

        // 9. Test error: en=0
        `uvm_info(get_type_name(), "Smoke: WR_CSR with en=0 -> expect STS_DISABLED", UVM_LOW)
        send_req_with_config(8'h10, 8'h00, 32'h0, 1'b0, 1'b1);
        #500ns;

        // 10. Test error: test_mode=0
        `uvm_info(get_type_name(), "Smoke: WR_CSR with test_mode=0 -> expect STS_NOT_IN_TEST", UVM_LOW)
        send_req_with_config(8'h10, 8'h00, 32'h0, 1'b1, 1'b0);
        #500ns;

        `uvm_info(get_type_name(), "Smoke test sequence completed", UVM_LOW)
    endtask

endclass
