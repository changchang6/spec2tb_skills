// APLC Coverage Collector
class aplc_coverage extends uvm_subscriber #(aplc_spi_transaction);

    `uvm_component_utils(aplc_coverage)

    aplc_spi_transaction m_xtn;

    covergroup cg_opcode;
        cp_opcode: coverpoint m_xtn.m_opcode {
            bins wr_csr       = {8'h10};
            bins rd_csr       = {8'h11};
            bins ahb_wr32     = {8'h20};
            bins ahb_rd32     = {8'h21};
            bins ahb_wr_burst = {8'h22};
            bins ahb_rd_burst = {8'h23};
        }
    endgroup

    covergroup cg_error_code;
        cp_status: coverpoint m_xtn.m_status {
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

    covergroup cg_lane_mode;
        cp_lane: coverpoint m_xtn.m_lane_mode {
            bins mode_1bit  = {2'b00};
            bins mode_4bit  = {2'b01};
            bins mode_8bit  = {2'b10};
            bins mode_16bit = {2'b11};
        }
    endgroup

    covergroup cg_burst_type;
        cp_burst_len: coverpoint m_xtn.m_burst_len {
            bins single = {1};
            bins incr4  = {4};
            bins incr8  = {8};
            bins incr16 = {16};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_opcode     = new();
        cg_error_code = new();
        cg_lane_mode  = new();
        cg_burst_type = new();
    endfunction

    function void write(aplc_spi_transaction t);
        m_xtn = t;
        cg_opcode.sample();
        cg_error_code.sample();
        cg_lane_mode.sample();
        if (t.is_burst_cmd())
            cg_burst_type.sample();
    endfunction

endclass
