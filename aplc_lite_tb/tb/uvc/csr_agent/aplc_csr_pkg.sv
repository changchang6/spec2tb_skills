// =============================================================================
// File: aplc_csr_pkg.sv
// Description: APLC-Lite CSR agent package
// =============================================================================

package aplc_csr_pkg;

    // -------------------------------------------------------------------------
    // Include UVM macros and import UVM package
    // -------------------------------------------------------------------------
    `include "uvm_macros.svh"
    import uvm_pkg::*;

    // -------------------------------------------------------------------------
    // Include CSR agent files
    // -------------------------------------------------------------------------
    `include "aplc_csr_txn.svh"
    `include "aplc_csr_config.svh"
    `include "aplc_csr_driver.svh"
    `include "aplc_csr_monitor.svh"
    `include "aplc_csr_sequencer.svh"
    `include "aplc_csr_agent.svh"

endpackage: aplc_csr_pkg
