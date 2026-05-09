// APLC Reference Model - Pure functional predictor
class aplc_ref_model extends uvm_component;

    `uvm_component_utils(aplc_ref_model)

    // Input: SPI request from monitor
    uvm_analysis_imp #(aplc_spi_transaction, aplc_ref_model) m_req_imp;

    // Output: expected transactions to scoreboard
    uvm_analysis_port #(aplc_csr_transaction)  m_csr_exp_ap;
    uvm_analysis_port #(aplc_spi_transaction)  m_resp_exp_ap;

    // Shadow state
    aplc_csr_shadow m_csr;

    // AHB shadow memory for predicting read data
    logic [31:0] m_ahb_mem[logic [31:0]];

    static string msg_id = "APLC_REF_MODEL";

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_req_imp    = new("m_req_imp", this);
        m_csr_exp_ap = new("m_csr_exp_ap", this);
        m_resp_exp_ap = new("m_resp_exp_ap", this);
        m_csr = aplc_csr_shadow::type_id::create("m_csr");
        m_csr.init();
    endfunction

    function void write(aplc_spi_transaction req);
        logic [7:0] status;
        bit         has_error;

        `uvm_info(msg_id, $sformatf("Processing request: %s", req.convert2string()), UVM_HIGH)

        // Update config state from request
        m_csr.m_en        = req.m_en;
        m_csr.m_test_mode = req.m_test_mode;
        m_csr.m_lane_mode = req.m_lane_mode;
        m_csr.update_ctrl_from_ports();

        // Check errors by priority
        check_errors(req, status, has_error);

        if (has_error) begin
            m_csr.update_status_on_error(status);
            send_error_response(status, req);
        end else begin
            predict_behavior(req);
        end
    endfunction

    function void check_errors(aplc_spi_transaction req, output logic [7:0] status, output bit has_error);
        has_error = 1;

        // Priority 1: FRAME_ERR
        if (req.m_frame_abort)
            status = STS_FRAME_ERR;
        // Priority 2: BAD_OPCODE
        else if (!(req.m_opcode inside {OPC_WR_CSR, OPC_RD_CSR, OPC_AHB_WR32, OPC_AHB_RD32, OPC_AHB_WR_BURST, OPC_AHB_RD_BURST}))
            status = STS_BAD_OPCODE;
        // Priority 3: NOT_IN_TEST
        else if (!m_csr.m_test_mode)
            status = STS_NOT_IN_TEST;
        // Priority 4: DISABLED
        else if (!m_csr.m_en)
            status = STS_DISABLED;
        // Priority 5: BAD_REG (CSR commands with addr >= 0x40)
        else if (req.is_csr_cmd() && req.m_reg_addr >= 8'h40)
            status = STS_BAD_REG;
        // Priority 6: ALIGN_ERR (AHB commands with non-aligned addr)
        else if (req.is_ahb_cmd() && req.m_ahb_addr[1:0] != 2'b00)
            status = STS_ALIGN_ERR;
        // Priority 7: BAD_BURST (burst_len not in {1,4,8,16})
        else if (req.is_burst_cmd() && !(req.m_burst_len inside {5'd1, 5'd4, 5'd8, 5'd16}))
            status = STS_BAD_BURST;
        // Priority 8: BURST_BOUND (burst crosses 1KB boundary)
        else if (req.is_burst_cmd() && crosses_1kb_boundary(req.m_ahb_addr, req.m_burst_len))
            status = STS_BURST_BOUND;
        else begin
            has_error = 0;
            status = STS_OK;
        end
    endfunction

    function bit crosses_1kb_boundary(logic [31:0] addr, logic [4:0] burst_len);
        logic [31:0] last_addr;
        last_addr = addr + (burst_len - 1) * 4;
        if (addr[31:10] != last_addr[31:10]) return 1;
        return 0;
    endfunction

    function void predict_behavior(aplc_spi_transaction req);
        case (req.m_opcode)
            OPC_WR_CSR: begin
                // Update CSR shadow
                m_csr.write_csr(req.m_reg_addr, req.m_wdata[0]);
                // Send expected CSR write transaction
                send_csr_expected(1, req.m_reg_addr, req.m_wdata[0], 32'h0);
                // Send OK response
                send_ok_response(req, 32'h0, 0);
            end
            OPC_RD_CSR: begin
                logic [31:0] expected_rdata;
                expected_rdata = m_csr.read_csr(req.m_reg_addr);
                // Send expected CSR read transaction
                send_csr_expected(0, req.m_reg_addr, 32'h0, expected_rdata);
                // Send OK response with predicted rdata
                send_ok_response(req, expected_rdata, 1);
            end
            OPC_AHB_WR32: begin
                // Update shadow memory
                m_ahb_mem[req.m_ahb_addr] = req.m_wdata[0];
                // Send OK response
                send_ok_response(req, 32'h0, 0);
            end
            OPC_AHB_RD32: begin
                logic [31:0] expected_rdata;
                if (m_ahb_mem.exists(req.m_ahb_addr))
                    expected_rdata = m_ahb_mem[req.m_ahb_addr];
                else
                    expected_rdata = 32'h0;
                // Send OK response with predicted rdata
                send_ok_response(req, expected_rdata, 1);
            end
            OPC_AHB_WR_BURST: begin
                // Update shadow memory for each beat
                for (int i = 0; i < req.m_wdata.size(); i++) begin
                    m_ahb_mem[req.m_ahb_addr + i*4] = req.m_wdata[i];
                end
                // Increment burst counter
                m_csr.m_burst_cnt_shadow++;
                // Send OK response
                send_ok_response(req, 32'h0, 0);
            end
            OPC_AHB_RD_BURST: begin
                // Send OK response with predicted rdata for each beat
                aplc_spi_transaction resp;
                resp = aplc_spi_transaction::type_id::create("resp_exp");
                resp.m_status    = STS_OK;
                resp.m_opcode    = req.m_opcode;
                resp.m_has_rdata = 1;
                resp.m_rdata     = new[req.m_burst_len];
                for (int i = 0; i < req.m_burst_len; i++) begin
                    logic [31:0] addr_i;
                    addr_i = req.m_ahb_addr + i*4;
                    if (m_ahb_mem.exists(addr_i))
                        resp.m_rdata[i] = m_ahb_mem[addr_i];
                    else
                        resp.m_rdata[i] = 32'h0;
                end
                m_csr.m_burst_cnt_shadow++;
                m_resp_exp_ap.write(resp);
            end
            default: ;
        endcase
    endfunction

    function void send_csr_expected(bit write, logic [7:0] addr, logic [31:0] wdata, logic [31:0] rdata);
        aplc_csr_transaction csr_xtn;
        csr_xtn = aplc_csr_transaction::type_id::create("csr_exp");
        csr_xtn.m_write = write;
        csr_xtn.m_addr  = addr;
        csr_xtn.m_wdata = wdata;
        csr_xtn.m_rdata = rdata;
        m_csr_exp_ap.write(csr_xtn);
    endfunction

    function void send_ok_response(aplc_spi_transaction req, logic [31:0] rdata, bit has_rdata);
        aplc_spi_transaction resp;
        resp = aplc_spi_transaction::type_id::create("resp_exp");
        resp.m_status    = STS_OK;
        resp.m_opcode    = req.m_opcode;
        resp.m_has_rdata = has_rdata;
        if (has_rdata) begin
            resp.m_rdata = new[1];
            resp.m_rdata[0] = rdata;
        end
        m_resp_exp_ap.write(resp);
    endfunction

    function void send_error_response(logic [7:0] status, aplc_spi_transaction req);
        aplc_spi_transaction resp;
        resp = aplc_spi_transaction::type_id::create("resp_exp_err");
        resp.m_status    = status;
        resp.m_opcode    = req.m_opcode;
        resp.m_has_rdata = 0;
        m_resp_exp_ap.write(resp);
    endfunction

endclass
