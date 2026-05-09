// APLC Base Virtual Sequence
class aplc_base_vseq extends uvm_sequence #(aplc_spi_transaction);

    `uvm_object_utils(aplc_base_vseq)
    `uvm_declare_p_sequencer(aplc_spi_sequencer)

    function new(string name = "aplc_base_vseq");
        super.new(name);
    endfunction

    task pre_start();
        if (starting_phase != null) begin
            starting_phase.raise_objection(this, get_type_name());
        end
    endtask

    task post_start();
        if (starting_phase != null) begin
            starting_phase.drop_objection(this, get_type_name());
        end
    endtask

    // Helper: send SPI transaction
    task send_spi_item(aplc_spi_transaction req);
        req.randomize();
        start_item(req);
        finish_item(req);
    endtask

endclass
