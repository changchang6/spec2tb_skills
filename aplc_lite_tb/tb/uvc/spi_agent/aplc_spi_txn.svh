// ----------------------------------------------------------------------
// File: aplc_spi_txn.svh
// Description: SPI-like Agent Transaction class for APLC-Lite UVM testbench
// ----------------------------------------------------------------------

class aplc_spi_txn extends uvm_sequence_item;

  // --- Opcode constants ---
  localparam bit [7:0] OPC_WR_CSR      = 8'h10;
  localparam bit [7:0] OPC_RD_CSR      = 8'h11;
  localparam bit [7:0] OPC_AHB_WR32    = 8'h20;
  localparam bit [7:0] OPC_AHB_RD32    = 8'h21;
  localparam bit [7:0] OPC_AHB_WR_BURST = 8'h22;
  localparam bit [7:0] OPC_AHB_RD_BURST = 8'h23;

  // --- Transaction fields ---
  rand bit [7:0]   opcode;
  rand bit [4:0]   burst_len;
  rand bit [7:0]   reg_addr;
  rand bit [31:0]  addr;
  rand bit [31:0]  wdata[];
  bit [7:0]        status;
  bit [31:0]       rdata[];
  rand bit [1:0]   lane_mode;
  bit              is_read;
  bit              is_burst;
  bit              has_rdata;

  // --- Constraints ---
  constraint c_burst_len_val {
    (is_burst) -> burst_len inside {1, 4, 8, 16};
    (!is_burst) -> burst_len == 1;
  }

  constraint c_wdata_size {
    (opcode == OPC_AHB_WR_BURST) -> wdata.size() == burst_len;
    (opcode != OPC_AHB_WR_BURST) -> wdata.size() inside {0, 1};
  }

  constraint c_reg_addr_range {
    (opcode inside {OPC_WR_CSR, OPC_RD_CSR}) -> reg_addr < 64;
  }

  constraint c_addr_aligned {
    (opcode inside {OPC_AHB_WR32, OPC_AHB_RD32,
                    OPC_AHB_WR_BURST, OPC_AHB_RD_BURST}) -> addr[1:0] == 2'b00;
  }

  // --- Utility: derive is_read / is_burst / has_rdata from opcode ---
  function void post_randomize();
    case (opcode)
      OPC_RD_CSR, OPC_AHB_RD32, OPC_AHB_RD_BURST: is_read = 1'b1;
      default: is_read = 1'b0;
    endcase
    case (opcode)
      OPC_AHB_WR_BURST, OPC_AHB_RD_BURST: is_burst = 1'b1;
      default: is_burst = 1'b0;
    endcase
    case (opcode)
      OPC_RD_CSR, OPC_AHB_RD32, OPC_AHB_RD_BURST: has_rdata = 1'b1;
      default: has_rdata = 1'b0;
    endcase
  endfunction : post_randomize

  // --- Constructor ---
  function new(string name = "aplc_spi_txn");
    super.new(name);
  endfunction : new

  // --- Factory registration ---
  `uvm_object_utils(aplc_spi_txn)

  // --- convert2string ---
  virtual function string convert2string();
    string s;
    s = $sformatf("opcode=0x%02h burst_len=%0d reg_addr=0x%02h addr=0x%08h lane_mode=%0d is_read=%0b is_burst=%0b has_rdata=%0b",
                   opcode, burst_len, reg_addr, addr, lane_mode, is_read, is_burst, has_rdata);
    if (wdata.size() > 0) begin
      s = {s, $sformatf("\n  wdata[%0d]:", wdata.size())};
      foreach (wdata[i])
        s = {s, $sformatf(" 0x%08h", wdata[i])};
    end
    if (rdata.size() > 0) begin
      s = {s, $sformatf("\n  rdata[%0d]:", rdata.size())};
      foreach (rdata[i])
        s = {s, $sformatf(" 0x%08h", rdata[i])};
    end
    s = {s, $sformatf("\n  status=0x%02h", status)};
    return s;
  endfunction : convert2string

  // --- do_copy ---
  virtual function void do_copy(uvm_object rhs);
    aplc_spi_txn rhs_;
    super.do_copy(rhs);
    if (!$cast(rhs_, rhs)) begin
      `uvm_error("DO_COPY", "Cast failed in do_copy")
      return;
    end
    opcode    = rhs_.opcode;
    burst_len = rhs_.burst_len;
    reg_addr  = rhs_.reg_addr;
    addr      = rhs_.addr;
    status    = rhs_.status;
    lane_mode = rhs_.lane_mode;
    is_read   = rhs_.is_read;
    is_burst  = rhs_.is_burst;
    has_rdata = rhs_.has_rdata;
    wdata     = new[rhs_.wdata.size()];
    foreach (wdata[i]) wdata[i] = rhs_.wdata[i];
    rdata     = new[rhs_.rdata.size()];
    foreach (rdata[i]) rdata[i] = rhs_.rdata[i];
  endfunction : do_copy

  // --- do_compare ---
  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    aplc_spi_txn rhs_;
    if (!$cast(rhs_, rhs)) begin
      `uvm_error("DO_COMPARE", "Cast failed in do_compare")
      return 0;
    end
    do_compare = super.do_compare(rhs, comparer);
    do_compare &= (opcode    === rhs_.opcode);
    do_compare &= (burst_len === rhs_.burst_len);
    do_compare &= (reg_addr  === rhs_.reg_addr);
    do_compare &= (addr      === rhs_.addr);
    do_compare &= (status    === rhs_.status);
    do_compare &= (lane_mode === rhs_.lane_mode);
    do_compare &= (is_read   === rhs_.is_read);
    do_compare &= (is_burst  === rhs_.is_burst);
    do_compare &= (has_rdata === rhs_.has_rdata);
    if (wdata.size() != rhs_.wdata.size())
      do_compare = 0;
    else begin
      foreach (wdata[i])
        do_compare &= (wdata[i] === rhs_.wdata[i]);
    end
    if (rdata.size() != rhs_.rdata.size())
      do_compare = 0;
    else begin
      foreach (rdata[i])
        do_compare &= (rdata[i] === rhs_.rdata[i]);
    end
  endfunction : do_compare

  // --- do_print ---
  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("opcode",    opcode,    8);
    printer.print_field("burst_len", burst_len, 5);
    printer.print_field("reg_addr",  reg_addr,  8);
    printer.print_field("addr",      addr,     32);
    printer.print_field("status",    status,    8);
    printer.print_field("lane_mode", lane_mode, 2);
    printer.print_field("is_read",   is_read,   1);
    printer.print_field("is_burst",  is_burst,  1);
    printer.print_field("has_rdata", has_rdata, 1);
    foreach (wdata[i])
      printer.print_field($sformatf("wdata[%0d]", i), wdata[i], 32);
    foreach (rdata[i])
      printer.print_field($sformatf("rdata[%0d]", i), rdata[i], 32);
  endfunction : do_print

  // --- do_record ---
  virtual function void do_record(uvm_recorder recorder);
    super.do_record(recorder);
    recorder.record_field("opcode",    opcode,    8,  UVM_NORADIX);
    recorder.record_field("burst_len", burst_len, 5,  UVM_NORADIX);
    recorder.record_field("reg_addr",  reg_addr,  8,  UVM_NORADIX);
    recorder.record_field("addr",      addr,     32,  UVM_NORADIX);
    recorder.record_field("status",    status,    8,  UVM_NORADIX);
    recorder.record_field("lane_mode", lane_mode, 2,  UVM_NORADIX);
    recorder.record_field("is_read",   is_read,   1,  UVM_NORADIX);
    recorder.record_field("is_burst",  is_burst,  1,  UVM_NORADIX);
    recorder.record_field("has_rdata", has_rdata, 1,  UVM_NORADIX);
    foreach (wdata[i])
      recorder.record_field($sformatf("wdata[%0d]", i), wdata[i], 32, UVM_NORADIX);
    foreach (rdata[i])
      recorder.record_field($sformatf("rdata[%0d]", i), rdata[i], 32, UVM_NORADIX);
  endfunction : do_record

endclass : aplc_spi_txn
