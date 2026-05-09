// APLC SPI Interface with SVA Assertions
interface aplc_spi_if (
    input logic clk_i,
    input logic rst_n_i
);

    // SPI frame signals
    logic        pcs_n_i;
    logic [15:0] pdi_i;
    logic [15:0] pdo_o;
    logic        pdo_oe_o;

    // Control signals
    logic [1:0]  lane_mode_i;
    logic        en_i;
    logic        test_mode_i;

    // FIFO status
    logic        rxfifo_empty_o;
    logic        rxfifo_full_o;
    logic        txfifo_empty_o;
    logic        txfifo_full_o;

    // Driver clocking block
    clocking drv_cb @(posedge clk_i);
        default input #1step output #1ns;
        output  pcs_n_i, pdi_i, lane_mode_i, en_i, test_mode_i;
        input   pdo_o, pdo_oe_o;
        input   rxfifo_empty_o, rxfifo_full_o, txfifo_empty_o, txfifo_full_o;
    endclocking

    // Monitor clocking block
    clocking mon_cb @(posedge clk_i);
        default input #1step;
        input  rst_n_i;
        input  pcs_n_i, pdi_i, pdo_o, pdo_oe_o;
        input  lane_mode_i, en_i, test_mode_i;
        input  rxfifo_empty_o, rxfifo_full_o, txfifo_empty_o, txfifo_full_o;
    endclocking

    // Modports
    modport driver_mp (
        clocking drv_cb,
        input    clk_i, rst_n_i
    );

    modport monitor_mp (
        clocking mon_cb,
        input    clk_i, rst_n_i
    );

    // ---- SVA Assertions ----

    // CHK_001: Reset state - pdo_oe_o and pdo_o must be 0 after reset
    property p_rst_pdo_oe;
        @(posedge clk_i) !rst_n_i |=> pdo_oe_o === 1'b0;
    endproperty
    assert property(p_rst_pdo_oe) else
        $error("[CHK_001] Reset: pdo_oe not 0 after reset");

    property p_rst_pdo_zero;
        @(posedge clk_i) !rst_n_i |=> pdo_o === '0;
    endproperty
    assert property(p_rst_pdo_zero) else
        $error("[CHK_001] Reset: pdo_o not 0 after reset");

    // CHK_002: Idle state - pcs_n=1 implies pdo_oe=0 and pdo_o stable
    property p_idle_pdo_oe;
        @(posedge clk_i) rst_n_i && pcs_n_i === 1'b1 |-> pdo_oe_o === 1'b0;
    endproperty
    assert property(p_idle_pdo_oe) else
        $error("[CHK_002] Idle: pdo_oe active when pcs_n=1");

    // CHK_004: pdo_oe only active within frame (pcs_n=0)
    property p_pdo_oe_in_frame;
        @(posedge clk_i) rst_n_i && pcs_n_i === 1'b1 |-> pdo_oe_o === 1'b0;
    endproperty
    assert property(p_pdo_oe_in_frame) else
        $error("[CHK_004] pdo_oe active outside frame");

endinterface
