// =============================================================================
// File: aplc_ahb_config.svh
// Description: APLC-Lite AHB agent configuration class
// =============================================================================

class aplc_ahb_config extends uvm_object;

    // -------------------------------------------------------------------------
    // Configuration fields
    // -------------------------------------------------------------------------
    virtual aplc_ahb_if              m_vif;
    uvm_active_passive_enum         m_is_active   = UVM_ACTIVE;
    int                             m_ready_delay = 0;
    bit                             m_has_coverage = 1;

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_object_utils(aplc_ahb_config)

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name = "aplc_ahb_config");
        super.new(name);
    endfunction: new

endclass: aplc_ahb_config
