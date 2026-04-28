// APLC-Lite AHB-Lite Slave Interface
// Connects DUT AHB Master to AHB Slave Agent
interface aplc_ahb_if (
    input logic hclk,
    input logic hresetn
);

    logic [31:0] haddr;
    logic        hwrite;
    logic [1:0]  htrans;
    logic [2:0]  hsize;
    logic [2:0]  hburst;
    logic [31:0] hwdata;
    logic [31:0] hrdata;
    logic        hready;
    logic        hresp;

    clocking cb @(posedge hclk);
        default input #1step output #0;
        input  haddr, hwrite, htrans, hsize, hburst, hwdata;
        output hrdata, hready, hresp;
    endclocking

    clocking cb_monitor @(posedge hclk);
        default input #1step output #0;
        input haddr, hwrite, htrans, hsize, hburst, hwdata;
        input hrdata, hready, hresp;
    endclocking

    modport slave (
        clocking cb,
        output hrdata, hready, hresp,
        input  haddr, hwrite, htrans, hsize, hburst, hwdata
    );

    modport monitor (
        clocking cb_monitor
    );

    modport passive (
        input  hclk, hresetn,
        input  haddr, hwrite, htrans, hsize, hburst, hwdata,
        input  hrdata, hready, hresp
    );

endinterface
