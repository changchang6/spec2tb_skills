//----------------------------------------------------------------------
// File: aplc_csr_monitor.svh
// Description: CSR monitor - observes CSR interface and creates transactions
//
// Monitors CSR interface:
//   - Detects write requests (csr_wr_en_o) and captures address + data
//   - Detects read requests (csr_rd_en_o) and captures address + response
//   - Read response has 1-cycle latency, captured via separate thread
//   - Sends transactions via analysis_port
//----------------------------------------------------------------------

class aplc_csr_monitor extends uvm_monitor;

  `uvm_component_utils(aplc_csr_monitor)

  // Analysis port
  uvm_analysis_port #(aplc_csr_txn) m_analysis_port;

  // Virtual interface
  virtual aplc_csr_if m_vif;

  // Configuration
  aplc_csr_config m_cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_analysis_port = new("m_analysis_port", this);

    if (!uvm_config_db #(aplc_csr_config)::get(this, "", "csr_config", m_cfg)) begin
      `uvm_fatal("NOCONFIG", "aplc_csr_config not found in config_db")
    end
    m_vif = m_cfg.m_vif;
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge m_vif.clk);
      collect_transaction();
    end
  endtask

  // Collect CSR transactions from the interface
  // Uses forked thread for read response capture to avoid blocking
  virtual task collect_transaction();
    bit        rd_en;
    bit        wr_en;
    bit [7:0]  addr;
    bit [31:0] wdata;

    // Sample request signals
    rd_en = m_vif.csr_rd_en_o;
    wr_en = m_vif.csr_wr_en_o;
    addr  = m_vif.csr_addr_o;
    wdata = m_vif.csr_wdata_o;

    // Create transaction for write
    if (wr_en) begin
      aplc_csr_txn txn;
      txn = aplc_csr_txn::type_id::create("txn");
      txn.addr     = addr;
      txn.data     = wdata;
      txn.write    = 1'b1;
      txn.response = wdata;

      `uvm_info("CSR_MON", $sformatf("Write: %s", txn.convert2string()), UVM_HIGH)
      m_analysis_port.write(txn);
    end

    // Create transaction for read (response captured next cycle)
    // Use a forked thread so we don't block the main collection loop
    if (rd_en) begin
      fork
        begin
          capture_read_response(addr);
        end
      join_none
    end
  endtask

  // Capture read response data (1 cycle latency)
  virtual task capture_read_response(bit [7:0] addr);
    aplc_csr_txn txn;
    bit [31:0]   rdata;

    // Wait 1 cycle for read data
    @(posedge m_vif.clk);
    rdata = m_vif.csr_rdata_i;

    txn = aplc_csr_txn::type_id::create("txn");
    txn.addr     = addr;
    txn.data     = 32'h0;
    txn.write    = 1'b0;
    txn.response = rdata;

    `uvm_info("CSR_MON", $sformatf("Read: %s", txn.convert2string()), UVM_HIGH)
    m_analysis_port.write(txn);
  endtask

endclass
