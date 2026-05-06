// APLC-Lite Scoreboard
// Checks SPI responses against expected values
`uvm_analysis_imp_decl(_spi)
`uvm_analysis_imp_decl(_csr)

class aplc_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(aplc_scoreboard)

    uvm_analysis_imp_spi #(spi_xtn, aplc_scoreboard) spi_imp;
    uvm_analysis_imp_csr #(csr_xtn, aplc_scoreboard) csr_imp;

    int m_check_count;
    int m_pass_count;
    int m_fail_count;

    function new(string name = "aplc_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        spi_imp = new("spi_imp", this);
        csr_imp = new("csr_imp", this);
    endfunction

    function void write_spi(spi_xtn xtn);
        m_check_count++;
        // Check that all commands received a valid (non-error) response
        if (xtn.status == 8'h00) begin
            m_pass_count++;
            `uvm_info(get_type_name(), $sformatf("PASS: opcode=0x%02h status=STS_OK rdata=0x%08h", xtn.opcode, xtn.rdata), UVM_HIGH)
        end else begin
            m_fail_count++;
            `uvm_error(get_type_name(), $sformatf("FAIL: opcode=0x%02h status=0x%02h rdata=0x%08h", xtn.opcode, xtn.status, xtn.rdata))
        end
    endfunction

    function void write_csr(csr_xtn xtn);
        `uvm_info(get_type_name(), $sformatf("CSR observed: %s", xtn.convert2string()), UVM_HIGH)
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Checks: %0d  Pass: %0d  Fail: %0d",
            m_check_count, m_pass_count, m_fail_count), UVM_NONE)
        if (m_fail_count > 0) begin
            `uvm_error(get_type_name(), "SCOREBOARD FAIL")
        end
    endfunction

endclass
