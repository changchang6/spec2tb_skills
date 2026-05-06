// APLC-Lite Environment
class aplc_env extends uvm_env;

    `uvm_component_utils(aplc_env)

    aplc_env_config m_env_cfg;
    spi_agent       m_spi_agent;
    csr_agent       m_csr_agent;
    yuu_ahb_env     m_ahb_env;
    aplc_scoreboard m_scoreboard;
    aplc_coverage   m_coverage;
    aplc_vsequencer m_vsequencer;

    function new(string name = "aplc_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aplc_env_config)::get(this, "", "aplc_env_config", m_env_cfg))
            `uvm_fatal(get_type_name(), "aplc_env_config not found")

        // Set sub-configs
        uvm_config_db #(spi_config)::set(this, "m_spi_agent*", "spi_config", m_env_cfg.m_spi_cfg);
        uvm_config_db #(csr_config)::set(this, "m_csr_agent*", "csr_config", m_env_cfg.m_csr_cfg);
        uvm_config_db #(yuu_ahb_env_config)::set(this, "m_ahb_env", "cfg", m_env_cfg.m_ahb_cfg);

        m_spi_agent  = spi_agent::type_id::create("m_spi_agent", this);
        m_csr_agent  = csr_agent::type_id::create("m_csr_agent", this);
        m_ahb_env    = yuu_ahb_env::type_id::create("m_ahb_env", this);
        m_scoreboard = aplc_scoreboard::type_id::create("m_scoreboard", this);
        m_coverage   = aplc_coverage::type_id::create("m_coverage", this);
        m_vsequencer = aplc_vsequencer::type_id::create("m_vsequencer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        m_vsequencer.spi_seqr = m_spi_agent.m_sequencer;
        m_spi_agent.m_monitor.ap.connect(m_scoreboard.spi_imp);
        m_spi_agent.m_monitor.ap.connect(m_coverage.analysis_export);
        m_csr_agent.m_monitor.ap.connect(m_scoreboard.csr_imp);
    endfunction

endclass
