// ----------------------------------------------------------------------
// File: aplc_spi_monitor.svh
// Description: SPI-like Agent Monitor for APLC-Lite UVM testbench
//              Passively observes both request and response directions
// ----------------------------------------------------------------------

class aplc_spi_monitor extends uvm_monitor;

  // --- Virtual interface ---
  virtual aplc_spi_if m_vif;

  // --- Configuration ---
  aplc_spi_config m_cfg;

  // --- Analysis port ---
  uvm_analysis_port #(aplc_spi_txn) m_analysis_port;

  // --- Opcode constants ---
  localparam bit [7:0] OPC_WR_CSR       = 8'h10;
  localparam bit [7:0] OPC_RD_CSR       = 8'h11;
  localparam bit [7:0] OPC_AHB_WR32     = 8'h20;
  localparam bit [7:0] OPC_AHB_RD32     = 8'h21;
  localparam bit [7:0] OPC_AHB_WR_BURST = 8'h22;
  localparam bit [7:0] OPC_AHB_RD_BURST = 8'h23;

  // --- Constructor ---
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // --- Factory registration ---
  `uvm_component_utils(aplc_spi_monitor)

  // --- Build phase ---
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(aplc_spi_config)::get(this, "", "aplc_spi_config", m_cfg)) begin
      `uvm_fatal("BUILD_ERR", "Unable to get aplc_spi_config from config_db")
    end
    m_vif = m_cfg.m_vif;
    m_analysis_port = new("m_analysis_port", this);
  endfunction : build_phase

  // --- Run phase ---
  virtual task run_phase(uvm_phase phase);
    forever begin
      // Wait for activity on the bus
      @(m_vif.cb);

      // Check direction: pdo_oe_o=0 means ATE is driving (request)
      //                   pdo_oe_o=1 means DUT is driving (response)
      if (m_vif.pcs_n_i === 1'b0 && m_vif.pdo_oe_o === 1'b0) begin
        // Request phase: ATE is driving, monitor pdi_i
        monitor_request();
      end else if (m_vif.pdo_oe_o === 1'b1) begin
        // Response phase: DUT is driving, monitor pdo_o
        monitor_response();
      end
    end
  endtask : run_phase

  // ---------------------------------------------------------------
  // monitor_request : Capture a request frame from pdi_i
  // ---------------------------------------------------------------
  virtual task monitor_request();
    aplc_spi_txn txn;
    logic [511:0] frame_data;
    int           frame_bit_idx;
    int           bits_per_cycle;
    logic [15:0]  captured_word;

    txn = aplc_spi_txn::type_id::create("mon_req_txn");

    bits_per_cycle = get_bits_per_cycle(m_cfg.lane_mode);
    frame_data     = '0;
    frame_bit_idx  = 511; // MSB position

    // Capture frame data while pcs_n_i is low
    while (m_vif.pcs_n_i === 1'b0) begin
      // Read bits from pdi_i based on lane_mode
      for (int b = 0; b < bits_per_cycle; b++) begin
        if (frame_bit_idx >= 0) begin
          frame_data[frame_bit_idx] = m_vif.pdi_i[bits_per_cycle - 1 - b];
          frame_bit_idx = frame_bit_idx - 1;
        end
      end
      @(m_vif.cb);
    end

    // pcs_n_i went high, frame is complete
    // Calculate total captured bits
    begin : calc_total_bits
      int total_bits;
      total_bits = 511 - frame_bit_idx;

    if (total_bits < 8) begin
      `uvm_error("MON_REQ", $sformatf("Frame too short: %0d bits", total_bits))
      return;
    end

    // Parse opcode (first 8 bits, at MSB)
    txn.opcode = frame_data[511 -: 8];

    // Parse remaining fields based on opcode
    parse_request_frame(txn, frame_data, total_bits);

    // Set derived fields
    txn.lane_mode = m_cfg.lane_mode;

    `uvm_info("MON_REQ", $sformatf("Monitored request: %s", txn.convert2string()), UVM_HIGH)

    m_analysis_port.write(txn);
    end : calc_total_bits
  endtask : monitor_request

  // ---------------------------------------------------------------
  // parse_request_frame : Decode the captured request bits
  // ---------------------------------------------------------------
  virtual function void parse_request_frame(aplc_spi_txn txn,
                                            logic [511:0] frame_data,
                                            int total_bits);
    case (txn.opcode)
      OPC_WR_CSR: begin
        // [opcode(8) | reg_addr(8) | wdata(32)] = 48 bits
        txn.is_burst  = 1'b0;
        txn.is_read   = 1'b0;
        txn.has_rdata = 1'b0;
        txn.reg_addr  = frame_data[(511-8) -: 8];
        txn.wdata     = new[1];
        txn.wdata[0]  = frame_data[(511-16) -: 32];
        txn.burst_len = 5'd1;
      end

      OPC_RD_CSR: begin
        // [opcode(8) | reg_addr(8)] = 16 bits
        txn.is_burst  = 1'b0;
        txn.is_read   = 1'b1;
        txn.has_rdata = 1'b1;
        txn.reg_addr  = frame_data[(511-8) -: 8];
        txn.burst_len = 5'd1;
      end

      OPC_AHB_WR32: begin
        // [opcode(8) | addr(32) | wdata(32)] = 72 bits
        txn.is_burst  = 1'b0;
        txn.is_read   = 1'b0;
        txn.has_rdata = 1'b0;
        txn.addr      = frame_data[(511-8) -: 32];
        txn.wdata     = new[1];
        txn.wdata[0]  = frame_data[(511-40) -: 32];
        txn.burst_len = 5'd1;
      end

      OPC_AHB_RD32: begin
        // [opcode(8) | addr(32)] = 40 bits
        txn.is_burst  = 1'b0;
        txn.is_read   = 1'b1;
        txn.has_rdata = 1'b1;
        txn.addr      = frame_data[(511-8) -: 32];
        txn.burst_len = 5'd1;
      end

      OPC_AHB_WR_BURST: begin
        // [opcode(8) | burst_len(5) | rsvd(3) | addr(32) | wdata*N]
        txn.is_burst  = 1'b1;
        txn.is_read   = 1'b0;
        txn.has_rdata = 1'b0;
        txn.burst_len = frame_data[(511-8) -: 5];
        txn.addr      = frame_data[(511-16) -: 32];
        txn.wdata     = new[txn.burst_len];
        for (int i = 0; i < txn.burst_len; i++) begin
          txn.wdata[i] = frame_data[(511-48-i*32) -: 32];
        end
      end

      OPC_AHB_RD_BURST: begin
        // [opcode(8) | burst_len(5) | rsvd(3) | addr(32)] = 48 bits
        txn.is_burst  = 1'b1;
        txn.is_read   = 1'b1;
        txn.has_rdata = 1'b1;
        txn.burst_len = frame_data[(511-8) -: 5];
        txn.addr      = frame_data[(511-16) -: 32];
      end

      default: begin
        `uvm_error("MON_PARSE", $sformatf("Unknown opcode: 0x%02h", txn.opcode))
      end
    endcase
  endfunction : parse_request_frame

  // ---------------------------------------------------------------
  // monitor_response : Capture a response frame from pdo_o
  // ---------------------------------------------------------------
  virtual task monitor_response();
    aplc_spi_txn txn;
    logic [511:0] resp_data;
    int           resp_bit_idx;
    int           bits_per_cycle;
    logic [7:0]   status_val;
    bit           is_known_request;
    int           extra_bits;
    int           num_words;

    // We need to know what kind of request this response belongs to.
    // The monitor tracks the last observed request opcode to determine
    // the expected response format. This is a simplified approach.
    // A more robust implementation would use a request queue.

    txn = aplc_spi_txn::type_id::create("mon_resp_txn");

    bits_per_cycle = get_bits_per_cycle(m_cfg.lane_mode);
    resp_data      = '0;
    resp_bit_idx   = 511;

    // Capture at least the status byte (8 bits)
    begin : capture_status_loop
      int captured;
      int bits_this_cycle;
      captured = 0;
      while (captured < 8) begin
        bits_this_cycle = ((8 - captured) < bits_per_cycle) ?
                           (8 - captured) : bits_per_cycle;
        for (int b = 0; b < bits_this_cycle; b++) begin
          if (m_vif.pdo_oe_o === 1'b1) begin
            resp_data[resp_bit_idx] = m_vif.pdo_o[bits_per_cycle - 1 - b];
            resp_bit_idx = resp_bit_idx - 1;
          end else begin
            // DUT stopped driving before we got 8 bits
            `uvm_error("MON_RESP", "DUT stopped driving before status byte complete")
            return;
          end
        end
        captured = captured + bits_this_cycle;
        if (captured < 8 && m_vif.pdo_oe_o === 1'b1) begin
          @(m_vif.cb);
        end
      end
    end : capture_status_loop

    // Parse status
    status_val   = resp_data[511 -: 8];
    txn.status   = status_val;

    // For responses with rdata, continue capturing.
    // We capture based on pdo_oe_o staying asserted and
    // use the expected response length from the last request.
    // Here we capture until pdo_oe_o de-asserts for generality.
    if (m_vif.pdo_oe_o === 1'b1) begin
      @(m_vif.cb);
      while (m_vif.pdo_oe_o === 1'b1) begin
        for (int b = 0; b < bits_per_cycle; b++) begin
          if (resp_bit_idx >= 0) begin
            resp_data[resp_bit_idx] = m_vif.pdo_o[bits_per_cycle - 1 - b];
            resp_bit_idx = resp_bit_idx - 1;
          end
        end
        @(m_vif.cb);
      end
    end

    // Calculate total captured bits beyond status
    extra_bits = 511 - 8 - resp_bit_idx;

    // Parse rdata if present
    if (extra_bits >= 32) begin
      num_words  = extra_bits / 32;
      txn.rdata  = new[num_words];
      txn.has_rdata = 1'b1;
      for (int i = 0; i < num_words; i++) begin
        txn.rdata[i] = resp_data[(511-8-i*32) -: 32];
      end
      // Determine if burst based on number of rdata words
      txn.is_burst = (num_words > 1) ? 1'b1 : 1'b0;
      txn.burst_len = (num_words > 1) ? num_words : 5'd1;
    end else begin
      txn.has_rdata = 1'b0;
      txn.is_burst  = 1'b0;
      txn.burst_len = 5'd1;
    end

    txn.lane_mode = m_cfg.lane_mode;

    `uvm_info("MON_RESP", $sformatf("Monitored response: %s", txn.convert2string()), UVM_HIGH)

    m_analysis_port.write(txn);
  endtask : monitor_response

  // ---------------------------------------------------------------
  // get_bits_per_cycle : Map lane_mode to bits per clock cycle
  // ---------------------------------------------------------------
  virtual function int get_bits_per_cycle(bit [1:0] lm);
    case (lm)
      2'b00: get_bits_per_cycle = 1;
      2'b01: get_bits_per_cycle = 4;
      2'b10: get_bits_per_cycle = 8;
      2'b11: get_bits_per_cycle = 16;
      default: get_bits_per_cycle = 1;
    endcase
  endfunction : get_bits_per_cycle

  // ---------------------------------------------------------------
  // check_protocol : Detect protocol violations
  // ---------------------------------------------------------------
  virtual task check_protocol();
    // Check that pcs_n_i is not asserted while pdo_oe_o is high
    // (no new request while DUT is still driving a response)
    if (m_vif.pcs_n_i === 1'b0 && m_vif.pdo_oe_o === 1'b1) begin
      `uvm_error("MON_PROTO", "Protocol violation: pcs_n_i low while DUT is driving (pdo_oe_o=1)")
    end
  endtask : check_protocol

endclass : aplc_spi_monitor
