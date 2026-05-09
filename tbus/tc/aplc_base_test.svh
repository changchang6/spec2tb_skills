// APLC Base Test
class aplc_base_test extends uvm_test;

    `uvm_component_utils(aplc_base_test)

    aplc_env       m_env;
    aplc_env_config m_env_config;
    virtual aplc_spi_if m_spi_vif;
    virtual aplc_csr_if m_csr_vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_env_config = aplc_env_config::type_id::create("m_env_config");

        // Get virtual interfaces from config_db
        if (!uvm_config_db #(virtual aplc_spi_if)::get(this, "", "spi_vif", m_spi_vif)) begin
            `uvm_fatal(get_type_name(), "spi_vif not found in config_db")
        end
        if (!uvm_config_db #(virtual aplc_csr_if)::get(this, "", "csr_vif", m_csr_vif)) begin
            `uvm_fatal(get_type_name(), "csr_vif not found in config_db")
        end

        m_env_config.m_spi_vif = m_spi_vif;
        m_env_config.m_csr_vif = m_csr_vif;

        // Set agents to ACTIVE mode
        m_env_config.m_spi_cfg.m_is_active = UVM_ACTIVE;
        m_env_config.m_csr_cfg.m_is_active = UVM_PASSIVE; // CSR agent is passive (monitor only)

        uvm_config_db #(aplc_env_config)::set(this, "*", "config", m_env_config);

        m_env = aplc_env::type_id::create("m_env", this);
    endfunction

endclass
