// APLC-Lite Smoke Test Sequence
`ifndef APLC_SMOKE_SEQ_SVH
`define APLC_SMOKE_SEQ_SVH

class aplc_smoke_seq extends aplc_base_seq;
    `uvm_object_utils(aplc_smoke_seq)

    function new(string name = "aplc_smoke_seq");
        super.new(name);
    endfunction

    task body();
        `uvm_info(get_type_name(), "Starting smoke test sequence", UVM_LOW)
        // 1. Write CTRL CSR
        send_wr_csr(6'h04, 32'h01);
        // 2. Read VERSION CSR
        send_rd_csr(6'h00);
        // 3. AHB single write
        send_ahb_wr32(32'h1000_0000, 32'hDEAD_BEEF);
        // 4. AHB single read
        send_ahb_rd32(32'h1000_0000);
        `uvm_info(get_type_name(), "Smoke test sequence completed", UVM_LOW)
    endtask
endclass

`endif
