// CSR Transaction
class csr_xtn extends uvm_sequence_item;

    `uvm_object_utils(csr_xtn)

    rand bit        is_write;
    rand logic [7:0]  addr;
    rand logic [31:0] wdata;
    logic [31:0]       rdata;

    function new(string name = "csr_xtn");
        super.new(name);
    endfunction

    function string convert2string();
        if (is_write)
            return $sformatf("CSR_WR addr=0x%02h data=0x%08h", addr, wdata);
        else
            return $sformatf("CSR_RD addr=0x%02h data=0x%08h", addr, rdata);
    endfunction

endclass
