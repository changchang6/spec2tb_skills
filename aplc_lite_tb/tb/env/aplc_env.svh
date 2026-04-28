// APLC-Lite UVM Environment

class aplc_env extends uvm_env;

    `uvm_component_utils(aplc_env)

    aplc_env_config m_cfg;

    aplc_spi_agent   m_spi_agent;
    aplc_ahb_agent   m_ahb_agent;
    aplc_csr_agent   m_csr_agent;
    aplc_ref_model   m_ref_model;
    aplc_scoreboard  m_scoreboard;
    aplc_coverage    m_coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(aplc_env_config)::get(this, "", "aplc_env_config", m_cfg)) begin
            `uvm_fatal("BUILD_ERR", "Unable to get aplc_env_config from config_db")
        end

        if (m_cfg.has_spi_agent) begin
            uvm_config_db #(aplc_spi_config)::set(this, "m_spi_agent*", "aplc_spi_config", m_cfg.m_spi_cfg);
            m_spi_agent = aplc_spi_agent::type_id::create("m_spi_agent", this);
        end

        if (m_cfg.has_ahb_agent) begin
            uvm_config_db #(aplc_ahb_config)::set(this, "m_ahb_agent*", "ahb_config", m_cfg.m_ahb_cfg);
            m_ahb_agent = aplc_ahb_agent::type_id::create("m_ahb_agent", this);
        end

        if (m_cfg.has_csr_agent) begin
            uvm_config_db #(aplc_csr_config)::set(this, "m_csr_agent*", "csr_config", m_cfg.m_csr_cfg);
            m_csr_agent = aplc_csr_agent::type_id::create("m_csr_agent", this);
        end

        if (m_cfg.has_scoreboard) begin
            m_ref_model  = aplc_ref_model::type_id::create("m_ref_model", this);
            m_scoreboard = aplc_scoreboard::type_id::create("m_scoreboard", this);
        end

        if (m_cfg.has_coverage) begin
            m_coverage = aplc_coverage::type_id::create("m_coverage", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (m_cfg.has_scoreboard) begin
            m_spi_agent.m_analysis_port.connect(m_ref_model.m_req_imp);

            m_ref_model.m_ahb_exp_ap.connect(m_scoreboard.m_ahb_exp_fifo.analysis_export);
            m_ahb_agent.m_analysis_port.connect(m_scoreboard.m_ahb_act_fifo.analysis_export);

            m_ref_model.m_csr_exp_ap.connect(m_scoreboard.m_csr_exp_fifo.analysis_export);
            m_csr_agent.m_analysis_port.connect(m_scoreboard.m_csr_act_fifo.analysis_export);
        end

        if (m_cfg.has_coverage) begin
            m_spi_agent.m_analysis_port.connect(m_coverage.m_spi_fifo.analysis_export);
        end
    endfunction

endclass
