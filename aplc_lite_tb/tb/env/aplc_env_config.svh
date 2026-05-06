class aplc_env_config extends uvm_object;

    `uvm_object_utils(aplc_env_config)

    spi_config m_spi_cfg;
    csr_config m_csr_cfg;

    // AHB slave agent config
    virtual yuu_ahb_slave_interface m_ahb_slv_vif;

    bit enable_scoreboard = 1;
    bit enable_coverage   = 1;

    function new(string name = "aplc_env_config");
        super.new(name);
        m_spi_cfg = spi_config::type_id::create("m_spi_cfg");
        m_csr_cfg = csr_config::type_id::create("m_csr_cfg");
    endfunction

endclass
