// APLC Scoreboard
// Verifies CSR readback values against shadow register model

class aplc_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(aplc_scoreboard)

    uvm_analysis_export#(spi_xtn) m_spi_export;
    uvm_analysis_export#(csr_xtn) m_csr_export;

    uvm_tlm_analysis_fifo#(spi_xtn) m_spi_fifo;
    uvm_tlm_analysis_fifo#(csr_xtn) m_csr_fifo;

    aplc_reg_model m_reg_model;

    int m_check_count;
    int m_pass_count;
    int m_fail_count;

    function new(string name = "aplc_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_spi_export = new("m_spi_export", this);
        m_csr_export = new("m_csr_export", this);
        m_spi_fifo   = new("m_spi_fifo", this);
        m_csr_fifo   = new("m_csr_fifo", this);
        m_reg_model  = aplc_reg_model::type_id::create("m_reg_model");
    endfunction

    function void connect_phase(uvm_phase phase);
        m_spi_export.connect(m_spi_fifo.analysis_export);
        m_csr_export.connect(m_csr_fifo.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
        fork
            process_spi();
            process_csr();
        join
    endtask

    task process_spi();
        spi_xtn txn;
        forever begin
            m_spi_fifo.get(txn);
            `uvm_info(get_type_name(), $sformatf("Got SPI txn: %s", txn.convert2string()), UVM_HIGH)

            // Update shadow model on writes
            case (txn.m_opcode)
                8'h10: begin // WR_CSR
                    m_reg_model.write(txn.m_reg_addr, txn.m_wdata);
                end
                8'h11: begin // RD_CSR - check readback
                    logic [31:0] expected;
                    expected = m_reg_model.read(txn.m_reg_addr);
                    m_check_count++;
                    if (txn.m_resp_status == 8'h00 && txn.m_resp_has_rdata) begin
                        if (txn.m_resp_rdata !== expected) begin
                            `uvm_error(get_type_name(), $sformatf(
                                "CSR RD mismatch: addr=0x%02h expected=0x%08h got=0x%08h",
                                txn.m_reg_addr, expected, txn.m_resp_rdata))
                            m_fail_count++;
                        end else begin
                            `uvm_info(get_type_name(), $sformatf(
                                "CSR RD match: addr=0x%02h data=0x%08h",
                                txn.m_reg_addr, txn.m_resp_rdata), UVM_LOW)
                            m_pass_count++;
                        end
                    end
                end
            endcase
        end
    endtask

    task process_csr();
        csr_xtn txn;
        forever begin
            m_csr_fifo.get(txn);
            `uvm_info(get_type_name(), $sformatf("Got CSR txn: %s", txn.convert2string()), UVM_HIGH)

            // Update shadow model on CSR writes from DUT
            if (!txn.is_read) begin
                m_reg_model.write(txn.addr, txn.wdata);
            end
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), $sformatf(
            "Scoreboard summary: checks=%0d pass=%0d fail=%0d",
            m_check_count, m_pass_count, m_fail_count), UVM_LOW)
    endfunction

endclass
