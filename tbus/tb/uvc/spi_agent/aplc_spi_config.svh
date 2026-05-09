// APLC SPI Agent Configuration
class aplc_spi_config extends uvm_object;

    `uvm_object_utils(aplc_spi_config)

    virtual aplc_spi_if m_vif;
    uvm_active_passive_enum m_is_active = UVM_ACTIVE;
    logic [1:0] m_lane_mode = 2'b11;

    function new(string name = "aplc_spi_config");
        super.new(name);
    endfunction

endclass
