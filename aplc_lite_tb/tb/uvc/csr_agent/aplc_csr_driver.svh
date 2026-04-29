// =============================================================================
// File: aplc_csr_driver.svh
// Description: APLC-Lite CSR driver
//              Responds to DUT's CSR read/write requests
//              Models external CSR File behavior with 1-cycle read latency
//
// CSR Protocol:
//   - Write: csr_valid=1, csr_write=1, csr_addr & csr_wdata valid same cycle
//            Data is stored at the addressed register immediately
//   - Read:  csr_valid=1, csr_write=0, csr_addr valid this cycle
//            csr_rdata is driven on the NEXT clock edge (1-cycle latency)
//   - Idle:  csr_valid=0, csr_rdata should be 0 (or don't care)
// =============================================================================

class aplc_csr_driver extends uvm_driver #(aplc_csr_txn);

    // -------------------------------------------------------------------------
    // Member variables
    // -------------------------------------------------------------------------
    virtual aplc_csr_if m_vif;
    aplc_csr_config     m_config;

    // -------------------------------------------------------------------------
    // Pending read state: tracks a read that was requested last cycle
    // whose rdata must be driven this cycle
    // -------------------------------------------------------------------------
    bit          m_read_pending;
    bit [31:0]   m_pending_rdata;

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_csr_driver)

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction: new

    // -------------------------------------------------------------------------
    // build_phase
    // -------------------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(aplc_csr_config)::get(this, "", "m_config", m_config)) begin
            `uvm_fatal("APLC_CSR_DRV", "Failed to get m_config from config db")
        end

        m_vif = m_config.m_vif;
        if (m_vif == null) begin
            `uvm_fatal("APLC_CSR_DRV", "Virtual interface handle is null")
        end
    endfunction: build_phase

    // -------------------------------------------------------------------------
    // run_phase - main driver loop
    // -------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        // Initialize state
        m_read_pending = 1'b0;
        m_pending_rdata = 32'h0;

        // Initialize outputs
        m_vif.drive_idle();

        forever begin
            @(m_vif.drv_cb);

            // If a read was pending from last cycle, drive the rdata now
            if (m_read_pending) begin
                m_vif.drv_cb.csr_rdata <= m_pending_rdata;
                m_read_pending = 1'b0;
            end else begin
                m_vif.drv_cb.csr_rdata <= 32'h0;
            end

            // Check if DUT is driving a valid CSR request
            if (m_vif.drv_cb.csr_valid === 1'b1) begin
                if (m_vif.drv_cb.csr_write === 1'b1) begin
                    // Write: store data into CSR memory immediately
                    handle_write();
                end else begin
                    // Read: schedule rdata to be driven on the next clock edge
                    handle_read();
                end
            end
        end
    endtask: run_phase

    // -------------------------------------------------------------------------
    // Task: handle_write - Process a CSR write request
    // -------------------------------------------------------------------------
    task handle_write();
        bit [5:0]  addr;
        bit [31:0] wdata;

        addr  = m_vif.drv_cb.csr_addr;
        wdata = m_vif.drv_cb.csr_wdata;

        // Store data in the CSR memory model
        m_config.m_csr_mem[addr] = wdata;

        `uvm_info("APLC_CSR_DRV",
            $sformatf("CSR Write: addr=0x%02h data=0x%08h", addr, wdata),
            UVM_HIGH)
    endtask: handle_write

    // -------------------------------------------------------------------------
    // Task: handle_read - Process a CSR read request
    //   1-cycle read latency: rdata is valid 1 cycle after rd_en
    //   The actual data is driven on the next clock edge via m_read_pending
    // -------------------------------------------------------------------------
    task handle_read();
        bit [5:0]  addr;
        bit [31:0] rdata;

        addr = m_vif.drv_cb.csr_addr;

        // Read from the CSR memory model
        rdata = m_config.m_csr_mem[addr];

        `uvm_info("APLC_CSR_DRV",
            $sformatf("CSR Read: addr=0x%02h -> data=0x%08h (1-cycle latency)", addr, rdata),
            UVM_HIGH)

        // Schedule the data to be driven on the next clock edge
        m_read_pending = 1'b1;
        m_pending_rdata = rdata;

    endtask: handle_read

endclass: aplc_csr_driver
