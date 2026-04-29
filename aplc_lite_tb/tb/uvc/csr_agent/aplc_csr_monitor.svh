// =============================================================================
// File: aplc_csr_monitor.svh
// Description: APLC-Lite CSR monitor
//              Monitors CSR bus transactions and sends via analysis port
// =============================================================================

class aplc_csr_monitor extends uvm_monitor;

    // -------------------------------------------------------------------------
    // Member variables
    // -------------------------------------------------------------------------
    virtual aplc_csr_if               m_vif;
    aplc_csr_config                   m_config;
    uvm_analysis_port #(aplc_csr_txn) m_analysis_port;

    // -------------------------------------------------------------------------
    // UVM factory registration
    // -------------------------------------------------------------------------
    `uvm_component_utils(aplc_csr_monitor)

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

        m_analysis_port = new("m_analysis_port", this);

        if (!uvm_config_db #(aplc_csr_config)::get(this, "", "m_config", m_config)) begin
            `uvm_fatal("APLC_CSR_MON", "Failed to get m_config from config db")
        end

        m_vif = m_config.m_vif;
        if (m_vif == null) begin
            `uvm_fatal("APLC_CSR_MON", "Virtual interface handle is null")
        end
    endfunction: build_phase

    // -------------------------------------------------------------------------
    // run_phase - main monitor loop
    // -------------------------------------------------------------------------
    task run_phase(uvm_phase phase);
        forever begin
            @(m_vif.mon_cb);

            // Check for valid CSR transaction
            if (m_vif.mon_cb.csr_valid === 1'b1) begin
                if (m_vif.mon_cb.csr_write === 1'b1) begin
                    collect_write();
                end else begin
                    collect_read();
                end
            end
        end
    endtask: run_phase

    // -------------------------------------------------------------------------
    // Task: collect_write - Collect a CSR write transaction
    // -------------------------------------------------------------------------
    task collect_write();
        aplc_csr_txn txn;

        txn = aplc_csr_txn::type_id::create("txn");
        txn.m_addr  = m_vif.mon_cb.csr_addr;
        txn.m_data  = m_vif.mon_cb.csr_wdata;
        txn.m_write = 1'b1;

        `uvm_info("APLC_CSR_MON",
            $sformatf("Collected write: %s", txn.convert2string()),
            UVM_MEDIUM)

        m_analysis_port.write(txn);
    endtask: collect_write

    // -------------------------------------------------------------------------
    // Task: collect_read - Collect a CSR read transaction
    //   CSR read has 1-cycle latency, so rdata is valid on the next cycle
    // -------------------------------------------------------------------------
    task collect_read();
        aplc_csr_txn txn;
        bit [5:0]  addr;

        addr = m_vif.mon_cb.csr_addr;

        // Wait 1 cycle for rdata to be valid (1-cycle read latency)
        @(m_vif.mon_cb);

        txn = aplc_csr_txn::type_id::create("txn");
        txn.m_addr  = addr;
        txn.m_data  = m_vif.mon_cb.csr_rdata;
        txn.m_write = 1'b0;

        `uvm_info("APLC_CSR_MON",
            $sformatf("Collected read: %s", txn.convert2string()),
            UVM_MEDIUM)

        m_analysis_port.write(txn);
    endtask: collect_read

endclass: aplc_csr_monitor
