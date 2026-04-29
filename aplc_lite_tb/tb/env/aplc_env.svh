// APLC Environment

class aplc_env extends uvm_env;

    `uvm_component_utils(aplc_env)

    aplc_env_config m_env_cfg;
    spi_agent       m_spi_agent;
    csr_agent       m_csr_agent;
    ahb_sagent      m_ahb_sagent;
    aplc_scoreboard m_scoreboard;
    aplc_coverage   m_coverage;
    aplc_vsequencer m_vsequencer;

    function new(string name = "aplc_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        if (!uvm_config_db#(aplc_env_config)::get(this, "", "aplc_env_config", m_env_cfg)) begin
            `uvm_fatal(get_type_name(), "Cannot get aplc_env_config from config_db")
        end

        // Set agent configs
        uvm_config_db#(spi_config)::set(this, "m_spi_agent*", "spi_config", m_env_cfg.m_spi_config);
        uvm_config_db#(csr_config)::set(this, "m_csr_agent*", "csr_config", m_env_cfg.m_csr_config);
        uvm_config_db#(ahb_sagent_config)::set(this, "m_ahb_sagent*", "ahb_sagent_config", m_env_cfg.m_ahb_sagent_config);

        // Create agents
        m_spi_agent = spi_agent::type_id::create("m_spi_agent", this);
        m_csr_agent = csr_agent::type_id::create("m_csr_agent", this);
        m_ahb_sagent = ahb_sagent::type_id::create("m_ahb_sagent", this);

        // Create optional components
        if (m_env_cfg.has_scoreboard) begin
            m_scoreboard = aplc_scoreboard::type_id::create("m_scoreboard", this);
        end
        if (m_env_cfg.has_coverage) begin
            m_coverage = aplc_coverage::type_id::create("m_coverage", this);
        end

        // Create virtual sequencer
        m_vsequencer = aplc_vsequencer::type_id::create("m_vsequencer", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // Connect monitor analysis ports to scoreboard
        if (m_env_cfg.has_scoreboard) begin
            m_spi_agent.m_ap.connect(m_scoreboard.m_spi_export);
            m_csr_agent.m_ap.connect(m_scoreboard.m_csr_export);
        end

        // Connect monitor analysis ports to coverage
        if (m_env_cfg.has_coverage) begin
            m_spi_agent.m_ap.connect(m_coverage.analysis_export);
        end

        // Connect virtual sequencer sub-sequencers
        if (m_env_cfg.spi_is_active == UVM_ACTIVE) begin
            m_vsequencer.m_spi_seqr = m_spi_agent.m_sequencer;
        end
        if (m_env_cfg.csr_is_active == UVM_ACTIVE) begin
            m_vsequencer.m_csr_seqr = m_csr_agent.m_sequencer;
        end
        if (m_env_cfg.ahb_is_active == UVM_ACTIVE) begin
            m_vsequencer.m_ahb_sseqr = m_ahb_sagent.sseqr_h;
        end
    endfunction

endclass
