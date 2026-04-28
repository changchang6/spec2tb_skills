//----------------------------------------------------------------------
// File: aplc_ahb_monitor.svh
// Description: AHB-Lite monitor - observes bus and creates transactions
//
// Monitors AHB bus activity with proper pipeline awareness:
//   - Detects NONSEQ as start of transfer
//   - Tracks burst beats (SEQ following NONSEQ)
//   - Captures address, data, burst info
//   - Handles hready=0 (wait states) correctly:
//       When hready=0, both address and data phases are stalled
//   - Sends transactions via analysis_port
//   - Detects AHB protocol violations
//----------------------------------------------------------------------

class aplc_ahb_monitor extends uvm_monitor;

  `uvm_component_utils(aplc_ahb_monitor)

  // Analysis port
  uvm_analysis_port #(aplc_ahb_txn) m_analysis_port;

  // Virtual interface
  virtual aplc_ahb_if m_vif;

  // Configuration
  aplc_ahb_config m_cfg;

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

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_analysis_port = new("m_analysis_port", this);

    if (!uvm_config_db #(aplc_ahb_config)::get(this, "", "ahb_config", m_cfg)) begin
      `uvm_fatal("NOCONFIG", "aplc_ahb_config not found in config_db")
    end
    m_vif = m_cfg.m_vif;
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge m_vif.hclk);
      collect_transaction();
    end
  endtask

  // Collect AHB transactions from the bus
  // Uses cycle-by-cycle tracking that correctly handles pipeline stalls
  virtual task collect_transaction();
    bit [1:0]  cur_htrans;
    bit [31:0] cur_addr;
    bit        cur_write;
    bit [2:0]  cur_burst;
    bit [2:0]  cur_size;
    bit        cur_hready;

    aplc_ahb_txn txn;
    int          beat_count;
    int          expected_beats;
    bit [31:0]   burst_addr;
    bit          burst_active;
    bit          burst_write;
    bit [2:0]    burst_type;

    // Sample address phase signals
    cur_htrans  = m_vif.htrans;
    cur_addr    = m_vif.haddr;
    cur_write   = m_vif.hwrite;
    cur_burst   = m_vif.hburst;
    cur_size    = m_vif.hsize;
    cur_hready  = m_vif.hready;

    // Detect start of transfer (NONSEQ with hready)
    // Note: hready here reflects the data phase completion; when hready=1,
    // the address phase is accepted and data phase moves forward
    if (cur_htrans == HTYPE_NONSEQ && cur_hready) begin
      txn = aplc_ahb_txn::type_id::create("txn");
      txn.addr  = cur_addr;
      txn.write = cur_write;
      txn.burst = cur_burst;
      txn.size  = cur_size;
      txn.trans = cur_htrans;

      // Calculate expected burst length
      case (cur_burst)
        HBURST_SINGLE: expected_beats = 1;
        HBURST_INCR4:  expected_beats = 4;
        HBURST_INCR8:  expected_beats = 8;
        HBURST_INCR16: expected_beats = 16;
        default:       expected_beats = 1;
      endcase
      txn.burst_len = expected_beats;
      txn.data = new[expected_beats];

      burst_addr   = cur_addr;
      burst_active = 1'b1;
      burst_write  = cur_write;
      burst_type   = cur_burst;
      beat_count   = 0;

      // Collect data phase for first beat
      // Data phase occurs when hready=1 (which may be this cycle or a future one)
      collect_beat_data(txn, beat_count, burst_write);
      beat_count++;
      burst_addr = burst_addr + 4;

      // Collect remaining burst beats
      while (beat_count < expected_beats && burst_active) begin
        @(posedge m_vif.hclk);
        cur_htrans  = m_vif.htrans;
        cur_hready  = m_vif.hready;

        // When hready=0, the address phase is stalled, wait for hready
        if (!cur_hready) begin
          // Wait for hready to assert
          while (!m_vif.hready) begin
            @(posedge m_vif.hclk);
          end
          cur_htrans = m_vif.htrans;
        end

        if (cur_htrans == HTYPE_SEQ) begin
          // Valid SEQ beat in burst
          burst_addr = m_vif.haddr;
          collect_beat_data(txn, beat_count, burst_write);
          beat_count++;
          burst_addr = burst_addr + 4;
        end
        else if (cur_htrans == HTYPE_IDLE) begin
          // Burst was terminated early
          `uvm_warning("AHB_MON", $sformatf("Burst terminated early at beat %0d of %0d", beat_count, expected_beats))
          burst_active = 1'b0;
        end
        else if (cur_htrans == HTYPE_NONSEQ) begin
          // New transfer started, burst was broken
          `uvm_warning("AHB_MON", $sformatf("Burst broken by NONSEQ at beat %0d of %0d", beat_count, expected_beats))
          burst_active = 1'b0;
        end
      end

      // Resize data array if burst was terminated early
      if (beat_count < expected_beats) begin
        bit [31:0] tmp_data[];
        tmp_data = new[beat_count];
        foreach (tmp_data[i]) tmp_data[i] = txn.data[i];
        txn.data = new[beat_count];
        foreach (txn.data[i]) txn.data[i] = tmp_data[i];
        txn.burst_len = beat_count;
      end

      // Send transaction
      `uvm_info("AHB_MON", $sformatf("Collected: %s", txn.convert2string()), UVM_HIGH)
      m_analysis_port.write(txn);
    end
    else if (cur_htrans == HTYPE_SEQ && cur_hready) begin
      // Stray SEQ without preceding NONSEQ - protocol violation
      `uvm_error("AHB_MON", $sformatf("SEQ without NONSEQ at addr=0x%08h", cur_addr))
    end

    // Check for protocol violations
    check_protocol(cur_htrans, cur_burst, cur_size, cur_hready);
  endtask

  // Collect data phase for a single beat
  // Waits for hready=1 in the data phase, then samples data
  virtual task collect_beat_data(aplc_ahb_txn txn, int beat_idx, bit is_write);
    // Wait for data phase (1 cycle after address phase)
    @(posedge m_vif.hclk);

    // Wait for hready in data phase (may have wait states)
    while (!m_vif.hready) begin
      @(posedge m_vif.hclk);
    end

    if (is_write) begin
      txn.data[beat_idx] = m_vif.hwdata;
    end
    else begin
      txn.data[beat_idx] = m_vif.hrdata;
    end

    // Capture response for this beat
    txn.response = m_vif.hresp;
  endtask

  // Check for AHB protocol violations
  virtual function void check_protocol(bit [1:0] htrans, bit [2:0] hburst, bit [2:0] hsize, bit hready);
    // Check that hsize is WORD (3'b010) for this design
    if ((htrans == HTYPE_NONSEQ || htrans == HTYPE_SEQ) && hsize != 3'b010) begin
      `uvm_error("AHB_PROTO", $sformatf("Invalid hsize=%03b, expected 3'b010 (WORD)", hsize))
    end

    // Check that hburst encoding is valid during active transfer
    if ((htrans == HTYPE_NONSEQ || htrans == HTYPE_SEQ)) begin
      if (!(hburst inside {HBURST_SINGLE, HBURST_INCR4, HBURST_INCR8, HBURST_INCR16})) begin
        `uvm_error("AHB_PROTO", $sformatf("Invalid hburst=%03b during active transfer", hburst))
      end
    end
  endfunction

endclass
