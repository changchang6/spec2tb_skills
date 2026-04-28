// APLC-Lite Functional Coverage Collector

class aplc_coverage extends uvm_component;

    `uvm_component_utils(aplc_coverage)

    uvm_tlm_analysis_fifo #(aplc_spi_txn) m_spi_fifo;

    localparam bit [7:0] OPC_WR_CSR       = 8'h10;
    localparam bit [7:0] OPC_RD_CSR       = 8'h11;
    localparam bit [7:0] OPC_AHB_WR32     = 8'h20;
    localparam bit [7:0] OPC_AHB_RD32     = 8'h21;
    localparam bit [7:0] OPC_AHB_WR_BURST = 8'h22;
    localparam bit [7:0] OPC_AHB_RD_BURST = 8'h23;

    covergroup cg_opcode;
        cp_opcode: coverpoint m_cov_txn.opcode {
            bins wr_csr    = {8'h10};
            bins rd_csr    = {8'h11};
            bins ahb_wr32  = {8'h20};
            bins ahb_rd32  = {8'h21};
            bins wr_burst  = {8'h22};
            bins rd_burst  = {8'h23};
            bins illegal   = default;
        }
    endgroup

    covergroup cg_lane_mode;
        cp_lane: coverpoint m_cov_txn.lane_mode {
            bins mode_1bit  = {2'b00};
            bins mode_4bit  = {2'b01};
            bins mode_8bit  = {2'b10};
            bins mode_16bit = {2'b11};
        }
    endgroup

    covergroup cg_status;
        cp_status: coverpoint m_cov_txn.status {
            bins ok          = {8'h00};
            bins frame_err   = {8'h01};
            bins bad_opcode  = {8'h02};
            bins not_in_test = {8'h04};
            bins disabled    = {8'h08};
            bins bad_reg     = {8'h10};
            bins align_err   = {8'h20};
            bins ahb_err     = {8'h40};
            bins bad_burst   = {8'h80};
            bins burst_bound = {8'h81};
        }
    endgroup

    covergroup cg_burst_len;
        cp_burst: coverpoint m_cov_txn.burst_len {
            bins len_1  = {1};
            bins len_4  = {4};
            bins len_8  = {8};
            bins len_16 = {16};
            bins illegal = default;
        }
    endgroup

    covergroup cg_opcode_x_lane;
        cp_opcode: coverpoint m_cov_txn.opcode {
            bins wr_csr   = {8'h10};
            bins rd_csr   = {8'h11};
            bins ahb_wr32 = {8'h20};
            bins ahb_rd32 = {8'h21};
            bins wr_burst = {8'h22};
            bins rd_burst = {8'h23};
        }
        cp_lane: coverpoint m_cov_txn.lane_mode;
        cross cp_opcode, cp_lane;
    endgroup

    protected aplc_spi_txn m_cov_txn;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_opcode_x_lane = new();
        cg_opcode        = new();
        cg_lane_mode     = new();
        cg_status        = new();
        cg_burst_len     = new();
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_spi_fifo = new("m_spi_fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            m_spi_fifo.get(m_cov_txn);
            cg_opcode.sample();
            cg_lane_mode.sample();
            cg_status.sample();
            if (m_cov_txn.is_burst)
                cg_burst_len.sample();
            cg_opcode_x_lane.sample();
        end
    endtask

endclass
