// Reference model: predicts DUT output behavior from input requests
class aplc_ref_model extends uvm_component;

    `uvm_component_utils(aplc_ref_model)

    uvm_analysis_imp #(spi_xtn, aplc_ref_model) m_req_imp;

    // Expected outputs
    uvm_analysis_port #(csr_xtn) m_csr_exp_ap;
    uvm_analysis_port #(yuu_ahb_item) m_ahb_exp_ap;
    uvm_analysis_port #(spi_xtn) m_resp_exp_ap;

    // Internal state
    bit m_en;
    bit m_test_mode;
    bit [1:0] m_lane_mode;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_req_imp    = new("m_req_imp", this);
        m_csr_exp_ap = new("m_csr_exp_ap", this);
        m_ahb_exp_ap = new("m_ahb_exp_ap", this);
        m_resp_exp_ap = new("m_resp_exp_ap", this);
    endfunction

    function void write(spi_xtn req);
        predict(req);
    endfunction

    function void predict(spi_xtn req);
        bit [7:0] status;
        bit has_error;

        // Update internal state from request
        m_en        = req.en;
        m_test_mode = req.test_mode;
        m_lane_mode = req.lane_mode;

        // Check error priority chain
        check_errors(req, status, has_error);

        if (has_error) begin
            // Send error response, no downstream transactions
            send_response(req, status);
        end else begin
            // Predict downstream behavior
            predict_behavior(req);
        end
    endfunction

    function void check_errors(spi_xtn req, output bit [7:0] status, output bit has_error);
        has_error = 1;
        // Priority chain from RTM CHK_012
        if (req.frame_abort)                   status = 8'h01; // STS_FRAME_ERR
        else if (!is_legal_opcode(req.opcode)) status = 8'h02; // STS_BAD_OPCODE
        else if (!req.test_mode)               status = 8'h04; // STS_NOT_IN_TEST
        else if (!req.en)                      status = 8'h08; // STS_DISABLED
        else if (req.is_csr && req.reg_addr >= 64) status = 8'h10; // STS_BAD_REG
        else if (req.is_ahb && req.addr[1:0] != 2'b00) status = 8'h20; // STS_ALIGN_ERR
        else if (req.is_burst && !(req.burst_len inside {1, 4, 8, 16})) status = 8'h80; // STS_BAD_BURST
        else if (req.is_burst && cross_1kb_boundary(req.addr, req.burst_len)) status = 8'h81; // STS_BURST_BOUND
        else begin
            has_error = 0;
            status = 8'h00; // STS_OK
        end
    endfunction

    function bit is_legal_opcode(bit [7:0] opcode);
        return opcode inside {8'h10, 8'h11, 8'h20, 8'h21, 8'h22, 8'h23};
    endfunction

    function bit cross_1kb_boundary(bit [31:0] addr, bit [4:0] burst_len);
        bit [31:0] end_addr;
        end_addr = addr + 4 * (burst_len - 1);
        return (addr[11:9] != end_addr[11:9]) && burst_len > 1;
    endfunction

    function void predict_behavior(spi_xtn req);
        case (req.opcode)
            8'h10: predict_wr_csr(req);
            8'h11: predict_rd_csr(req);
            8'h20: predict_ahb_wr32(req);
            8'h21: predict_ahb_rd32(req);
            8'h22: predict_ahb_wr_burst(req);
            8'h23: predict_ahb_rd_burst(req);
        endcase
    endfunction

    function void predict_wr_csr(spi_xtn req);
        csr_xtn exp;
        // Predict CSR write transaction
        exp = csr_xtn::type_id::create("exp_csr_wr");
        exp.is_write = 1'b1;
        exp.addr     = req.reg_addr;
        exp.wdata    = req.wdata[0];
        m_csr_exp_ap.write(exp);
        // Predict success response
        send_response(req, 8'h00);
    endfunction

    function void predict_rd_csr(spi_xtn req);
        csr_xtn exp;
        // Predict CSR read transaction
        exp = csr_xtn::type_id::create("exp_csr_rd");
        exp.is_write = 1'b0;
        exp.addr     = req.reg_addr;
        // Read data cannot be predicted (no memory model)
        m_csr_exp_ap.write(exp);
        // Predict success response with rdata
        send_response(req, 8'h00);
    endfunction

    function void predict_ahb_wr32(spi_xtn req);
        yuu_ahb_item exp;
        exp = yuu_ahb_item::type_id::create("exp_ahb_wr");
        exp.direction   = WRITE;
        exp.burst       = SINGLE;
        exp.start_address = req.addr;
        exp.data        = new[1];
        exp.data[0]     = req.wdata[0];
        exp.len         = 0;
        exp.size        = SIZE32;
        m_ahb_exp_ap.write(exp);
        send_response(req, 8'h00);
    endfunction

    function void predict_ahb_rd32(spi_xtn req);
        yuu_ahb_item exp;
        exp = yuu_ahb_item::type_id::create("exp_ahb_rd");
        exp.direction   = READ;
        exp.burst       = SINGLE;
        exp.start_address = req.addr;
        exp.len         = 0;
        exp.size        = SIZE32;
        m_ahb_exp_ap.write(exp);
        send_response(req, 8'h00);
    endfunction

    function void predict_ahb_wr_burst(spi_xtn req);
        yuu_ahb_item exp;
        exp = yuu_ahb_item::type_id::create("exp_ahb_wr_burst");
        exp.direction   = WRITE;
        exp.start_address = req.addr;
        exp.data        = new[req.burst_len];
        foreach (exp.data[i]) exp.data[i] = req.wdata[i];
        exp.len         = req.burst_len - 1;
        exp.size        = SIZE32;
        case (req.burst_len)
            5'd4:  exp.burst = INCR4;
            5'd8:  exp.burst = INCR8;
            5'd16: exp.burst = INCR16;
            default: exp.burst = SINGLE;
        endcase
        m_ahb_exp_ap.write(exp);
        send_response(req, 8'h00);
    endfunction

    function void predict_ahb_rd_burst(spi_xtn req);
        yuu_ahb_item exp;
        exp = yuu_ahb_item::type_id::create("exp_ahb_rd_burst");
        exp.direction   = READ;
        exp.start_address = req.addr;
        exp.len         = req.burst_len - 1;
        exp.size        = SIZE32;
        case (req.burst_len)
            5'd4:  exp.burst = INCR4;
            5'd8:  exp.burst = INCR8;
            5'd16: exp.burst = INCR16;
            default: exp.burst = SINGLE;
        endcase
        m_ahb_exp_ap.write(exp);
        send_response(req, 8'h00);
    endfunction

    function void send_response(spi_xtn req, bit [7:0] status);
        spi_xtn resp;
        resp = spi_xtn::type_id::create("resp");
        resp.opcode    = req.opcode;
        resp.reg_addr  = req.reg_addr;
        resp.addr      = req.addr;
        resp.burst_len = req.burst_len;
        resp.is_read   = req.is_read;
        resp.is_csr    = req.is_csr;
        resp.is_ahb    = req.is_ahb;
        resp.is_burst  = req.is_burst;
        resp.lane_mode = req.lane_mode;
        resp.en        = req.en;
        resp.test_mode = req.test_mode;
        resp.status    = status;
        m_resp_exp_ap.write(resp);
    endfunction

endclass
