// =============================================================================
// File: aplc_spi_txn.svh
// Description: APLC-Lite SPI transaction class
// =============================================================================

class aplc_spi_txn extends uvm_sequence_item;

    // -------------------------------------------------------------------------
    // Utility and registration
    // -------------------------------------------------------------------------
    `uvm_object_utils(aplc_spi_txn)

    // -------------------------------------------------------------------------
    // Opcode constants
    // -------------------------------------------------------------------------
    localparam bit [7:0] OPC_WR_CSR      = 8'h10;
    localparam bit [7:0] OPC_RD_CSR      = 8'h11;
    localparam bit [7:0] OPC_AHB_WR32    = 8'h20;
    localparam bit [7:0] OPC_AHB_RD32    = 8'h21;
    localparam bit [7:0] OPC_AHB_WR_BURST = 8'h22;
    localparam bit [7:0] OPC_AHB_RD_BURST = 8'h23;

    // -------------------------------------------------------------------------
    // Status code constants
    // -------------------------------------------------------------------------
    localparam bit [7:0] STS_OK           = 8'h00;
    localparam bit [7:0] STS_FRAME_ERR    = 8'h01;
    localparam bit [7:0] STS_BAD_OPCODE   = 8'h02;
    localparam bit [7:0] STS_NOT_IN_TEST  = 8'h04;
    localparam bit [7:0] STS_DISABLED     = 8'h08;
    localparam bit [7:0] STS_BAD_REG      = 8'h10;
    localparam bit [7:0] STS_ALIGN_ERR    = 8'h20;
    localparam bit [7:0] STS_AHB_ERR      = 8'h40;
    localparam bit [7:0] STS_BAD_BURST    = 8'h80;
    localparam bit [7:0] STS_BURST_BOUND  = 8'h81;

    // -------------------------------------------------------------------------
    // Transaction fields
    // -------------------------------------------------------------------------
    rand bit [7:0]  m_opcode;
    rand bit [4:0]  m_burst_len;
    rand bit [2:0]  m_hburst;
    rand bit [7:0]  m_reg_addr;
    rand bit [31:0] m_addr;
    rand bit [31:0] m_wdata[];
    rand bit [7:0]  m_status;
    rand bit [31:0] m_rdata[];
    rand bit [1:0]  m_lane_mode;

    rand bit              m_is_read;
    rand bit              m_is_burst;

    // -------------------------------------------------------------------------
    // Constraints
    // -------------------------------------------------------------------------
    constraint c_opcode {
        m_opcode inside {8'h10, 8'h11, 8'h20, 8'h21, 8'h22, 8'h23};
    }

    constraint c_burst_len {
        m_burst_len inside {1, 4, 8, 16};
    }

    constraint c_addr_aligned {
        m_addr[1:0] == 2'b00;
    }

    constraint c_reg_addr_range {
        m_reg_addr < 8'h40;
    }

    constraint c_hburst_mapping {
        (m_burst_len == 1)  -> m_hburst == 3'b000;
        (m_burst_len == 4)  -> m_hburst == 3'b011;
        (m_burst_len == 8)  -> m_hburst == 3'b101;
        (m_burst_len == 16) -> m_hburst == 3'b111;
    }

    constraint c_wdata_size {
        solve m_opcode before m_wdata;
        solve m_burst_len before m_wdata;
        (m_opcode == 8'h10) -> m_wdata.size() == 1;
        (m_opcode == 8'h20) -> m_wdata.size() == 1;
        (m_opcode == 8'h22) -> m_wdata.size() == m_burst_len;
        (m_opcode == 8'h11) -> m_wdata.size() == 0;
        (m_opcode == 8'h21) -> m_wdata.size() == 0;
        (m_opcode == 8'h23) -> m_wdata.size() == 0;
    }

    constraint c_rdata_size {
        solve m_opcode before m_rdata;
        solve m_burst_len before m_rdata;
        (m_opcode == 8'h11) -> m_rdata.size() == 1;
        (m_opcode == 8'h21) -> m_rdata.size() == 1;
        (m_opcode == 8'h23) -> m_rdata.size() == m_burst_len;
        (m_opcode == 8'h10) -> m_rdata.size() == 0;
        (m_opcode == 8'h20) -> m_rdata.size() == 0;
        (m_opcode == 8'h22) -> m_rdata.size() == 0;
    }

    constraint c_is_read {
        solve m_opcode before m_is_read;
        (m_opcode inside {8'h11, 8'h21, 8'h23}) -> m_is_read == 1'b1;
        (m_opcode inside {8'h10, 8'h20, 8'h22}) -> m_is_read == 1'b0;
    }

    constraint c_is_burst {
        solve m_opcode before m_is_burst;
        (m_opcode inside {8'h22, 8'h23}) -> m_is_burst == 1'b1;
        (m_opcode inside {8'h10, 8'h11, 8'h20, 8'h21}) -> m_is_burst == 1'b0;
    }

    constraint c_burst_len_valid {
        solve m_opcode before m_burst_len;
        (m_opcode inside {8'h10, 8'h11, 8'h20, 8'h21}) -> m_burst_len == 1;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    function new(string name = "aplc_spi_txn");
        super.new(name);
    endfunction: new

    // -------------------------------------------------------------------------
    // convert2string
    // -------------------------------------------------------------------------
    function string convert2string();
        string s;
        string wdata_str;
        string rdata_str;
        int    i;

        s = $sformatf("opcode=0x%02h reg_addr=0x%02h addr=0x%08h burst_len=%0d lane_mode=%0d is_read=%0b is_burst=%0b status=0x%02h",
                       m_opcode, m_reg_addr, m_addr, m_burst_len, m_lane_mode, m_is_read, m_is_burst, m_status);

        wdata_str = " wdata=[";
        for (i = 0; i < m_wdata.size(); i++) begin
            if (i > 0) wdata_str = {wdata_str, ","};
            wdata_str = {wdata_str, $sformatf("0x%08h", m_wdata[i])};
        end
        wdata_str = {wdata_str, "]"};
        s = {s, wdata_str};

        rdata_str = " rdata=[";
        for (i = 0; i < m_rdata.size(); i++) begin
            if (i > 0) rdata_str = {rdata_str, ","};
            rdata_str = {rdata_str, $sformatf("0x%08h", m_rdata[i])};
        end
        rdata_str = {rdata_str, "]"};
        s = {s, rdata_str};

        return s;
    endfunction: convert2string

    // -------------------------------------------------------------------------
    // do_copy
    // -------------------------------------------------------------------------
    function void do_copy(uvm_object rhs);
        aplc_spi_txn rhs_txn;
        int          i;

        super.do_copy(rhs);
        if (!$cast(rhs_txn, rhs)) begin
            `uvm_error(get_type_name(), "Cast failed in do_copy")
            return;
        end

        m_opcode    = rhs_txn.m_opcode;
        m_burst_len = rhs_txn.m_burst_len;
        m_hburst    = rhs_txn.m_hburst;
        m_reg_addr  = rhs_txn.m_reg_addr;
        m_addr      = rhs_txn.m_addr;
        m_status    = rhs_txn.m_status;
        m_lane_mode = rhs_txn.m_lane_mode;
        m_is_read   = rhs_txn.m_is_read;
        m_is_burst  = rhs_txn.m_is_burst;

        m_wdata = new[rhs_txn.m_wdata.size()];
        for (i = 0; i < rhs_txn.m_wdata.size(); i++) begin
            m_wdata[i] = rhs_txn.m_wdata[i];
        end

        m_rdata = new[rhs_txn.m_rdata.size()];
        for (i = 0; i < rhs_txn.m_rdata.size(); i++) begin
            m_rdata[i] = rhs_txn.m_rdata[i];
        end
    endfunction: do_copy

    // -------------------------------------------------------------------------
    // do_compare
    // -------------------------------------------------------------------------
    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        aplc_spi_txn rhs_txn;
        int          i;
        bit          result;

        result = super.do_compare(rhs, comparer);
        if (!$cast(rhs_txn, rhs)) begin
            `uvm_error(get_type_name(), "Cast failed in do_compare")
            return 0;
        end

        result &= (m_opcode    == rhs_txn.m_opcode);
        result &= (m_burst_len == rhs_txn.m_burst_len);
        result &= (m_hburst    == rhs_txn.m_hburst);
        result &= (m_reg_addr  == rhs_txn.m_reg_addr);
        result &= (m_addr      == rhs_txn.m_addr);
        result &= (m_status    == rhs_txn.m_status);
        result &= (m_lane_mode == rhs_txn.m_lane_mode);
        result &= (m_is_read   == rhs_txn.m_is_read);
        result &= (m_is_burst  == rhs_txn.m_is_burst);

        result &= (m_wdata.size() == rhs_txn.m_wdata.size());
        if (m_wdata.size() == rhs_txn.m_wdata.size()) begin
            for (i = 0; i < m_wdata.size(); i++) begin
                result &= (m_wdata[i] == rhs_txn.m_wdata[i]);
            end
        end

        result &= (m_rdata.size() == rhs_txn.m_rdata.size());
        if (m_rdata.size() == rhs_txn.m_rdata.size()) begin
            for (i = 0; i < m_rdata.size(); i++) begin
                result &= (m_rdata[i] == rhs_txn.m_rdata[i]);
            end
        end

        return result;
    endfunction: do_compare

    // -------------------------------------------------------------------------
    // do_print
    // -------------------------------------------------------------------------
    function void do_print(uvm_printer printer);
        int i;

        super.do_print(printer);
        printer.print_field("opcode",    m_opcode,    8);
        printer.print_field("burst_len", m_burst_len, 5);
        printer.print_field("hburst",    m_hburst,    3);
        printer.print_field("reg_addr",  m_reg_addr,  8);
        printer.print_field("addr",      m_addr,     32);
        printer.print_field("status",    m_status,    8);
        printer.print_field("lane_mode", m_lane_mode, 2);
        printer.print_field("is_read",   m_is_read,   1);
        printer.print_field("is_burst",  m_is_burst,  1);

        for (i = 0; i < m_wdata.size(); i++) begin
            printer.print_field($sformatf("wdata[%0d]", i), m_wdata[i], 32);
        end
        for (i = 0; i < m_rdata.size(); i++) begin
            printer.print_field($sformatf("rdata[%0d]", i), m_rdata[i], 32);
        end
    endfunction: do_print

    // -------------------------------------------------------------------------
    // do_record
    // -------------------------------------------------------------------------
    function void do_record(uvm_recorder recorder);
        int i;

        super.do_record(recorder);
        `uvm_record_field("opcode",    m_opcode)
        `uvm_record_field("burst_len", m_burst_len)
        `uvm_record_field("hburst",    m_hburst)
        `uvm_record_field("reg_addr",  m_reg_addr)
        `uvm_record_field("addr",      m_addr)
        `uvm_record_field("status",    m_status)
        `uvm_record_field("lane_mode", m_lane_mode)
        `uvm_record_field("is_read",   m_is_read)
        `uvm_record_field("is_burst",  m_is_burst)

        for (i = 0; i < m_wdata.size(); i++) begin
            `uvm_record_field($sformatf("wdata[%0d]", i), m_wdata[i])
        end
        for (i = 0; i < m_rdata.size(); i++) begin
            `uvm_record_field($sformatf("rdata[%0d]", i), m_rdata[i])
        end
    endfunction: do_record

endclass: aplc_spi_txn
