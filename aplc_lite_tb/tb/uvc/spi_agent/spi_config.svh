class spi_config extends uvm_object;

    `uvm_object_utils(spi_config)

    uvm_active_passive_enum is_active = UVM_ACTIVE;
    logic [1:0] lane_mode = 2'b11; // default 16-bit

    function new(string name = "spi_config");
        super.new(name);
    endfunction

endclass
