// =============================================================================
// File: aplc_spi_config.svh
// Description: APLC-Lite SPI agent configuration object
// =============================================================================

class aplc_spi_config extends uvm_object;

    // -------------------------------------------------------------------------
    // Utility and registration
    // -------------------------------------------------------------------------
    `uvm_object_utils(aplc_spi_config)

    // -------------------------------------------------------------------------
    // Configuration fields
    // -------------------------------------------------------------------------
    virtual aplc_spi_if             m_vif;
    uvm_active_passive_enum         m_is_active = UVM_ACTIVE;
    bit                             m_has_coverage = 1;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name = "aplc_spi_config");
        super.new(name);
    endfunction: new

endclass: aplc_spi_config
