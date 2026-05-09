// APLC CSR Driver - Drives csr_rdata_i for external CSR addresses
class aplc_csr_driver extends uvm_driver #(aplc_csr_transaction);

    `uvm_component_utils(aplc_csr_driver)

    virtual aplc_csr_if m_vif;
    static string msg_id = "APLC_CSR_DRV";

    // Shadow memory for external CSR addresses
    logic [31:0] m_ext_csr_mem[logic [7:0]];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual aplc_csr_if)::get(this, "", "vif", m_vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface not found in config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        // Default: drive csr_rdata_i = 0
        m_vif.drv_cb.csr_rdata_i <= 32'h0;
        fork
            respond_reads();
        join_none
    endtask

    task respond_reads();
        forever begin
            @(m_vif.drv_cb);
            // Check for read to external address on previous cycle
            // (1-cycle read latency: DUT asserts rd_en, we respond next cycle)
            if (m_vif.drv_cb.csr_rd_en_o === 1'b1 && m_vif.drv_cb.csr_addr_o >= 8'h14) begin
                logic [7:0] rd_addr;
                rd_addr = m_vif.drv_cb.csr_addr_o;
                // Respond next cycle with data from shadow memory
                @(m_vif.drv_cb);
                if (m_ext_csr_mem.exists(rd_addr))
                    m_vif.drv_cb.csr_rdata_i <= m_ext_csr_mem[rd_addr];
                else
                    m_vif.drv_cb.csr_rdata_i <= 32'h0;
            end else begin
                m_vif.drv_cb.csr_rdata_i <= 32'h0;
            end
        end
    endtask

endclass
