// APLC Environment Configuration

class aplc_env_config extends uvm_object;

    `uvm_object_utils(aplc_env_config)

    spi_config        m_spi_config;
    csr_config        m_csr_config;
    ahb_sagent_config m_ahb_sagent_config;

    uvm_active_passive_enum spi_is_active;
    uvm_active_passive_enum csr_is_active;
    uvm_active_passive_enum ahb_is_active;

    bit has_scoreboard;
    bit has_coverage;

    function new(string name = "aplc_env_config");
        super.new(name);
        spi_is_active = UVM_ACTIVE;
        csr_is_active = UVM_ACTIVE;
        ahb_is_active = UVM_ACTIVE;
        has_scoreboard = 1'b1;
        has_coverage   = 1'b1;
    endfunction

endclass
