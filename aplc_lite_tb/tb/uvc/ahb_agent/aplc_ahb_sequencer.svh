// =============================================================================
// File: aplc_ahb_sequencer.svh
// Description: APLC-Lite AHB sequencer
// =============================================================================

class aplc_ahb_sequencer extends uvm_sequencer #(aplc_ahb_txn);

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_ahb_sequencer)

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

endclass: aplc_ahb_sequencer
