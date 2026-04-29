// SPI Interface for APLC_LITE
// Matches DUT serial port: pcs_n_i, pdi_i[15:0], pdo_o[15:0], pdo_oe_o, lane_mode_i[1:0]

interface spi_intf(input logic clk_i);

    logic        pcs_n;
    logic [15:0] pdi;
    logic [15:0] pdo;
    logic        pdo_oe;
    logic [1:0]  lane_mode;

    // Driver clocking block: TB drives pcs_n, pdi, lane_mode; observes pdo, pdo_oe
    // output #1step drives signal just before clock edge so DUT can sample it
    clocking drv_cb @(posedge clk_i);
        default input #1 output #1step;
        output pcs_n;
        output pdi;
        output lane_mode;
        input  pdo;
        input  pdo_oe;
    endclocking

    // Monitor clocking block: observes all signals
    clocking mon_cb @(posedge clk_i);
        default input #1 output #0;
        input pcs_n;
        input pdi;
        input pdo;
        input pdo_oe;
        input lane_mode;
    endclocking

    modport DRV_MP(clocking drv_cb);
    modport MON_MP(clocking mon_cb);

endinterface
