// SPI Agent for APLC_LITE

class spi_agent extends uvm_agent;

    `uvm_component_utils(spi_agent)

    spi_driver     m_driver;
    spi_monitor    m_monitor;
    spi_sequencer  m_sequencer;
    spi_config     m_cfg;

    uvm_analysis_port#(spi_xtn) m_ap;

    function new(string name = "spi_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(spi_config)::get(this, "", "spi_config", m_cfg)) begin
            `uvm_fatal(get_type_name(), "Cannot get spi_config from config_db")
        end

        m_monitor = spi_monitor::type_id::create("m_monitor", this);
        m_ap = new("m_ap", this);

        if (m_cfg.m_is_active == UVM_ACTIVE) begin
            m_driver     = spi_driver::type_id::create("m_driver", this);
            m_sequencer  = spi_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        m_ap.connect(m_monitor.m_ap);
        if (m_cfg.m_is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass
