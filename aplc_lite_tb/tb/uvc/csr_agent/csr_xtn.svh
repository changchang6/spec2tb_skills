// CSR Transaction for APLC_LITE

class csr_xtn extends uvm_sequence_item;

    `uvm_object_utils(csr_xtn)

    rand logic        is_read;
    rand logic [7:0]  addr;
    rand logic [31:0] wdata;
    logic [31:0]      rdata;

    constraint addr_range_c { addr < 8'h40; }

    function new(string name = "csr_xtn");
        super.new(name);
    endfunction

    function void do_copy(uvm_object rhs);
        csr_xtn txn;
        super.do_copy(rhs);
        $cast(txn, rhs);
        is_read = txn.is_read;
        addr    = txn.addr;
        wdata   = txn.wdata;
        rdata   = txn.rdata;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        csr_xtn txn;
        do_compare = super.do_compare(rhs, comparer);
        $cast(txn, rhs);
        do_compare &= (is_read === txn.is_read);
        do_compare &= (addr    === txn.addr);
        do_compare &= (wdata   === txn.wdata);
        do_compare &= (rdata   === txn.rdata);
    endfunction

    function string convert2string();
        string s;
        if (is_read)
            $sformat(s, "RD addr=0x%02h rdata=0x%08h", addr, rdata);
        else
            $sformat(s, "WR addr=0x%02h wdata=0x%08h", addr, wdata);
        return s;
    endfunction

    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("is_read", is_read, 1);
        printer.print_field("addr", addr, 8);
        printer.print_field("wdata", wdata, 32);
        printer.print_field("rdata", rdata, 32);
    endfunction

endclass
