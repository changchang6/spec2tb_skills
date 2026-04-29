// APLC-Lite SPI-like Half-Duplex Test Interface
`ifndef APLC_SPI_IF_SV
`define APLC_SPI_IF_SV

interface aplc_spi_if (
    input logic clk,
    input logic rst_n
);

    // -------------------------------------------------------------------------
    // Signal declarations
    // -------------------------------------------------------------------------
    logic        pcs_n;          // Frame chip select, active-low (TB drives)
    logic [15:0] pdi;            // Parallel data input (TB drives)
    logic [15:0] pdo;            // Parallel data output (DUT drives)
    logic        pdo_oe;         // Output enable (DUT drives)
    logic [1:0]  lane_mode;      // 00=1-bit, 01=4-bit, 10=8-bit, 11=16-bit (TB drives)
    logic        en;             // Module enable (TB drives)
    logic        test_mode;      // Test mode indicator (TB drives)
    logic        rxfifo_empty;   // RX FIFO empty status (DUT drives)
    logic        rxfifo_full;    // RX FIFO full status (DUT drives)
    logic        txfifo_empty;   // TX FIFO empty status (DUT drives)
    logic        txfifo_full;    // TX FIFO full status (DUT drives)

    // Initialize TB-driven signals to idle state
    initial begin
        pcs_n      = 1'b1;
        pdi        = 16'h0;
        lane_mode  = 2'b00; // 1-bit mode (DUT reset default)
        en         = 1'b1;
        test_mode  = 1'b1;
    end

    // -------------------------------------------------------------------------
    // Clocking block for driver
    // -------------------------------------------------------------------------
    clocking drv_cb @(posedge clk);
        output  pcs_n;
        output  pdi;
        output  lane_mode;
        output  en;
        output  test_mode;
        input   pdo;
        input   pdo_oe;
        input   rxfifo_empty;
        input   rxfifo_full;
        input   txfifo_empty;
        input   txfifo_full;
    endclocking: drv_cb

    // -------------------------------------------------------------------------
    // Clocking block for monitor
    // -------------------------------------------------------------------------
    clocking mon_cb @(posedge clk);
        input  pcs_n;
        input  pdi;
        input  pdo;
        input  pdo_oe;
        input  lane_mode;
        input  en;
        input  test_mode;
        input  rxfifo_empty;
        input  rxfifo_full;
        input  txfifo_empty;
        input  txfifo_full;
    endclocking: mon_cb

    // -------------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------------
    modport DRIVER (
        clocking drv_cb,
        import task drive_idle()
    );

    modport MONITOR (
        clocking mon_cb
    );

    // -------------------------------------------------------------------------
    // Task: drive_idle
    // -------------------------------------------------------------------------
    task drive_idle();
        pcs_n      = 1'b1;
        pdi        = 16'h0;
        lane_mode  = 2'b00; // 1-bit mode (DUT reset default)
        en         = 1'b1;
        test_mode  = 1'b1;
    endtask: drive_idle

    // -------------------------------------------------------------------------
    // Concurrent assertions
    // -------------------------------------------------------------------------
    property p_pcs_n_idle_no_response;
        @(posedge clk) disable iff (!rst_n)
        (pcs_n [*2]) |-> !pdo_oe;
    endproperty

    assert property (p_pcs_n_idle_no_response)
        else $error("APLC-SPI: pdo_oe active while pcs_n deasserted");

endinterface: aplc_spi_if

`endif
