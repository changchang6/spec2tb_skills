// APLC-Lite Coverage Collector
`ifndef APLC_COVERAGE_SVH
`define APLC_COVERAGE_SVH

`uvm_analysis_imp_decl(_spi)
`uvm_analysis_imp_decl(_ahb)

class aplc_coverage extends uvm_component;
    `uvm_component_utils(aplc_coverage)

    uvm_analysis_imp_spi #(aplc_spi_txn, aplc_coverage) m_spi_imp;
    uvm_analysis_imp_ahb #(aplc_ahb_txn, aplc_coverage) m_ahb_imp;

    bit [7:0]  m_opcode;
    bit [1:0]  m_lane_mode;
    bit [4:0]  m_burst_len;
    bit [7:0]  m_status;
    bit [2:0]  m_hburst;
    bit        m_hwrite;
    bit        m_hresp;

    covergroup cg_spi;
        cp_opcode: coverpoint m_opcode {
            bins wr_csr      = {8'h10};
            bins rd_csr      = {8'h11};
            bins ahb_wr32    = {8'h20};
            bins ahb_rd32    = {8'h21};
            bins ahb_wr_burst = {8'h22};
            bins ahb_rd_burst = {8'h23};
        }
        cp_lane_mode: coverpoint m_lane_mode {
            bins mode_1bit  = {2'b00};
            bins mode_4bit  = {2'b01};
            bins mode_8bit  = {2'b10};
            bins mode_16bit = {2'b11};
        }
        cp_burst_len: coverpoint m_burst_len {
            bins bl1  = {1};
            bins bl4  = {4};
            bins bl8  = {8};
            bins bl16 = {16};
            bins illegal = default;
        }
        cp_status: coverpoint m_status {
            bins ok           = {8'h00};
            bins frame_err    = {8'h01};
            bins bad_opcode   = {8'h02};
            bins not_in_test  = {8'h04};
            bins disabled     = {8'h08};
            bins bad_reg      = {8'h10};
            bins align_err    = {8'h20};
            bins ahb_err      = {8'h40};
            bins bad_burst    = {8'h80};
            bins burst_bound  = {8'h81};
        }
        cx_cmd_lane: cross cp_opcode, cp_lane_mode;
        cx_cmd_burst: cross cp_opcode, cp_burst_len;
        cx_cmd_status: cross cp_opcode, cp_status;
    endgroup

    covergroup cg_ahb;
        cp_hburst: coverpoint m_hburst {
            bins single = {3'b000};
            bins incr4  = {3'b011};
            bins incr8  = {3'b101};
            bins incr16 = {3'b111};
        }
        cp_hwrite: coverpoint m_hwrite;
        cp_hresp: coverpoint m_hresp;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_spi = new();
        cg_ahb = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_spi_imp = new("m_spi_imp", this);
        m_ahb_imp = new("m_ahb_imp", this);
    endfunction

    function void write_spi(aplc_spi_txn txn);
        m_opcode    = txn.m_opcode;
        m_lane_mode = txn.m_lane_mode;
        m_burst_len = txn.m_burst_len;
        m_status    = txn.m_status;
        cg_spi.sample();
    endfunction

    function void write_ahb(aplc_ahb_txn txn);
        m_hburst = txn.m_burst;
        m_hwrite = txn.m_write;
        m_hresp  = txn.m_response;
        cg_ahb.sample();
    endfunction
endclass

`endif
