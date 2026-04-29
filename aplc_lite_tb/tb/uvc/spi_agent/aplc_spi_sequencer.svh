// =============================================================================
// File: aplc_spi_sequencer.svh
// Description: APLC-Lite SPI sequencer
// =============================================================================

class aplc_spi_sequencer extends uvm_sequencer #(aplc_spi_txn);

    // -------------------------------------------------------------------------
    // Utility and registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_spi_sequencer)

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

endclass: aplc_spi_sequencer
