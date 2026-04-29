// APLC Virtual Sequencer

class aplc_vsequencer extends uvm_sequencer;

    `uvm_component_utils(aplc_vsequencer)

    spi_sequencer  m_spi_seqr;
    csr_sequencer  m_csr_seqr;
    ahb_sseqr      m_ahb_sseqr;

    function new(string name = "aplc_vsequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass
