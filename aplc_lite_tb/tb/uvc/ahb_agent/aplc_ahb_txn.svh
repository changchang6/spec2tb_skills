// =============================================================================
// File: aplc_ahb_txn.svh
// Description: APLC-Lite AHB transaction class
// =============================================================================

class aplc_ahb_txn extends uvm_sequence_item;

    // -------------------------------------------------------------------------
    // Transaction fields
    // -------------------------------------------------------------------------
    rand bit [31:0] m_addr;
    rand bit [31:0] m_data[];
    rand bit        m_write;
    rand bit [2:0]  m_size;
    rand bit [2:0]  m_burst;
    rand bit [1:0]  m_trans;
    rand bit        m_response;  // 0=OKAY, 1=ERROR

    // -------------------------------------------------------------------------
    // Burst type constants
    // -------------------------------------------------------------------------
    localparam BT_SINGLE = 3'b000;
    localparam BT_INCR4  = 3'b011;
    localparam BT_INCR8  = 3'b101;
    localparam BT_INCR16 = 3'b111;

    // -------------------------------------------------------------------------
    // Transfer type constants
    // -------------------------------------------------------------------------
    localparam TT_IDLE   = 2'b00;
    localparam TT_NONSEQ = 2'b10;
    localparam TT_SEQ    = 2'b11;

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_object_utils(aplc_ahb_txn)

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name = "aplc_ahb_txn");
        super.new(name);
    endfunction: new

    // -------------------------------------------------------------------------
    // Constraint: default burst length based on burst type
    // -------------------------------------------------------------------------
    constraint c_burst_len {
        m_data.size() inside {[1:16]};
        if (m_burst == BT_SINGLE) {
            m_data.size() == 1;
        } else if (m_burst == BT_INCR4) {
            m_data.size() == 4;
        } else if (m_burst == BT_INCR8) {
            m_data.size() == 8;
        } else if (m_burst == BT_INCR16) {
            m_data.size() == 16;
        }
    }

    // -------------------------------------------------------------------------
    // Constraint: hsize is always WORD
    // -------------------------------------------------------------------------
    constraint c_size_word {
        m_size == 3'b010;
    }

    // -------------------------------------------------------------------------
    // Constraint: address must be word-aligned
    // -------------------------------------------------------------------------
    constraint c_addr_aligned {
        m_addr[1:0] == 2'b00;
    }

    // -------------------------------------------------------------------------
    // convert2string
    // -------------------------------------------------------------------------
    function string convert2string();
        string s;
        string burst_str;
        string trans_str;
        string resp_str;

        case (m_burst)
            3'b000: burst_str = "SINGLE";
            3'b011: burst_str = "INCR4";
            3'b101: burst_str = "INCR8";
            3'b111: burst_str = "INCR16";
            default: burst_str = $sformatf("0x%0h", m_burst);
        endcase

        case (m_trans)
            2'b00: trans_str = "IDLE";
            2'b10: trans_str = "NONSEQ";
            2'b11: trans_str = "SEQ";
            default: trans_str = $sformatf("0x%0h", m_trans);
        endcase

        resp_str = (m_response == 0) ? "OKAY" : "ERROR";

        s = $sformatf("addr=0x%08h write=%0s burst=%0s trans=%0s resp=%0s size=%0d data[0]=0x%08h",
                       m_addr,
                       m_write ? "WR" : "RD",
                       burst_str,
                       trans_str,
                       resp_str,
                       m_data.size(),
                       (m_data.size() > 0) ? m_data[0] : 32'h0);
        return s;
    endfunction: convert2string

    // -------------------------------------------------------------------------
    // do_copy
    // -------------------------------------------------------------------------
    function void do_copy(uvm_object rhs);
        aplc_ahb_txn rhs_txn;

        if (!$cast(rhs_txn, rhs)) begin
            `uvm_fatal("APLC_AHB_TXN", "do_copy: cast failed")
        end

        super.do_copy(rhs);
        m_addr     = rhs_txn.m_addr;
        m_write    = rhs_txn.m_write;
        m_size     = rhs_txn.m_size;
        m_burst    = rhs_txn.m_burst;
        m_trans    = rhs_txn.m_trans;
        m_response = rhs_txn.m_response;
        m_data     = rhs_txn.m_data;
    endfunction: do_copy

    // -------------------------------------------------------------------------
    // do_compare
    // -------------------------------------------------------------------------
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        aplc_ahb_txn rhs_txn;

        if (!$cast(rhs_txn, rhs)) begin
            `uvm_fatal("APLC_AHB_TXN", "do_compare: cast failed")
        end

        do_compare = super.do_compare(rhs, comparer) &&
                     (m_addr     === rhs_txn.m_addr) &&
                     (m_write    === rhs_txn.m_write) &&
                     (m_size     === rhs_txn.m_size) &&
                     (m_burst    === rhs_txn.m_burst) &&
                     (m_trans    === rhs_txn.m_trans) &&
                     (m_response === rhs_txn.m_response) &&
                     (m_data     === rhs_txn.m_data);
    endfunction: do_compare

    // -------------------------------------------------------------------------
    // do_print
    // -------------------------------------------------------------------------
    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("m_addr",     m_addr,     32, UVM_HEX);
        printer.print_field("m_write",    m_write,     1, UVM_BIN);
        printer.print_field("m_size",     m_size,      3, UVM_BIN);
        printer.print_field("m_burst",    m_burst,     3, UVM_BIN);
        printer.print_field("m_trans",    m_trans,     2, UVM_BIN);
        printer.print_field("m_response", m_response,  1, UVM_BIN);
        foreach (m_data[i]) begin
            printer.print_field($sformatf("m_data[%0d]", i), m_data[i], 32, UVM_HEX);
        end
    endfunction: do_print

endclass: aplc_ahb_txn
