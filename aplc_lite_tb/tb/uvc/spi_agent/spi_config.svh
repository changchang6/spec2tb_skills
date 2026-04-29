// SPI Agent Configuration

class spi_config extends uvm_object;

    `uvm_object_utils(spi_config)

    virtual spi_intf m_vif;
    uvm_active_passive_enum m_is_active;

    function new(string name = "spi_config");
        super.new(name);
        m_is_active = UVM_ACTIVE;
    endfunction

endclass
