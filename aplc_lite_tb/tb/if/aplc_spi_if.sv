// APLC-Lite SPI-like Half-Duplex Interface
// Connects ATE host to DUT's serial test interface
interface aplc_spi_if (
    input logic clk,
    input logic rst_n
);

    logic        pcs_n_i;
    logic [15:0] pdi_i;
    logic [15:0] pdo_o;
    logic        pdo_oe_o;
    logic [1:0]  lane_mode_i;
    logic        en_i;
    logic        test_mode_i;
    logic        rxfifo_empty_o;
    logic        rxfifo_full_o;
    logic        txfifo_empty_o;
    logic        txfifo_full_o;

    clocking cb @(posedge clk);
        default input #1step output #0;
        output pcs_n_i, pdi_i, lane_mode_i, en_i, test_mode_i;
        input  pdo_o, pdo_oe_o;
        input  rxfifo_empty_o, rxfifo_full_o, txfifo_empty_o, txfifo_full_o;
    endclocking

    clocking cb_monitor @(posedge clk);
        default input #1step output #0;
        input pcs_n_i, pdi_i, pdo_o, pdo_oe_o, lane_mode_i, en_i, test_mode_i;
        input rxfifo_empty_o, rxfifo_full_o, txfifo_empty_o, txfifo_full_o;
    endclocking

    modport master (
        clocking cb,
        output pcs_n_i, pdi_i, lane_mode_i, en_i, test_mode_i
    );

    modport monitor (
        clocking cb_monitor
    );

    modport passive (
        input  clk, rst_n,
        input  pcs_n_i, pdi_i, pdo_o, pdo_oe_o, lane_mode_i, en_i, test_mode_i,
        input  rxfifo_empty_o, rxfifo_full_o, txfifo_empty_o, txfifo_full_o
    );

endinterface
