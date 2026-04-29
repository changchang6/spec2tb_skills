// APLC Coverage Collector

class aplc_coverage extends uvm_subscriber#(spi_xtn);

    `uvm_component_utils(aplc_coverage)

    spi_xtn m_txn;

    covergroup cg_spi;
        cp_opcode: coverpoint m_txn.m_opcode {
            bins wr_csr  = {8'h10};
            bins rd_csr  = {8'h11};
            bins ahb_wr  = {8'h20};
            bins ahb_rd  = {8'h21};
            bins wr_bst  = {8'h22};
            bins rd_bst  = {8'h23};
        }
        cp_csr_addr: coverpoint m_txn.m_reg_addr {
            bins version   = {8'h00};
            bins ctrl      = {8'h04};
            bins status    = {8'h08};
            bins last_err  = {8'h0C};
            bins burst_cnt = {8'h10};
        }
        cp_lane_mode: coverpoint m_txn.m_lane_mode {
            bins lane_1  = {2'b00};
            bins lane_4  = {2'b01};
            bins lane_8  = {2'b10};
            bins lane_16 = {2'b11};
        }
        cp_resp_status: coverpoint m_txn.m_resp_status {
            bins ok       = {8'h00};
            bins others   = default;
        }
    endgroup

    function new(string name = "aplc_coverage", uvm_component parent = null);
        super.new(name, parent);
        cg_spi = new();
    endfunction

    function void write(spi_xtn t);
        m_txn = t;
        cg_spi.sample();
    endfunction

endclass
