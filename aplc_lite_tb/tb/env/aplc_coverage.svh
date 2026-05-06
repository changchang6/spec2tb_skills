// Coverage collector: CHK_016 DFX stats + functional coverage
class aplc_coverage extends uvm_subscriber #(spi_xtn);

    `uvm_component_utils(aplc_coverage)

    spi_xtn m_xtn;

    covergroup cg_opcode;
        cp_opcode: coverpoint m_xtn.opcode {
            bins wr_csr       = {8'h10};
            bins rd_csr       = {8'h11};
            bins ahb_wr32     = {8'h20};
            bins ahb_rd32     = {8'h21};
            bins ahb_wr_burst = {8'h22};
            bins ahb_rd_burst = {8'h23};
        }
    endgroup

    covergroup cg_lane_mode;
        cp_lane: coverpoint m_xtn.lane_mode {
            bins mode_1bit  = {2'b00};
            bins mode_4bit  = {2'b01};
            bins mode_8bit  = {2'b10};
            bins mode_16bit = {2'b11};
        }
    endgroup

    covergroup cg_burst;
        cp_burst_len: coverpoint m_xtn.burst_len {
            bins bl_1  = {1};
            bins bl_4  = {4};
            bins bl_8  = {8};
            bins bl_16 = {16};
            ignore_bins ig_zero = {0};
        }
        cp_is_burst: coverpoint m_xtn.is_burst;
    endgroup

    covergroup cg_error;
        cp_en:        coverpoint m_xtn.en;
        cp_test_mode: coverpoint m_xtn.test_mode;
        cp_frame_abort: coverpoint m_xtn.frame_abort;
    endgroup

    covergroup cg_csr_addr;
        cp_addr: coverpoint m_xtn.reg_addr {
            bins version    = {8'h00};
            bins ctrl       = {8'h04};
            bins status     = {8'h08};
            bins last_err   = {8'h0C};
            bins burst_cnt  = {8'h10};
            bins reserved   = {[8'h14:8'h3F]};
        }
        cp_is_csr: coverpoint m_xtn.is_csr;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_opcode   = new();
        cg_lane_mode = new();
        cg_burst    = new();
        cg_error    = new();
        cg_csr_addr = new();
    endfunction

    function void write(spi_xtn t);
        m_xtn = t;
        cg_opcode.sample();
        cg_lane_mode.sample();
        if (t.is_burst) cg_burst.sample();
        cg_error.sample();
        if (t.is_csr) cg_csr_addr.sample();
    endfunction

endclass
