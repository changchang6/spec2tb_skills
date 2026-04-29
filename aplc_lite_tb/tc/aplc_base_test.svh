// APLC-Lite Base Test
`ifndef APLC_BASE_TEST_SVH
`define APLC_BASE_TEST_SVH

class aplc_base_test extends uvm_test;
    `uvm_component_utils(aplc_base_test)

    aplc_env       m_env;
    aplc_env_config m_env_cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_env_cfg = aplc_env_config::type_id::create("m_env_cfg");

        // Configure agents
        m_env_cfg.m_spi_cfg.m_is_active = UVM_ACTIVE;
        m_env_cfg.m_ahb_cfg.m_is_active = UVM_ACTIVE;
        m_env_cfg.m_csr_cfg.m_is_active = UVM_ACTIVE;
        m_env_cfg.m_spi_cfg.m_has_coverage = 1;
        m_env_cfg.m_ahb_cfg.m_has_coverage = 1;
        m_env_cfg.m_csr_cfg.m_has_coverage = 1;

        uvm_config_db#(aplc_env_config)::set(this, "m_env", "aplc_env_cfg", m_env_cfg);
        m_env = aplc_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        // Override in derived tests
    endtask
endclass

`endif
