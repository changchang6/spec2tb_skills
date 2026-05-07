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

    // Initialize driver-controlled signals to idle state
    initial begin
        pcs_n     = 1'b1;
        pdi       = '0;
        en        = 1'b0;
        test_mode = 1'b0;
        lane_mode = 2'b00;
    end

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

    // CHK_SPI: Every frame (pcs_n low) must have DUT response (pdo_oe high)
    property p_frame_has_response;
        @(posedge clk) disable iff (!rst_n)
        $fell(pcs_n) |-> (!pcs_n) throughout (##[1:$] pdo_oe === 1'b1);
    endproperty
    assert property(p_frame_has_response) else
        $error("[CHK_SPI] Frame without response: pdo_oe not asserted during pcs_n low");

endinterface
