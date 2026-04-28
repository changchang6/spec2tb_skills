//----------------------------------------------------------------------
// File: aplc_csr_txn.svh
// Description: CSR transaction object
//----------------------------------------------------------------------

class aplc_csr_txn extends uvm_sequence_item;

  `uvm_object_utils(aplc_csr_txn)

  // CSR address (8-bit)
  rand bit [7:0]  addr;

  // Data (32-bit)
  rand bit [31:0] data;

  // Direction: 1=write, 0=read
  rand bit        write;

  // Response data (for reads, the value returned by slave)
  rand bit [31:0] response;

  function new(string name = "aplc_csr_txn");
    super.new(name);
  endfunction

  virtual function string convert2string();
    string s;
    s = $sformatf("addr=0x%02h data=0x%08h write=%0b response=0x%08h",
                  addr, data, write, response);
    return s;
  endfunction

  virtual function void do_copy(uvm_object rhs);
    aplc_csr_txn rhs_;

    if (!$cast(rhs_, rhs)) begin
      `uvm_fatal("DO_COPY", "cast failed in do_copy")
    end
    super.do_copy(rhs);
    addr     = rhs_.addr;
    data     = rhs_.data;
    write    = rhs_.write;
    response = rhs_.response;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    aplc_csr_txn rhs_;

    if (!$cast(rhs_, rhs)) begin
      `uvm_fatal("DO_COMPARE", "cast failed in do_compare")
      return 0;
    end
    do_compare = (super.do_compare(rhs, comparer) &&
                  addr     === rhs_.addr &&
                  data     === rhs_.data &&
                  write    === rhs_.write &&
                  response === rhs_.response);
  endfunction

  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("addr",     addr,     8,  UVM_HEX);
    printer.print_field("data",     data,     32, UVM_HEX);
    printer.print_field("write",    write,    1,  UVM_BIN);
    printer.print_field("response", response, 32, UVM_HEX);
  endfunction

  virtual function void do_record(uvm_recorder recorder);
    super.do_record(recorder);
    recorder.record_field("addr",     addr,     8,  UVM_HEX);
    recorder.record_field("data",     data,     32, UVM_HEX);
    recorder.record_field("write",    write,    1,  UVM_BIN);
    recorder.record_field("response", response, 32, UVM_HEX);
  endfunction

endclass
