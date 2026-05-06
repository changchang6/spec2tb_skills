class csr_sequencer extends uvm_sequencer #(csr_xtn);

    `uvm_component_utils(csr_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
