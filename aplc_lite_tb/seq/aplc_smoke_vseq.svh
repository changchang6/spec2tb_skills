// APLC Smoke Test Virtual Sequence
// Tests CSR write then readback, and VERSION register read

class aplc_smoke_vseq extends aplc_base_vseq;

    `uvm_object_utils(aplc_smoke_vseq)

    function new(string name = "aplc_smoke_vseq");
        super.new(name);
    endfunction

    task body();
        spi_xtn req;
        ahb_ready_sseq ahb_seq;

        // Start AHB slave response sequence in background
        fork
            forever begin
                ahb_seq = ahb_ready_sseq::type_id::create("ahb_seq");
                ahb_seq.start(p_sequencer.m_ahb_sseqr);
            end
        join_none

        // Wait for reset to release and DUT to stabilize
        #1us;

        // Test 1: Write CTRL register (addr=0x04) with known value
        `uvm_info("SMOKE", "=== Test 1: WR_CSR to CTRL (0x04) ===", UVM_LOW)
        req = spi_xtn::type_id::create("req");
        start_item(req, , p_sequencer.m_spi_seqr);
        req.m_opcode    = 8'h10; // WR_CSR
        req.m_reg_addr  = 8'h04;
        req.m_wdata     = 32'hDEAD_BEEF;
        req.m_lane_mode = 2'b00; // 1-bit lane
        finish_item(req);

        `uvm_info("SMOKE", $sformatf("WR_CSR response: status=0x%02h", req.m_resp_status), UVM_LOW)
        if (req.m_resp_status != 8'h00) begin
            `uvm_error("SMOKE", $sformatf("WR_CSR failed with status=0x%02h", req.m_resp_status))
        end

        #500ns;

        // Test 2: Read back CTRL register
        `uvm_info("SMOKE", "=== Test 2: RD_CSR from CTRL (0x04) ===", UVM_LOW)
        req = spi_xtn::type_id::create("req2");
        start_item(req, , p_sequencer.m_spi_seqr);
        req.m_opcode    = 8'h11; // RD_CSR
        req.m_reg_addr  = 8'h04;
        req.m_lane_mode = 2'b00;
        finish_item(req);

        `uvm_info("SMOKE", $sformatf("RD_CSR response: status=0x%02h rdata=0x%08h has_rdata=%0b",
                  req.m_resp_status, req.m_resp_rdata, req.m_resp_has_rdata), UVM_LOW)

        if (req.m_resp_status != 8'h00) begin
            `uvm_error("SMOKE", $sformatf("RD_CSR CTRL failed with status=0x%02h", req.m_resp_status))
        end else if (req.m_resp_has_rdata && req.m_resp_rdata !== 32'hDEAD_BEEF) begin
            `uvm_error("SMOKE", $sformatf("CTRL readback mismatch: expected 0xDEADBEEF, got 0x%08h", req.m_resp_rdata))
        end else begin
            `uvm_info("SMOKE", "CTRL readback PASSED!", UVM_LOW)
        end

        #500ns;

        // Test 3: Read VERSION register (RO, addr=0x00)
        `uvm_info("SMOKE", "=== Test 3: RD_CSR from VERSION (0x00) ===", UVM_LOW)
        req = spi_xtn::type_id::create("req3");
        start_item(req, , p_sequencer.m_spi_seqr);
        req.m_opcode    = 8'h11; // RD_CSR
        req.m_reg_addr  = 8'h00;
        req.m_lane_mode = 2'b00;
        finish_item(req);

        `uvm_info("SMOKE", $sformatf("RD_CSR VERSION response: status=0x%02h rdata=0x%08h",
                  req.m_resp_status, req.m_resp_rdata), UVM_LOW)

        if (req.m_resp_status != 8'h00) begin
            `uvm_error("SMOKE", $sformatf("RD_CSR VERSION failed with status=0x%02h", req.m_resp_status))
        end else if (req.m_resp_has_rdata) begin
            `uvm_info("SMOKE", $sformatf("VERSION = 0x%08h (readback check)", req.m_resp_rdata), UVM_LOW)
        end

        // Allow drain time
        #1us;
    endtask

endclass
