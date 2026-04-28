// APLC-Lite Reference Model
// Predicts expected AHB/CSR behavior and status codes based on input commands

class aplc_ref_model extends uvm_component;

    `uvm_component_utils(aplc_ref_model)

    uvm_analysis_imp #(aplc_spi_txn, aplc_ref_model) m_req_imp;

    uvm_analysis_port #(aplc_ahb_txn) m_ahb_exp_ap;
    uvm_analysis_port #(aplc_csr_txn) m_csr_exp_ap;
    uvm_analysis_port #(aplc_spi_txn) m_resp_exp_ap;

    localparam logic [7:0] STS_OK          = 8'h00;
    localparam logic [7:0] STS_FRAME_ERR   = 8'h01;
    localparam logic [7:0] STS_BAD_OPCODE  = 8'h02;
    localparam logic [7:0] STS_NOT_IN_TEST = 8'h04;
    localparam logic [7:0] STS_DISABLED    = 8'h08;
    localparam logic [7:0] STS_BAD_REG     = 8'h10;
    localparam logic [7:0] STS_ALIGN_ERR   = 8'h20;
    localparam logic [7:0] STS_AHB_ERR     = 8'h40;
    localparam logic [7:0] STS_BAD_BURST   = 8'h80;
    localparam logic [7:0] STS_BURST_BOUND = 8'h81;

    localparam bit [7:0] OPC_WR_CSR       = 8'h10;
    localparam bit [7:0] OPC_RD_CSR       = 8'h11;
    localparam bit [7:0] OPC_AHB_WR32     = 8'h20;
    localparam bit [7:0] OPC_AHB_RD32     = 8'h21;
    localparam bit [7:0] OPC_AHB_WR_BURST = 8'h22;
    localparam bit [7:0] OPC_AHB_RD_BURST = 8'h23;

    bit m_test_mode;
    bit m_en;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_req_imp    = new("m_req_imp",    this);
        m_ahb_exp_ap = new("m_ahb_exp_ap", this);
        m_csr_exp_ap = new("m_csr_exp_ap", this);
        m_resp_exp_ap = new("m_resp_exp_ap", this);
        m_test_mode = 1'b1;
        m_en        = 1'b1;
    endfunction

    virtual function void write(aplc_spi_txn txn);
        logic [7:0] status;
        status = check_errors(txn);

        if (status == STS_OK) begin
            predict_behavior(txn, status);
        end else begin
            predict_error_response(txn, status);
        end
    endfunction

    virtual function logic [7:0] check_errors(aplc_spi_txn txn);
        if (txn.opcode inside {8'h10, 8'h11, 8'h20, 8'h21, 8'h22, 8'h23} == 0)
            return STS_BAD_OPCODE;
        if (!m_test_mode)
            return STS_NOT_IN_TEST;
        if (!m_en)
            return STS_DISABLED;
        if (txn.opcode inside {8'h10, 8'h11} && txn.reg_addr >= 64)
            return STS_BAD_REG;
        if (txn.opcode inside {8'h20, 8'h21, 8'h22, 8'h23} && txn.addr[1:0] != 2'b00)
            return STS_ALIGN_ERR;
        if (txn.opcode inside {8'h22, 8'h23} && txn.burst_len inside {1, 4, 8, 16} == 0)
            return STS_BAD_BURST;
        if (txn.opcode inside {8'h22, 8'h23}) begin
            logic [31:0] end_addr;
            end_addr = txn.addr + 4 * (txn.burst_len - 1);
            if (txn.addr[9:0] + 4*(txn.burst_len-1) >= 1024)
                return STS_BURST_BOUND;
        end
        return STS_OK;
    endfunction

    virtual function void predict_behavior(aplc_spi_txn txn, logic [7:0] status);
        aplc_spi_txn resp_txn;
        resp_txn = aplc_spi_txn::type_id::create("resp_txn");
        resp_txn.copy(txn);
        resp_txn.status = STS_OK;

        case (txn.opcode)
            OPC_WR_CSR: begin
                aplc_csr_txn csr_exp;
                csr_exp = aplc_csr_txn::type_id::create("csr_exp");
                csr_exp.addr  = txn.reg_addr;
                csr_exp.data  = txn.wdata[0];
                csr_exp.write = 1'b1;
                m_csr_exp_ap.write(csr_exp);
                m_resp_exp_ap.write(resp_txn);
            end

            OPC_RD_CSR: begin
                aplc_csr_txn csr_exp;
                csr_exp = aplc_csr_txn::type_id::create("csr_exp");
                csr_exp.addr  = txn.reg_addr;
                csr_exp.write = 1'b0;
                m_csr_exp_ap.write(csr_exp);
                resp_txn.has_rdata = 1'b1;
                m_resp_exp_ap.write(resp_txn);
            end

            OPC_AHB_WR32: begin
                aplc_ahb_txn ahb_exp;
                ahb_exp = aplc_ahb_txn::type_id::create("ahb_exp");
                ahb_exp.addr  = txn.addr;
                ahb_exp.data  = new[1];
                ahb_exp.data[0] = txn.wdata[0];
                ahb_exp.write = 1'b1;
                ahb_exp.burst = 3'b000;
                ahb_exp.burst_len = 1;
                m_ahb_exp_ap.write(ahb_exp);
                m_resp_exp_ap.write(resp_txn);
            end

            OPC_AHB_RD32: begin
                aplc_ahb_txn ahb_exp;
                ahb_exp = aplc_ahb_txn::type_id::create("ahb_exp");
                ahb_exp.addr  = txn.addr;
                ahb_exp.write = 1'b0;
                ahb_exp.burst = 3'b000;
                ahb_exp.burst_len = 1;
                ahb_exp.data  = new[1];
                m_ahb_exp_ap.write(ahb_exp);
                resp_txn.has_rdata = 1'b1;
                m_resp_exp_ap.write(resp_txn);
            end

            OPC_AHB_WR_BURST: begin
                aplc_ahb_txn ahb_exp;
                ahb_exp = aplc_ahb_txn::type_id::create("ahb_exp");
                ahb_exp.addr  = txn.addr;
                ahb_exp.data  = new[txn.burst_len];
                for (int i = 0; i < txn.burst_len; i++)
                    ahb_exp.data[i] = txn.wdata[i];
                ahb_exp.write = 1'b1;
                ahb_exp.burst = get_hburst(txn.burst_len);
                ahb_exp.burst_len = txn.burst_len;
                m_ahb_exp_ap.write(ahb_exp);
                m_resp_exp_ap.write(resp_txn);
            end

            OPC_AHB_RD_BURST: begin
                aplc_ahb_txn ahb_exp;
                ahb_exp = aplc_ahb_txn::type_id::create("ahb_exp");
                ahb_exp.addr  = txn.addr;
                ahb_exp.write = 1'b0;
                ahb_exp.burst = get_hburst(txn.burst_len);
                ahb_exp.burst_len = txn.burst_len;
                ahb_exp.data  = new[txn.burst_len];
                m_ahb_exp_ap.write(ahb_exp);
                resp_txn.has_rdata = 1'b1;
                m_resp_exp_ap.write(resp_txn);
            end

            default: begin
                resp_txn.status = STS_BAD_OPCODE;
                m_resp_exp_ap.write(resp_txn);
            end
        endcase
    endfunction

    virtual function void predict_error_response(aplc_spi_txn txn, logic [7:0] status);
        aplc_spi_txn resp_txn;
        resp_txn = aplc_spi_txn::type_id::create("resp_txn");
        resp_txn.copy(txn);
        resp_txn.status = status;
        m_resp_exp_ap.write(resp_txn);
    endfunction

    virtual function logic [2:0] get_hburst(logic [4:0] burst_len);
        case (burst_len)
            5'd1:  return 3'b000;
            5'd4:  return 3'b011;
            5'd8:  return 3'b101;
            5'd16: return 3'b111;
            default: return 3'b000;
        endcase
    endfunction

endclass
