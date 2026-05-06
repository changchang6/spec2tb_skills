class aplc_smoke_test extends aplc_base_test;

    `uvm_component_utils(aplc_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        aplc_smoke_vseq seq;

        phase.raise_objection(this);

        // Wait for reset
        #100ns;

        seq = aplc_smoke_vseq::type_id::create("seq");
        seq.start(m_env.m_spi_agent.m_sequencer);

        // Allow time for last response
        #1us;

        phase.drop_objection(this);
    endtask

endclass
