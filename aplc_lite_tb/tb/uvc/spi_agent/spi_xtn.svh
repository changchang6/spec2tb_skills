// SPI request transaction
class spi_xtn extends uvm_sequence_item;

    `uvm_object_utils(spi_xtn)

    // Opcode definitions
    typedef enum bit [7:0] {
        WR_CSR       = 8'h10,
        RD_CSR       = 8'h11,
        AHB_WR32     = 8'h20,
        AHB_RD32     = 8'h21,
        AHB_WR_BURST = 8'h22,
        AHB_RD_BURST = 8'h23
    } opcode_e;

    // Status code definitions
    typedef enum bit [7:0] {
        STS_OK         = 8'h00,
        STS_FRAME_ERR  = 8'h01,
        STS_BAD_OPCODE = 8'h02,
        STS_NOT_IN_TEST= 8'h04,
        STS_DISABLED   = 8'h08,
        STS_BAD_REG    = 8'h10,
        STS_ALIGN_ERR  = 8'h20,
        STS_AHB_ERR    = 8'h40,
        STS_BAD_BURST  = 8'h80,
        STS_BURST_BOUND= 8'h81
    } status_e;

    rand bit [7:0]  opcode;
    rand bit [7:0]  reg_addr;
    rand bit [31:0] addr;
    rand bit [31:0] wdata[];
    rand bit [4:0]  burst_len;
    rand bit [1:0]  lane_mode;

    bit              en;
    bit              test_mode;
    bit              frame_abort;

    // Derived classification
    bit              is_read;
    bit              is_csr;
    bit              is_ahb;
    bit              is_burst;

    constraint c_wdata_size {
        solve opcode before wdata;
        opcode == WR_CSR       -> wdata.size() == 1;
        opcode == AHB_WR32     -> wdata.size() == 1;
        opcode == AHB_WR_BURST -> wdata.size() == burst_len;
        opcode inside {RD_CSR, AHB_RD32, AHB_RD_BURST} -> wdata.size() == 0;
    }

    constraint c_burst_len {
        solve opcode before burst_len;
        opcode inside {AHB_WR_BURST, AHB_RD_BURST} -> burst_len inside {1, 4, 8, 16};
        opcode inside {WR_CSR, RD_CSR, AHB_WR32, AHB_RD32} -> burst_len == 0;
    }

    constraint c_reg_addr {
        solve opcode before reg_addr;
        opcode inside {WR_CSR, RD_CSR} -> reg_addr < 64;
    }

    constraint c_addr_align {
        solve opcode before addr;
        opcode inside {AHB_WR32, AHB_RD32, AHB_WR_BURST, AHB_RD_BURST} -> addr[1:0] == 2'b00;
    }

    constraint c_lane_mode {
        lane_mode inside {2'b00, 2'b01, 2'b10, 2'b11};
    }

    function new(string name = "spi_xtn");
        super.new(name);
    endfunction

    function void post_randomize();
        is_csr   = opcode inside {WR_CSR, RD_CSR};
        is_ahb   = opcode inside {AHB_WR32, AHB_RD32, AHB_WR_BURST, AHB_RD_BURST};
        is_read  = opcode inside {RD_CSR, AHB_RD32, AHB_RD_BURST};
        is_burst = opcode inside {AHB_WR_BURST, AHB_RD_BURST};
    endfunction

    function bit [11:0] get_frame_length();
        case (opcode)
            WR_CSR:       get_frame_length = 48;
            RD_CSR:       get_frame_length = 16;
            AHB_WR32:     get_frame_length = 72;
            AHB_RD32:     get_frame_length = 40;
            AHB_WR_BURST: get_frame_length = 48 + 32 * burst_len;
            AHB_RD_BURST: get_frame_length = 48;
            default:      get_frame_length = 0;
        endcase
    endfunction

    function bit [11:0] get_response_length();
        case (opcode)
            WR_CSR, AHB_WR32, AHB_WR_BURST:
                get_response_length = 8;
            RD_CSR, AHB_RD32:
                get_response_length = 40;
            AHB_RD_BURST:
                get_response_length = 8 + 32 * burst_len;
            default:
                get_response_length = 8;
        endcase
    endfunction

    function int get_bpc();
        case (lane_mode)
            2'b00: get_bpc = 1;
            2'b01: get_bpc = 4;
            2'b10: get_bpc = 8;
            2'b11: get_bpc = 16;
        endcase
    endfunction

    virtual function void do_copy(uvm_object rhs);
        spi_xtn rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        opcode    = rhs_.opcode;
        reg_addr  = rhs_.reg_addr;
        addr      = rhs_.addr;
        wdata     = rhs_.wdata;
        burst_len = rhs_.burst_len;
        lane_mode = rhs_.lane_mode;
        en        = rhs_.en;
        test_mode = rhs_.test_mode;
        frame_abort = rhs_.frame_abort;
        is_read   = rhs_.is_read;
        is_csr    = rhs_.is_csr;
        is_ahb    = rhs_.is_ahb;
        is_burst  = rhs_.is_burst;
    endfunction

    virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        spi_xtn rhs_;
        bit same = 1;
        $cast(rhs_, rhs);
        same &= (opcode    == rhs_.opcode);
        same &= (reg_addr  == rhs_.reg_addr);
        same &= (addr      == rhs_.addr);
        same &= (burst_len == rhs_.burst_len);
        same &= (is_read   == rhs_.is_read);
        same &= (is_csr    == rhs_.is_csr);
        same &= (is_ahb    == rhs_.is_ahb);
        same &= (is_burst  == rhs_.is_burst);
        if (wdata.size() == rhs_.wdata.size()) begin
            foreach (wdata[i])
                same &= (wdata[i] == rhs_.wdata[i]);
        end else begin
            same = 0;
        end
        return same;
    endfunction

    virtual function string convert2string();
        string s;
        s = $sformatf("opcode=0x%02h reg_addr=0x%02h addr=0x%08h burst_len=%0d lane=%0d en=%0b test_mode=%0b",
            opcode, reg_addr, addr, burst_len, lane_mode, en, test_mode);
        if (wdata.size() > 0) begin
            foreach (wdata[i])
                s = {s, $sformatf(" wdata[%0d]=0x%08h", i, wdata[i])};
        end
        return s;
    endfunction

    virtual function void do_print(uvm_printer printer);
        printer.m_string = convert2string();
    endfunction

    virtual function void do_record(uvm_recorder recorder);
        super.do_record(recorder);
    endfunction

endclass
