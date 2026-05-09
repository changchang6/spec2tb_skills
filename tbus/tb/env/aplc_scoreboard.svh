// APLC Scoreboard - Multi-channel comparison
class aplc_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(aplc_scoreboard)

    // CSR channel
    `uvm_analysis_imp_decl(_csr_exp)
    `uvm_analysis_imp_decl(_csr_act)

    uvm_analysis_imp_csr_exp #(aplc_csr_transaction, aplc_scoreboard) m_csr_exp_imp;
    uvm_analysis_imp_csr_act #(aplc_csr_transaction, aplc_scoreboard) m_csr_act_imp;
    uvm_tlm_analysis_fifo #(aplc_csr_transaction) m_csr_exp_fifo;
    uvm_tlm_analysis_fifo #(aplc_csr_transaction) m_csr_act_fifo;

    // Response channel
    `uvm_analysis_imp_decl(_resp_exp)
    `uvm_analysis_imp_decl(_resp_act)

    uvm_analysis_imp_resp_exp #(aplc_spi_transaction, aplc_scoreboard) m_resp_exp_imp;
    uvm_analysis_imp_resp_act #(aplc_spi_transaction, aplc_scoreboard) m_resp_act_imp;
    uvm_tlm_analysis_fifo #(aplc_spi_transaction) m_resp_exp_fifo;
    uvm_tlm_analysis_fifo #(aplc_spi_transaction) m_resp_act_fifo;

    // Counters
    int m_csr_match_count;
    int m_csr_mismatch_count;
    int m_resp_match_count;
    int m_resp_mismatch_count;

    static string msg_id = "APLC_SCOREBOARD";

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_csr_exp_imp  = new("m_csr_exp_imp", this);
        m_csr_act_imp  = new("m_csr_act_imp", this);
        m_csr_exp_fifo = new("m_csr_exp_fifo", this);
        m_csr_act_fifo = new("m_csr_act_fifo", this);

        m_resp_exp_imp  = new("m_resp_exp_imp", this);
        m_resp_act_imp  = new("m_resp_act_imp", this);
        m_resp_exp_fifo = new("m_resp_exp_fifo", this);
        m_resp_act_fifo = new("m_resp_act_fifo", this);
    endfunction

    // CSR channel write methods
    function void write_csr_exp(aplc_csr_transaction xtn);
        m_csr_exp_fifo.write(xtn);
    endfunction

    function void write_csr_act(aplc_csr_transaction xtn);
        m_csr_act_fifo.write(xtn);
    endfunction

    // Response channel write methods
    function void write_resp_exp(aplc_spi_transaction xtn);
        m_resp_exp_fifo.write(xtn);
    endfunction

    function void write_resp_act(aplc_spi_transaction xtn);
        m_resp_act_fifo.write(xtn);
    endfunction

    task run_phase(uvm_phase phase);
        fork
            csr_compare_loop();
            resp_compare_loop();
        join_none
    endtask

    task csr_compare_loop();
        aplc_csr_transaction act, exp;
        forever begin
            m_csr_act_fifo.get(act);
            m_csr_exp_fifo.get(exp);
            compare_csr(act, exp);
        end
    endtask

    task resp_compare_loop();
        aplc_spi_transaction act, exp;
        forever begin
            m_resp_act_fifo.get(act);
            m_resp_exp_fifo.get(exp);
            compare_resp(act, exp);
        end
    endtask

    function void compare_csr(aplc_csr_transaction act, aplc_csr_transaction exp);
        bit match = 1;
        string detail = "";

        if (act.m_addr !== exp.m_addr) begin
            match = 0;
            detail = {detail, $sformatf(" addr:act=0x%02h exp=0x%02h", act.m_addr, exp.m_addr)};
        end
        if (act.m_write !== exp.m_write) begin
            match = 0;
            detail = {detail, $sformatf(" dir:act=%0b exp=%0b", act.m_write, exp.m_write)};
        end
        if (act.m_write && act.m_wdata !== exp.m_wdata) begin
            match = 0;
            detail = {detail, $sformatf(" wdata:act=0x%08h exp=0x%08h", act.m_wdata, exp.m_wdata)};
        end
        if (!act.m_write && act.m_rdata !== exp.m_rdata) begin
            match = 0;
            detail = {detail, $sformatf(" rdata:act=0x%08h exp=0x%08h", act.m_rdata, exp.m_rdata)};
        end

        if (match) begin
            m_csr_match_count++;
            `uvm_info(msg_id, $sformatf("CSR MATCH: %s", act.convert2string()), UVM_HIGH)
        end else begin
            m_csr_mismatch_count++;
            `uvm_error(msg_id, $sformatf("CSR MISMATCH:%s  act=%s  exp=%s",
                detail, act.convert2string(), exp.convert2string()))
        end
    endfunction

    function void compare_resp(aplc_spi_transaction act, aplc_spi_transaction exp);
        bit match = 1;
        string detail = "";

        if (act.m_status !== exp.m_status) begin
            match = 0;
            detail = {detail, $sformatf(" status:act=0x%02h exp=0x%02h", act.m_status, exp.m_status)};
        end

        if (exp.m_has_rdata) begin
            if (!act.m_has_rdata) begin
                match = 0;
                detail = {detail, " act has no rdata but exp does"};
            end else if (act.m_rdata.size() != exp.m_rdata.size()) begin
                match = 0;
                detail = {detail, $sformatf(" rdata_size:act=%0d exp=%0d", act.m_rdata.size(), exp.m_rdata.size())};
            end else begin
                foreach (exp.m_rdata[i]) begin
                    if (act.m_rdata[i] !== exp.m_rdata[i]) begin
                        match = 0;
                        detail = {detail, $sformatf(" rdata[%0d]:act=0x%08h exp=0x%08h", i, act.m_rdata[i], exp.m_rdata[i])};
                    end
                end
            end
        end

        if (match) begin
            m_resp_match_count++;
            `uvm_info(msg_id, $sformatf("RESP MATCH: status=0x%02h", act.m_status), UVM_HIGH)
        end else begin
            m_resp_mismatch_count++;
            `uvm_error(msg_id, $sformatf("RESP MISMATCH:%s  act_status=0x%02h exp_status=0x%02h",
                detail, act.m_status, exp.m_status))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(msg_id,
            $sformatf("CSR  - Match: %0d  Mismatch: %0d", m_csr_match_count, m_csr_mismatch_count),
            UVM_NONE)
        `uvm_info(msg_id,
            $sformatf("RESP - Match: %0d  Mismatch: %0d", m_resp_match_count, m_resp_mismatch_count),
            UVM_NONE)
        if (m_csr_mismatch_count > 0)
            `uvm_error(msg_id, "CSR SCOREBOARD FAIL")
        if (m_resp_mismatch_count > 0)
            `uvm_error(msg_id, "RESP SCOREBOARD FAIL")
    endfunction

endclass
