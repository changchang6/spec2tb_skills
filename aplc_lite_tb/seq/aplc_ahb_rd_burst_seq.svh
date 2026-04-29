// APLC-Lite AHB_RD_BURST Sequence
`ifndef APLC_AHB_RD_BURST_SEQ_SVH
`define APLC_AHB_RD_BURST_SEQ_SVH

class aplc_ahb_rd_burst_seq extends aplc_base_seq;
    `uvm_object_utils(aplc_ahb_rd_burst_seq)

    function new(string name = "aplc_ahb_rd_burst_seq");
        super.new(name);
    endfunction

    task body();
        send_ahb_rd_burst(32'h2000_0000, 4);
        send_ahb_rd_burst(32'h3000_0000, 8);
        send_ahb_rd_burst(32'h4000_0000, 16);
    endtask
endclass

`endif
