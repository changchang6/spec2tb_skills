// APLC-Lite Testbench Top Module
module tb;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import aplc_tc_pkg::*;
    import yuu_ahb_pkg::*;

    // -------------------- Clock & Reset --------------------
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #5ns clk = ~clk; // 100MHz
    end

    initial begin
        rst_n = 0;
        #200ns;
        rst_n = 1;
    end

    // -------------------- DUT Signals --------------------
    logic        en_i;
    logic        test_mode_i;
    logic [1:0]  lane_mode_i;
    logic        pcs_n_i;
    logic [15:0] pdi_i;
    logic [15:0] pdo_o;
    logic        pdo_oe_o;
    logic        rxfifo_empty_o;
    logic        rxfifo_full_o;
    logic        txfifo_empty_o;
    logic        txfifo_full_o;
    logic        csr_rd_en_o;
    logic        csr_wr_en_o;
    logic [7:0]  csr_addr_o;
    logic [31:0] csr_wdata_o;
    logic [31:0] csr_rdata_i;
    logic [31:0] haddr_o;
    logic        hwrite_o;
    logic [1:0]  htrans_o;
    logic [2:0]  hsize_o;
    logic [2:0]  hburst_o;
    logic [31:0] hwdata_o;
    logic [31:0] hrdata_i;
    logic        hready_i;
    logic        hresp_i;

    // -------------------- Interfaces --------------------
    spi_if spi_vif(.clk(clk), .rst_n(rst_n));
    csr_if csr_vif(.clk(clk), .rst_n(rst_n));

    // Connect SPI interface to DUT signals
    assign pcs_n_i     = spi_vif.pcs_n;
    assign pdi_i       = spi_vif.pdi;
    assign en_i        = spi_vif.en;
    assign test_mode_i = spi_vif.test_mode;
    assign lane_mode_i = spi_vif.lane_mode;
    assign spi_vif.pdo       = pdo_o;
    assign spi_vif.pdo_oe   = pdo_oe_o;
    assign spi_vif.rxfifo_empty = rxfifo_empty_o;
    assign spi_vif.rxfifo_full  = rxfifo_full_o;
    assign spi_vif.txfifo_empty = txfifo_empty_o;
    assign spi_vif.txfifo_full  = txfifo_full_o;

    // Connect CSR interface to DUT signals
    // DUT drives rd_en/wr_en/addr/wdata (outputs), TB observes via interface
    assign csr_vif.csr_rd_en  = csr_rd_en_o;
    assign csr_vif.csr_wr_en  = csr_wr_en_o;
    assign csr_vif.csr_addr   = csr_addr_o;
    assign csr_vif.csr_wdata  = csr_wdata_o;
    // TB drives rdata (DUT input), CSR agent responds via slv_cb
    assign csr_rdata_i  = csr_vif.csr_rdata;

    // AHB interface (VIP)
    yuu_ahb_interface ahb_if();

    // Connect AHB clock/reset
    assign ahb_if.hclk    = clk;
    assign ahb_if.hreset_n = rst_n;

    // Connect DUT AHB master to VIP slave[0]
    assign ahb_if.slave_if[0].hsel      = (htrans_o != 2'b00); // select when active
    assign ahb_if.slave_if[0].haddr     = haddr_o;
    assign ahb_if.slave_if[0].htrans    = htrans_o;
    assign ahb_if.slave_if[0].hburst    = hburst_o;
    assign ahb_if.slave_if[0].hwrite    = hwrite_o;
    assign ahb_if.slave_if[0].hsize     = hsize_o;
    assign ahb_if.slave_if[0].hwdata    = hwdata_o;
    assign ahb_if.slave_if[0].hprot     = 4'b0011;
    assign ahb_if.slave_if[0].hmaster   = 4'b0000;
    assign ahb_if.slave_if[0].hmastlock = 1'b0;
    assign ahb_if.slave_if[0].hnonsec   = 1'b0;

    assign hrdata_i = ahb_if.slave_if[0].hrdata;
    assign hresp_i  = ahb_if.slave_if[0].hresp[0]; // VIP hresp is 2-bit, DUT is 1-bit
    assign hready_i = ahb_if.slave_if[0].hready_o;
    assign ahb_if.slave_if[0].hready_i = ahb_if.slave_if[0].hready_o; // single slave loopback

    // -------------------- DUT Instantiation --------------------
    APLC_LITE dut (
        .clk_i          (clk),
        .rst_n_i        (rst_n),
        .en_i           (en_i),
        .test_mode_i    (test_mode_i),
        .pcs_n_i        (pcs_n_i),
        .pdi_i          (pdi_i),
        .pdo_o          (pdo_o),
        .pdo_oe_o       (pdo_oe_o),
        .lane_mode_i    (lane_mode_i),
        .rxfifo_empty_o (rxfifo_empty_o),
        .rxfifo_full_o  (rxfifo_full_o),
        .txfifo_empty_o (txfifo_empty_o),
        .txfifo_full_o  (txfifo_full_o),
        .csr_rd_en_o    (csr_rd_en_o),
        .csr_wr_en_o    (csr_wr_en_o),
        .csr_addr_o     (csr_addr_o),
        .csr_wdata_o    (csr_wdata_o),
        .csr_rdata_i    (csr_rdata_i),
        .haddr_o        (haddr_o),
        .hwrite_o       (hwrite_o),
        .htrans_o       (htrans_o),
        .hsize_o        (hsize_o),
        .hburst_o       (hburst_o),
        .hwdata_o       (hwdata_o),
        .hrdata_i       (hrdata_i),
        .hready_i       (hready_i),
        .hresp_i        (hresp_i)
    );

    // -------------------- UVM Initialization --------------------
    initial begin
        uvm_config_db#(virtual spi_if)::set(null, "uvm_test_top", "spi_vif", spi_vif);
        uvm_config_db#(virtual csr_if)::set(null, "uvm_test_top", "csr_vif", csr_vif);
        uvm_config_db#(virtual yuu_ahb_slave_interface)::set(null, "uvm_test_top",
            "ahb_slv_vif", ahb_if.get_slave_if(0));
        run_test();
    end

    // -------------------- Waveform Dump --------------------
    `ifdef DUMP_FSDB
    initial begin
        $fsdbDumpfile("aplc_tb.fsdb");
        $fsdbDumpvars(0, tb);
    end
    `endif

    // -------------------- Simulation Timeout --------------------
    initial begin
        #100ms;
        $display("[TB_TIMEOUT] Simulation timed out at %0t", $time);
        $finish;
    end

    // =====================================================
    // SVA Assertions (CHK_001, CHK_014, CHK_015)
    // =====================================================

    // CHK_001: Reset state assertions
    property p_reset_pdo_oe;
        @(posedge clk) !rst_n |=> pdo_oe_o === 1'b0;
    endproperty
    assert property(p_reset_pdo_oe) else
        $error("[CHK_001] Reset: pdo_oe_o not 0 after reset");

    property p_reset_htrans_idle;
        @(posedge clk) !rst_n |=> htrans_o === 2'b00;
    endproperty
    assert property(p_reset_htrans_idle) else
        $error("[CHK_001] Reset: htrans_o not IDLE after reset");

    property p_reset_csr_idle;
        @(posedge clk) !rst_n |=> csr_rd_en_o === 1'b0 && csr_wr_en_o === 1'b0;
    endproperty
    assert property(p_reset_csr_idle) else
        $error("[CHK_001] Reset: CSR signals not idle after reset");

    property p_reset_pdo_zero;
        @(posedge clk) !rst_n |=> pdo_o === 16'b0;
    endproperty
    assert property(p_reset_pdo_zero) else
        $error("[CHK_001] Reset: pdo_o not 0 after reset");

    // CHK_015: AHB Master protocol assertions
    property p_ahb_hsize_word;
        @(posedge clk) rst_n && htrans_o != 2'b00 |-> hsize_o === 3'b010;
    endproperty
    assert property(p_ahb_hsize_word) else
        $error("[CHK_015] AHB: hsize not WORD during active transfer");

    property p_ahb_addr_aligned;
        @(posedge clk) rst_n && htrans_o != 2'b00 |-> haddr_o[1:0] === 2'b00;
    endproperty
    assert property(p_ahb_addr_aligned) else
        $error("[CHK_015] AHB: haddr not 4-byte aligned during active transfer");

    property p_ahb_hburst_stable;
        @(posedge clk) rst_n && htrans_o inside {2'b10, 2'b11} |-> $stable(hburst_o);
    endproperty
    assert property(p_ahb_hburst_stable) else
        $error("[CHK_015] AHB: hburst changed during burst");

    // CHK_014: Low power assertions
    property p_idle_no_csr_access;
        @(posedge clk) rst_n && pcs_n_i === 1'b1 |-> csr_rd_en_o === 1'b0 && csr_wr_en_o === 1'b0;
    endproperty
    assert property(p_idle_no_csr_access) else
        $error("[CHK_014] Low power: CSR access during idle (pcs_n=1)");

    property p_idle_htrans_idle;
        @(posedge clk) rst_n && pcs_n_i === 1'b1 |-> htrans_o === 2'b00;
    endproperty
    assert property(p_idle_htrans_idle) else
        $error("[CHK_014] Low power: AHB not IDLE during idle (pcs_n=1)");

    // CHK_003: CSR timing assertions
    property p_csr_wr_single_pulse;
        @(posedge clk) rst_n |-> !(csr_wr_en_o && $past(csr_wr_en_o));
    endproperty
    assert property(p_csr_wr_single_pulse) else
        $error("[CHK_003] CSR: wr_en not single-cycle pulse");

    property p_csr_rd_single_pulse;
        @(posedge clk) rst_n |-> !(csr_rd_en_o && $past(csr_rd_en_o));
    endproperty
    assert property(p_csr_rd_single_pulse) else
        $error("[CHK_003] CSR: rd_en not single-cycle pulse");

endmodule
