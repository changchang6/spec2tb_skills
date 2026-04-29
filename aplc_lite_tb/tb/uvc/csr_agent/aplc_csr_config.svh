// =============================================================================
// File: aplc_csr_config.svh
// Description: APLC-Lite CSR agent configuration class
// =============================================================================

class aplc_csr_config extends uvm_object;

    // -------------------------------------------------------------------------
    // Configuration fields
    // -------------------------------------------------------------------------
    virtual aplc_csr_if              m_vif;
    uvm_active_passive_enum         m_is_active    = UVM_ACTIVE;
    bit                             m_has_coverage = 1;

    // -------------------------------------------------------------------------
    // CSR register storage (64 entries of 32-bit, addresses 0x00~0x3F)
    // -------------------------------------------------------------------------
    bit [31:0] m_csr_mem [64];

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_object_utils(aplc_csr_config)

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name = "aplc_csr_config");
        super.new(name);
        init_csr_mem();
    endfunction: new

    // -------------------------------------------------------------------------
    // Task: init_csr_mem - Initialize all CSR registers to zero
    // -------------------------------------------------------------------------
    function void init_csr_mem();
        foreach (m_csr_mem[i]) begin
            m_csr_mem[i] = 32'h0;
        end
    endfunction: init_csr_mem

    // -------------------------------------------------------------------------
    // Function: set_csr - Write a value to a CSR register
    // -------------------------------------------------------------------------
    function void set_csr(bit [5:0] addr, bit [31:0] data);
        m_csr_mem[addr] = data;
    endfunction: set_csr

    // -------------------------------------------------------------------------
    // Function: get_csr - Read a value from a CSR register
    // -------------------------------------------------------------------------
    function bit [31:0] get_csr(bit [5:0] addr);
        return m_csr_mem[addr];
    endfunction: get_csr

endclass: aplc_csr_config
