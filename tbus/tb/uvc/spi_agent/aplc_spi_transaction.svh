// APLC SPI Transaction
class aplc_spi_transaction extends uvm_sequence_item;

    `uvm_object_utils(aplc_spi_transaction)

    // Request fields
    rand logic [7:0]  m_opcode;
    rand logic [7:0]  m_reg_addr;
    rand logic [31:0] m_ahb_addr;
    rand logic [31:0] m_wdata[];
    rand logic [4:0]  m_burst_len;
    rand logic [1:0]  m_lane_mode;
    rand bit          m_en;
    rand bit          m_test_mode;

    // Response fields
    logic [7:0]       m_status;
    logic [31:0]      m_rdata[];
    bit               m_has_rdata;
    bit               m_is_write;
    bit               m_frame_abort;

    // Opcode constants
    localparam logic [7:0] OPC_WR_CSR      = 8'h10;
    localparam logic [7:0] OPC_RD_CSR      = 8'h11;
    localparam logic [7:0] OPC_AHB_WR32    = 8'h20;
    localparam logic [7:0] OPC_AHB_RD32    = 8'h21;
    localparam logic [7:0] OPC_AHB_WR_BURST = 8'h22;
    localparam logic [7:0] OPC_AHB_RD_BURST = 8'h23;

    function new(string name = "aplc_spi_transaction");
        super.new(name);
    endfunction

    function void do_copy(uvm_object rhs);
        aplc_spi_transaction tgt;
        super.do_copy(rhs);
        $cast(tgt, rhs);
        m_opcode    = tgt.m_opcode;
        m_reg_addr  = tgt.m_reg_addr;
        m_ahb_addr  = tgt.m_ahb_addr;
        m_wdata     = tgt.m_wdata;
        m_burst_len = tgt.m_burst_len;
        m_lane_mode = tgt.m_lane_mode;
        m_en        = tgt.m_en;
        m_test_mode = tgt.m_test_mode;
        m_status    = tgt.m_status;
        m_rdata     = tgt.m_rdata;
        m_has_rdata = tgt.m_has_rdata;
        m_is_write  = tgt.m_is_write;
        m_frame_abort = tgt.m_frame_abort;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        aplc_spi_transaction tgt;
        do_compare = super.do_compare(rhs, comparer);
        if (!do_compare) return 0;
        $cast(tgt, rhs);
        do_compare = (m_opcode    === tgt.m_opcode) &&
                     (m_reg_addr  === tgt.m_reg_addr) &&
                     (m_ahb_addr  === tgt.m_ahb_addr) &&
                     (m_burst_len === tgt.m_burst_len) &&
                     (m_status    === tgt.m_status) &&
                     (m_has_rdata === tgt.m_has_rdata) &&
                     (m_is_write  === tgt.m_is_write);
        if (m_wdata.size() != tgt.m_wdata.size()) do_compare = 0;
        else begin
            foreach (m_wdata[i])
                if (m_wdata[i] !== tgt.m_wdata[i]) do_compare = 0;
        end
        if (m_rdata.size() != tgt.m_rdata.size()) do_compare = 0;
        else begin
            foreach (m_rdata[i])
                if (m_rdata[i] !== tgt.m_rdata[i]) do_compare = 0;
        end
    endfunction

    function string convert2string();
        string s;
        s = $sformatf("opcode=0x%02h reg_addr=0x%02h ahb_addr=0x%08h burst_len=%0d lane=%0d en=%0b tm=%0b is_wr=%0b status=0x%02h has_rdata=%0b",
            m_opcode, m_reg_addr, m_ahb_addr, m_burst_len, m_lane_mode, m_en, m_test_mode, m_is_write, m_status, m_has_rdata);
        if (m_wdata.size() > 0) begin
            s = {s, $sformatf(" wdata[0]=0x%08h", m_wdata[0])};
        end
        if (m_rdata.size() > 0) begin
            s = {s, $sformatf(" rdata[0]=0x%08h", m_rdata[0])};
        end
        return s;
    endfunction

    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("opcode",     m_opcode,    8);
        printer.print_field("reg_addr",   m_reg_addr,  8);
        printer.print_field("ahb_addr",   m_ahb_addr, 32);
        printer.print_field("burst_len",  m_burst_len, 5);
        printer.print_field("lane_mode",  m_lane_mode, 2);
        printer.print_field("status",     m_status,    8);
    endfunction

    function void do_record(uvm_recorder recorder);
        super.do_record(recorder);
    endfunction

    // Determine if this is a CSR command
    function bit is_csr_cmd();
        return (m_opcode == OPC_WR_CSR || m_opcode == OPC_RD_CSR);
    endfunction

    // Determine if this is an AHB command
    function bit is_ahb_cmd();
        return (m_opcode inside {OPC_AHB_WR32, OPC_AHB_RD32, OPC_AHB_WR_BURST, OPC_AHB_RD_BURST});
    endfunction

    // Determine if this is a burst command
    function bit is_burst_cmd();
        return (m_opcode == OPC_AHB_WR_BURST || m_opcode == OPC_AHB_RD_BURST);
    endfunction

    // Determine if this is a read command
    function bit is_read_cmd();
        return (m_opcode inside {OPC_RD_CSR, OPC_AHB_RD32, OPC_AHB_RD_BURST});
    endfunction

endclass
