class aplc_base_test extends uvm_test;

    `uvm_component_utils(aplc_base_test)

    aplc_env m_env;
    aplc_env_config m_env_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_env_cfg = aplc_env_config::type_id::create("m_env_cfg");

        // SPI config
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "spi_vif", m_env_cfg.m_spi_cfg.m_vif))
            `uvm_fatal(get_type_name(), "Cannot get spi_vif")
        m_env_cfg.m_spi_cfg.is_active = UVM_ACTIVE;

        // CSR config
        if (!uvm_config_db#(virtual csr_if)::get(this, "", "csr_vif", m_env_cfg.m_csr_cfg.m_vif))
            `uvm_fatal(get_type_name(), "Cannot get csr_vif")
        m_env_cfg.m_csr_cfg.is_active = UVM_ACTIVE;

        // AHB slave vif
        if (!uvm_config_db#(virtual yuu_ahb_slave_interface)::get(this, "", "ahb_slv_vif", m_env_cfg.m_ahb_slv_vif))
            `uvm_fatal(get_type_name(), "Cannot get ahb_slv_vif")

        uvm_config_db#(aplc_env_config)::set(this, "m_env", "cfg", m_env_cfg);
        m_env = aplc_env::type_id::create("m_env", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
    endfunction

endclass
