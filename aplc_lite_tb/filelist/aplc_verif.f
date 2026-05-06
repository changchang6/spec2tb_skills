// APLC-Lite Verification File List
// NOTE: This file uses environment variable substitution which VCS does not support.
// The Makefile generates a resolved version at compile time.

// ---- VIP: yuu_ahb ----
+incdir+APLC_TB_HOME/vip/yuu_ahb/include
+incdir+APLC_TB_HOME/vip/yuu_ahb/pkg/yuu_amba/include
+incdir+APLC_TB_HOME/vip/yuu_ahb/pkg/yuu_amba/src/sv
+incdir+APLC_TB_HOME/vip/yuu_ahb/pkg/yuu_common/include
+incdir+APLC_TB_HOME/vip/yuu_ahb/pkg/yuu_common/src/sv
+incdir+APLC_TB_HOME/vip/yuu_ahb/src/sv
+incdir+APLC_TB_HOME/vip/yuu_ahb/seq
APLC_TB_HOME/vip/yuu_ahb/pkg/yuu_common/include/yuu_common_pkg.sv
APLC_TB_HOME/vip/yuu_ahb/pkg/yuu_amba/include/yuu_amba_pkg.sv
APLC_TB_HOME/vip/yuu_ahb/include/yuu_ahb_pkg.sv

// ---- TB interfaces ----
+incdir+APLC_TB_HOME/aplc_lite_tb/tb/if
APLC_TB_HOME/aplc_lite_tb/tb/if/spi_intf.sv
APLC_TB_HOME/aplc_lite_tb/tb/if/csr_intf.sv

// ---- TB packages ----
APLC_TB_HOME/aplc_lite_tb/tb/uvc/spi_agent/spi_agent_pkg.sv
+incdir+APLC_TB_HOME/aplc_lite_tb/tb/uvc/spi_agent
APLC_TB_HOME/aplc_lite_tb/tb/uvc/csr_agent/csr_agent_pkg.sv
+incdir+APLC_TB_HOME/aplc_lite_tb/tb/uvc/csr_agent
APLC_TB_HOME/aplc_lite_tb/reg/aplc_reg_pkg.sv
+incdir+APLC_TB_HOME/aplc_lite_tb/reg
APLC_TB_HOME/aplc_lite_tb/tb/env/aplc_env_pkg.sv
+incdir+APLC_TB_HOME/aplc_lite_tb/tb/env
APLC_TB_HOME/aplc_lite_tb/seq/aplc_seq_pkg.sv
+incdir+APLC_TB_HOME/aplc_lite_tb/seq
APLC_TB_HOME/aplc_lite_tb/tc/aplc_tc_pkg.sv
+incdir+APLC_TB_HOME/aplc_lite_tb/tc

// ---- Top TB ----
APLC_TB_HOME/aplc_lite_tb/tb/tb.sv

// ---- DUT RTL ----
APLC_RTL_HOME/SLC_TASKALLO.sv
APLC_RTL_HOME/SLC_BANK.sv
APLC_RTL_HOME/SLC_CAXIS.sv
APLC_RTL_HOME/SLC_CCMD.sv
APLC_RTL_HOME/SLC_DPCHK.sv
APLC_RTL_HOME/SLC_DPIPE.sv
APLC_RTL_HOME/SLC_RXFIFO.sv
APLC_RTL_HOME/SLC_SAXIM.sv
APLC_RTL_HOME/SLC_SAXIS.sv
APLC_RTL_HOME/SLC_SCTRL_BACK.sv
APLC_RTL_HOME/SLC_SCTRL_FRONT.sv
APLC_RTL_HOME/SLC_TPIPE.sv
APLC_RTL_HOME/SLC_TXFIFO.sv
APLC_RTL_HOME/SLC_WBB.sv
APLC_RTL_HOME/APLC_LITE.sv
