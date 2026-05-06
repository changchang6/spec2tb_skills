class aplc_env_config extends uvm_object;

    `uvm_object_utils(aplc_env_config)

    spi_config  m_spi_cfg;
    csr_config  m_csr_cfg;
    yuu_ahb_env_config m_ahb_cfg;

    function new(string name = "aplc_env_config");
        super.new(name);
        m_spi_cfg = spi_config::type_id::create("m_spi_cfg");
        m_csr_cfg = csr_config::type_id::create("m_csr_cfg");
        m_ahb_cfg = yuu_ahb_env_config::type_id::create("m_ahb_cfg");
    endfunction

endclass
