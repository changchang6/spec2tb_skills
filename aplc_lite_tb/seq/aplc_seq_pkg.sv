// APLC-Lite Sequence Package
package aplc_seq_pkg;

import uvm_pkg::*;
import aplc_spi_pkg::*;
import aplc_ahb_pkg::*;
import aplc_csr_pkg::*;

`include "uvm_macros.svh"
`include "aplc_base_seq.svh"
`include "aplc_wr_csr_seq.svh"
`include "aplc_rd_csr_seq.svh"
`include "aplc_ahb_wr32_seq.svh"
`include "aplc_ahb_rd32_seq.svh"
`include "aplc_ahb_wr_burst_seq.svh"
`include "aplc_ahb_rd_burst_seq.svh"
`include "aplc_smoke_seq.svh"

endpackage
