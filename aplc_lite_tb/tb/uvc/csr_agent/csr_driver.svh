// CSR Reactive Driver for APLC_LITE
// Monitors CSR writes and updates the shared shadow register model
// Note: csr_rdata is driven combinationally in tb.sv (not by this driver)
// to avoid clocking block output #0 timing races with DPIPE

class csr_driver extends uvm_driver#(csr_xtn);

    `uvm_component_utils(csr_driver)

    virtual csr_intf m_vif;
    csr_config m_cfg;

    function new(string name = "csr_driver", uvm_component parent = null);
        super.new(name, parent);
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

    // csr_rdata is driven by tb.sv combinational logic, not by this driver
    task run_phase(uvm_phase phase);
        @(posedge m_vif.clk_i);
        forever begin
            @(posedge m_vif.clk_i);
        end
    endtask

endclass
