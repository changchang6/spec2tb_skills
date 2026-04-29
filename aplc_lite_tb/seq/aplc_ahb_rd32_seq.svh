// APLC-Lite AHB_RD32 Sequence
`ifndef APLC_AHB_RD32_SEQ_SVH
`define APLC_AHB_RD32_SEQ_SVH

class aplc_ahb_rd32_seq extends aplc_base_seq;
    `uvm_object_utils(aplc_ahb_rd32_seq)

    function new(string name = "aplc_ahb_rd32_seq");
        super.new(name);
    endfunction

    task body();
        send_ahb_rd32(32'h1000_0000);
        send_ahb_rd32(32'h1000_0004);
        send_ahb_rd32(32'h1000_1000);
    endtask
endclass

`endif
