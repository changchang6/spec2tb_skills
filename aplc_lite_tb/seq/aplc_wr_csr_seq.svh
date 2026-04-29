// APLC-Lite WR_CSR Sequence
`ifndef APLC_WR_CSR_SEQ_SVH
`define APLC_WR_CSR_SEQ_SVH

class aplc_wr_csr_seq extends aplc_base_seq;
    `uvm_object_utils(aplc_wr_csr_seq)

    function new(string name = "aplc_wr_csr_seq");
        super.new(name);
    endfunction

    task body();
        send_wr_csr(6'h04, 32'h1);
        send_wr_csr(6'h00, 32'hA5A5);
        send_wr_csr(6'h08, 32'h0);
    endtask
endclass

`endif
