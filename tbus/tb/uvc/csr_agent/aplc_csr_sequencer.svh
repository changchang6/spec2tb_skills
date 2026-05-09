// APLC CSR Sequencer
class aplc_csr_sequencer extends uvm_sequencer #(aplc_csr_transaction);

    `uvm_component_utils(aplc_csr_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
