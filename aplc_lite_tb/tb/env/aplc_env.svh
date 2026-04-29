// APLC-Lite Environment
`ifndef APLC_ENV_SVH
`define APLC_ENV_SVH

class aplc_env extends uvm_component;
    `uvm_component_utils(aplc_env)

    aplc_env_config  m_env_cfg;
    aplc_spi_agent   m_spi_agent;
    aplc_ahb_agent   m_ahb_agent;
    aplc_csr_agent   m_csr_agent;
    aplc_ref_model   m_ref_model;
    aplc_scoreboard  m_scoreboard;
    aplc_coverage    m_coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(aplc_env_config)::get(this, "", "aplc_env_cfg", m_env_cfg)) begin
            `uvm_fatal(get_type_name(), "Failed to get env config from uvm_config_db")
        end

        // Set agent configs
        uvm_config_db#(aplc_spi_config)::set(this, "m_spi_agent*", "m_config", m_env_cfg.m_spi_cfg);
        uvm_config_db#(aplc_ahb_config)::set(this, "m_ahb_agent*", "m_config", m_env_cfg.m_ahb_cfg);
        uvm_config_db#(aplc_csr_config)::set(this, "m_csr_agent*", "m_config", m_env_cfg.m_csr_cfg);

        m_spi_agent = aplc_spi_agent::type_id::create("m_spi_agent", this);
        m_ahb_agent = aplc_ahb_agent::type_id::create("m_ahb_agent", this);
        m_csr_agent = aplc_csr_agent::type_id::create("m_csr_agent", this);

        if (m_env_cfg.m_has_ref_model) begin
            m_ref_model = aplc_ref_model::type_id::create("m_ref_model", this);
        end
        if (m_env_cfg.m_has_scoreboard) begin
            m_scoreboard = aplc_scoreboard::type_id::create("m_scoreboard", this);
        end
        if (m_env_cfg.m_has_coverage) begin
            m_coverage = aplc_coverage::type_id::create("m_coverage", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (m_env_cfg.m_has_ref_model) begin
            // SPI monitor -> Ref model
            m_spi_agent.m_analysis_port.connect(m_ref_model.m_spi_req_imp);

            // Ref model -> Scoreboard expected
            if (m_env_cfg.m_has_scoreboard) begin
                m_ref_model.m_ahb_exp_port.connect(m_scoreboard.m_ahb_exp_fifo.analysis_export);
                m_ref_model.m_csr_exp_port.connect(m_scoreboard.m_csr_exp_fifo.analysis_export);
            end
        end

        // AHB monitor -> Scoreboard actual
        if (m_env_cfg.m_has_scoreboard) begin
            m_ahb_agent.m_analysis_port.connect(m_scoreboard.m_ahb_act_imp);
            m_csr_agent.m_analysis_port.connect(m_scoreboard.m_csr_act_imp);
        end

        // Monitor -> Coverage
        if (m_env_cfg.m_has_coverage) begin
            m_spi_agent.m_analysis_port.connect(m_coverage.m_spi_imp);
            m_ahb_agent.m_analysis_port.connect(m_coverage.m_ahb_imp);
        end
    endfunction
endclass

`endif
