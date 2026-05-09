// APLC SPI Agent
class aplc_spi_agent extends uvm_agent;

    `uvm_component_utils(aplc_spi_agent)

    aplc_spi_config     m_config;
    aplc_spi_driver     m_driver;
    aplc_spi_monitor    m_monitor;
    aplc_spi_sequencer  m_sequencer;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aplc_spi_config)::get(this, "", "config", m_config)) begin
            `uvm_fatal(get_type_name(), "aplc_spi_config not found in config_db")
        end

        // Pass virtual interface to monitor
        uvm_config_db #(virtual aplc_spi_if)::set(this, "m_monitor", "vif", m_config.m_vif);

        m_monitor = aplc_spi_monitor::type_id::create("m_monitor", this);

        if (m_config.m_is_active == UVM_ACTIVE) begin
            m_driver     = aplc_spi_driver::type_id::create("m_driver", this);
            m_sequencer  = aplc_spi_sequencer::type_id::create("m_sequencer", this);
            // Pass virtual interface to driver
            uvm_config_db #(virtual aplc_spi_if)::set(this, "m_driver", "vif", m_config.m_vif);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (m_config.m_is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass
