// CSR Interface for APLC_LITE
// Matches DUT CSR port: csr_rd_en_o, csr_wr_en_o, csr_addr_o[7:0], csr_wdata_o[31:0], csr_rdata_i[31:0]

interface csr_intf(input logic clk_i);

    logic        csr_rd_en;
    logic        csr_wr_en;
    logic [7:0]  csr_addr;
    logic [31:0] csr_wdata;
    logic [31:0] csr_rdata;

    // Slave driver clocking block: TB provides csr_rdata in response to reads
    clocking slv_cb @(posedge clk_i);
        default input #1 output #0;
        input  csr_rd_en;
        input  csr_wr_en;
        input  csr_addr;
        input  csr_wdata;
        output csr_rdata;
    endclocking

    // Monitor clocking block: observes all CSR signals
    clocking mon_cb @(posedge clk_i);
        default input #1 output #0;
        input csr_rd_en;
        input csr_wr_en;
        input csr_addr;
        input csr_wdata;
        input csr_rdata;
    endclocking

    modport SLV_MP(clocking slv_cb);
    modport MON_MP(clocking mon_cb);

endinterface
