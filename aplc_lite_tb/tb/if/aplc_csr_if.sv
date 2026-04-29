// =============================================================================
// File: aplc_csr_if.sv
// Description: APLC-Lite CSR interface for testbench
//              DUT drives CSR requests; TB models CSR File behavior
// =============================================================================

interface aplc_csr_if (
    input logic csr_clk
);

    // -------------------------------------------------------------------------
    // Signal declarations
    // -------------------------------------------------------------------------
    logic [5:0]  csr_addr;
    logic [31:0] csr_wdata;
    logic [31:0] csr_rdata;
    logic        csr_write;
    logic        csr_valid;

    initial csr_rdata = 32'h0;

    // -------------------------------------------------------------------------
    // Clocking block for driver
    //   - Outputs: csr_rdata (driven by TB CSR model)
    //   - Inputs:  csr_addr, csr_wdata, csr_write, csr_valid (driven by DUT)
    // -------------------------------------------------------------------------
    clocking drv_cb @(posedge csr_clk);
        output csr_rdata;
        input  csr_addr;
        input  csr_wdata;
        input  csr_write;
        input  csr_valid;
    endclocking: drv_cb

    // -------------------------------------------------------------------------
    // Clocking block for monitor
    //   - Inputs: all signals (observe only)
    // -------------------------------------------------------------------------
    clocking mon_cb @(posedge csr_clk);
        input csr_addr;
        input csr_wdata;
        input csr_rdata;
        input csr_write;
        input csr_valid;
    endclocking: mon_cb

    // -------------------------------------------------------------------------
    // Modports
    // -------------------------------------------------------------------------
    modport DRIVER (
        clocking drv_cb,
        import   task drive_idle()
    );

    modport MONITOR (
        clocking mon_cb
    );

    // -------------------------------------------------------------------------
    // Task: drive_idle - Set CSR outputs to idle/default state
    // -------------------------------------------------------------------------
    task drive_idle();
        csr_rdata = 32'h0;
    endtask: drive_idle

endinterface: aplc_csr_if
