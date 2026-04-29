// APLC-Lite Scoreboard
`ifndef APLC_SCOREBOARD_SVH
`define APLC_SCOREBOARD_SVH

`uvm_analysis_imp_decl(_ahb_act)
`uvm_analysis_imp_decl(_csr_act)

class aplc_scoreboard extends uvm_component;
    `uvm_component_utils(aplc_scoreboard)

    uvm_analysis_imp_ahb_act #(aplc_ahb_txn, aplc_scoreboard) m_ahb_act_imp;
    uvm_analysis_imp_csr_act #(aplc_csr_txn, aplc_scoreboard) m_csr_act_imp;
    uvm_tlm_analysis_fifo #(aplc_ahb_txn) m_ahb_exp_fifo;
    uvm_tlm_analysis_fifo #(aplc_ahb_txn) m_ahb_act_fifo;
    uvm_tlm_analysis_fifo #(aplc_csr_txn) m_csr_exp_fifo;
    uvm_tlm_analysis_fifo #(aplc_csr_txn) m_csr_act_fifo;

    int m_ahb_match_count;
    int m_ahb_mismatch_count;
    int m_csr_match_count;
    int m_csr_mismatch_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_ahb_act_imp  = new("m_ahb_act_imp", this);
        m_csr_act_imp  = new("m_csr_act_imp", this);
        m_ahb_exp_fifo = new("m_ahb_exp_fifo", this);
        m_ahb_act_fifo = new("m_ahb_act_fifo", this);
        m_csr_exp_fifo = new("m_csr_exp_fifo", this);
        m_csr_act_fifo = new("m_csr_act_fifo", this);
    endfunction

    task run_phase(uvm_phase phase);
        fork
            compare_ahb();
            compare_csr();
        join
    endtask

    task compare_ahb();
        aplc_ahb_txn exp_txn, act_txn;
        forever begin
            m_ahb_exp_fifo.get(exp_txn);
            m_ahb_act_fifo.get(act_txn);
            if (!compare_ahb_txn(exp_txn, act_txn)) begin
                `uvm_error(get_type_name(),
                    $sformatf("AHB MISMATCH: exp addr=0x%08h write=%0b burst=%0d | act addr=0x%08h write=%0b burst=%0d",
                    exp_txn.m_addr, exp_txn.m_write, exp_txn.m_burst,
                    act_txn.m_addr, act_txn.m_write, act_txn.m_burst))
                m_ahb_mismatch_count++;
            end else begin
                m_ahb_match_count++;
            end
        end
    endtask

    task compare_csr();
        aplc_csr_txn exp_txn, act_txn;
        forever begin
            m_csr_exp_fifo.get(exp_txn);
            m_csr_act_fifo.get(act_txn);
            if (!compare_csr_txn(exp_txn, act_txn)) begin
                `uvm_error(get_type_name(),
                    $sformatf("CSR MISMATCH: exp addr=0x%02h write=%0b data=0x%08h | act addr=0x%02h write=%0b data=0x%08h",
                    exp_txn.m_addr, exp_txn.m_write, exp_txn.m_data,
                    act_txn.m_addr, act_txn.m_write, act_txn.m_data))
                m_csr_mismatch_count++;
            end else begin
                m_csr_match_count++;
            end
        end
    endtask

    function bit compare_ahb_txn(aplc_ahb_txn exp, aplc_ahb_txn act);
        if (exp.m_addr != act.m_addr) return 0;
        if (exp.m_write != act.m_write) return 0;
        if (exp.m_burst != act.m_burst) return 0;
        if (exp.m_size != act.m_size) return 0;
        if (exp.m_data.size() != act.m_data.size()) return 0;
        foreach (exp.m_data[i]) begin
            if (exp.m_write && exp.m_data[i] !== act.m_data[i]) return 0;
        end
        return 1;
    endfunction

    function bit compare_csr_txn(aplc_csr_txn exp, aplc_csr_txn act);
        if (exp.m_addr !== act.m_addr) return 0;
        if (exp.m_write !== act.m_write) return 0;
        if (exp.m_write && exp.m_data !== act.m_data) return 0;
        return 1;
    endfunction

    function void write_ahb_act(aplc_ahb_txn txn);
        m_ahb_act_fifo.write(txn);
    endfunction

    function void write_csr_act(aplc_csr_txn txn);
        m_csr_act_fifo.write(txn);
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(),
            $sformatf("AHB: %0d match, %0d mismatch | CSR: %0d match, %0d mismatch",
            m_ahb_match_count, m_ahb_mismatch_count,
            m_csr_match_count, m_csr_mismatch_count), UVM_LOW)
    endfunction
endclass

`endif
