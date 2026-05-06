class csr_xtn extends uvm_sequence_item;

    `uvm_object_utils(csr_xtn)

    rand bit        is_write;
    rand bit [7:0]  addr;
    rand bit [31:0] wdata;
         bit [31:0] rdata;

    constraint c_addr_range {
        addr < 64;
    }

    function new(string name = "csr_xtn");
        super.new(name);
    endfunction

    virtual function void do_copy(uvm_object rhs);
        csr_xtn rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        is_write = rhs_.is_write;
        addr     = rhs_.addr;
        wdata    = rhs_.wdata;
        rdata    = rhs_.rdata;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        csr_xtn rhs_;
        $cast(rhs_, rhs);
        return (is_write === rhs_.is_write &&
                addr     === rhs_.addr &&
                wdata    === rhs_.wdata);
    endfunction

    virtual function string convert2string();
        if (is_write)
            return $sformatf("WR addr=0x%02h wdata=0x%08h", addr, wdata);
        else
            return $sformatf("RD addr=0x%02h rdata=0x%08h", addr, rdata);
    endfunction

    virtual function void do_print(uvm_printer printer);
        printer.m_string = convert2string();
    endfunction

endclass
