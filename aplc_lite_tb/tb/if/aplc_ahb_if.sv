// =============================================================================
// File: aplc_ahb_if.sv
// Description: APLC-Lite AHB-Lite interface for testbench
//              DUT is AHB Master; TB provides AHB Slave
// =============================================================================

interface aplc_ahb_if (
    input logic hclk,
    input logic hresetn
);

    // -------------------------------------------------------------------------
    // Signal declarations
    // -------------------------------------------------------------------------
    logic        hsel;
    logic [31:0] haddr;
    logic        hwrite;
    logic [2:0]  hsize;
    logic [2:0]  hburst;
    logic [1:0]  htrans;
    logic [31:0] hwdata;
    logic [31:0] hrdata;
    logic        hreadyout;
    logic        hresp;

    // -------------------------------------------------------------------------
    // AHB Burst type constants
    // -------------------------------------------------------------------------
    localparam BT_SINGLE = 3'b000;
    localparam BT_INCR4  = 3'b011;
    localparam BT_INCR8  = 3'b101;
    localparam BT_INCR16 = 3'b111;

    // -------------------------------------------------------------------------
    // AHB Transfer type constants
    // -------------------------------------------------------------------------
    localparam TT_IDLE   = 2'b00;
    localparam TT_NONSEQ = 2'b10;
    localparam TT_SEQ    = 2'b11;

    // -------------------------------------------------------------------------
    // AHB Response constants
    // -------------------------------------------------------------------------
    localparam RSP_OKAY  = 1'b0;
    localparam RSP_ERROR = 1'b1;

    initial begin
        hrdata    = 32'h0;
        hreadyout = 1'b1;
        hresp     = RSP_OKAY;
    end

    // -------------------------------------------------------------------------
    // Clocking block for slave driver
    //   - Inputs: signals driven by AHB master (DUT)
    //   - Outputs: signals driven by AHB slave (TB)
    // -------------------------------------------------------------------------
    clocking sdrv_cb @(posedge hclk);
        input  hsel;
        input  haddr;
        input  hwrite;
        input  hsize;
        input  hburst;
        input  htrans;
        input  hwdata;
        output hrdata;
        output hreadyout;
        output hresp;
    endclocking: sdrv_cb

    // -------------------------------------------------------------------------
    // Clocking block for monitor
    //   - Inputs: all signals (observe only)
    // -------------------------------------------------------------------------
    clocking mon_cb @(posedge hclk);
        input hsel;
        input haddr;
        input hwrite;
        input hsize;
        input hburst;
        input htrans;
        input hwdata;
        input hrdata;
        input hreadyout;
        input hresp;
    endclocking: mon_cb

    // -------------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------------
    modport SLAVE_DRIVER (
        clocking sdrv_cb,
        import   task drive_idle()
    );

    modport MONITOR (
        clocking mon_cb
    );

    // -------------------------------------------------------------------------
    // Task: drive_idle - Set slave outputs to idle/default state
    // -------------------------------------------------------------------------
    task drive_idle();
        hrdata    = 32'h0;
        hreadyout = 1'b1;
        hresp     = RSP_OKAY;
    endtask: drive_idle

    // -------------------------------------------------------------------------
    // Concurrent assertions for AHB protocol checking
    // -------------------------------------------------------------------------

    // Property: hresp must be OKAY when htrans is IDLE
    property p_idle_okay;
        @(posedge hclk)
        disable iff (!hresetn)
        (htrans == TT_IDLE) |-> (hresp == RSP_OKAY);
    endproperty: p_idle_okay

    // Property: hsize must be WORD (3'b010) per design requirement
    property p_hsize_word;
        @(posedge hclk)
        disable iff (!hresetn)
        (htrans inside {TT_NONSEQ, TT_SEQ}) |-> (hsize == 3'b010);
    endproperty: p_hsize_word

    // Property: haddr must be word-aligned when transfer is active
    property p_haddr_aligned;
        @(posedge hclk)
        disable iff (!hresetn)
        (htrans inside {TT_NONSEQ, TT_SEQ}) |-> (haddr[1:0] == 2'b00);
    endproperty: p_haddr_aligned

    assert property (p_idle_okay)
        else $error("APLC-AHB protocol violation: hresp not OKAY during IDLE");

    assert property (p_hsize_word)
        else $error("APLC-AHB protocol violation: hsize not WORD during active transfer");

    assert property (p_haddr_aligned)
        else $error("APLC-AHB protocol violation: haddr not word-aligned during active transfer");

endinterface: aplc_ahb_if
