// =============================================================================
// File: aplc_spi_pkg.sv
// Description: APLC-Lite SPI agent package
// =============================================================================

package aplc_spi_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "aplc_spi_txn.svh"
    `include "aplc_spi_config.svh"
    `include "aplc_spi_sequencer.svh"
    `include "aplc_spi_driver.svh"
    `include "aplc_spi_monitor.svh"
    `include "aplc_spi_agent.svh"

endpackage: aplc_spi_pkg
