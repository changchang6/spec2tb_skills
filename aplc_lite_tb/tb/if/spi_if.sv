// SPI-like interface for APLC-Lite test IO
interface spi_if(input logic clk, input logic rst_n);

    logic        pcs_n;
    logic [15:0] pdi;
    logic [15:0] pdo;
    logic        pdo_oe;
    logic [1:0]  lane_mode;
    logic        en;
    logic        test_mode;

    // FIFO status (observed by monitor)
    logic        rxfifo_empty;
    logic        rxfifo_full;
    logic        txfifo_empty;
    logic        txfifo_full;

    clocking drv_cb @(posedge clk);
        output pcs_n, pdi, lane_mode, en, test_mode;
        input  pdo, pdo_oe;
    endclocking

    clocking mon_cb @(posedge clk);
        input pcs_n, pdi, pdo, pdo_oe, lane_mode, en, test_mode;
        input rxfifo_empty, rxfifo_full, txfifo_empty, txfifo_full;
    endclocking

    modport drv_mp(clocking drv_cb);
    modport mon_mp(clocking mon_cb);

endinterface
