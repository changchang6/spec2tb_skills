// ----------------------------------------------------------------------
// File: aplc_spi_pkg.sv
// Description: SPI-like Agent Package for APLC-Lite UVM testbench
// ----------------------------------------------------------------------

package aplc_spi_pkg;

  // --- UVM imports ---
  `include "uvm_macros.svh"
  import uvm_pkg::*;

  // --- Agent source files ---
  `include "aplc_spi_txn.svh"
  `include "aplc_spi_config.svh"
  `include "aplc_spi_driver.svh"
  `include "aplc_spi_monitor.svh"
  `include "aplc_spi_sequencer.svh"
  `include "aplc_spi_agent.svh"

endpackage : aplc_spi_pkg
