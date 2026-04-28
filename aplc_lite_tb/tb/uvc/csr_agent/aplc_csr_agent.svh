//----------------------------------------------------------------------
// File: aplc_csr_agent.svh
// Description: CSR agent
//----------------------------------------------------------------------

class aplc_csr_agent extends uvm_agent;

  `uvm_component_utils(aplc_csr_agent)

  // Configuration
  aplc_csr_config m_cfg;

  // Components
  aplc_csr_driver    m_driver;
  aplc_csr_sequencer m_sequencer;
  aplc_csr_monitor   m_monitor;

  // Analysis port (connected to monitor's analysis port)
  uvm_analysis_port #(aplc_csr_txn) m_analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration
    if (!uvm_config_db #(aplc_csr_config)::get(this, "", "csr_config", m_cfg)) begin
      `uvm_fatal("NOCONFIG", "aplc_csr_config not found in config_db")
    end

    // Create monitor
    if (m_cfg.has_monitor) begin
      m_monitor = aplc_csr_monitor::type_id::create("m_monitor", this);
    end

    // Create driver and sequencer for active mode
    if (m_cfg.is_active == UVM_ACTIVE) begin
      m_driver    = aplc_csr_driver::type_id::create("m_driver", this);
      m_sequencer = aplc_csr_sequencer::type_id::create("m_sequencer", this);
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
