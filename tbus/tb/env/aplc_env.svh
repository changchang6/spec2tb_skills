// APLC Environment
class aplc_env extends uvm_env;

    `uvm_component_utils(aplc_env)

    aplc_env_config m_config;
    aplc_spi_agent  m_spi_agent;
    aplc_csr_agent  m_csr_agent;
    aplc_ref_model  m_ref_model;
    aplc_scoreboard m_scoreboard;
    aplc_coverage   m_coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aplc_env_config)::get(this, "", "config", m_config)) begin
            `uvm_fatal(get_type_name(), "aplc_env_config not found in config_db")
        end

        // Set sub-agent configs
        m_config.m_spi_cfg.m_vif = m_config.m_spi_vif;
        m_config.m_csr_cfg.m_vif = m_config.m_csr_vif;

        uvm_config_db #(aplc_spi_config)::set(this, "m_spi_agent*", "config", m_config.m_spi_cfg);
        uvm_config_db #(aplc_csr_config)::set(this, "m_csr_agent*", "config", m_config.m_csr_cfg);

        m_spi_agent  = aplc_spi_agent::type_id::create("m_spi_agent", this);
        m_csr_agent  = aplc_csr_agent::type_id::create("m_csr_agent", this);
        m_ref_model  = aplc_ref_model::type_id::create("m_ref_model", this);
        m_scoreboard = aplc_scoreboard::type_id::create("m_scoreboard", this);
        m_coverage   = aplc_coverage::type_id::create("m_coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // SPI monitor request -> ref model + coverage
        m_spi_agent.m_monitor.m_req_ap.connect(m_ref_model.m_req_imp);
        m_spi_agent.m_monitor.m_req_ap.connect(m_coverage.analysis_export);

        // SPI monitor response -> scoreboard (actual)
        m_spi_agent.m_monitor.m_resp_ap.connect(m_scoreboard.m_resp_act_imp);

        // Ref model -> scoreboard (expected)
        m_ref_model.m_csr_exp_ap.connect(m_scoreboard.m_csr_exp_imp);
        m_ref_model.m_resp_exp_ap.connect(m_scoreboard.m_resp_exp_imp);

        // CSR monitor -> scoreboard (actual CSR)
        m_csr_agent.m_monitor.m_ap.connect(m_scoreboard.m_csr_act_imp);
    endfunction

endclass
