// APLC-Lite RD_CSR Sequence
`ifndef APLC_RD_CSR_SEQ_SVH
`define APLC_RD_CSR_SEQ_SVH

class aplc_rd_csr_seq extends aplc_base_seq;
    `uvm_object_utils(aplc_rd_csr_seq)

    function new(string name = "aplc_rd_csr_seq");
        super.new(name);
    endfunction

    task body();
        send_rd_csr(6'h00);
        send_rd_csr(6'h04);
        send_rd_csr(6'h08);
        send_rd_csr(6'h0C);
        send_rd_csr(6'h10);
    endtask
endclass

`endif
