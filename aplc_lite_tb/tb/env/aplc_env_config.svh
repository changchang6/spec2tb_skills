// APLC-Lite Environment Configuration

class aplc_env_config extends uvm_object;

    `uvm_object_utils(aplc_env_config)

    aplc_spi_config m_spi_cfg;
    aplc_ahb_config m_ahb_cfg;
    aplc_csr_config m_csr_cfg;

    bit has_spi_agent = 1'b1;
    bit has_ahb_agent = 1'b1;
    bit has_csr_agent = 1'b1;
    bit has_scoreboard = 1'b1;
    bit has_coverage   = 1'b1;

    function new(string name = "aplc_env_config");
        super.new(name);
        m_spi_cfg = aplc_spi_config::type_id::create("m_spi_cfg");
        m_ahb_cfg = aplc_ahb_config::type_id::create("m_ahb_cfg");
        m_csr_cfg = aplc_csr_config::type_id::create("m_csr_cfg");
    endfunction

endclass
