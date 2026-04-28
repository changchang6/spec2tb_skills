//----------------------------------------------------------------------
// File: aplc_ahb_agent.svh
// Description: AHB-Lite agent
//----------------------------------------------------------------------

class aplc_ahb_agent extends uvm_agent;

  `uvm_component_utils(aplc_ahb_agent)

  // Configuration
  aplc_ahb_config m_cfg;

  // Components
  aplc_ahb_driver    m_driver;
  aplc_ahb_sequencer m_sequencer;
  aplc_ahb_monitor   m_monitor;

  // Analysis port (connected to monitor's analysis port)
  uvm_analysis_port #(aplc_ahb_txn) m_analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration
    if (!uvm_config_db #(aplc_ahb_config)::get(this, "", "ahb_config", m_cfg)) begin
      `uvm_fatal("NOCONFIG", "aplc_ahb_config not found in config_db")
    end

    // Create monitor
    if (m_cfg.has_monitor) begin
      m_monitor = aplc_ahb_monitor::type_id::create("m_monitor", this);
    end

    // Create driver and sequencer for active mode
    if (m_cfg.is_active == UVM_ACTIVE) begin
      m_driver    = aplc_ahb_driver::type_id::create("m_driver", this);
      m_sequencer = aplc_ahb_sequencer::type_id::create("m_sequencer", this);
    end

    // Create analysis port
    m_analysis_port = new("m_analysis_port", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor analysis port to agent analysis port
    if (m_cfg.has_monitor && m_monitor != null) begin
      m_monitor.m_analysis_port.connect(m_analysis_port);
    end

    // Connect driver to sequencer
    if (m_cfg.is_active == UVM_ACTIVE) begin
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end
  endfunction

endclass
