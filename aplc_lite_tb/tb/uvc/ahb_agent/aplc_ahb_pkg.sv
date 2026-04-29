// =============================================================================
// File: aplc_ahb_pkg.sv
// Description: APLC-Lite AHB agent package
// =============================================================================

package aplc_ahb_pkg;

    // -------------------------------------------------------------------------
    // Include UVM macros and import UVM package
    // -------------------------------------------------------------------------
    `include "uvm_macros.svh"
    import uvm_pkg::*;

    // -------------------------------------------------------------------------
    // Include AHB agent files
    // -------------------------------------------------------------------------
    `include "aplc_ahb_txn.svh"
    `include "aplc_ahb_config.svh"
    `include "aplc_ahb_driver.svh"
    `include "aplc_ahb_monitor.svh"
    `include "aplc_ahb_sequencer.svh"
    `include "aplc_ahb_agent.svh"

endpackage: aplc_ahb_pkg
