// APLC CSR Monitor - Captures CSR read/write transactions
class aplc_csr_monitor extends uvm_monitor;

    `uvm_component_utils(aplc_csr_monitor)

    virtual aplc_csr_if m_vif;
    static string msg_id = "APLC_CSR_MON";

    uvm_analysis_port #(aplc_csr_transaction) m_ap;

    // Pipeline register for 1-cycle read latency
    bit          m_rd_pending;
    logic [7:0]  m_pending_rd_addr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual aplc_csr_if)::get(this, "", "vif", m_vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
        end
        m_ap = new("m_ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        m_rd_pending = 0;
        fork
            capture_csr_transactions();
        join_none
    endtask

    task capture_csr_transactions();
        forever begin
            @(m_vif.mon_cb);
            if (m_vif.mon_cb.rst_n_i !== 1'b1) begin
                m_rd_pending = 0;
                continue;
            end

            // Capture rdata for pending read (1-cycle latency per LRS)
            if (m_rd_pending) begin
                aplc_csr_transaction rd_xtn;
                rd_xtn = aplc_csr_transaction::type_id::create("csr_rd");
                rd_xtn.m_write = 0;
                rd_xtn.m_addr  = m_pending_rd_addr;
                rd_xtn.m_rdata = m_vif.mon_cb.csr_rdata_i;
                `uvm_info(msg_id, $sformatf("Captured: %s", rd_xtn.convert2string()), UVM_HIGH)
                m_ap.write(rd_xtn);
                m_rd_pending = 0;
            end

            // Check for write transaction
            if (m_vif.mon_cb.csr_wr_en_o === 1'b1) begin
                aplc_csr_transaction wr_xtn;
                wr_xtn = aplc_csr_transaction::type_id::create("csr_wr");
                wr_xtn.m_write = 1;
                wr_xtn.m_addr  = m_vif.mon_cb.csr_addr_o;
                wr_xtn.m_wdata = m_vif.mon_cb.csr_wdata_o;
                `uvm_info(msg_id, $sformatf("Captured: %s", wr_xtn.convert2string()), UVM_HIGH)
                m_ap.write(wr_xtn);
            end

            // Check for read transaction - store address for next-cycle capture
            if (m_vif.mon_cb.csr_rd_en_o === 1'b1) begin
                m_pending_rd_addr = m_vif.mon_cb.csr_addr_o;
                m_rd_pending = 1;
            end
        end
    endtask

endclass
