class csr_monitor extends uvm_monitor;

    `uvm_component_utils(csr_monitor)

    virtual csr_if m_vif;
    csr_config     m_cfg;
    uvm_analysis_port #(csr_xtn) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(csr_config)::get(this, "", "cfg", m_cfg))
            `uvm_fatal(get_type_name(), "Cannot get csr_config")
        m_vif = m_cfg.m_vif;
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        bit rd_en_d1;
        bit [7:0] addr_d1;

        rd_en_d1 = 1'b0;
        addr_d1  = 8'b0;
        forever begin
            @(m_vif.mon_cb);
            // Capture write transaction
            if (m_vif.mon_cb.csr_wr_en) begin
                csr_xtn xtn = csr_xtn::type_id::create("wr_xtn");
                xtn.is_write = 1'b1;
                xtn.addr     = m_vif.mon_cb.csr_addr;
                xtn.wdata    = m_vif.mon_cb.csr_wdata;
                ap.write(xtn);
            end
            // Capture read transaction (rdata available 1 cycle after rd_en)
            if (rd_en_d1) begin
                csr_xtn xtn = csr_xtn::type_id::create("rd_xtn");
                xtn.is_write = 1'b0;
                xtn.addr     = addr_d1;
                xtn.rdata    = m_vif.mon_cb.csr_rdata;
                ap.write(xtn);
            end
            rd_en_d1 = m_vif.mon_cb.csr_rd_en;
            addr_d1  = m_vif.mon_cb.csr_addr;
        end
    endtask

endclass
