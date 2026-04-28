// ----------------------------------------------------------------------
// File: aplc_spi_agent.svh
// Description: SPI-like Agent for APLC-Lite UVM testbench
//              Standard agent structure with driver, monitor, sequencer
// ----------------------------------------------------------------------

class aplc_spi_agent extends uvm_agent;

  // --- Configuration ---
  aplc_spi_config m_cfg;

  // --- Sub-components ---
  aplc_spi_driver    m_driver;
  aplc_spi_monitor   m_monitor;
  aplc_spi_sequencer m_sequencer;

  // --- Analysis port (pass-through from monitor) ---
  uvm_analysis_port #(aplc_spi_txn) m_analysis_port;

  // --- Constructor ---
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // --- Factory registration ---
  `uvm_component_utils(aplc_spi_agent)

  // --- Build phase ---
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get configuration
    if (!uvm_config_db #(aplc_spi_config)::get(this, "", "aplc_spi_config", m_cfg)) begin
      `uvm_fatal("BUILD_ERR", "Unable to get aplc_spi_config from config_db")
    end

    // Create monitor if enabled
    if (m_cfg.has_monitor) begin
      m_monitor = aplc_spi_monitor::type_id::create("m_monitor", this);
    end

    // Create driver and sequencer if active
    if (m_cfg.is_active == UVM_ACTIVE) begin
      m_driver     = aplc_spi_driver::type_id::create("m_driver", this);
      m_sequencer  = aplc_spi_sequencer::type_id::create("m_sequencer", this);
    end

    // Create agent-level analysis port
    m_analysis_port = new("m_analysis_port", this);
  endfunction : build_phase

  // --- Connect phase ---
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect monitor analysis port to agent analysis port
    if (m_cfg.has_monitor) begin
      m_monitor.m_analysis_port.connect(m_analysis_port);
    end

    // Connect driver port to sequencer
    if (m_cfg.is_active == UVM_ACTIVE) begin
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    end
  endfunction : connect_phase

endclass : aplc_spi_agent
