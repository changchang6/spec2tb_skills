//----------------------------------------------------------------------
// File: aplc_ahb_txn.svh
// Description: AHB-Lite transaction object
//----------------------------------------------------------------------

class aplc_ahb_txn extends uvm_sequence_item;

  `uvm_object_utils(aplc_ahb_txn)

  // AHB address
  rand bit [31:0] addr;

  // Data payload (dynamic array to support burst)
  rand bit [31:0] data[];

  // Transfer direction: 1=write, 0=read
  rand bit write;

  // Transfer size: 3'b010 = WORD (32-bit)
  rand bit [2:0] size;

  // Burst type
  rand bit [2:0] burst;

  // Transfer type
  rand bit [1:0] trans;

  // Response: 0=OKAY, 1=ERROR
  rand bit [1:0] response;

  // Burst length (number of beats)
  rand int burst_len;

  // Current beat index within burst
  rand int beat_idx;

  // Constants for htrans
  localparam bit [1:0] HTYPE_IDLE   = 2'b00;
  localparam bit [1:0] HTYPE_BUSY   = 2'b01;
  localparam bit [1:0] HTYPE_NONSEQ = 2'b10;
  localparam bit [1:0] HTYPE_SEQ    = 2'b11;

  // Constants for hburst
  localparam bit [2:0] HBURST_SINGLE = 3'b000;
  localparam bit [2:0] HBURST_INCR4  = 3'b011;
  localparam bit [2:0] HBURST_INCR8  = 3'b101;
  localparam bit [2:0] HBURST_INCR16 = 3'b111;

  // Constants for hresp
  localparam bit [1:0] HRESP_OKAY  = 2'b00;
  localparam bit [1:0] HRESP_ERROR = 2'b01;

  // Constraints
  constraint c_size { size == 3'b010; } // WORD only
  constraint c_data_size { data.size() == burst_len; }
  constraint c_burst_len {
    (burst == HBURST_SINGLE) -> burst_len == 1;
    (burst == HBURST_INCR4)  -> burst_len == 4;
    (burst == HBURST_INCR8)  -> burst_len == 8;
    (burst == HBURST_INCR16) -> burst_len == 16;
  }
  constraint c_burst_valid {
    burst inside {HBURST_SINGLE, HBURST_INCR4, HBURST_INCR8, HBURST_INCR16};
  }
  constraint c_trans_valid { trans inside {HTYPE_IDLE, HTYPE_NONSEQ, HTYPE_SEQ}; }
  constraint c_beat_idx { beat_idx >= 0 && beat_idx < burst_len; }
  constraint c_response { response inside {HRESP_OKAY, HRESP_ERROR}; }

  function new(string name = "aplc_ahb_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string s;
    s = $sformatf("addr=0x%08h write=%0b size=%0b burst=%0b trans=%0b response=%0b burst_len=%0d beat_idx=%0d",
                  addr, write, size, burst, trans, response, burst_len, beat_idx);
    foreach (data[i]) begin
      s = {s, $sformatf("\n  data[%0d]=0x%08h", i, data[i])};
    end
    return s;
  endfunction

  virtual function void do_copy(uvm_object rhs);
    aplc_ahb_txn rhs_;

    if (!$cast(rhs_, rhs)) begin
      `uvm_fatal("DO_COPY", "cast failed in do_copy")
    end
    super.do_copy(rhs);
    addr      = rhs_.addr;
    write     = rhs_.write;
    size      = rhs_.size;
    burst     = rhs_.burst;
    trans     = rhs_.trans;
    response  = rhs_.response;
    burst_len = rhs_.burst_len;
    beat_idx  = rhs_.beat_idx;
    data      = new[rhs_.data.size()];
    foreach (data[i]) begin
      data[i] = rhs_.data[i];
    end
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    aplc_ahb_txn rhs_;

    if (!$cast(rhs_, rhs)) begin
      `uvm_fatal("DO_COMPARE", "cast failed in do_compare")
      return 0;
    end
    if (data.size() != rhs_.data.size()) return 0;
    foreach (data[i]) begin
      if (data[i] !== rhs_.data[i]) return 0;
    end
    do_compare = (super.do_compare(rhs, comparer) &&
                  addr      === rhs_.addr &&
                  write     === rhs_.write &&
                  size      === rhs_.size &&
                  burst     === rhs_.burst &&
                  trans     === rhs_.trans &&
                  response  === rhs_.response &&
                  burst_len === rhs_.burst_len &&
                  beat_idx  === rhs_.beat_idx);
  endfunction

  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("addr",      addr,      32, UVM_HEX);
    printer.print_field("write",     write,      1, UVM_BIN);
    printer.print_field("size",      size,       3, UVM_BIN);
    printer.print_field("burst",     burst,      3, UVM_BIN);
    printer.print_field("trans",     trans,      2, UVM_BIN);
    printer.print_field("response",  response,   2, UVM_BIN);
    printer.print_int("burst_len",  burst_len,  32, UVM_DEC);
    printer.print_int("beat_idx",   beat_idx,   32, UVM_DEC);
    foreach (data[i]) begin
      printer.print_field($sformatf("data[%0d]", i), data[i], 32, UVM_HEX);
    end
  endfunction

  virtual function void do_record(uvm_recorder recorder);
    super.do_record(recorder);
    recorder.record_field("addr",     addr,     32, UVM_HEX);
    recorder.record_field("write",    write,     1, UVM_BIN);
    recorder.record_field("size",     size,      3, UVM_BIN);
    recorder.record_field("burst",    burst,     3, UVM_BIN);
    recorder.record_field("trans",    trans,     2, UVM_BIN);
    recorder.record_field("response", response,  2, UVM_BIN);
    recorder.record_field("burst_len", burst_len, 32, UVM_DEC);
    recorder.record_field("beat_idx",  beat_idx,  32, UVM_DEC);
    foreach (data[i]) begin
      recorder.record_field($sformatf("data[%0d]", i), data[i], 32, UVM_HEX);
    end
  endfunction

endclass
