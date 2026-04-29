// =============================================================================
// File: aplc_csr_txn.svh
// Description: APLC-Lite CSR transaction class
// =============================================================================

class aplc_csr_txn extends uvm_sequence_item;

    // -------------------------------------------------------------------------
    // Transaction fields
    // -------------------------------------------------------------------------
    rand bit [5:0]  m_addr;
    rand bit [31:0] m_data;
    rand bit        m_write;

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_object_utils(aplc_csr_txn)

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name = "aplc_csr_txn");
        super.new(name);
    endfunction: new

    // -------------------------------------------------------------------------
    // Constraint: address range 0x00~0x3F (6-bit)
    // -------------------------------------------------------------------------
    constraint c_addr_range {
        m_addr inside {[6'h00:6'h3F]};
    }

    // -------------------------------------------------------------------------
    // convert2string
    // -------------------------------------------------------------------------
    function string convert2string();
        string s;
        s = $sformatf("addr=0x%02h data=0x%08h %s",
                       m_addr, m_data, m_write ? "WR" : "RD");
        return s;
    endfunction: convert2string

    // -------------------------------------------------------------------------
    // do_copy
    // -------------------------------------------------------------------------
    function void do_copy(uvm_object rhs);
        aplc_csr_txn rhs_txn;

        if (!$cast(rhs_txn, rhs)) begin
            `uvm_fatal("APLC_CSR_TXN", "do_copy: cast failed")
        end

        super.do_copy(rhs);
        m_addr  = rhs_txn.m_addr;
        m_data  = rhs_txn.m_data;
        m_write = rhs_txn.m_write;
    endfunction: do_copy

    // -------------------------------------------------------------------------
    // do_compare
    // -------------------------------------------------------------------------
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        aplc_csr_txn rhs_txn;

        if (!$cast(rhs_txn, rhs)) begin
            `uvm_fatal("APLC_CSR_TXN", "do_compare: cast failed")
        end

        do_compare = super.do_compare(rhs, comparer) &&
                     (m_addr  === rhs_txn.m_addr) &&
                     (m_data  === rhs_txn.m_data) &&
                     (m_write === rhs_txn.m_write);
    endfunction: do_compare

    // -------------------------------------------------------------------------
    // do_print
    // -------------------------------------------------------------------------
    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("m_addr",  m_addr,  6, UVM_HEX);
        printer.print_field("m_data",  m_data, 32, UVM_HEX);
        printer.print_field("m_write", m_write,  1, UVM_BIN);
    endfunction: do_print

endclass: aplc_csr_txn
