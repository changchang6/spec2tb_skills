// APLC-Lite Scoreboard
// Compares AHB/CSR actual transactions with expected from Reference Model

class aplc_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(aplc_scoreboard)

    uvm_tlm_analysis_fifo #(aplc_ahb_txn) m_ahb_act_fifo;
    uvm_tlm_analysis_fifo #(aplc_ahb_txn) m_ahb_exp_fifo;
    uvm_tlm_analysis_fifo #(aplc_csr_txn) m_csr_act_fifo;
    uvm_tlm_analysis_fifo #(aplc_csr_txn) m_csr_exp_fifo;

    int m_ahb_match_count;
    int m_ahb_mismatch_count;
    int m_csr_match_count;
    int m_csr_mismatch_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_ahb_act_fifo = new("m_ahb_act_fifo", this);
        m_ahb_exp_fifo = new("m_ahb_exp_fifo", this);
        m_csr_act_fifo = new("m_csr_act_fifo", this);
        m_csr_exp_fifo = new("m_csr_exp_fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        fork
            process_ahb();
            process_csr();
        join
    endtask

    virtual task process_ahb();
        aplc_ahb_txn act_txn, exp_txn;
        forever begin
            m_ahb_act_fifo.get(act_txn);
            m_ahb_exp_fifo.get(exp_txn);
            if (!compare_ahb(exp_txn, act_txn)) begin
                `uvm_error("SCB_AHB_MISMATCH",
                    $sformatf("EXP: %s\nACT: %s", exp_txn.convert2string(), act_txn.convert2string()))
                m_ahb_mismatch_count++;
            end else begin
                m_ahb_match_count++;
            end
        end
    endtask

    virtual task process_csr();
        aplc_csr_txn act_txn, exp_txn;
        forever begin
            m_csr_act_fifo.get(act_txn);
            m_csr_exp_fifo.get(exp_txn);
            if (!compare_csr(exp_txn, act_txn)) begin
                `uvm_error("SCB_CSR_MISMATCH",
                    $sformatf("EXP: %s\nACT: %s", exp_txn.convert2string(), act_txn.convert2string()))
                m_csr_mismatch_count++;
            end else begin
                m_csr_match_count++;
            end
        end
    endtask

    virtual function bit compare_ahb(aplc_ahb_txn exp, aplc_ahb_txn act);
        if (exp.addr !== act.addr) return 0;
        if (exp.write !== act.write) return 0;
        if (exp.burst !== act.burst) return 0;
        if (exp.data.size() != act.data.size()) return 0;
        foreach (exp.data[i])
            if (exp.data[i] !== act.data[i]) return 0;
        return 1;
    endfunction

    virtual function bit compare_csr(aplc_csr_txn exp, aplc_csr_txn act);
        if (exp.addr  !== act.addr)  return 0;
        if (exp.write !== act.write) return 0;
        if (exp.write && exp.data !== act.data) return 0;
        return 1;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB_REPORT",
            $sformatf("AHB: match=%0d mismatch=%0d | CSR: match=%0d mismatch=%0d",
                      m_ahb_match_count, m_ahb_mismatch_count,
                      m_csr_match_count, m_csr_mismatch_count), UVM_LOW)
    endfunction

endclass
