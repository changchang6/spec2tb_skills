//----------------------------------------------------------------------
// File: aplc_ahb_config.svh
// Description: AHB-Lite agent configuration object
//----------------------------------------------------------------------

class aplc_ahb_config extends uvm_object;

  `uvm_object_utils(aplc_ahb_config)

  // Virtual interface
  virtual aplc_ahb_if m_vif;

  // Active/passive mode
  bit is_active = UVM_ACTIVE;

  // Enable monitor
  bit has_monitor = 1;

  // Default delay for hready (0 = no delay)
  int default_delay = 0;

  // Error injection enable
  bit error_inject = 0;

  // Beat index on which to inject error (0-based)
  int error_beat_idx = -1;

  function new(string name = "aplc_ahb_config");
    super.new(name);
  endfunction

endclass
