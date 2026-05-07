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
        check_csr_rd(8'h00, 32'h0000_0220, "VERSION");
        #500ns;

        // 2. Write CTRL register (addr=0x04), then read back
        `uvm_info(get_type_name(), "Smoke: WR_CSR CTRL (0x04) = 0x0000_0007", UVM_LOW)
        send_wr_csr(8'h04, 32'h0000_0007);
        check_wr_status("CTRL write");
        #500ns;

        `uvm_info(get_type_name(), "Smoke: RD_CSR CTRL (0x04)", UVM_LOW)
        send_rd_csr(8'h04);
        check_csr_rd(8'h04, 32'h0000_000F, "CTRL read-back");
        #500ns;

        // 3. Read STATUS register (addr=0x08)
        `uvm_info(get_type_name(), "Smoke: RD_CSR STATUS (0x08)", UVM_LOW)
        send_rd_csr(8'h08);
        check_csr_rd_status("STATUS");
        #500ns;

        // 4. Read LAST_ERR register (addr=0x0C)
        `uvm_info(get_type_name(), "Smoke: RD_CSR LAST_ERR (0x0C)", UVM_LOW)
        send_rd_csr(8'h0C);
        check_csr_rd_status("LAST_ERR");
        #500ns;

        // 5. AHB write then read-back at address 0x0000_1000
        `uvm_info(get_type_name(), "Smoke: AHB_WR32 addr=0x1000 data=0xDEAD_BEEF", UVM_LOW)
        send_ahb_wr32(32'h0000_1000, 32'hDEAD_BEEF);
        check_ahb_wr_status("AHB_WR32 @0x1000");
        #500ns;

        `uvm_info(get_type_name(), "Smoke: AHB_RD32 addr=0x1000", UVM_LOW)
        send_ahb_rd32(32'h0000_1000);
        check_ahb_rd(32'h0000_1000, 32'hDEAD_BEEF, "AHB_RD32 @0x1000");
        #500ns;

        // 6. AHB write then read-back at a different address
        `uvm_info(get_type_name(), "Smoke: AHB_WR32 addr=0x2000 data=0x1234_5678", UVM_LOW)
        send_ahb_wr32(32'h0000_2000, 32'h1234_5678);
        check_ahb_wr_status("AHB_WR32 @0x2000");
        #500ns;

        `uvm_info(get_type_name(), "Smoke: AHB_RD32 addr=0x2000", UVM_LOW)
        send_ahb_rd32(32'h0000_2000);
        check_ahb_rd(32'h0000_2000, 32'h1234_5678, "AHB_RD32 @0x2000");
        #500ns;

        // 7. Verify first address still retains its value
        `uvm_info(get_type_name(), "Smoke: AHB_RD32 addr=0x1000 (retain check)", UVM_LOW)
        send_ahb_rd32(32'h0000_1000);
        check_ahb_rd(32'h0000_1000, 32'hDEAD_BEEF, "AHB_RD32 @0x1000 retain");
        #500ns;

        `uvm_info(get_type_name(), "Smoke test sequence completed", UVM_LOW)
    endtask

    // Check CSR read: verify status==STS_OK and rdata==expected
    task check_csr_rd(bit [7:0] addr, bit [31:0] exp_data, string reg_name);
        if (last_rsp_status != 8'h00) begin
            `uvm_error(get_type_name(), $sformatf("CSR RD %s (0x%02h) FAIL: status=0x%02h (expected 0x00)",
                reg_name, addr, last_rsp_status))
        end else if (last_rsp_rdata !== exp_data) begin
            `uvm_error(get_type_name(), $sformatf("CSR RD %s (0x%02h) DATA MISMATCH: rdata=0x%08h expected=0x%08h",
                reg_name, addr, last_rsp_rdata, exp_data))
        end else begin
            `uvm_info(get_type_name(), $sformatf("CSR RD %s (0x%02h) PASS: rdata=0x%08h",
                reg_name, addr, last_rsp_rdata), UVM_LOW)
        end
    endtask

    // Check CSR read: verify status==STS_OK only (rdata unknown)
    task check_csr_rd_status(string reg_name);
        if (last_rsp_status != 8'h00) begin
            `uvm_error(get_type_name(), $sformatf("CSR RD %s FAIL: status=0x%02h (expected 0x00)",
                reg_name, last_rsp_status))
        end else begin
            `uvm_info(get_type_name(), $sformatf("CSR RD %s PASS: status=OK rdata=0x%08h",
                reg_name, last_rsp_rdata), UVM_LOW)
        end
    endtask

    // Check write status (CSR or AHB)
    task check_wr_status(string op_name);
        if (last_rsp_status != 8'h00) begin
            `uvm_error(get_type_name(), $sformatf("CSR WR %s FAIL: status=0x%02h (expected 0x00)",
                op_name, last_rsp_status))
        end else begin
            `uvm_info(get_type_name(), $sformatf("CSR WR %s PASS: status=OK", op_name), UVM_LOW)
        end
    endtask

    // Check AHB write status
    task check_ahb_wr_status(string op_name);
        if (last_rsp_status != 8'h00) begin
            `uvm_error(get_type_name(), $sformatf("%s FAIL: status=0x%02h (expected 0x00)",
                op_name, last_rsp_status))
        end else begin
            `uvm_info(get_type_name(), $sformatf("%s PASS: status=OK", op_name), UVM_LOW)
        end
    endtask

    // Check AHB read: verify status==STS_OK and rdata==expected
    task check_ahb_rd(bit [31:0] addr, bit [31:0] exp_data, string op_name);
        if (last_rsp_status != 8'h00) begin
            `uvm_error(get_type_name(), $sformatf("%s FAIL: status=0x%02h (expected 0x00)",
                op_name, last_rsp_status))
        end else if (last_rsp_rdata !== exp_data) begin
            `uvm_error(get_type_name(), $sformatf("%s DATA MISMATCH: rdata=0x%08h expected=0x%08h",
                op_name, last_rsp_rdata, exp_data))
        end else begin
            `uvm_info(get_type_name(), $sformatf("%s PASS: rdata=0x%08h", op_name, last_rsp_rdata), UVM_LOW)
        end
    endtask

endclass
