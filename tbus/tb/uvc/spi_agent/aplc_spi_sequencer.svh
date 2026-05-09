// APLC SPI Sequencer
class aplc_spi_sequencer extends uvm_sequencer #(aplc_spi_transaction);

    `uvm_component_utils(aplc_spi_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
