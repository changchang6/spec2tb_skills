//----------------------------------------------------------------------
// File: aplc_csr_pkg.sv
// Description: CSR agent package
//----------------------------------------------------------------------

package aplc_csr_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "aplc_csr_txn.svh"
  `include "aplc_csr_config.svh"
  `include "aplc_csr_driver.svh"
  `include "aplc_csr_monitor.svh"
  `include "aplc_csr_sequencer.svh"
  `include "aplc_csr_agent.svh"

endpackage
