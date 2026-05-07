// Scoreboard: compares expected vs actual transactions on CSR, AHB, SPI response channels
class aplc_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(aplc_scoreboard)

    // CSR channel
    `uvm_analysis_imp_decl(_csr_exp)
    `uvm_analysis_imp_decl(_csr_act)
    uvm_analysis_imp_csr_exp #(csr_xtn, aplc_scoreboard) m_csr_exp_imp;
    uvm_analysis_imp_csr_act #(csr_xtn, aplc_scoreboard) m_csr_act_imp;
    uvm_tlm_analysis_fifo #(csr_xtn) m_csr_exp_fifo;
    uvm_tlm_analysis_fifo #(csr_xtn) m_csr_act_fifo;

    // AHB channel
    `uvm_analysis_imp_decl(_ahb_exp)
    `uvm_analysis_imp_decl(_ahb_act)
    uvm_analysis_imp_ahb_exp #(yuu_ahb_item, aplc_scoreboard) m_ahb_exp_imp;
    uvm_analysis_imp_ahb_act #(yuu_ahb_item, aplc_scoreboard) m_ahb_act_imp;
    uvm_tlm_analysis_fifo #(yuu_ahb_item) m_ahb_exp_fifo;
    uvm_tlm_analysis_fifo #(yuu_ahb_item) m_ahb_act_fifo;

    // SPI response channel
    `uvm_analysis_imp_decl(_resp_exp)
    `uvm_analysis_imp_decl(_resp_act)
    uvm_analysis_imp_resp_exp #(spi_xtn, aplc_scoreboard) m_resp_exp_imp;
    uvm_analysis_imp_resp_act #(spi_xtn, aplc_scoreboard) m_resp_act_imp;
    uvm_tlm_analysis_fifo #(spi_xtn) m_resp_exp_fifo;
    uvm_tlm_analysis_fifo #(spi_xtn) m_resp_act_fifo;

    int m_csr_match_count;
    int m_csr_mismatch_count;
    int m_ahb_match_count;
    int m_ahb_mismatch_count;
    int m_resp_match_count;
    int m_resp_mismatch_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // CSR
        m_csr_exp_imp  = new("m_csr_exp_imp", this);
        m_csr_act_imp  = new("m_csr_act_imp", this);
        m_csr_exp_fifo = new("m_csr_exp_fifo", this);
        m_csr_act_fifo = new("m_csr_act_fifo", this);
        // AHB
        m_ahb_exp_imp  = new("m_ahb_exp_imp", this);
        m_ahb_act_imp  = new("m_ahb_act_imp", this);
        m_ahb_exp_fifo = new("m_ahb_exp_fifo", this);
        m_ahb_act_fifo = new("m_ahb_act_fifo", this);
        // Response
        m_resp_exp_imp  = new("m_resp_exp_imp", this);
        m_resp_act_imp  = new("m_resp_act_imp", this);
        m_resp_exp_fifo = new("m_resp_exp_fifo", this);
        m_resp_act_fifo = new("m_resp_act_fifo", this);
    endfunction

    function void write_csr_exp(csr_xtn xtn);
        `uvm_info(get_type_name(), $sformatf("CSR EXP: %s", xtn.convert2string()), UVM_HIGH)
        m_csr_exp_fifo.write(xtn);
    endfunction

    function void write_csr_act(csr_xtn xtn);
        `uvm_info(get_type_name(), $sformatf("CSR ACT: %s", xtn.convert2string()), UVM_HIGH)
        m_csr_act_fifo.write(xtn);
    endfunction

    function void write_ahb_exp(yuu_ahb_item xtn);
        `uvm_info(get_type_name(), $sformatf("AHB EXP: dir=%s addr=0x%08h burst=%s",
            xtn.direction.name(), xtn.start_address, xtn.burst.name()), UVM_HIGH)
        m_ahb_exp_fifo.write(xtn);
    endfunction

    function void write_ahb_act(yuu_ahb_item xtn);
        `uvm_info(get_type_name(), $sformatf("AHB ACT: dir=%s addr=0x%08h burst=%s",
            xtn.direction.name(), xtn.start_address, xtn.burst.name()), UVM_HIGH)
        m_ahb_act_fifo.write(xtn);
    endfunction

    function void write_resp_exp(spi_xtn xtn);
        `uvm_info(get_type_name(), $sformatf("RESP EXP: opcode=0x%02h status=0x%02h",
            xtn.opcode, xtn.status), UVM_HIGH)
        m_resp_exp_fifo.write(xtn);
    endfunction

    function void write_resp_act(spi_xtn xtn);
        `uvm_info(get_type_name(), $sformatf("RESP ACT: opcode=0x%02h status=0x%02h",
            xtn.opcode, xtn.status), UVM_HIGH)
        m_resp_act_fifo.write(xtn);
    endfunction

    task run_phase(uvm_phase phase);
        fork
            csr_compare_loop();
            ahb_compare_loop();
            resp_compare_loop();
        join_none
    endtask

    task csr_compare_loop();
        csr_xtn act, exp;
        forever begin
            m_csr_act_fifo.get(act);
            m_csr_exp_fifo.get(exp);
            compare_csr(act, exp);
        end
    endtask

    task ahb_compare_loop();
        yuu_ahb_item act, exp;
        forever begin
            m_ahb_act_fifo.get(act);
            m_ahb_exp_fifo.get(exp);
            compare_ahb(act, exp);
        end
    endtask

    task resp_compare_loop();
        spi_xtn act, exp;
        forever begin
            m_resp_act_fifo.get(act);
            m_resp_exp_fifo.get(exp);
            compare_resp(act, exp);
        end
    endtask

    function void compare_csr(csr_xtn act, csr_xtn exp);
        bit match = 1;
        if (act.is_write !== exp.is_write) match = 0;
        if (act.addr     !== exp.addr)     match = 0;
        // Only compare wdata for writes
        if (exp.is_write && act.wdata !== exp.wdata) match = 0;
        // For reads, don't compare rdata (no memory model)

        if (match) begin
            m_csr_match_count++;
            `uvm_info(get_type_name(), $sformatf("CSR MATCH: %s", act.convert2string()), UVM_HIGH)
        end else begin
            m_csr_mismatch_count++;
            `uvm_error(get_type_name(), $sformatf("CSR MISMATCH: act=%s exp=%s",
                act.convert2string(), exp.convert2string()))
        end
    endfunction

    function void compare_ahb(yuu_ahb_item act, yuu_ahb_item exp);
        bit match = 1;
        if (act.direction !== exp.direction) match = 0;
        if (act.start_address !== exp.start_address) match = 0;
        if (act.burst !== exp.burst) match = 0;
        // Compare write data for writes
        if (exp.direction == WRITE) begin
            if (act.data.size() != exp.data.size()) match = 0;
            else begin
                foreach (exp.data[i])
                    if (act.data[i] !== exp.data[i]) match = 0;
            end
        end
        // For reads, don't compare data (no memory model)

        if (match) begin
            m_ahb_match_count++;
            `uvm_info(get_type_name(), "AHB MATCH", UVM_HIGH)
        end else begin
            m_ahb_mismatch_count++;
            `uvm_error(get_type_name(), $sformatf("AHB MISMATCH: act_dir=%s exp_dir=%s act_addr=0x%08h exp_addr=0x%08h",
                act.direction.name(), exp.direction.name(), act.start_address, exp.start_address))
        end
    endfunction

    function void compare_resp(spi_xtn act, spi_xtn exp);
        bit match = 1;
        if (act.status !== exp.status) match = 0;

        if (match) begin
            m_resp_match_count++;
            `uvm_info(get_type_name(), $sformatf("RESP MATCH: status=0x%02h", act.status), UVM_HIGH)
        end else begin
            m_resp_mismatch_count++;
            `uvm_error(get_type_name(), $sformatf("RESP MISMATCH: act_status=0x%02h exp_status=0x%02h exp_opcode=0x%02h",
                act.status, exp.status, exp.opcode))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(),
            $sformatf("\n--- Scoreboard Report ---\nCSR:  Match=%0d Mismatch=%0d\nAHB:  Match=%0d Mismatch=%0d\nRESP: Match=%0d Mismatch=%0d",
                m_csr_match_count, m_csr_mismatch_count,
                m_ahb_match_count, m_ahb_mismatch_count,
                m_resp_match_count, m_resp_mismatch_count),
            UVM_NONE)
        if (m_csr_mismatch_count > 0 || m_ahb_mismatch_count > 0 || m_resp_mismatch_count > 0)
            `uvm_error(get_type_name(), "SCOREBOARD FAIL")
    endfunction

endclass
