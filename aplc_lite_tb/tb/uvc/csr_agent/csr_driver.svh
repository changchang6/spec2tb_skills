// CSR slave driver: responds to DUT's CSR read/write requests
class csr_driver extends uvm_driver #(csr_xtn);

    `uvm_component_utils(csr_driver)

    virtual csr_if m_vif;
    csr_config     m_cfg;
    logic [31:0] csr_mem[64];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(csr_config)::get(this, "", "cfg", m_cfg))
            `uvm_fatal(get_type_name(), "Cannot get csr_config")
        m_vif = m_cfg.m_vif;
        init_csr_mem();
    endfunction

    function void init_csr_mem();
        // Initialize CSR memory with default values
        foreach (csr_mem[i]) csr_mem[i] = 32'b0;
        csr_mem[8'h00] = 32'h0000_0220; // VERSION: v2.2
        csr_mem[8'h04] = 32'b0;          // CTRL: reset mirrors port values
        csr_mem[8'h08] = 32'b0;          // STATUS
        csr_mem[8'h0C] = 32'b0;          // LAST_ERR
        csr_mem[8'h10] = 32'b0;          // BURST_CNT
    endfunction

    task run_phase(uvm_phase phase);
        bit rd_en_d1;
        bit [7:0] addr_d1;

        m_vif.slv_cb.csr_rdata <= 32'b0;
        rd_en_d1 = 1'b0;
        addr_d1  = 8'b0;

        forever begin
            @(m_vif.slv_cb);
            // Handle write
            if (m_vif.slv_cb.csr_wr_en) begin
                if (m_vif.slv_cb.csr_addr < 64) begin
                    csr_mem[m_vif.slv_cb.csr_addr] = m_vif.slv_cb.csr_wdata;
                end
            end
            // Handle read (1 cycle delay: rd_en seen now, rdata next cycle)
            if (rd_en_d1) begin
                m_vif.slv_cb.csr_rdata <= csr_mem[addr_d1];
            end else begin
                m_vif.slv_cb.csr_rdata <= 32'b0;
            end
            // Pipeline delay registers
            rd_en_d1 = m_vif.slv_cb.csr_rd_en;
            addr_d1  = m_vif.slv_cb.csr_addr;
        end
    endtask

    // API for sequences to directly set CSR values
    function void set_csr(bit [7:0] addr, bit [31:0] data);
        if (addr < 64)
            csr_mem[addr] = data;
    endfunction

    function bit [31:0] get_csr(bit [7:0] addr);
        if (addr < 64)
            return csr_mem[addr];
        return 32'b0;
    endfunction

endclass
