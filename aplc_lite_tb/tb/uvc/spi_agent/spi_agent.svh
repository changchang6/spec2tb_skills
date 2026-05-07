class spi_agent extends uvm_agent;

    `uvm_component_utils(spi_agent)

    spi_driver    m_driver;
    spi_monitor   m_monitor;
    spi_sequencer m_sequencer;
    spi_config    m_config;

    function new(string name = "spi_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(spi_config)::get(this, "", "cfg", m_config))
            `uvm_fatal(get_type_name(), "spi_config not found")

        // Propagate config to children
        uvm_config_db#(spi_config)::set(this, "m_monitor", "cfg", m_config);

        m_monitor = spi_monitor::type_id::create("m_monitor", this);
        if (m_config.is_active == UVM_ACTIVE) begin
            uvm_config_db#(spi_config)::set(this, "m_driver", "cfg", m_config);
            m_driver    = spi_driver::type_id::create("m_driver", this);
            m_sequencer = spi_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (m_config.is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass
