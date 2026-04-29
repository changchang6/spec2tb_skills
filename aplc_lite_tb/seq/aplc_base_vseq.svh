// APLC Base Virtual Sequence

class aplc_base_vseq extends uvm_sequence;

    `uvm_object_utils(aplc_base_vseq)
    `uvm_declare_p_sequencer(aplc_vsequencer)

    function new(string name = "aplc_base_vseq");
        super.new(name);
    endfunction

    task pre_start();
        uvm_phase phase;
        phase = get_starting_phase();
        if (phase != null) begin
            phase.raise_objection(this);
        end
    endtask

    task post_start();
        uvm_phase phase;
        phase = get_starting_phase();
        if (phase != null) begin
            phase.drop_objection(this);
        end
    endtask

endclass
