// APLC-Lite Virtual Sequencer
class aplc_vsequencer extends uvm_sequencer;

    `uvm_component_utils(aplc_vsequencer)

    uvm_sequencer #(spi_xtn) spi_seqr;

    function new(string name = "aplc_vsequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass
