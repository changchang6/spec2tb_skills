// APLC Register Model Package
package aplc_reg_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Status code constants
    localparam logic [7:0] STS_OK         = 8'h00;
    localparam logic [7:0] STS_FRAME_ERR  = 8'h01;
    localparam logic [7:0] STS_BAD_OPCODE = 8'h02;
    localparam logic [7:0] STS_NOT_IN_TEST = 8'h04;
    localparam logic [7:0] STS_DISABLED   = 8'h08;
    localparam logic [7:0] STS_BAD_REG    = 8'h10;
    localparam logic [7:0] STS_ALIGN_ERR  = 8'h20;
    localparam logic [7:0] STS_AHB_ERR    = 8'h40;
    localparam logic [7:0] STS_BAD_BURST  = 8'h80;
    localparam logic [7:0] STS_BURST_BOUND = 8'h81;

    // CSR address constants
    localparam logic [7:0] ADDR_VERSION   = 8'h00;
    localparam logic [7:0] ADDR_CTRL      = 8'h04;
    localparam logic [7:0] ADDR_STATUS    = 8'h08;
    localparam logic [7:0] ADDR_LAST_ERR  = 8'h0C;
    localparam logic [7:0] ADDR_BURST_CNT = 8'h10;

    // Opcode constants
    localparam logic [7:0] OPC_WR_CSR      = 8'h10;
    localparam logic [7:0] OPC_RD_CSR      = 8'h11;
    localparam logic [7:0] OPC_AHB_WR32    = 8'h20;
    localparam logic [7:0] OPC_AHB_RD32    = 8'h21;
    localparam logic [7:0] OPC_AHB_WR_BURST = 8'h22;
    localparam logic [7:0] OPC_AHB_RD_BURST = 8'h23;

    // AHB burst type mapping
    localparam logic [2:0] AHB_SINGLE = 3'b000;
    localparam logic [2:0] AHB_INCR4  = 3'b011;
    localparam logic [2:0] AHB_INCR8  = 3'b101;
    localparam logic [2:0] AHB_INCR16 = 3'b111;

    // CSR register shadow model
    class aplc_csr_shadow extends uvm_object;

        `uvm_object_utils(aplc_csr_shadow)

        logic [31:0] m_version_shadow;
        logic [31:0] m_ctrl_shadow;
        logic [7:0]  m_status_shadow;
        logic [7:0]  m_last_err_shadow;
        logic [15:0] m_burst_cnt_shadow;

        // Port input state (authoritative for CTRL)
        bit          m_en;
        bit          m_test_mode;
        logic [1:0]  m_lane_mode;

        function new(string name = "aplc_csr_shadow");
            super.new(name);
            init();
        endfunction

        function void init();
            m_version_shadow  = 32'h0000_0220;
            m_status_shadow   = 8'h00;
            m_last_err_shadow = 8'h00;
            m_burst_cnt_shadow = 16'h0000;
            update_ctrl_from_ports();
        endfunction

        function void update_ctrl_from_ports();
            m_ctrl_shadow = {27'b0, 1'b0, m_test_mode, m_lane_mode, m_en};
        endfunction

        function logic [31:0] read_csr(logic [7:0] addr);
            case (addr)
                ADDR_VERSION:   return m_version_shadow;
                ADDR_CTRL:      return m_ctrl_shadow;
                ADDR_STATUS:    return {24'b0, m_status_shadow};
                ADDR_LAST_ERR:  return {24'b0, m_last_err_shadow};
                ADDR_BURST_CNT: return {16'b0, m_burst_cnt_shadow};
                default:        return 32'h0;
            endcase
        endfunction

        function void write_csr(logic [7:0] addr, logic [31:0] wdata);
            case (addr)
                ADDR_CTRL: begin
                    // CTRL is RW: bit[4]=soft_rst(W1 self-clear), bit[3]=test_mode, bit[2:1]=lane_mode, bit[0]=en
                    // But port inputs are authoritative source for en/test_mode/lane_mode
                    // Write to CTRL updates internal state but ports override
                    // For ref model: we just track the write, but actual CTRL reads port inputs
                    m_ctrl_shadow = wdata;
                end
                ADDR_STATUS: begin
                    // WC semantics: clear sticky bits where wdata[i]=1
                    m_status_shadow = m_status_shadow & ~wdata[7:0];
                end
                ADDR_LAST_ERR: begin
                    // WC: any write clears
                    m_last_err_shadow = 8'h00;
                end
                ADDR_BURST_CNT: begin
                    // WC: any write clears
                    m_burst_cnt_shadow = 16'h0000;
                end
                // VERSION is RO - ignore writes
                default: ;
            endcase
        endfunction

        function void update_status_on_error(logic [7:0] err_code);
            case (err_code)
                STS_FRAME_ERR:  m_status_shadow[4] = 1'b1; // FRAME_ERR
                STS_AHB_ERR:    m_status_shadow[3] = 1'b1; // BUS_ERR
                STS_BAD_BURST,
                STS_BURST_BOUND: m_status_shadow[7] = 1'b1; // BURST_ERR
                default:        m_status_shadow[2] = 1'b1;   // CMD_ERR
            endcase
            m_last_err_shadow = err_code;
        endfunction

    endclass

endpackage
