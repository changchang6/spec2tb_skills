// =============================================================================
// File: aplc_spi_agent.svh
// Description: APLC-Lite SPI agent - encapsulates driver, monitor, sequencer
// =============================================================================

class aplc_spi_agent extends uvm_agent;

    // -------------------------------------------------------------------------
    // Utility and registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_spi_agent)

    // -------------------------------------------------------------------------
    // Member variables
    // -------------------------------------------------------------------------
    aplc_spi_config                m_config;
    aplc_spi_driver                m_driver;
    aplc_spi_monitor               m_monitor;
    aplc_spi_sequencer             m_sequencer;
    uvm_analysis_port #(aplc_spi_txn) m_analysis_port;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    // -------------------------------------------------------------------------
    // build_phase
    // -------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get config object
        if (!uvm_config_db #(aplc_spi_config)::get(this, "", "m_config", m_config)) begin
            `uvm_fatal(get_type_name(), "Failed to get aplc_spi_config from config_db")
        end

        // Create monitor (always present)
        m_monitor = aplc_spi_monitor::type_id::create("m_monitor", this);

        // Create driver and sequencer only in active mode
        if (m_config.m_is_active == UVM_ACTIVE) begin
            m_driver     = aplc_spi_driver::type_id::create("m_driver", this);
            m_sequencer  = aplc_spi_sequencer::type_id::create("m_sequencer", this);
        end

        // Create analysis port
        m_analysis_port = new("m_analysis_port", this);

        // Propagate virtual interface to sub-components
        uvm_config_db #(virtual aplc_spi_if)::set(this, "m_driver", "m_vif", m_config.m_vif);
        uvm_config_db #(virtual aplc_spi_if)::set(this, "m_monitor", "m_vif", m_config.m_vif);
        uvm_config_db #(uvm_active_passive_enum)::set(this, "m_driver", "m_is_active", m_config.m_is_active);
    endfunction: build_phase

    // -------------------------------------------------------------------------
    // connect_phase
    // -------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect driver-sequencer
        if (m_config.m_is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end

        // Connect monitor analysis port to agent analysis port
        m_monitor.m_analysis_port.connect(m_analysis_port);
    endfunction: connect_phase

endclass: aplc_spi_agent
