// CSR Monitor
// Observes CSR interface transactions
class csr_monitor extends uvm_monitor;

    `uvm_component_utils(csr_monitor)

    uvm_analysis_port #(csr_xtn) ap;
    virtual csr_intf.mon_mp vif;

    function new(string name = "csr_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (!uvm_config_db #(virtual csr_intf.mon_mp)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "vif not found")
    endfunction

    task run_phase(uvm_phase phase);
        csr_xtn xtn;
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.csr_wr_en === 1'b1) begin
                xtn = csr_xtn::type_id::create("xtn");
                xtn.is_write = 1'b1;
                xtn.addr  = vif.mon_cb.csr_addr;
                xtn.wdata = vif.mon_cb.csr_wdata;
                `uvm_info(get_type_name(), $sformatf("Observed: %s", xtn.convert2string()), UVM_HIGH)
                ap.write(xtn);
            end
            if (vif.mon_cb.csr_rd_en === 1'b1) begin
                xtn = csr_xtn::type_id::create("xtn");
                xtn.is_write = 1'b0;
                xtn.addr  = vif.mon_cb.csr_addr;
                // rdata is valid next cycle, capture it then
                @(vif.mon_cb);
                xtn.rdata = vif.mon_cb.csr_rdata;
                `uvm_info(get_type_name(), $sformatf("Observed: %s", xtn.convert2string()), UVM_HIGH)
                ap.write(xtn);
            end
        end
    endtask

endclass
