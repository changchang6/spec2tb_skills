// CSR Agent for APLC_LITE

class csr_agent extends uvm_agent;

    `uvm_component_utils(csr_agent)

    csr_driver     m_driver;
    csr_monitor    m_monitor;
    csr_sequencer  m_sequencer;
    csr_config     m_cfg;

    uvm_analysis_port#(csr_xtn) m_ap;

    function new(string name = "csr_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(csr_config)::get(this, "", "csr_config", m_cfg)) begin
            `uvm_fatal(get_type_name(), "Cannot get csr_config from config_db")
        end

        m_monitor = csr_monitor::type_id::create("m_monitor", this);
        m_ap = new("m_ap", this);

        if (m_cfg.m_is_active == UVM_ACTIVE) begin
            m_driver     = csr_driver::type_id::create("m_driver", this);
            m_sequencer  = csr_sequencer::type_id::create("m_sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        m_ap.connect(m_monitor.m_ap);
        if (m_cfg.m_is_active == UVM_ACTIVE) begin
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
        end
    endfunction

endclass
