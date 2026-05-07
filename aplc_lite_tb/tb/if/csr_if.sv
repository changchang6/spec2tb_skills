// CSR interface for APLC-Lite CSR File
// DUT is master, TB CSR agent is slave
interface csr_if(input logic clk, input logic rst_n);

    logic        csr_rd_en;
    logic        csr_wr_en;
    logic [7:0]  csr_addr;
    logic [31:0] csr_wdata;
    logic [31:0] csr_rdata;

    // Initialize rdata to 0 (idle state)
    initial begin
        csr_rdata = '0;
    end

    // Slave clocking block (TB responds to DUT CSR requests)
    clocking slv_cb @(posedge clk);
        input  csr_rd_en, csr_wr_en, csr_addr, csr_wdata;
        output csr_rdata;
    endclocking

    // Monitor clocking block (observes all signals)
    clocking mon_cb @(posedge clk);
        input csr_rd_en, csr_wr_en, csr_addr, csr_wdata, csr_rdata;
    endclocking

    modport slv_mp(clocking slv_cb);
    modport mon_mp(clocking mon_cb);

endinterface
