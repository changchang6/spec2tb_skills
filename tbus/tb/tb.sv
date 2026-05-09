// APLC_LITE Testbench Top Module
module aplc_tb_top;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Clock and reset
    logic clk;
    logic rst_n;

    // Clock generation: 100 MHz (10ns period)
    initial begin
        clk = 0;
        forever #5ns clk = ~clk;
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #100ns rst_n = 1;
    end

    // Interfaces
    aplc_spi_if    spi_if_inst (.clk_i(clk), .rst_n_i(rst_n));
    aplc_csr_if    csr_if_inst (.clk_i(clk), .rst_n_i(rst_n));
    yuu_ahb_interface ahb_if_inst();

    // Connect AHB interface clock and reset
    assign ahb_if_inst.hclk    = clk;
    assign ahb_if_inst.hreset_n = rst_n;

    // DUT instantiation
    APLC_LITE u_dut (
        .clk_i          (clk),
        .rst_n_i        (rst_n),
        .en_i           (spi_if_inst.en_i),
        .test_mode_i    (spi_if_inst.test_mode_i),

        // SPI interface
        .pcs_n_i        (spi_if_inst.pcs_n_i),
        .pdi_i          (spi_if_inst.pdi_i),
        .pdo_o          (spi_if_inst.pdo_o),
        .pdo_oe_o       (spi_if_inst.pdo_oe_o),
        .lane_mode_i    (spi_if_inst.lane_mode_i),

        // FIFO status
        .rxfifo_empty_o (spi_if_inst.rxfifo_empty_o),
        .rxfifo_full_o  (spi_if_inst.rxfifo_full_o),
        .txfifo_empty_o (spi_if_inst.txfifo_empty_o),
        .txfifo_full_o  (spi_if_inst.txfifo_full_o),

        // CSR interface
        .csr_rd_en_o    (csr_if_inst.csr_rd_en_o),
        .csr_wr_en_o    (csr_if_inst.csr_wr_en_o),
        .csr_addr_o     (csr_if_inst.csr_addr_o),
        .csr_wdata_o    (csr_if_inst.csr_wdata_o),
        .csr_rdata_i    (csr_if_inst.csr_rdata_i),

        // AHB-Lite master port
        .haddr_o        (ahb_if_inst.slave_if[0].haddr),
        .hwrite_o       (ahb_if_inst.slave_if[0].hwrite),
        .htrans_o       (ahb_if_inst.slave_if[0].htrans),
        .hsize_o        (ahb_if_inst.slave_if[0].hsize),
        .hburst_o       (ahb_if_inst.slave_if[0].hburst),
        .hwdata_o       (ahb_if_inst.slave_if[0].hwdata),
        .hrdata_i       (ahb_if_inst.slave_if[0].hrdata),
        .hready_i       (ahb_if_inst.slave_if[0].hready_o),
        .hresp_i        (ahb_if_inst.slave_if[0].hresp)
    );

    // AHB slave select and ready (always selected, single slave)
    assign ahb_if_inst.slave_if[0].hsel     = 1'b1;
    assign ahb_if_inst.slave_if[0].hready_i = 1'b1;

    // Default: drive csr_rdata_i = 0 for external addresses
    // (The CSR driver handles this in UVM, but this is a safe default
    //  for the case where UVM driver is not yet active)
    // Note: csr_rdata_i is driven by the CSR agent driver via the interface

    // Set virtual interfaces in config_db
    initial begin
        uvm_config_db #(virtual aplc_spi_if)::set(null, "uvm_test_top", "spi_vif", spi_if_inst);
        uvm_config_db #(virtual aplc_csr_if)::set(null, "uvm_test_top", "csr_vif", csr_if_inst);
    end

    // Waveform dump
    `ifdef DUMP_FSDB
        initial begin
            $fsdbDumpfile("aplc_tb.fsdb");
            $fsdbDumpvars(0, aplc_tb_top);
        end
    `elsif DUMP_VPD
        initial begin
            $vcdpluson;
            $vcdplusmemon;
        end
    `endif

    // Simulation timeout
    initial begin
        #(10us);
        $error("Simulation timeout after 10us");
        $finish;
    end

    // Run UVM test
    initial begin
        run_test();
    end

endmodule
