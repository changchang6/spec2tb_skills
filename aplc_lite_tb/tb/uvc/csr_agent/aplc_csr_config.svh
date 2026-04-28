//----------------------------------------------------------------------
// File: aplc_csr_config.svh
// Description: CSR agent configuration object
//----------------------------------------------------------------------

class aplc_csr_config extends uvm_object;

  `uvm_object_utils(aplc_csr_config)

  // Virtual interface
  virtual aplc_csr_if m_vif;

  // Active/passive mode
  bit is_active = UVM_ACTIVE;

  // Enable monitor
  bit has_monitor = 1;

  // CSR register map (address -> value)
  // Initialized with default values in build_phase of agent/driver
  bit [31:0] csr_reg_map [bit [7:0]];

  function new(string name = "aplc_csr_config");
    super.new(name);
    init_default_regs();
  endfunction

  // Initialize CSR register map with default values
  virtual function void init_default_regs();
    // 0x00: VERSION (RO, static)
    csr_reg_map[8'h00] = 32'h0001_0000; // Version 1.0
    // 0x04: CTRL (RW)
    csr_reg_map[8'h04] = 32'h0000_0000;
    // 0x08: STATUS (RO, dynamic)
    csr_reg_map[8'h08] = 32'h0000_0000;
    // 0x0C: LAST_ERR (RO, dynamic)
    csr_reg_map[8'h0C] = 32'h0000_0000;
    // 0x10: BURST_CNT (WC)
    csr_reg_map[8'h10] = 32'h0000_0000;
  endfunction

endclass
