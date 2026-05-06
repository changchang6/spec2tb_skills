class aplc_env extends uvm_env;

    `uvm_component_utils(aplc_env)

    aplc_env_config m_config;

    spi_agent       m_spi_agent;
    csr_agent       m_csr_agent;
    yuu_ahb_slave_agent m_ahb_slave_agent;
    aplc_ref_model  m_ref_model;
    aplc_scoreboard m_scoreboard;
    aplc_coverage   m_coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(aplc_env_config)::get(this, "", "cfg", m_config))
            `uvm_fatal(get_type_name(), "Cannot get env config")

        // SPI agent
        uvm_config_db#(spi_config)::set(this, "m_spi_agent", "cfg", m_config.m_spi_cfg);
        m_spi_agent = spi_agent::type_id::create("m_spi_agent", this);

        // CSR agent
        uvm_config_db#(csr_config)::set(this, "m_csr_agent", "cfg", m_config.m_csr_cfg);
        m_csr_agent = csr_agent::type_id::create("m_csr_agent", this);

        // AHB slave agent (VIP)
        begin
            yuu_ahb_slave_config ahb_slv_cfg = yuu_ahb_slave_config::type_id::create("ahb_slv_cfg");
            ahb_slv_cfg.index = 0;
            ahb_slv_cfg.is_active = UVM_ACTIVE;
            ahb_slv_cfg.coverage_enable = 1;
            ahb_slv_cfg.protocol_check_enable = 1;
            ahb_slv_cfg.vif = m_config.m_ahb_slv_vif;
            ahb_slv_cfg.events = new("events");
            ahb_slv_cfg.set_map(0, 32'hFFFF_FFFF);
            uvm_config_db#(yuu_ahb_slave_config)::set(this, "m_ahb_slave_agent", "cfg", ahb_slv_cfg);
        end
        m_ahb_slave_agent = yuu_ahb_slave_agent::type_id::create("m_ahb_slave_agent", this);

        // Set default slave response sequence
        uvm_config_db#(uvm_object_wrapper)::set(this,
            "m_ahb_slave_agent.sequencer.run_phase",
            "default_sequence",
            yuu_ahb_slave_response_sequence::type_id::get());

        // Ref model
        m_ref_model = aplc_ref_model::type_id::create("m_ref_model", this);

        // Scoreboard
        if (m_config.enable_scoreboard)
            m_scoreboard = aplc_scoreboard::type_id::create("m_scoreboard", this);

        // Coverage
        if (m_config.enable_coverage)
            m_coverage = aplc_coverage::type_id::create("m_coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // SPI monitor request -> ref model
        m_spi_agent.m_monitor.req_ap.connect(m_ref_model.m_req_imp);

        // SPI monitor request -> coverage
        if (m_config.enable_coverage)
            m_spi_agent.m_monitor.req_ap.connect(m_coverage.analysis_export);

        // Ref model CSR expected -> scoreboard
        if (m_config.enable_scoreboard) begin
            m_ref_model.m_csr_exp_ap.connect(m_scoreboard.m_csr_exp_imp);

            // Ref model AHB expected -> scoreboard
            m_ref_model.m_ahb_exp_ap.connect(m_scoreboard.m_ahb_exp_imp);

            // Ref model response expected -> scoreboard
            m_ref_model.m_resp_exp_ap.connect(m_scoreboard.m_resp_exp_imp);

            // CSR monitor actual -> scoreboard
            m_csr_agent.m_monitor.ap.connect(m_scoreboard.m_csr_act_imp);

            // AHB slave monitor actual -> scoreboard
            m_ahb_slave_agent.out_monitor_port.connect(m_scoreboard.m_ahb_act_imp);

            // SPI monitor response -> scoreboard
            m_spi_agent.m_monitor.resp_ap.connect(m_scoreboard.m_resp_act_imp);
        end
    endfunction

endclass
