// APLC-Lite Smoke Test
`ifndef APLC_SMOKE_TEST_SVH
`define APLC_SMOKE_TEST_SVH

class aplc_smoke_test extends aplc_base_test;
    `uvm_component_utils(aplc_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        aplc_smoke_seq seq;
        phase.raise_objection(this);
        seq = aplc_smoke_seq::type_id::create("seq");
        seq.start(m_env.m_spi_agent.m_sequencer);
        phase.drop_objection(this);
    endtask
endclass

`endif
