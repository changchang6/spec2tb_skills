//----------------------------------------------------------------------
// File: aplc_csr_driver.svh
// Description: CSR slave driver - responds to DUT CSR requests
//
// DUT drives: csr_rd_en_o, csr_wr_en_o, csr_addr_o, csr_wdata_o
// This agent drives: csr_rdata_i (returned 1 cycle after csr_rd_en)
//
// CSR register types:
//   RO  - Read Only: writes ignored, reads return stored value
//   RW  - Read/Write: reads and writes both allowed
//   WC  - Write Clear: writing any value clears to 0, reads return value
//   Dynamic RO - Read Only, but value can be updated externally
//----------------------------------------------------------------------

class aplc_csr_driver extends uvm_driver #(aplc_csr_txn);

  `uvm_component_utils(aplc_csr_driver)

  // Virtual interface
  virtual aplc_csr_if m_vif;

  // Configuration
  aplc_csr_config m_cfg;

  // Internal register map (maintained by this driver)
  bit [31:0] m_regs [bit [7:0]];

  // Register access type enumeration
  typedef enum {
    CSR_RO,    // Read Only
    CSR_RW,    // Read/Write
    CSR_WC     // Write Clear
  } csr_access_e;

  // Register access type map
  csr_access_e m_reg_type [bit [7:0]];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(aplc_csr_config)::get(this, "", "csr_config", m_cfg)) begin
      `uvm_fatal("NOCONFIG", "aplc_csr_config not found in config_db")
    end
    m_vif = m_cfg.m_vif;
    init_regs();
  endfunction

  // Initialize register map with defaults and access types
  virtual function void init_regs();
    // 0x00: VERSION (RO, static)
    m_regs[8'h00]    = 32'h0001_0000;
    m_reg_type[8'h00] = CSR_RO;

    // 0x04: CTRL (RW)
    m_regs[8'h04]    = 32'h0000_0000;
    m_reg_type[8'h04] = CSR_RW;

    // 0x08: STATUS (RO, dynamic)
    m_regs[8'h08]    = 32'h0000_0000;
    m_reg_type[8'h08] = CSR_RO;

    // 0x0C: LAST_ERR (RO, dynamic)
    m_regs[8'h0C]    = 32'h0000_0000;
    m_reg_type[8'h0C] = CSR_RO;

    // 0x10: BURST_CNT (WC)
    m_regs[8'h10]    = 32'h0000_0000;
    m_reg_type[8'h10] = CSR_WC;
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Initialize output
    m_vif.csr_rdata_i <= 32'h0;

    forever begin
      @(posedge m_vif.clk);
      process_csr_access();
    end
  endtask

  // Process CSR read/write requests from DUT
  virtual task process_csr_access();
    bit [7:0]  addr;
    bit [31:0] wdata;
    bit        rd_en;
    bit        wr_en;

    // Sample request signals from DUT
    rd_en = m_vif.csr_rd_en_o;
    wr_en = m_vif.csr_wr_en_o;
    addr  = m_vif.csr_addr_o;
    wdata = m_vif.csr_wdata_o;

    // Handle write request
    if (wr_en) begin
      handle_write(addr, wdata);
    end

    // Handle read request (response driven next cycle)
    if (rd_en) begin
      handle_read(addr);
    end
    else begin
      // No read request: drive 0 (or hold previous - spec says 1 cycle latency)
      m_vif.csr_rdata_i <= 32'h0;
    end
  endtask

  // Handle a CSR write
  virtual function void handle_write(bit [7:0] addr, bit [31:0] wdata);
    csr_access_e access_type;

    if (m_reg_type.exists(addr)) begin
      access_type = m_reg_type[addr];
    end
    else begin
      access_type = CSR_RW; // Default for unmapped addresses
    end

    case (access_type)
      CSR_RO: begin
        // Read Only: ignore write, no effect
        `uvm_info("CSR_DRV", $sformatf("Write to RO register addr=0x%02h ignored", addr), UVM_HIGH)
      end
      CSR_RW: begin
        // Read/Write: store value
        m_regs[addr] = wdata;
        `uvm_info("CSR_DRV", $sformatf("Write RW addr=0x%02h data=0x%08h", addr, wdata), UVM_HIGH)
      end
      CSR_WC: begin
        // Write Clear: writing any value clears to 0
        m_regs[addr] = 32'h0;
        `uvm_info("CSR_DRV", $sformatf("Write WC addr=0x%02h (cleared to 0)", addr), UVM_HIGH)
      end
      default: begin
        m_regs[addr] = wdata;
      end
    endcase
  endfunction

  // Handle a CSR read (drive csr_rdata_i next cycle)
  virtual task handle_read(bit [7:0] addr);
    bit [31:0] rdata;

    if (m_regs.exists(addr)) begin
      rdata = m_regs[addr];
    end
    else begin
      rdata = 32'h0; // Default for unmapped addresses
    end

    // Drive read data with 1-cycle latency
    m_vif.csr_rdata_i <= rdata;

    `uvm_info("CSR_DRV", $sformatf("Read addr=0x%02h rdata=0x%08h", addr, rdata), UVM_HIGH)
  endtask

  // Utility: update a register value externally (for dynamic RO registers)
  virtual function void set_reg(bit [7:0] addr, bit [31:0] value);
    m_regs[addr] = value;
  endfunction

  // Utility: read a register value (for scoreboarding)
  virtual function bit [31:0] get_reg(bit [7:0] addr);
    if (m_regs.exists(addr)) begin
      return m_regs[addr];
    end
    return 32'h0;
  endfunction

endclass
