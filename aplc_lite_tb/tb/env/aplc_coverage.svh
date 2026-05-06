// APLC-Lite Coverage
class aplc_coverage extends uvm_subscriber #(spi_xtn);

    `uvm_component_utils(aplc_coverage)

    logic [7:0] m_opcode;
    logic [7:0] m_status;
    logic [1:0] m_lane_mode;

    covergroup cg_aplc;
        cp_opcode: coverpoint m_opcode {
            bins wr_csr       = {8'h10};
            bins rd_csr       = {8'h11};
            bins ahb_wr32     = {8'h20};
            bins ahb_rd32     = {8'h21};
            bins ahb_wr_burst = {8'h22};
            bins ahb_rd_burst = {8'h23};
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
        cp_lane_mode: coverpoint m_lane_mode {
            bins mode_1bit  = {2'b00};
            bins mode_4bit  = {2'b01};
            bins mode_8bit  = {2'b10};
            bins mode_16bit = {2'b11};
        }
    endgroup

    function new(string name = "aplc_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_aplc = new();
    endfunction

    function void write(spi_xtn t);
        m_opcode    = t.opcode;
        m_status    = t.status;
        m_lane_mode = t.lane_mode;
        cg_aplc.sample();
    endfunction

endclass
