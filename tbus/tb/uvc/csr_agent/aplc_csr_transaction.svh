// APLC CSR Transaction
class aplc_csr_transaction extends uvm_sequence_item;

    `uvm_object_utils(aplc_csr_transaction)

    rand bit          m_write;
    rand logic [7:0]  m_addr;
    rand logic [31:0] m_wdata;
    logic [31:0]      m_rdata;

    function new(string name = "aplc_csr_transaction");
        super.new(name);
    endfunction

    function void do_copy(uvm_object rhs);
        aplc_csr_transaction tgt;
        super.do_copy(rhs);
        $cast(tgt, rhs);
        m_write = tgt.m_write;
        m_addr  = tgt.m_addr;
        m_wdata = tgt.m_wdata;
        m_rdata = tgt.m_rdata;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        aplc_csr_transaction tgt;
        do_compare = super.do_compare(rhs, comparer);
        if (!do_compare) return 0;
        $cast(tgt, rhs);
        do_compare = (m_write === tgt.m_write) &&
                     (m_addr  === tgt.m_addr);
        if (m_write)
            do_compare = do_compare && (m_wdata === tgt.m_wdata);
        else
            do_compare = do_compare && (m_rdata === tgt.m_rdata);
    endfunction

    function string convert2string();
        if (m_write)
            return $sformatf("CSR_WR addr=0x%02h wdata=0x%08h", m_addr, m_wdata);
        else
            return $sformatf("CSR_RD addr=0x%02h rdata=0x%08h", m_addr, m_rdata);
    endfunction

    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("addr",  m_addr,  8);
        printer.print_field("write", m_write, 1);
    endfunction

    function void do_record(uvm_recorder recorder);
        super.do_record(recorder);
    endfunction

endclass
