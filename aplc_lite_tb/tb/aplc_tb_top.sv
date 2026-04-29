// APLC-Lite Testbench Top
`ifndef APLC_TB_TOP_SV
`define APLC_TB_TOP_SV

module aplc_tb_top;

    import uvm_pkg::*;
    import aplc_spi_pkg::*;
    import aplc_ahb_pkg::*;
    import aplc_csr_pkg::*;
    import aplc_env_pkg::*;
    import aplc_seq_pkg::*;
    import aplc_test_pkg::*;

    // Clock and reset
    logic clk;
    logic rst_n;

    // Control signals
    logic        en_i;
    logic        test_mode_i;
    logic [1:0]  lane_mode_i;

    // Intermediate signal for DUT csr_addr_o (8-bit) to csr_if.csr_addr (6-bit)
    logic [7:0]  csr_addr_wire;

    // Clock generation: 100 MHz (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    // Control signal initialization
    initial begin
        en_i        = 1;
        test_mode_i = 1;
        lane_mode_i = 2'b00; // 1-bit mode (DUT reset default)
    end

    // Instantiate interfaces
    aplc_spi_if spi_if (
        .clk(clk),
        .rst_n(rst_n)
    );

    aplc_ahb_if ahb_if (
        .hclk(clk),
        .hresetn(rst_n)
    );

    aplc_csr_if csr_if (
        .csr_clk(clk)
    );

    // Instantiate DUT - map interface signals to DUT ports
    APLC_LITE dut (
        .clk_i          (clk),
        .rst_n_i        (rst_n),
        .en_i           (en_i),
        .test_mode_i    (test_mode_i),
        .pcs_n_i        (spi_if.pcs_n),
        .pdi_i          (spi_if.pdi),
        .pdo_o          (spi_if.pdo),
        .pdo_oe_o       (spi_if.pdo_oe),
        .lane_mode_i    (lane_mode_i),
        .rxfifo_empty_o (spi_if.rxfifo_empty),
        .rxfifo_full_o  (spi_if.rxfifo_full),
        .txfifo_empty_o (spi_if.txfifo_empty),
        .txfifo_full_o  (spi_if.txfifo_full),
        .csr_rd_en_o    (csr_if.csr_valid),
        .csr_wr_en_o    (csr_if.csr_write),
        .csr_addr_o     (csr_addr_wire),
        .csr_wdata_o    (csr_if.csr_wdata),
        .csr_rdata_i    (csr_if.csr_rdata),
        .haddr_o        (ahb_if.haddr),
        .hwrite_o       (ahb_if.hwrite),
        .htrans_o       (ahb_if.htrans),
        .hsize_o        (ahb_if.hsize),
        .hburst_o       (ahb_if.hburst),
        .hwdata_o       (ahb_if.hwdata),
        .hrdata_i       (ahb_if.hrdata),
        .hready_i       (ahb_if.hreadyout),
        .hresp_i        (ahb_if.hresp)
    );

    // Assign AHB slave select (always selected)
    assign ahb_if.hsel = 1'b1;

    // Assign DUT csr_addr output (8-bit) to CSR interface (6-bit)
    assign csr_if.csr_addr = csr_addr_wire[5:0];

    // Set virtual interfaces in config_db
    initial begin
        aplc_spi_config spi_cfg;
        aplc_ahb_config ahb_cfg;
        aplc_csr_config csr_cfg;
        aplc_env_config env_cfg;

        spi_cfg = aplc_spi_config::type_id::create("spi_cfg");
        ahb_cfg = aplc_ahb_config::type_id::create("ahb_cfg");
        csr_cfg = aplc_csr_config::type_id::create("csr_cfg");
        env_cfg = aplc_env_config::type_id::create("env_cfg");

        spi_cfg.m_vif = spi_if;
        ahb_cfg.m_vif = ahb_if;
        csr_cfg.m_vif = csr_if;

        env_cfg.m_spi_cfg = spi_cfg;
        env_cfg.m_ahb_cfg = ahb_cfg;
        env_cfg.m_csr_cfg = csr_cfg;

        uvm_config_db#(aplc_spi_config)::set(null, "uvm_test_top.m_env.m_spi_agent*", "aplc_spi_cfg", spi_cfg);
        uvm_config_db#(aplc_ahb_config)::set(null, "uvm_test_top.m_env.m_ahb_agent*", "aplc_ahb_cfg", ahb_cfg);
        uvm_config_db#(aplc_csr_config)::set(null, "uvm_test_top.m_env.m_csr_agent*", "aplc_csr_cfg", csr_cfg);
        uvm_config_db#(aplc_env_config)::set(null, "uvm_test_top.m_env", "aplc_env_cfg", env_cfg);

        run_test("aplc_smoke_test");
    end

    // Waveform dump
    initial begin
        `ifdef DUMP_FSDB
            $fsdbDumpfile("aplc.fsdb");
            $fsdbDumpvars(0, aplc_tb_top);
        `elsif DUMP_VPD
            $vcdplusfile("aplc.vpd");
            $vcdpluson(0, aplc_tb_top);
        `else
            $dumpfile("aplc.vcd");
            $dumpvars(0, aplc_tb_top);
        `endif
    end

    // Simulation timeout (10ms)
    initial begin
        #10000000;
        `uvm_fatal("TIMEOUT", "Simulation timeout after 10ms")
    end

endmodule

`endif
