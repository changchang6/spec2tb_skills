# APLC-Lite Verification File List
# Compile order: VIP packages -> TB packages -> RTL -> TB top

# -------------------- VIP: yuu_common --------------------
+incdir+${VIP_AHB_HOME}/pkg/yuu_common/include
+incdir+${VIP_AHB_HOME}/pkg/yuu_common/src/sv
${VIP_AHB_HOME}/pkg/yuu_common/include/yuu_common_pkg.sv

# -------------------- VIP: yuu_amba --------------------
+incdir+${VIP_AHB_HOME}/pkg/yuu_amba/include
+incdir+${VIP_AHB_HOME}/pkg/yuu_amba/src/sv
${VIP_AHB_HOME}/pkg/yuu_amba/include/yuu_amba_pkg.sv

# -------------------- VIP: yuu_ahb --------------------
+incdir+${VIP_AHB_HOME}/include
+incdir+${VIP_AHB_HOME}/src/sv
+incdir+${VIP_AHB_HOME}/seq
${VIP_AHB_HOME}/include/yuu_ahb_pkg.sv
${VIP_AHB_HOME}/include/yuu_ahb_macros.svh
${VIP_AHB_HOME}/include/yuu_ahb_master_interface.svi
${VIP_AHB_HOME}/include/yuu_ahb_slave_interface.svi
${VIP_AHB_HOME}/include/yuu_ahb_interface.svi

# -------------------- TB: Register --------------------
+incdir+${APLC_TB_HOME}/reg
${APLC_TB_HOME}/reg/aplc_reg_pkg.sv

# -------------------- TB: SPI Agent --------------------
+incdir+${APLC_TB_HOME}/tb/uvc/spi_agent
${APLC_TB_HOME}/tb/uvc/spi_agent/spi_agent_pkg.sv

# -------------------- TB: CSR Agent --------------------
+incdir+${APLC_TB_HOME}/tb/uvc/csr_agent
${APLC_TB_HOME}/tb/uvc/csr_agent/csr_agent_pkg.sv

# -------------------- TB: Environment --------------------
+incdir+${APLC_TB_HOME}/tb/env
${APLC_TB_HOME}/tb/env/aplc_env_pkg.sv

# -------------------- TB: Sequences --------------------
+incdir+${APLC_TB_HOME}/seq
${APLC_TB_HOME}/seq/aplc_seq_pkg.sv

# -------------------- TB: Test Cases --------------------
+incdir+${APLC_TB_HOME}/tc
${APLC_TB_HOME}/tc/aplc_tc_pkg.sv

# -------------------- RTL --------------------
+incdir+${APLC_RTL_HOME}
${APLC_RTL_HOME}/SLC_BANK.sv
${APLC_RTL_HOME}/SLC_CAXIS.sv
${APLC_RTL_HOME}/SLC_CCMD.sv
${APLC_RTL_HOME}/SLC_DPCHK.sv
${APLC_RTL_HOME}/SLC_DPIPE.sv
${APLC_RTL_HOME}/SLC_RXFIFO.sv
${APLC_RTL_HOME}/SLC_SAXIM.sv
${APLC_RTL_HOME}/SLC_SAXIS.sv
${APLC_RTL_HOME}/SLC_SCTRL_BACK.sv
${APLC_RTL_HOME}/SLC_SCTRL_FRONT.sv
${APLC_RTL_HOME}/SLC_TASKALLO.sv
${APLC_RTL_HOME}/SLC_TPIPE.sv
${APLC_RTL_HOME}/SLC_TXFIFO.sv
${APLC_RTL_HOME}/SLC_WBB.sv
${APLC_RTL_HOME}/APLC_LITE.sv

# -------------------- TB: Interfaces --------------------
+incdir+${APLC_TB_HOME}/tb/if
${APLC_TB_HOME}/tb/if/spi_if.sv
${APLC_TB_HOME}/tb/if/csr_if.sv

# -------------------- TB: Top --------------------
${APLC_TB_HOME}/tb/tb.sv
