// CSR Slave Driver
// Responds to DUT's CSR interface read/write requests
// Maintains a memory model of CSR registers
class csr_driver extends uvm_driver #(csr_xtn);

    `uvm_component_utils(csr_driver)

    virtual csr_intf.drv_mp vif;
    csr_config m_config;
    logic [31:0] csr_mem [256]; // 256-entry CSR memory

    function new(string name = "csr_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(csr_config)::get(this, "", "csr_config", m_config))
            `uvm_fatal(get_type_name(), "csr_config not found")
        init_csr_mem();
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (!uvm_config_db #(virtual csr_intf.drv_mp)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "vif not found")
    endfunction

    function void init_csr_mem();
        // Initialize CSR memory with default values
        foreach (csr_mem[i]) csr_mem[i] = 32'h0;
        csr_mem[8'h00] = 32'h0000_0220; // VERSION: v2.2
        // CTRL, STATUS, LAST_ERR, BURST_CNT default to 0
    endfunction

    task run_phase(uvm_phase phase);
        vif.drv_cb.csr_rdata <= 32'h0;
        forever begin
            @(vif.drv_cb);
            // Handle CSR write
            if (vif.drv_cb.csr_wr_en === 1'b1) begin
                csr_mem[vif.drv_cb.csr_addr] = vif.drv_cb.csr_wdata;
                `uvm_info(get_type_name(), $sformatf("CSR WR addr=0x%02h data=0x%08h",
                    vif.drv_cb.csr_addr, vif.drv_cb.csr_wdata), UVM_HIGH)
            end
            // Handle CSR read - rdata valid next cycle
            if (vif.drv_cb.csr_rd_en === 1'b1) begin
                // Drive rdata next cycle
                vif.drv_cb.csr_rdata <= csr_mem[vif.drv_cb.csr_addr];
                `uvm_info(get_type_name(), $sformatf("CSR RD addr=0x%02h data=0x%08h",
                    vif.drv_cb.csr_addr, csr_mem[vif.drv_cb.csr_addr]), UVM_HIGH)
            end else begin
                vif.drv_cb.csr_rdata <= 32'h0;
            end
        end
    endtask

    // API to set CSR value from testbench
    function void set_csr(logic [7:0] addr, logic [31:0] data);
        csr_mem[addr] = data;
    endfunction

    // API to get CSR value from testbench
    function logic [31:0] get_csr(logic [7:0] addr);
        return csr_mem[addr];
    endfunction

endclass
