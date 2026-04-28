// ----------------------------------------------------------------------
// File: aplc_spi_sequencer.svh
// Description: SPI-like Agent Sequencer for APLC-Lite UVM testbench
// ----------------------------------------------------------------------

class aplc_spi_sequencer extends uvm_sequencer #(aplc_spi_txn);

  // --- Constructor ---
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // --- Factory registration ---
  `uvm_component_utils(aplc_spi_sequencer)

endclass : aplc_spi_sequencer
