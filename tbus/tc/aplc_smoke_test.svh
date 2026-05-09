// APLC Smoke Test
class aplc_smoke_test extends aplc_base_test;

    `uvm_component_utils(aplc_smoke_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        aplc_smoke_vseq vseq;

        phase.raise_objection(this, get_type_name());

        vseq = aplc_smoke_vseq::type_id::create("vseq");

        // Set the sequencer for the virtual sequence
        if (m_env.m_spi_agent.m_sequencer != null) begin
            vseq.start(m_env.m_spi_agent.m_sequencer);
        end else begin
            `uvm_fatal(get_type_name(), "SPI sequencer is null")
        end

        phase.drop_objection(this, get_type_name());
    endtask

endclass
