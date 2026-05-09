// APLC Environment Configuration
class aplc_env_config extends uvm_object;

    `uvm_object_utils(aplc_env_config)

    aplc_spi_config m_spi_cfg;
    aplc_csr_config m_csr_cfg;

    // Virtual interfaces set by test
    virtual aplc_spi_if m_spi_vif;
    virtual aplc_csr_if m_csr_vif;

    function new(string name = "aplc_env_config");
        super.new(name);
        m_spi_cfg = aplc_spi_config::type_id::create("m_spi_cfg");
        m_csr_cfg = aplc_csr_config::type_id::create("m_csr_cfg");
    endfunction

endclass
