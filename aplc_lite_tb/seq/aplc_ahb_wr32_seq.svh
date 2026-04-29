// APLC-Lite AHB_WR32 Sequence
`ifndef APLC_AHB_WR32_SEQ_SVH
`define APLC_AHB_WR32_SEQ_SVH

class aplc_ahb_wr32_seq extends aplc_base_seq;
    `uvm_object_utils(aplc_ahb_wr32_seq)

    function new(string name = "aplc_ahb_wr32_seq");
        super.new(name);
    endfunction

    task body();
        send_ahb_wr32(32'h1000_0000, 32'hDEAD_BEEF);
        send_ahb_wr32(32'h1000_0004, 32'h1234_5678);
        send_ahb_wr32(32'h1000_1000, 32'hCAFE_BABE);
    endtask
endclass

`endif
