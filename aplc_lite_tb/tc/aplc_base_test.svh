// APLC-Lite Base Test
class aplc_base_test extends uvm_test;

    `uvm_component_utils(aplc_base_test)

    aplc_env         m_env;
    aplc_env_config  m_env_cfg;

    function new(string name = "aplc_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_env_cfg = aplc_env_config::type_id::create("m_env_cfg");

        // Configure SPI agent (active, 16-bit lane)
        m_env_cfg.m_spi_cfg.is_active = UVM_ACTIVE;
        m_env_cfg.m_spi_cfg.lane_mode = 2'b11;

        // Configure CSR agent (active slave)
        m_env_cfg.m_csr_cfg.is_active = UVM_ACTIVE;

        // Configure AHB VIP (slave mode)
        configure_ahb_env();

        uvm_config_db #(aplc_env_config)::set(this, "*", "aplc_env_config", m_env_cfg);
        m_env = aplc_env::type_id::create("m_env", this);
    endfunction

    function void configure_ahb_env();
        yuu_ahb_slave_config slv_cfg;
        virtual yuu_ahb_interface ahb_vif;

        if (!uvm_config_db #(virtual yuu_ahb_interface)::get(this, "", "yuu_ahb_interface", ahb_vif))
            `uvm_fatal(get_type_name(), "yuu_ahb_interface not found in config_db")

        m_env_cfg.m_ahb_cfg.ahb_if = ahb_vif;
        m_env_cfg.m_ahb_cfg.events = new("ahb_events");

        slv_cfg = yuu_ahb_slave_config::type_id::create("slv_cfg");
        slv_cfg.index = 0;
        slv_cfg.is_active = UVM_ACTIVE;
        slv_cfg.set_map(32'h0000_0000, 32'hFFFF_FFFF);
        m_env_cfg.m_ahb_cfg.set_config(slv_cfg);
    endfunction

    task run_phase(uvm_phase phase);
        phase.phase_done.set_propagate_mode(0);
    endtask

endclass
