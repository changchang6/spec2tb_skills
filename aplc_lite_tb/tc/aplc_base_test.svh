// APLC Base Test

class aplc_base_test extends uvm_test;

    `uvm_component_utils(aplc_base_test)

    aplc_env        m_env;
    aplc_env_config m_env_cfg;

    function new(string name = "aplc_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        virtual spi_intf  spi_vif;
        virtual csr_intf  csr_vif;
        virtual ahb_intf  ahb_vif;

        super.build_phase(phase);

        // Create env config
        m_env_cfg = aplc_env_config::type_id::create("m_env_cfg");

        // Get virtual interfaces from config_db
        if (!uvm_config_db#(virtual spi_intf)::get(this, "", "spi_vif", spi_vif)) begin
            `uvm_fatal(get_type_name(), "Cannot get spi_vif from config_db")
        end
        if (!uvm_config_db#(virtual csr_intf)::get(this, "", "csr_vif", csr_vif)) begin
            `uvm_fatal(get_type_name(), "Cannot get csr_vif from config_db")
        end
        if (!uvm_config_db#(virtual ahb_intf)::get(this, "", "ahb_vif", ahb_vif)) begin
            `uvm_fatal(get_type_name(), "Cannot get ahb_vif from config_db")
        end

        // Create and configure agent configs
        m_env_cfg.m_spi_config = spi_config::type_id::create("m_spi_config");
        m_env_cfg.m_spi_config.m_vif = spi_vif;
        m_env_cfg.m_spi_config.m_is_active = UVM_ACTIVE;

        m_env_cfg.m_csr_config = csr_config::type_id::create("m_csr_config");
        m_env_cfg.m_csr_config.m_vif = csr_vif;
        m_env_cfg.m_csr_config.m_is_active = UVM_ACTIVE;

        m_env_cfg.m_ahb_sagent_config = ahb_sagent_config::type_id::create("m_ahb_sagent_config");
        m_env_cfg.m_ahb_sagent_config.vif = ahb_vif;
        m_env_cfg.m_ahb_sagent_config.is_active = UVM_ACTIVE;

        // Set env config
        uvm_config_db#(aplc_env_config)::set(this, "m_env", "aplc_env_config", m_env_cfg);

        // Create env
        m_env = aplc_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info(get_type_name(), "Base test run_phase (override in subclass)", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass
