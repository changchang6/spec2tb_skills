// APLC Verification Filelist
// Compile order: VIP deps -> VIP -> DUT -> TB

// ---- VIP: yuu_common ----
+incdir+${APLC_TB_HOME}/../vip/yuu_ahb/pkg/yuu_common/src/sv
${APLC_TB_HOME}/../vip/yuu_ahb/pkg/yuu_common/include/yuu_common_pkg.sv

// ---- VIP: yuu_amba ----
+incdir+${APLC_TB_HOME}/../vip/yuu_ahb/pkg/yuu_amba/include
+incdir+${APLC_TB_HOME}/../vip/yuu_ahb/pkg/yuu_amba/src/sv
${APLC_TB_HOME}/../vip/yuu_ahb/pkg/yuu_amba/include/yuu_amba_defines.svh
${APLC_TB_HOME}/../vip/yuu_ahb/pkg/yuu_amba/include/yuu_amba_pkg.sv

// ---- VIP: yuu_ahb ----
+incdir+${APLC_TB_HOME}/../vip/yuu_ahb/include
+incdir+${APLC_TB_HOME}/../vip/yuu_ahb/src/sv
+incdir+${APLC_TB_HOME}/../vip/yuu_ahb/seq
${APLC_TB_HOME}/../vip/yuu_ahb/include/yuu_ahb_macros.svh
${APLC_TB_HOME}/../vip/yuu_ahb/include/yuu_ahb_master_interface.svi
${APLC_TB_HOME}/../vip/yuu_ahb/include/yuu_ahb_slave_interface.svi
${APLC_TB_HOME}/../vip/yuu_ahb/include/yuu_ahb_interface.svi
${APLC_TB_HOME}/../vip/yuu_ahb/include/yuu_ahb_pkg.sv

// ---- DUT RTL ----
${APLC_RTL_HOME}/SLC_CSRFILE.sv
${APLC_RTL_HOME}/SLC_CAXIS.sv
${APLC_RTL_HOME}/SLC_DPCHK.sv
${APLC_RTL_HOME}/SLC_CCMD.sv
${APLC_RTL_HOME}/SLC_SAXIS.sv
${APLC_RTL_HOME}/SLC_SCTRL_FRONT.sv
${APLC_RTL_HOME}/SLC_TPIPE.sv
${APLC_RTL_HOME}/SLC_DPIPE.sv
${APLC_RTL_HOME}/SLC_SAXIM.sv
${APLC_RTL_HOME}/SLC_WBB.sv
${APLC_RTL_HOME}/SLC_SCTRL_BACK.sv
${APLC_RTL_HOME}/SLC_RXFIFO.sv
${APLC_RTL_HOME}/SLC_TXFIFO.sv
${APLC_RTL_HOME}/SLC_BANK.sv
${APLC_RTL_HOME}/SLC_TASKALLO.sv
${APLC_RTL_HOME}/APLC_LITE.sv

// ---- TB Interfaces ----
+incdir+${APLC_TB_HOME}/tb/if
${APLC_TB_HOME}/tb/if/spi_if.sv
${APLC_TB_HOME}/tb/if/csr_if.sv

// ---- TB Packages ----
+incdir+${APLC_TB_HOME}/tb/uvc/spi_agent
+incdir+${APLC_TB_HOME}/tb/uvc/csr_agent
+incdir+${APLC_TB_HOME}/tb/env
+incdir+${APLC_TB_HOME}/seq
+incdir+${APLC_TB_HOME}/tc
${APLC_TB_HOME}/tb/uvc/spi_agent/aplc_spi_pkg.sv
${APLC_TB_HOME}/tb/uvc/csr_agent/aplc_csr_pkg.sv
${APLC_TB_HOME}/reg/aplc_reg_pkg.sv
${APLC_TB_HOME}/tb/env/aplc_env_pkg.sv
${APLC_TB_HOME}/seq/aplc_seq_pkg.sv
${APLC_TB_HOME}/tc/aplc_tc_pkg.sv

// ---- TB Top ----
${APLC_TB_HOME}/tb/tb.sv
