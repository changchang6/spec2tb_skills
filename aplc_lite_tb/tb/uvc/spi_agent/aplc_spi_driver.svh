// ----------------------------------------------------------------------
// File: aplc_spi_driver.svh
// Description: SPI-like Agent Driver for APLC-Lite UVM testbench
//              Uses half-duplex serial protocol with lane_mode support
//              Drives: pcs_n_i, pdi_i[15:0]
//              Observes: pdo_o[15:0], pdo_oe_o
// ----------------------------------------------------------------------

class aplc_spi_driver extends uvm_driver #(aplc_spi_txn);

  // --- Virtual interface ---
  virtual aplc_spi_if m_vif;

  // --- Configuration ---
  aplc_spi_config m_cfg;

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
  `uvm_component_utils(aplc_spi_driver)

  // --- Build phase ---
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(aplc_spi_config)::get(this, "", "aplc_spi_config", m_cfg)) begin
      `uvm_fatal("BUILD_ERR", "Unable to get aplc_spi_config from config_db")
    end
    m_vif = m_cfg.m_vif;
  endfunction : build_phase

  // --- Run phase ---
  virtual task run_phase(uvm_phase phase);
    // Initialize interface signals: idle state
    m_vif.pcs_n_i   <= 1'b1;
    m_vif.pdi_i     <= '0;
    m_vif.en_i      <= 1'b1;
    m_vif.test_mode_i <= 1'b1;
    m_vif.lane_mode_i <= 2'b00;

    // Wait for reset to deassert before driving any transactions
    wait (m_vif.rst_n === 1'b1);
    @(m_vif.cb);

    forever begin
      seq_item_port.try_next_item(req);
      if (req != null) begin
        drive_transaction(req);
        seq_item_port.item_done();
      end else begin
        @(m_vif.cb);
      end
    end
  endtask : run_phase

  // ---------------------------------------------------------------
  // drive_transaction : Top-level task to drive a full transaction
  // ---------------------------------------------------------------
  virtual task drive_transaction(aplc_spi_txn txn);
    drive_request(txn);
    if (txn.has_rdata) begin
      // Read commands expect status + rdata response
      drive_turnaround();
      capture_response(txn);
    end else begin
      // Write commands expect status-only response
      drive_turnaround();
      capture_status_only(txn);
    end
  endtask : drive_transaction

  // ---------------------------------------------------------------
  // drive_request : Shift out the request frame MSB-first
  // ---------------------------------------------------------------
  virtual task drive_request(aplc_spi_txn txn);
    logic [511:0] frame_data;
    int           frame_bits;
    int           bits_per_cycle;

    // Determine bits per cycle from lane_mode
    bits_per_cycle = get_bits_per_cycle(txn.lane_mode);

    // Build the request frame
    build_request_frame(txn, frame_bits, frame_data);

    // Set lane_mode and assert pcs_n_i to start frame
    // Drive pcs_n_i and first data word in the same cycle so DUT captures
    // valid data on the very first clock edge it sees pcs_n_i low
    m_vif.lane_mode_i <= txn.lane_mode;
    m_vif.pcs_n_i     <= 1'b0;

    // Shift out frame data MSB-first (first word driven immediately)
    send_frame(frame_data, frame_bits, bits_per_cycle);

    // De-assert pcs_n_i to end frame
    m_vif.pcs_n_i <= 1'b1;
    m_vif.pdi_i   <= '0;
    @(m_vif.cb);
  endtask : drive_request

  // ---------------------------------------------------------------
  // build_request_frame : Construct the request bit-stream
  //   Frame data is left-aligned at bit 511 (MSB)
  //   frame_bits returns the total number of valid bits
  // ---------------------------------------------------------------
  virtual function void build_request_frame(aplc_spi_txn txn,
                                            output int frame_bits,
                                            output logic [511:0] frame);
    int bit_pos;

    frame   = '0;
    bit_pos = 0;

    // Opcode is always first 8 bits at MSB
    frame[511 -: 8] = txn.opcode;
    bit_pos = 8;

    case (txn.opcode)
      OPC_WR_CSR: begin
        // [opcode(8) | reg_addr(8) | wdata(32)] = 48 bits
        frame[(511-8) -: 8]   = txn.reg_addr;
        bit_pos = 16;
        frame[(511-16) -: 32] = txn.wdata[0];
        bit_pos = 48;
      end

      OPC_RD_CSR: begin
        // [opcode(8) | reg_addr(8)] = 16 bits
        frame[(511-8) -: 8] = txn.reg_addr;
        bit_pos = 16;
      end

      OPC_AHB_WR32: begin
        // [opcode(8) | addr(32) | wdata(32)] = 72 bits
        frame[(511-8) -: 32]  = txn.addr;
        bit_pos = 40;
        frame[(511-40) -: 32] = txn.wdata[0];
        bit_pos = 72;
      end

      OPC_AHB_RD32: begin
        // [opcode(8) | addr(32)] = 40 bits
        frame[(511-8) -: 32] = txn.addr;
        bit_pos = 40;
      end

      OPC_AHB_WR_BURST: begin
        // [opcode(8) | burst_len(5) | rsvd(3) | addr(32) | wdata*N(32)]
        frame[(511-8) -: 5]   = txn.burst_len;
        frame[(511-13) -: 3]  = 3'b000;
        bit_pos = 16;
        frame[(511-16) -: 32] = txn.addr;
        bit_pos = 48;
        for (int i = 0; i < txn.wdata.size(); i++) begin
          frame[(511-bit_pos) -: 32] = txn.wdata[i];
          bit_pos = bit_pos + 32;
        end
      end

      OPC_AHB_RD_BURST: begin
        // [opcode(8) | burst_len(5) | rsvd(3) | addr(32)] = 48 bits
        frame[(511-8) -: 5]   = txn.burst_len;
        frame[(511-13) -: 3]  = 3'b000;
        bit_pos = 16;
        frame[(511-16) -: 32] = txn.addr;
        bit_pos = 48;
      end

      default: begin
        `uvm_error("DRIVE", $sformatf("Unknown opcode: 0x%02h", txn.opcode))
      end
    endcase

    frame_bits = bit_pos;
  endfunction : build_request_frame

  // ---------------------------------------------------------------
  // send_frame : Shift out bits according to lane_mode
  //   DUT CAXIS concatenates pdi_i at the LSB of its shift register,
  //   so the first byte of each 16-bit word must be in pdi_i[7:0].
  //   For 1/4/8-bit modes the existing MSB-first mapping is correct.
  //   For 16-bit mode, byte-swap each word so the earlier byte
  //   occupies the lower 8 bits.
  // ---------------------------------------------------------------
  virtual task send_frame(logic [511:0] frame_data, int frame_bits, int bits_per_cycle);
    int remaining_bits;
    int shift_idx;
    logic [15:0] data_out;

    remaining_bits = frame_bits;
    shift_idx      = 511; // MSB position in the packed array

    while (remaining_bits > 0) begin
      int bits_this_cycle;
      bits_this_cycle = (remaining_bits < bits_per_cycle) ? remaining_bits : bits_per_cycle;

      // Build pdi_i value: MSB-first in the active lane positions
      data_out = '0;
      for (int b = 0; b < bits_this_cycle; b++) begin
        data_out[bits_per_cycle - 1 - b] = frame_data[shift_idx - b];
      end

      // For 16-bit mode, swap bytes so first byte goes to pdi_i[7:0]
      // This matches DUT CAXIS convention where lower bits are earlier data
      if (bits_per_cycle == 16 && bits_this_cycle == 16) begin
        data_out = {data_out[7:0], data_out[15:8]};
      end

      m_vif.pdi_i <= data_out;
      @(m_vif.cb);

      shift_idx      = shift_idx - bits_this_cycle;
      remaining_bits = remaining_bits - bits_this_cycle;
    end
  endtask : send_frame

  // ---------------------------------------------------------------
  // drive_turnaround : 1-cycle turnaround between request/response
  //   During turnaround, ATE stops driving (pdi_i = 0)
  // ---------------------------------------------------------------
  virtual task drive_turnaround();
    m_vif.pdi_i <= '0;
    @(m_vif.cb);
  endtask : drive_turnaround

  // ---------------------------------------------------------------
  // capture_response : Capture status + rdata from DUT response
  //   Used for read transactions (RD_CSR, AHB_RD32, AHB_RD_BURST)
  // ---------------------------------------------------------------
  virtual task capture_response(aplc_spi_txn txn);
    logic [7:0]   status_val;
    int           bits_per_cycle;
    int           total_response_bits;
    logic [511:0] resp_data;
    int           resp_bit_idx;
    int           bits_this_cycle;
    int           num_words;

    bits_per_cycle = get_bits_per_cycle(txn.lane_mode);

    // Wait for DUT to start driving (pdo_oe_o = 1)
    wait (m_vif.pdo_oe_o === 1'b1);
    @(m_vif.cb);

    // Determine total response bits
    case (txn.opcode)
      OPC_RD_CSR:       total_response_bits = 8 + 32; // status + rdata
      OPC_AHB_RD32:     total_response_bits = 8 + 32;
      OPC_AHB_RD_BURST: total_response_bits = 8 + 32 * txn.burst_len;
      default:          total_response_bits = 8; // fallback
    endcase

    // Capture response bits MSB-first
    resp_data    = '0;
    resp_bit_idx = 511;

    begin : capture_resp_loop
      int captured;
      captured = 0;
      while (captured < total_response_bits) begin
        bits_this_cycle = ((total_response_bits - captured) < bits_per_cycle) ?
                           (total_response_bits - captured) : bits_per_cycle;

        // Read from pdo_o, MSB-first in active lane positions
        for (int b = 0; b < bits_this_cycle; b++) begin
          resp_data[resp_bit_idx - b] = m_vif.pdo_o[bits_per_cycle - 1 - b];
        end

        resp_bit_idx = resp_bit_idx - bits_this_cycle;
        captured     = captured + bits_this_cycle;

        if (captured < total_response_bits) begin
          @(m_vif.cb);
        end
      end
    end : capture_resp_loop

    // Parse status byte (first 8 bits of response)
    status_val = resp_data[511 -: 8];
    txn.status = status_val;

    // Parse rdata words if present
    if (total_response_bits > 8) begin
      int num_words;
      num_words   = (total_response_bits - 8) / 32;
      txn.rdata   = new[num_words];
      for (int i = 0; i < num_words; i++) begin
        txn.rdata[i] = resp_data[(511-8-i*32) -: 32];
      end
    end

    // Wait for DUT to release the bus
    wait (m_vif.pdo_oe_o === 1'b0);
  endtask : capture_response

  // ---------------------------------------------------------------
  // capture_status_only : Capture only the status byte for writes
  //   Used for write transactions (WR_CSR, AHB_WR32, AHB_WR_BURST)
  // ---------------------------------------------------------------
  virtual task capture_status_only(aplc_spi_txn txn);
    logic [7:0] status_val;
    int         bits_per_cycle;
    int         bits_this_cycle;
    int         captured;

    bits_per_cycle = get_bits_per_cycle(txn.lane_mode);

    // Wait for DUT to start driving (pdo_oe_o = 1)
    wait (m_vif.pdo_oe_o === 1'b1);
    @(m_vif.cb);

    // Capture 8-bit status MSB-first
    status_val = '0;
    captured = 0;
    while (captured < 8) begin
      bits_this_cycle = ((8 - captured) < bits_per_cycle) ?
                         (8 - captured) : bits_per_cycle;
      for (int b = 0; b < bits_this_cycle; b++) begin
        status_val[7 - captured - b] = m_vif.pdo_o[bits_per_cycle - 1 - b];
      end
      captured = captured + bits_this_cycle;
      if (captured < 8) @(m_vif.cb);
    end

    txn.status = status_val;

    // Wait for DUT to release the bus
    wait (m_vif.pdo_oe_o === 1'b0);
  endtask : capture_status_only

  // ---------------------------------------------------------------
  // get_bits_per_cycle : Map lane_mode to bits per clock cycle
  //   2'b00 = 1-bit, 2'b01 = 4-bit, 2'b10 = 8-bit, 2'b11 = 16-bit
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

endclass : aplc_spi_driver
