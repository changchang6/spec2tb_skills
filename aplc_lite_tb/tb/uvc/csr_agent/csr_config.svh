// CSR Agent Configuration

class csr_config extends uvm_object;

    `uvm_object_utils(csr_config)

    virtual csr_intf m_vif;
    uvm_active_passive_enum m_is_active;

    function new(string name = "csr_config");
        super.new(name);
        m_is_active = UVM_ACTIVE;
    endfunction

endclass
