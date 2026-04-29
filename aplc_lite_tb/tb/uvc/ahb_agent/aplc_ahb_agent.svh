// =============================================================================
// File: aplc_ahb_agent.svh
// Description: APLC-Lite AHB agent
//              Contains driver, monitor, sequencer, and config
// =============================================================================

class aplc_ahb_agent extends uvm_agent;

    // -------------------------------------------------------------------------
    // Member variables
    // -------------------------------------------------------------------------
    aplc_ahb_driver     m_driver;
    aplc_ahb_monitor    m_monitor;
    aplc_ahb_sequencer  m_sequencer;
    aplc_ahb_config     m_config;
    uvm_analysis_port #(aplc_ahb_txn) m_analysis_port;

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_ahb_agent)

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
        if (!uvm_config_db #(aplc_ahb_config)::get(this, "", "m_config", m_config)) begin
            `uvm_fatal("APLC_AHB_AGENT", "Failed to get m_config from config db")
        end

        // Create monitor (always present)
        m_monitor = aplc_ahb_monitor::type_id::create("m_monitor", this);

        // Create driver and sequencer only in ACTIVE mode
        if (m_config.m_is_active == UVM_ACTIVE) begin
            m_driver    = aplc_ahb_driver::type_id::create("m_driver", this);
            m_sequencer = aplc_ahb_sequencer::type_id::create("m_sequencer", this);
        end

        // Propagate config to sub-components
        uvm_config_db#(aplc_ahb_config)::set(this, "m_driver*", "m_config", m_config);
        uvm_config_db#(aplc_ahb_config)::set(this, "m_monitor*", "m_config", m_config);

        // Create analysis port
        m_analysis_port = new("m_analysis_port", this);
    endfunction: build_phase

    // -------------------------------------------------------------------------
    // connect_phase
    // -------------------------------------------------------------------------
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect monitor analysis port to agent analysis port
        m_monitor.m_analysis_port.connect(m_analysis_port);

        // Connect driver to sequencer in ACTIVE mode
        if (m_config.m_is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction: connect_phase

endclass: aplc_ahb_agent
