`timescale 1ns/1ps

module aplc_tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import aplc_test_pkg::*;

    logic clk;
    logic rst_n;

    aplc_spi_if spi_if (.clk(clk), .rst_n(rst_n));
    aplc_ahb_if ahb_if (.hclk(clk), .hresetn(rst_n));
    aplc_csr_if csr_if (.clk(clk), .rst_n(rst_n));

    APLC_LITE u_dut (
        .clk_i           (clk),
        .rst_n_i         (rst_n),
        .en_i            (spi_if.en_i),
        .test_mode_i     (spi_if.test_mode_i),
        .pcs_n_i         (spi_if.pcs_n_i),
        .pdi_i           (spi_if.pdi_i),
        .pdo_o           (spi_if.pdo_o),
        .pdo_oe_o        (spi_if.pdo_oe_o),
        .lane_mode_i     (spi_if.lane_mode_i),
        .rxfifo_empty_o  (spi_if.rxfifo_empty_o),
        .rxfifo_full_o   (spi_if.rxfifo_full_o),
        .txfifo_empty_o  (spi_if.txfifo_empty_o),
        .txfifo_full_o   (spi_if.txfifo_full_o),
        .csr_rd_en_o     (csr_if.csr_rd_en_o),
        .csr_wr_en_o     (csr_if.csr_wr_en_o),
        .csr_addr_o      (csr_if.csr_addr_o),
        .csr_wdata_o     (csr_if.csr_wdata_o),
        .csr_rdata_i     (csr_if.csr_rdata_i),
        .haddr_o         (ahb_if.haddr),
        .hwrite_o        (ahb_if.hwrite),
        .htrans_o        (ahb_if.htrans),
        .hsize_o         (ahb_if.hsize),
        .hburst_o        (ahb_if.hburst),
        .hwdata_o        (ahb_if.hwdata),
        .hrdata_i        (ahb_if.hrdata),
        .hready_i        (ahb_if.hready),
        .hresp_i         (ahb_if.hresp)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    initial begin
        uvm_config_db #(virtual aplc_spi_if)::set(null, "uvm_test_top", "spi_vif", spi_if);
        uvm_config_db #(virtual aplc_ahb_if)::set(null, "uvm_test_top", "ahb_vif", ahb_if);
        uvm_config_db #(virtual aplc_csr_if)::set(null, "uvm_test_top", "csr_vif", csr_if);
        run_test();
    end

`ifdef DUMP_FSDB
    initial begin
        $fsdbDumpfile("aplc_tb.fsdb");
        $fsdbDumpvars(0, aplc_tb_top);
        $fsdbDumpvars(0, spi_if);
        $fsdbDumpvars(0, ahb_if);
        $fsdbDumpvars(0, csr_if);
        $fsdbDumpon;
    end
`endif

endmodule
