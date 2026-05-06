class csr_config extends uvm_object;

    `uvm_object_utils(csr_config)

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name = "csr_config");
        super.new(name);
    endfunction

endclass
