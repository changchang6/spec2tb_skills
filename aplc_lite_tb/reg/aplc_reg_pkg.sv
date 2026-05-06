package aplc_reg_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Minimal register definitions for APLC-Lite CSR space
    // Used by CSR driver for initialization

    parameter bit [7:0] CSR_VERSION    = 8'h00;
    parameter bit [7:0] CSR_CTRL       = 8'h04;
    parameter bit [7:0] CSR_STATUS     = 8'h08;
    parameter bit [7:0] CSR_LAST_ERR   = 8'h0C;
    parameter bit [7:0] CSR_BURST_CNT  = 8'h10;

    parameter bit [31:0] VERSION_DEFAULT = 32'h0000_0220;

endpackage
