// APLC-Lite Reference Model
`ifndef APLC_REF_MODEL_SVH
`define APLC_REF_MODEL_SVH

class aplc_ref_model extends uvm_component;
    `uvm_component_utils(aplc_ref_model)

    uvm_analysis_imp #(aplc_spi_txn, aplc_ref_model) m_spi_req_imp;
    uvm_analysis_port #(aplc_ahb_txn)                 m_ahb_exp_port;
    uvm_analysis_port #(aplc_csr_txn)                 m_csr_exp_port;
    uvm_analysis_port #(aplc_spi_txn)                 m_spi_resp_port;

    bit        m_test_mode;
    bit        m_en;
    logic [31:0] m_csr_mem [64];

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_spi_req_imp = new("m_spi_req_imp", this);
        m_ahb_exp_port = new("m_ahb_exp_port", this);
        m_csr_exp_port = new("m_csr_exp_port", this);
        m_spi_resp_port = new("m_spi_resp_port", this);
        m_test_mode = 1;
        m_en = 1;
        foreach (m_csr_mem[i]) m_csr_mem[i] = '0;
    endfunction

    function bit [7:0] check_errors(aplc_spi_txn txn);
        bit [7:0] err_code;
        bit [5:0] reg_addr;
        bit [31:0] addr;
        bit [4:0] burst_len;

        reg_addr   = txn.m_reg_addr;
        addr       = txn.m_addr;
        burst_len  = txn.m_burst_len;

        // Priority chain: FRAME_ERR > BAD_OPCODE > NOT_IN_TEST > DISABLED
        //                > BAD_REG > ALIGN_ERR > BAD_BURST > BURST_BOUND
        if (!(txn.m_opcode inside {8'h10, 8'h11, 8'h20, 8'h21, 8'h22, 8'h23})) begin
            return 8'h02; // STS_BAD_OPCODE
        end
        if (!m_test_mode) begin
            return 8'h04; // STS_NOT_IN_TEST
        end
        if (!m_en) begin
            return 8'h08; // STS_DISABLED
        end
        if ((txn.m_opcode == 8'h10 || txn.m_opcode == 8'h11) && reg_addr >= 8'h40) begin
            return 8'h10; // STS_BAD_REG
        end
        if ((txn.m_opcode inside {8'h20, 8'h21, 8'h22, 8'h23}) && addr[1:0] != 2'b00) begin
            return 8'h20; // STS_ALIGN_ERR
        end
        if ((txn.m_opcode inside {8'h22, 8'h23}) && !(burst_len inside {1, 4, 8, 16})) begin
            return 8'h80; // STS_BAD_BURST
        end
        if ((txn.m_opcode inside {8'h22, 8'h23}) && burst_len > 1) begin
            if (addr[9:0] + 4 * (burst_len - 1) >= 1024) begin
                return 8'h81; // STS_BURST_BOUND
            end
        end
        return 8'h00; // STS_OK
    endfunction

    function bit is_csr_cmd(bit [7:0] opcode);
        return (opcode inside {8'h10, 8'h11});
    endfunction

    function bit is_ahb_cmd(bit [7:0] opcode);
        return (opcode inside {8'h20, 8'h21, 8'h22, 8'h23});
    endfunction

    function bit is_burst_cmd(bit [7:0] opcode);
        return (opcode inside {8'h22, 8'h23});
    endfunction

    function bit is_read_cmd(bit [7:0] opcode);
        return (opcode inside {8'h11, 8'h21, 8'h23});
    endfunction

    function void write(aplc_spi_txn txn);
        bit [7:0] err_code;
        aplc_ahb_txn ahb_exp;
        aplc_csr_txn csr_exp;
        aplc_spi_txn spi_resp;
        int burst_len;

        err_code = check_errors(txn);

        // Create predicted SPI response
        spi_resp = aplc_spi_txn::type_id::create("spi_resp");
        spi_resp.copy(txn);
        spi_resp.m_status = err_code;

        if (err_code != 8'h00) begin
            // Error path: no AHB/CSR transactions generated
            m_spi_resp_port.write(spi_resp);
            return;
        end

        // Happy path: generate expected AHB/CSR transactions
        if (is_csr_cmd(txn.m_opcode)) begin
            csr_exp = aplc_csr_txn::type_id::create("csr_exp");
            csr_exp.m_addr  = txn.m_reg_addr[5:0];
            csr_exp.m_write = (txn.m_opcode == 8'h10);
            if (csr_exp.m_write) begin
                csr_exp.m_data = txn.m_wdata.size() > 0 ? txn.m_wdata[0] : '0;
                m_csr_mem[csr_exp.m_addr] = csr_exp.m_data;
            end else begin
                csr_exp.m_data = m_csr_mem[csr_exp.m_addr];
                spi_resp.m_rdata = new[1](spi_resp.m_rdata);
                spi_resp.m_rdata[0] = csr_exp.m_data;
            end
            m_csr_exp_port.write(csr_exp);
        end else if (is_ahb_cmd(txn.m_opcode)) begin
            ahb_exp = aplc_ahb_txn::type_id::create("ahb_exp");
            ahb_exp.m_addr   = txn.m_addr;
            ahb_exp.m_write  = !is_read_cmd(txn.m_opcode);
            ahb_exp.m_size   = 3'b010; // WORD
            ahb_exp.m_trans  = 2'b10;  // NONSEQ

            if (is_burst_cmd(txn.m_opcode)) begin
                burst_len = txn.m_burst_len;
                case (burst_len)
                    1:       ahb_exp.m_burst = 3'b000; // SINGLE
                    4:       ahb_exp.m_burst = 3'b011; // INCR4
                    8:       ahb_exp.m_burst = 3'b101; // INCR8
                    16:      ahb_exp.m_burst = 3'b111; // INCR16
                    default: ahb_exp.m_burst = 3'b000;
                endcase
                ahb_exp.m_data = new[burst_len];
                if (ahb_exp.m_write) begin
                    for (int i = 0; i < burst_len && i < txn.m_wdata.size(); i++) begin
                        ahb_exp.m_data[i] = txn.m_wdata[i];
                    end
                end else begin
                    for (int i = 0; i < burst_len; i++) begin
                        ahb_exp.m_data[i] = 32'hDEAD_BEEF ^ (i * 32'h01010101);
                    end
                    spi_resp.m_rdata = new[burst_len];
                    for (int i = 0; i < burst_len; i++) begin
                        spi_resp.m_rdata[i] = ahb_exp.m_data[i];
                    end
                end
            end else begin
                // SINGLE
                ahb_exp.m_burst = 3'b000;
                ahb_exp.m_data = new[1];
                if (ahb_exp.m_write) begin
                    ahb_exp.m_data[0] = txn.m_wdata.size() > 0 ? txn.m_wdata[0] : '0;
                end else begin
                    ahb_exp.m_data[0] = 32'hDEAD_BEEF;
                    spi_resp.m_rdata = new[1];
                    spi_resp.m_rdata[0] = ahb_exp.m_data[0];
                end
            end
            m_ahb_exp_port.write(ahb_exp);
        end

        m_spi_resp_port.write(spi_resp);
    endfunction
endclass

`endif
