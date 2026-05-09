// APLC CSR Interface with SVA Assertions
interface aplc_csr_if (
    input logic clk_i,
    input logic rst_n_i
);

    // CSR signals (DUT outputs -> monitor, TB slave model -> rdata)
    logic        csr_rd_en_o;
    logic        csr_wr_en_o;
    logic [7:0]  csr_addr_o;
    logic [31:0] csr_wdata_o;
    logic [31:0] csr_rdata_i;

    // Driver clocking block (for CSR rdata slave model)
    clocking drv_cb @(posedge clk_i);
        default input #1step output #1ns;
        input  csr_rd_en_o, csr_wr_en_o, csr_addr_o, csr_wdata_o;
        output csr_rdata_i;
    endclocking

    // Monitor clocking block
    clocking mon_cb @(posedge clk_i);
        default input #1step;
        input rst_n_i;
        input csr_rd_en_o, csr_wr_en_o, csr_addr_o, csr_wdata_o, csr_rdata_i;
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

    // CHK_010: Reset CSR idle
    property p_rst_csr_idle;
        @(posedge clk_i) !rst_n_i |=> csr_rd_en_o === 1'b0 && csr_wr_en_o === 1'b0;
    endproperty
    assert property(p_rst_csr_idle) else
        $error("[CHK_010] Reset: CSR en not 0 after reset");

    // CHK_011: wr_en single-cycle pulse
    property p_csr_wr_pulse;
        @(posedge clk_i) rst_n_i && csr_wr_en_o === 1'b1 |=> csr_wr_en_o === 1'b0;
    endproperty
    assert property(p_csr_wr_pulse) else
        $error("[CHK_011] CSR wr_en not single-cycle pulse");

    // CHK_012: rd_en single-cycle pulse
    property p_csr_rd_pulse;
        @(posedge clk_i) rst_n_i && csr_rd_en_o === 1'b1 |=> csr_rd_en_o === 1'b0;
    endproperty
    assert property(p_csr_rd_pulse) else
        $error("[CHK_012] CSR rd_en not single-cycle pulse");

    // CHK_013: wr_en and rd_en mutual exclusion
    property p_csr_rw_excl;
        @(posedge clk_i) rst_n_i |-> !(csr_wr_en_o === 1'b1 && csr_rd_en_o === 1'b1);
    endproperty
    assert property(p_csr_rw_excl) else
        $error("[CHK_013] CSR wr_en and rd_en both active");

    // CHK_014: CSR address range < 0x40 when enabled
    property p_csr_addr_range;
        @(posedge clk_i) rst_n_i && (csr_wr_en_o === 1'b1 || csr_rd_en_o === 1'b1) |-> csr_addr_o < 8'h40;
    endproperty
    assert property(p_csr_addr_range) else
        $error("[CHK_014] CSR addr out of range: 0x%02h", $sampled(csr_addr_o));

    // CHK_016: Read latency - rdata valid 1 cycle after rd_en
    property p_csr_rd_latency;
        @(posedge clk_i) rst_n_i && csr_rd_en_o === 1'b1 |=> !$isunknown(csr_rdata_i);
    endproperty
    assert property(p_csr_rd_latency) else
        $error("[CHK_016] CSR rdata not valid after rd_en");

endinterface
