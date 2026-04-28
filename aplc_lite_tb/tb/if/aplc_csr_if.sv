// APLC-Lite CSR File Interface
// Connects DUT CSR interface to CSR Agent
// Signal names use _o/_i suffixes matching DUT port names
interface aplc_csr_if (
    input logic clk,
    input logic rst_n
);

    logic        csr_rd_en_o;
    logic        csr_wr_en_o;
    logic [7:0]  csr_addr_o;
    logic [31:0] csr_wdata_o;
    logic [31:0] csr_rdata_i;

    clocking cb @(posedge clk);
        default input #1step output #0;
        input  csr_rd_en_o, csr_wr_en_o, csr_addr_o, csr_wdata_o;
        output csr_rdata_i;
    endclocking

    clocking cb_monitor @(posedge clk);
        default input #1step output #0;
        input csr_rd_en_o, csr_wr_en_o, csr_addr_o, csr_wdata_o, csr_rdata_i;
    endclocking

    modport slave (
        clocking cb,
        output csr_rdata_i,
        input  csr_rd_en_o, csr_wr_en_o, csr_addr_o, csr_wdata_o
    );

    modport monitor (
        clocking cb_monitor
    );

    modport passive (
        input  clk, rst_n,
        input  csr_rd_en_o, csr_wr_en_o, csr_addr_o, csr_wdata_o, csr_rdata_i
    );

endinterface
