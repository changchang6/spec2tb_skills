//----------------------------------------------------------------------
// File: aplc_ahb_driver.svh
// Description: AHB-Lite slave driver - responds to DUT master requests
//
// AHB-Lite 2-phase pipeline:
//   Address phase: haddr, hwrite, htrans, hsize, hburst
//   Data phase (1 cycle later): hwdata (write) or hrdata (read)
//
// This slave driver uses two concurrent threads:
//   Thread 1: Captures address phase every cycle and queues for data response
//   Thread 2: Processes data phase responses from queue, drives hrdata/hready/hresp
//
// This ensures address phases are never missed even during delay/error responses.
//----------------------------------------------------------------------

class aplc_ahb_driver extends uvm_driver #(aplc_ahb_txn);

  `uvm_component_utils(aplc_ahb_driver)

  // Virtual interface
  virtual aplc_ahb_if m_vif;

  // Configuration
  aplc_ahb_config m_cfg;

  // Internal memory model (word-addressable)
  bit [31:0] m_mem [bit [31:0]];

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
  localparam bit HRESP_OKAY  = 1'b0;
  localparam bit HRESP_ERROR = 1'b1;

  // Address phase info structure for pipelining
  typedef struct {
    bit [31:0] addr;
    bit        write;
    bit [2:0]  burst;
    int        beat_idx;
  } addr_phase_t;

  // Queue of pending data-phase responses
  addr_phase_t m_pending_data[$];

  // Current beat index tracking for burst
  int m_cur_beat_idx;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(aplc_ahb_config)::get(this, "", "ahb_config", m_cfg)) begin
      `uvm_fatal("NOCONFIG", "aplc_ahb_config not found in config_db")
    end
    m_vif = m_cfg.m_vif;
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Initialize slave outputs
    m_vif.hrdata <= 32'h0;
    m_vif.hready <= 1'b1;
    m_vif.hresp  <= 1'b0;

    m_cur_beat_idx = 0;

    fork
      // Thread 1: Capture address phase every cycle
      capture_addr_phase();

      // Thread 2: Process data phase responses
      process_data_phase();
    join_none
  endtask

  // Thread 1: Capture address phase information every clock cycle
  // This thread never blocks, so no address phases are missed
  virtual task capture_addr_phase();
    bit [1:0] cur_htrans;

    forever begin
      @(posedge m_vif.hclk);

      cur_htrans = m_vif.htrans;

      if (cur_htrans == HTYPE_NONSEQ) begin
        addr_phase_t ap;
        ap.addr     = m_vif.haddr;
        ap.write    = m_vif.hwrite;
        ap.burst    = m_vif.hburst;
        ap.beat_idx = 0;
        m_pending_data.push_back(ap);
        m_cur_beat_idx = 1; // Next SEQ beat will be index 1
      end
      else if (cur_htrans == HTYPE_SEQ) begin
        addr_phase_t ap;
        ap.addr     = m_vif.haddr;
        ap.write    = m_vif.hwrite;
        ap.burst    = m_vif.hburst;
        ap.beat_idx = m_cur_beat_idx;
        m_pending_data.push_back(ap);
        m_cur_beat_idx++;
      end
      // IDLE or BUSY: no address phase to capture
    end
  endtask

  // Thread 2: Process data phase responses from the pending queue
  // This thread handles hready delays and error injection
  virtual task process_data_phase();
    bit [31:0] rdata;

    forever begin
      // Wait for a pending data phase request
      wait (m_pending_data.size() > 0);

      @(posedge m_vif.hclk);

      if (m_pending_data.size() > 0) begin
        addr_phase_t dp;
        bit          inject_err;
        int          delay;

        dp = m_pending_data[0];

        // Check if error should be injected on this beat
        inject_err = (m_cfg.error_inject && dp.beat_idx == m_cfg.error_beat_idx);

        if (inject_err) begin
          // Error response: 2 cycles
          // Cycle 1: hresp=ERROR, hready=0
          m_vif.hresp  <= HRESP_ERROR;
          m_vif.hready <= 1'b0;

          if (!dp.write) begin
            m_vif.hrdata <= 32'hDEAD_BEEF;
          end

          @(posedge m_vif.hclk);

          // Cycle 2: hresp=ERROR, hready=1
          m_vif.hresp  <= HRESP_ERROR;
          m_vif.hready <= 1'b1;

          if (dp.write) begin
            // Sample write data even on error
            m_mem[dp.addr] = m_vif.hwdata;
          end

          // Pop completed data phase
          void'(m_pending_data.pop_front());

          // Reset to OKAY
          m_vif.hresp  <= HRESP_OKAY;
          m_vif.hrdata <= 32'h0;
        end
        else begin
          // Apply configurable delay (backpressure)
          delay = m_cfg.default_delay;
          if (delay > 0) begin
            m_vif.hready <= 1'b0;
            m_vif.hresp  <= HRESP_OKAY;
            repeat (delay) begin
              @(posedge m_vif.hclk);
            end
          end

          // Normal (OKAY) response
          m_vif.hready <= 1'b1;
          m_vif.hresp  <= HRESP_OKAY;

          if (dp.write) begin
            // Write: sample hwdata from DUT master and store in memory
            m_mem[dp.addr] = m_vif.hwdata;
          end
          else begin
            // Read: drive hrdata from memory model
            if (m_mem.exists(dp.addr)) begin
              rdata = m_mem[dp.addr];
            end
            else begin
              rdata = 32'h0;
            end
            m_vif.hrdata <= rdata;
          end

          // Pop completed data phase
          void'(m_pending_data.pop_front());
        end
      end
    end
  endtask

  // Utility: preload memory (for read-response preparation)
  virtual function void write_mem(bit [31:0] addr, bit [31:0] data);
    m_mem[addr] = data;
  endfunction

  // Utility: read memory (for scoreboarding)
  virtual function bit [31:0] read_mem(bit [31:0] addr);
    if (m_mem.exists(addr)) begin
      return m_mem[addr];
    end
    return 32'h0;
  endfunction

endclass
