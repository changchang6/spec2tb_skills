//----------------------------------------------------------------------
// File: aplc_ahb_sequencer.svh
// Description: AHB-Lite sequencer
//----------------------------------------------------------------------

class aplc_ahb_sequencer extends uvm_sequencer #(aplc_ahb_txn);

  `uvm_component_utils(aplc_ahb_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
