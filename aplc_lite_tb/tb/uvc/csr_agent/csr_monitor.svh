// CSR Monitor for APLC_LITE
// Observes CSR bus and publishes transactions

class csr_monitor extends uvm_monitor;

    `uvm_component_utils(csr_monitor)

    virtual csr_intf.MON_MP m_vif;
    csr_config m_cfg;
    uvm_analysis_port#(csr_xtn) m_ap;

    function new(string name = "csr_monitor", uvm_component parent = null);
        super.new(name, parent);
        m_ap = new("m_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(csr_config)::get(this, "", "csr_config", m_cfg)) begin
            `uvm_fatal(get_type_name(), "Cannot get csr_config from config_db")
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        m_vif = m_cfg.m_vif;
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(m_vif.mon_cb);
            if (m_vif.mon_cb.csr_wr_en) begin
                csr_xtn txn;
                txn = csr_xtn::type_id::create("txn");
                txn.is_read = 1'b0;
                txn.addr    = m_vif.mon_cb.csr_addr;
                txn.wdata   = m_vif.mon_cb.csr_wdata;
                `uvm_info(get_type_name(), $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
                m_ap.write(txn);
            end
            if (m_vif.mon_cb.csr_rd_en) begin
                csr_xtn txn;
                txn = csr_xtn::type_id::create("txn");
                txn.is_read = 1'b1;
                txn.addr    = m_vif.mon_cb.csr_addr;
                // rdata is available 1 cycle after rd_en, capture on next cycle
                @(m_vif.mon_cb);
                txn.rdata = m_vif.mon_cb.csr_rdata;
                `uvm_info(get_type_name(), $sformatf("Observed: %s", txn.convert2string()), UVM_HIGH)
                m_ap.write(txn);
            end
        end
    endtask

endclass
