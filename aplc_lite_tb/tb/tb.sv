// APLC_LITE Testbench Top Module
// Instantiates DUT, interfaces, and connects AHB VIP slave agent

`timescale 1ns/1ps

module aplc_tb_top;

    import uvm_pkg::*;
    import aplc_tc_pkg::*;

    // -------------------------------------------------------
    // Clock and Reset Generation
    // -------------------------------------------------------
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz, 10ns period
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    // -------------------------------------------------------
    // Interface Instantiation
    // -------------------------------------------------------
    spi_intf  spi_vif(clk);
    csr_intf  csr_vif(clk);
    ahb_intf  ahb_vif(clk, rst_n); // HRESETn driven as port

    // -------------------------------------------------------
    // AHB Connection: DUT master -> VIP slave
    // DUT outputs drive VIP interface directly
    // VIP slave driver drives HRDATA/HREADY/HRESP
    // -------------------------------------------------------

    APLC_LITE dut (
        .clk_i       (clk),
        .rst_n_i     (rst_n),
        .en_i        (1'b1),          // Always enabled
        .test_mode_i (1'b1),          // Required for DPCHK to pass

        // SPI interface
        .pcs_n_i     (spi_vif.pcs_n),
        .pdi_i       (spi_vif.pdi),
        .pdo_o       (spi_vif.pdo),
        .pdo_oe_o    (spi_vif.pdo_oe),
        .lane_mode_i (spi_vif.lane_mode),

        // FIFO status outputs
        .rxfifo_empty_o (),
        .rxfifo_full_o  (),
        .txfifo_empty_o (),
        .txfifo_full_o  (),

        // CSR interface
        .csr_rd_en_o (csr_vif.csr_rd_en),
        .csr_wr_en_o (csr_vif.csr_wr_en),
        .csr_addr_o  (csr_vif.csr_addr),
        .csr_wdata_o (csr_vif.csr_wdata),
        .csr_rdata_i (csr_vif.csr_rdata),

        // AHB-Lite master interface
        // DUT outputs -> VIP interface
        .haddr_o     (ahb_vif.HADDR),
        .hwrite_o    (ahb_vif.HWRITE),
        .htrans_o    (ahb_vif.HTRANS),
        .hsize_o     (ahb_vif.HSIZE),
        .hburst_o    (ahb_vif.HBURST),
        .hwdata_o    (ahb_vif.HWDATA),
        // VIP slave outputs -> DUT inputs
        .hrdata_i    (ahb_vif.HRDATA),
        .hready_i    (ahb_vif.HREADY),
        .hresp_i     (ahb_vif.HRESP[0]) // 2-bit to 1-bit mapping
    );

    // -------------------------------------------------------
    // CSR Response Logic (combinational read)
    // DPIPE samples csr_rdata_i one cycle after asserting csr_rd_en_o,
    // so we must drive csr_rdata combinationally in response to rd_en/addr.
    // A UVM driver with clocking block has output #0 timing issues,
    // so we handle CSR read response directly in the testbench module.
    // The CSR driver still handles writes to update the shadow model.
    // -------------------------------------------------------
    logic [31:0] csr_shadow [logic [7:0]];

    initial begin
        csr_shadow[8'h00] = 32'h0001_0000; // VERSION (RO)
        csr_shadow[8'h04] = 32'h0000_0000; // CTRL (RW)
        csr_shadow[8'h08] = 32'h0000_0000; // STATUS (RO)
        csr_shadow[8'h0C] = 32'h0000_0000; // LAST_ERR (RO)
        csr_shadow[8'h10] = 32'h0000_0000; // BURST_CNT (WC)
    end

    // Combinational read response
    always @(*) begin
        csr_vif.csr_rdata = '0;
        if (csr_vif.csr_rd_en && csr_shadow.exists(csr_vif.csr_addr))
            csr_vif.csr_rdata = csr_shadow[csr_vif.csr_addr];
    end

    // Update shadow model on CSR writes
    always @(posedge clk) begin
        if (rst_n && csr_vif.csr_wr_en) begin
            case (csr_vif.csr_addr)
                8'h04: csr_shadow[csr_vif.csr_addr] = csr_vif.csr_wdata; // CTRL: RW
                8'h10: csr_shadow[csr_vif.csr_addr] = '0;                // BURST_CNT: WC
                // RO registers: ignore write
            endcase
        end
    end

    // -------------------------------------------------------
    // UVM Configuration
    // -------------------------------------------------------
    initial begin
        uvm_config_db#(virtual spi_intf)::set(null, "uvm_test_top", "spi_vif", spi_vif);
        uvm_config_db#(virtual csr_intf)::set(null, "uvm_test_top", "csr_vif", csr_vif);
        uvm_config_db#(virtual ahb_intf)::set(null, "uvm_test_top", "ahb_vif", ahb_vif);
        run_test();
    end

    // -------------------------------------------------------
    // Waveform Dump
    // -------------------------------------------------------
    `ifdef DUMP_FSDB
    initial begin
        $fsdbDumpfile("aplc_tb.fsdb");
        $fsdbDumpvars(0, aplc_tb_top);
    end
    `endif

    // -------------------------------------------------------
    // Timeout Mechanism
    // -------------------------------------------------------
    initial begin
        #10ms;
        $display("ERROR: Simulation timeout at time %0t", $time);
        $finish;
    end

endmodule
