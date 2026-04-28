//----------------------------------------------------------------------
// File: aplc_csr_sequencer.svh
// Description: CSR sequencer
//----------------------------------------------------------------------

class aplc_csr_sequencer extends uvm_sequencer #(aplc_csr_txn);

  `uvm_component_utils(aplc_csr_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
