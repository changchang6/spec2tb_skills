// SPI Transaction for APLC_LITE
// Represents a complete SPI frame exchange (command + response)

class spi_xtn extends uvm_sequence_item;

    `uvm_object_utils(spi_xtn)

    // Command fields
    rand logic [7:0]  m_opcode;
    rand logic [7:0]  m_reg_addr;
    rand logic [31:0] m_addr;
    rand logic [31:0] m_wdata;
    rand logic [4:0]  m_burst_len;
    rand logic [1:0]  m_lane_mode;

    // Response fields (filled by driver after DUT responds)
    logic [7:0]  m_resp_status;
    logic [31:0] m_resp_rdata;
    logic        m_resp_has_rdata;

    // Opcodes
    localparam logic [7:0] OP_WR_CSR      = 8'h10;
    localparam logic [7:0] OP_RD_CSR      = 8'h11;
    localparam logic [7:0] OP_AHB_WR32    = 8'h20;
    localparam logic [7:0] OP_AHB_RD32    = 8'h21;
    localparam logic [7:0] OP_AHB_WR_BURST = 8'h22;
    localparam logic [7:0] OP_AHB_RD_BURST = 8'h23;

    constraint opcode_c {
        m_opcode inside {OP_WR_CSR, OP_RD_CSR, OP_AHB_WR32,
                       OP_AHB_RD32, OP_AHB_WR_BURST, OP_AHB_RD_BURST};
    }

    constraint burst_len_c {
        m_burst_len inside {5'd1, 5'd4, 5'd8, 5'd16};
    }

    constraint lane_mode_c {
        m_lane_mode inside {2'b00, 2'b01, 2'b10, 2'b11};
    }

    constraint addr_align_c { m_addr[1:0] == 2'b00; }
    constraint reg_addr_range_c { m_reg_addr < 8'h40; }

    function new(string name = "spi_xtn");
        super.new(name);
    endfunction

    function void do_copy(uvm_object rhs);
        spi_xtn txn;
        super.do_copy(rhs);
        $cast(txn, rhs);
        m_opcode      = txn.m_opcode;
        m_reg_addr    = txn.m_reg_addr;
        m_addr        = txn.m_addr;
        m_wdata       = txn.m_wdata;
        m_burst_len   = txn.m_burst_len;
        m_lane_mode   = txn.m_lane_mode;
        m_resp_status = txn.m_resp_status;
        m_resp_rdata  = txn.m_resp_rdata;
        m_resp_has_rdata = txn.m_resp_has_rdata;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        spi_xtn txn;
        do_compare = super.do_compare(rhs, comparer);
        $cast(txn, rhs);
        do_compare &= (m_opcode    === txn.m_opcode);
        do_compare &= (m_reg_addr  === txn.m_reg_addr);
        do_compare &= (m_addr      === txn.m_addr);
        do_compare &= (m_wdata     === txn.m_wdata);
        do_compare &= (m_resp_status === txn.m_resp_status);
        do_compare &= (m_resp_rdata  === txn.m_resp_rdata);
    endfunction

    function string convert2string();
        string s;
        $sformat(s, "opcode=0x%02h reg_addr=0x%02h addr=0x%08h wdata=0x%08h burst_len=%0d lane=%0d | resp_status=0x%02h resp_rdata=0x%08h resp_has_rdata=%0b",
                 m_opcode, m_reg_addr, m_addr, m_wdata, m_burst_len, m_lane_mode, m_resp_status, m_resp_rdata, m_resp_has_rdata);
        return s;
    endfunction

    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("opcode", m_opcode, 8);
        printer.print_field("reg_addr", m_reg_addr, 8);
        printer.print_field("addr", m_addr, 32);
        printer.print_field("wdata", m_wdata, 32);
        printer.print_field("burst_len", m_burst_len, 5);
        printer.print_field("lane_mode", m_lane_mode, 2);
        printer.print_field("resp_status", m_resp_status, 8);
        printer.print_field("resp_rdata", m_resp_rdata, 32);
        printer.print_field("resp_has_rdata", m_resp_has_rdata, 1);
    endfunction

    function void do_record(uvm_recorder recorder);
        super.do_record(recorder);
        recorder.record_field("opcode", m_opcode, 8, UVM_NORADIX);
        recorder.record_field("reg_addr", m_reg_addr, 8, UVM_NORADIX);
        recorder.record_field("addr", m_addr, 32, UVM_NORADIX);
        recorder.record_field("wdata", m_wdata, 32, UVM_NORADIX);
        recorder.record_field("burst_len", m_burst_len, 5, UVM_NORADIX);
        recorder.record_field("lane_mode", m_lane_mode, 2, UVM_NORADIX);
        recorder.record_field("resp_status", m_resp_status, 8, UVM_NORADIX);
        recorder.record_field("resp_rdata", m_resp_rdata, 32, UVM_NORADIX);
        recorder.record_field("resp_has_rdata", m_resp_has_rdata, 1, UVM_NORADIX);
    endfunction

    // Calculate expected TX frame bit count based on opcode
    function int get_tx_bit_count();
        case (m_opcode)
            8'h10: return 48;   // WR_CSR
            8'h11: return 16;   // RD_CSR
            8'h20: return 72;   // AHB_WR32
            8'h21: return 40;   // AHB_RD32
            8'h22: return 48 + 32 * m_burst_len; // AHB_WR_BURST
            8'h23: return 48;   // AHB_RD_BURST (header only)
            default: return 0;
        endcase
    endfunction

    // Calculate expected RX (response) bit count
    function int get_rx_bit_count();
        case (m_opcode)
            8'h10: return 8;                              // WR_CSR: status only
            8'h11: return 40;                             // RD_CSR: status + rdata
            8'h20: return 8;                              // AHB_WR32: status only
            8'h21: return 40;                             // AHB_RD32: status + rdata
            8'h22: return 8;                              // AHB_WR_BURST: status only
            8'h23: return 8 + 32 * m_burst_len;          // AHB_RD_BURST: status + data
            default: return 0;
        endcase
    endfunction

endclass
