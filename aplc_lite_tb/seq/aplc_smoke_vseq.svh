// APLC-Lite Smoke Test Virtual Sequence
// Strategy: Use 1-bit mode (reset default) for initial CTRL configuration,
// then switch to 16-bit for all subsequent transactions.
class aplc_smoke_vseq extends aplc_base_vseq;

    `uvm_object_utils(aplc_smoke_vseq)

    localparam logic [1:0] LANE_1BIT  = 2'b00;
    localparam logic [1:0] LANE_16BIT = 2'b11;

    function new(string name = "aplc_smoke_vseq");
        super.new(name);
    endfunction

    task body();
        logic [7:0]  status;
        logic [31:0] rdata;
        int pass_cnt, fail_cnt;
        pass_cnt = 0;
        fail_cnt = 0;

        `uvm_info(get_type_name(), "=== APLC Smoke Test ===", UVM_LOW)

        // Wait for reset to deassert
        #200ns;

        // Phase 1: 1-bit mode (DUT reset default)
        // Write CTRL to enable DUT: en=1, lane_mode=16-bit, test_mode=1
        `uvm_info(get_type_name(), "Test 1 (1-bit): WR_CSR CTRL = 0x111", UVM_LOW)
        send_wr_csr(8'h04, 32'h0000_0111, LANE_1BIT, status);
        if (status == 8'h00) begin
            `uvm_info(get_type_name(), "  PASS: CTRL write STS_OK", UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf("  FAIL: CTRL write status=0x%02h", status))
            fail_cnt++;
        end

        // Verify CTRL in 1-bit mode first (to confirm write committed)
        `uvm_info(get_type_name(), "Test 2 (1-bit): RD_CSR CTRL", UVM_LOW)
        send_rd_csr(8'h04, LANE_1BIT, status, rdata);
        if (status == 8'h00 && rdata == 32'h0000_0111) begin
            `uvm_info(get_type_name(), $sformatf("  PASS: CTRL=0x%08h (1-bit)", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf("  FAIL: CTRL (1-bit) status=0x%02h rdata=0x%08h (expected 0x00000111)", status, rdata))
            fail_cnt++;
        end

        // Phase 2: 16-bit mode (DUT now configured for 16-bit)
        // Verify CTRL in 16-bit mode
        `uvm_info(get_type_name(), "Test 3 (16-bit): RD_CSR CTRL", UVM_LOW)
        send_rd_csr(8'h04, LANE_16BIT, status, rdata);
        if (status == 8'h00 && rdata == 32'h0000_0111) begin
            `uvm_info(get_type_name(), $sformatf("  PASS: CTRL=0x%08h (16-bit)", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf("  FAIL: CTRL (16-bit) status=0x%02h rdata=0x%08h (expected 0x00000111)", status, rdata))
            fail_cnt++;
        end

        // Read VERSION
        `uvm_info(get_type_name(), "Test 4 (16-bit): RD_CSR VERSION", UVM_LOW)
        send_rd_csr(8'h00, LANE_16BIT, status, rdata);
        if (status == 8'h00) begin
            `uvm_info(get_type_name(), $sformatf("  PASS: VERSION=0x%08h", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf("  FAIL: VERSION status=0x%02h", status))
            fail_cnt++;
        end

        // Read STATUS
        `uvm_info(get_type_name(), "Test 5 (16-bit): RD_CSR STATUS", UVM_LOW)
        send_rd_csr(8'h08, LANE_16BIT, status, rdata);
        if (status == 8'h00) begin
            `uvm_info(get_type_name(), $sformatf("  PASS: STATUS=0x%08h", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf("  FAIL: STATUS status=0x%02h", status))
            fail_cnt++;
        end

        // Read LAST_ERR
        `uvm_info(get_type_name(), "Test 6 (16-bit): RD_CSR LAST_ERR", UVM_LOW)
        send_rd_csr(8'h0C, LANE_16BIT, status, rdata);
        if (status == 8'h00) begin
            `uvm_info(get_type_name(), $sformatf("  PASS: LAST_ERR=0x%08h", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf("  FAIL: LAST_ERR status=0x%02h", status))
            fail_cnt++;
        end

        // Read BURST_CNT
        `uvm_info(get_type_name(), "Test 7 (16-bit): RD_CSR BURST_CNT", UVM_LOW)
        send_rd_csr(8'h10, LANE_16BIT, status, rdata);
        if (status == 8'h00) begin
            `uvm_info(get_type_name(), $sformatf("  PASS: BURST_CNT=0x%08h", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf("  FAIL: BURST_CNT status=0x%02h", status))
            fail_cnt++;
        end

        // AHB WR/RD
        `uvm_info(get_type_name(), "Test 8 (16-bit): AHB_WR32/AHB_RD32", UVM_LOW)
        send_ahb_wr32(32'h0001_0000, 32'hDEAD_BEEF, LANE_16BIT, status);
        if (status == 8'h00) begin
            `uvm_info(get_type_name(), "  PASS: AHB_WR32 STS_OK", UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf("  FAIL: AHB_WR32 status=0x%02h", status))
            fail_cnt++;
        end
        send_ahb_rd32(32'h0001_0000, LANE_16BIT, status, rdata);
        if (status == 8'h00) begin
            `uvm_info(get_type_name(), $sformatf("  PASS: AHB_RD32 STS_OK, rdata=0x%08h", rdata), UVM_LOW)
            pass_cnt++;
        end else begin
            `uvm_error(get_type_name(), $sformatf("  FAIL: AHB_RD32 status=0x%02h", status))
            fail_cnt++;
        end

        // Summary
        `uvm_info(get_type_name(), $sformatf("=== Smoke Test Summary: PASS=%0d FAIL=%0d ===", pass_cnt, fail_cnt), UVM_NONE)
        if (fail_cnt > 0) begin
            `uvm_error(get_type_name(), "SMOKE TEST FAILED")
        end else begin
            `uvm_info(get_type_name(), "SMOKE TEST PASSED", UVM_NONE)
        end
    endtask

endclass
