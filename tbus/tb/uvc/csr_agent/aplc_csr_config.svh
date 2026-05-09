// APLC CSR Agent Configuration
class aplc_csr_config extends uvm_object;

    `uvm_object_utils(aplc_csr_config)

    virtual aplc_csr_if m_vif;
    uvm_active_passive_enum m_is_active = UVM_PASSIVE;

    function new(string name = "aplc_csr_config");
        super.new(name);
    endfunction

endclass
