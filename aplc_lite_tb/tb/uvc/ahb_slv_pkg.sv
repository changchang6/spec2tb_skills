// AHB Slave Agent Package
// Wraps the AHB2 VIP slave agent components for reuse in APLC_LITE TB
// Uses fixed ahb_smonitor that waits for clock edge before reading clocking block

package ahb_slv_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // VIP type definitions and transactions (from VIP include dirs)
    `include "tb_defs.svh"
    `include "ahb_sxtn.svh"
    `include "ahb_sagent_config.svh"
    `include "ahb_sseqr.svh"
    `include "ahb_sdriver.svh"

    // Use fixed monitor instead of VIP's original (avoids $cast on 'x' at time 0)
    `include "ahb_smonitor_fixed.svh"

    `include "ahb_sseqs.svh"
    `include "ahb_sagent.svh"

endpackage
