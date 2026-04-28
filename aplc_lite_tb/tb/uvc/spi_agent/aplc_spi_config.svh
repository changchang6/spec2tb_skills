// ----------------------------------------------------------------------
// File: aplc_spi_config.svh
// Description: SPI-like Agent Configuration object for APLC-Lite UVM testbench
//              The virtual interface type (aplc_spi_if) must be defined
//              in the testbench top level before this file is included.
// ----------------------------------------------------------------------

class aplc_spi_config extends uvm_object;

  // --- Configuration fields ---
  virtual aplc_spi_if             m_vif;
  uvm_active_passive_enum         is_active   = UVM_ACTIVE;
  bit [1:0]                       lane_mode   = 2'b00;
  bit                             has_monitor = 1'b1;

  // --- Constructor ---
  function new(string name = "aplc_spi_config");
    super.new(name);
  endfunction : new

  // --- Factory registration ---
  `uvm_object_utils(aplc_spi_config)

  // --- convert2string ---
  virtual function string convert2string();
    string active_str;
    active_str = (is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE";
    return $sformatf("is_active=%s lane_mode=%0d has_monitor=%0b",
                     active_str, lane_mode, has_monitor);
  endfunction : convert2string

  // --- do_copy ---
  virtual function void do_copy(uvm_object rhs);
    aplc_spi_config rhs_;
    super.do_copy(rhs);
    if (!$cast(rhs_, rhs)) begin
      `uvm_error("DO_COPY", "Cast failed in do_copy")
      return;
    end
    m_vif       = rhs_.m_vif;
    is_active   = rhs_.is_active;
    lane_mode   = rhs_.lane_mode;
    has_monitor = rhs_.has_monitor;
  endfunction : do_copy

  // --- do_compare ---
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    aplc_spi_config rhs_;
    if (!$cast(rhs_, rhs)) begin
      `uvm_error("DO_COMPARE", "Cast failed in do_compare")
      return 0;
    end
    do_compare = super.do_compare(rhs, comparer);
    do_compare &= (is_active   === rhs_.is_active);
    do_compare &= (lane_mode   === rhs_.lane_mode);
    do_compare &= (has_monitor === rhs_.has_monitor);
  endfunction : do_compare

  // --- do_print ---
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("is_active",   is_active,   32);
    printer.print_field("lane_mode",   lane_mode,    2);
    printer.print_field("has_monitor", has_monitor,  1);
  endfunction : do_print

  // --- do_record ---
  virtual function void do_record(uvm_recorder recorder);
    super.do_record(recorder);
    recorder.record_field("is_active",   is_active,  32, UVM_NORADIX);
    recorder.record_field("lane_mode",   lane_mode,   2, UVM_NORADIX);
    recorder.record_field("has_monitor", has_monitor,  1, UVM_NORADIX);
  endfunction : do_record

endclass : aplc_spi_config
