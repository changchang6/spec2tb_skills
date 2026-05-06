// APLC-Lite CSR File Interface
interface csr_intf(input logic clk_i, input logic rst_n_i);

    logic        csr_rd_en;
    logic        csr_wr_en;
    logic [7:0]  csr_addr;
    logic [31:0] csr_wdata;
    logic [31:0] csr_rdata;

    clocking drv_cb @(posedge clk_i);
        default input #1step output #0;
        input   csr_rd_en, csr_wr_en, csr_addr, csr_wdata;
        output  csr_rdata;
    endclocking

    clocking mon_cb @(posedge clk_i);
        default input #1step;
        input  csr_rd_en, csr_wr_en, csr_addr, csr_wdata, csr_rdata;
    endclocking

    modport drv_mp(clocking drv_cb);
    modport mon_mp(clocking mon_cb);

endinterface
