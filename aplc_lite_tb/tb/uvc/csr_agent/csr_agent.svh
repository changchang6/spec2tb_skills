class csr_agent extends uvm_agent;

    `uvm_component_utils(csr_agent)

    csr_driver    m_driver;
    csr_monitor   m_monitor;
    csr_sequencer m_sequencer;
    csr_config    m_config;

    function new(string name = "csr_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(csr_config)::get(this, "", "csr_config", m_config))
            `uvm_fatal(get_type_name(), "csr_config not found")

        m_monitor = csr_monitor::type_id::create("m_monitor", this);
        if (m_config.is_active == UVM_ACTIVE) begin
            m_driver    = csr_driver::type_id::create("m_driver", this);
            m_sequencer = csr_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (m_config.is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass
