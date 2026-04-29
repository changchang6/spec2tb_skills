// =============================================================================
// File: aplc_csr_sequencer.svh
// Description: APLC-Lite CSR sequencer
// =============================================================================

class aplc_csr_sequencer extends uvm_sequencer #(aplc_csr_txn);

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_csr_sequencer)

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

endclass: aplc_csr_sequencer
