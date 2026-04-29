// APLC Smoke Test
// Tests CSR write/read with value verification

class aplc_smoke_test extends aplc_base_test;

    `uvm_component_utils(aplc_smoke_test)

    function new(string name = "aplc_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        aplc_smoke_vseq vseq;

        phase.raise_objection(this);

        vseq = aplc_smoke_vseq::type_id::create("vseq");
        vseq.start(m_env.m_vsequencer);

        #1us;
        phase.drop_objection(this);
    endtask

endclass
