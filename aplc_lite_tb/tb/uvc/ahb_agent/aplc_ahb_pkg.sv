//----------------------------------------------------------------------
// File: aplc_ahb_pkg.sv
// Description: AHB-Lite agent package
//----------------------------------------------------------------------

package aplc_ahb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "aplc_ahb_txn.svh"
  `include "aplc_ahb_config.svh"
  `include "aplc_ahb_driver.svh"
  `include "aplc_ahb_monitor.svh"
  `include "aplc_ahb_sequencer.svh"
  `include "aplc_ahb_agent.svh"

endpackage
