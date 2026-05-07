// APLC-Lite SPI Transaction
// Represents a command sent/received via the external test IO interface
class spi_xtn extends uvm_sequence_item;

    `uvm_object_utils(spi_xtn)

    // Command fields
    rand logic [7:0]  opcode;
    rand logic [7:0]  reg_addr;
    rand logic [31:0] addr;
    rand logic [31:0] wdata[];       // dynamic array: 1 for single, burst_len for burst, 0 for reads
    rand logic [4:0]  burst_len;
    rand logic [1:0]  lane_mode;

    // Config fields (set by sequence, used by ref_model for error checking)
    rand bit en;
    rand bit test_mode;

    // Category flags (derived from opcode)
    bit is_read;
    bit is_csr;
    bit is_ahb;
    bit is_burst;
    bit frame_abort;

    // Response fields
    rand logic [7:0]  status;
    rand logic [31:0] rdata;

    // Opcode definitions
    localparam logic [7:0] OP_WR_CSR       = 8'h10;
    localparam logic [7:0] OP_RD_CSR       = 8'h11;
    localparam logic [7:0] OP_AHB_WR32     = 8'h20;
    localparam logic [7:0] OP_AHB_RD32     = 8'h21;
    localparam logic [7:0] OP_AHB_WR_BURST = 8'h22;
    localparam logic [7:0] OP_AHB_RD_BURST = 8'h23;

    // Status code definitions
    localparam logic [7:0] STS_OK           = 8'h00;
    localparam logic [7:0] STS_FRAME_ERR    = 8'h01;
    localparam logic [7:0] STS_BAD_OPCODE   = 8'h02;
    localparam logic [7:0] STS_NOT_IN_TEST  = 8'h04;
    localparam logic [7:0] STS_DISABLED     = 8'h08;
    localparam logic [7:0] STS_BAD_REG      = 8'h10;
    localparam logic [7:0] STS_ALIGN_ERR    = 8'h20;
    localparam logic [7:0] STS_AHB_ERR      = 8'h40;
    localparam logic [7:0] STS_BAD_BURST    = 8'h80;
    localparam logic [7:0] STS_BURST_BOUND  = 8'h81;

    constraint c_wdata_size {
        solve opcode before wdata;
        if (opcode inside {OP_WR_CSR, OP_AHB_WR32})
            wdata.size() == 1;
        else if (opcode inside {OP_AHB_WR_BURST})
            wdata.size() == burst_len;
        else
            wdata.size() == 0;
    }

    constraint c_lane_mode {
        lane_mode inside {2'b00, 2'b01, 2'b10, 2'b11};
    }

    constraint c_valid_opcode {
        opcode inside {OP_WR_CSR, OP_RD_CSR, OP_AHB_WR32,
                       OP_AHB_RD32, OP_AHB_WR_BURST, OP_AHB_RD_BURST};
    }

    constraint c_burst_len_valid {
        if (opcode == OP_AHB_WR_BURST || opcode == OP_AHB_RD_BURST)
            burst_len inside {5'd1, 5'd4, 5'd8, 5'd16};
        else
            burst_len == 5'd0;
    }

    function new(string name = "spi_xtn");
        super.new(name);
    endfunction

    function void post_randomize();
        is_read  = opcode inside {OP_RD_CSR, OP_AHB_RD32, OP_AHB_RD_BURST};
        is_csr   = opcode inside {OP_WR_CSR, OP_RD_CSR};
        is_ahb   = opcode inside {OP_AHB_WR32, OP_AHB_RD32, OP_AHB_WR_BURST, OP_AHB_RD_BURST};
        is_burst = opcode inside {OP_AHB_WR_BURST, OP_AHB_RD_BURST};
    endfunction

    function string convert2string();
        string s;
        s = $sformatf("opcode=0x%02h reg_addr=0x%02h addr=0x%08h burst_len=%0d status=0x%02h rdata=0x%08h en=%0b test_mode=%0b",
                       opcode, reg_addr, addr, burst_len, status, rdata, en, test_mode);
        if (wdata.size() > 0)
            s = {s, $sformatf(" wdata[0]=0x%08h", wdata[0])};
        return s;
    endfunction

    function void do_copy(uvm_object rhs);
        spi_xtn rhs_;
        super.do_copy(rhs);
        $cast(rhs_, rhs);
        opcode     = rhs_.opcode;
        reg_addr   = rhs_.reg_addr;
        addr       = rhs_.addr;
        wdata      = rhs_.wdata;
        burst_len  = rhs_.burst_len;
        lane_mode  = rhs_.lane_mode;
        en         = rhs_.en;
        test_mode  = rhs_.test_mode;
        is_read    = rhs_.is_read;
        is_csr     = rhs_.is_csr;
        is_ahb     = rhs_.is_ahb;
        is_burst   = rhs_.is_burst;
        frame_abort = rhs_.frame_abort;
        status     = rhs_.status;
        rdata      = rhs_.rdata;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        spi_xtn rhs_;
        do_compare = 1;
        $cast(rhs_, rhs);
        do_compare &= (opcode    === rhs_.opcode);
        do_compare &= (reg_addr  === rhs_.reg_addr);
        do_compare &= (addr      === rhs_.addr);
        do_compare &= (burst_len === rhs_.burst_len);
        if (wdata.size() != rhs_.wdata.size()) do_compare = 0;
        else begin
            foreach (wdata[i])
                if (wdata[i] !== rhs_.wdata[i]) do_compare = 0;
        end
    endfunction

endclass
