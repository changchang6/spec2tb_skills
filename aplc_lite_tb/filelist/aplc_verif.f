// APLC-Lite TB File List
// Interfaces
${APLC_TB_HOME}/tb/if/aplc_spi_if.sv
${APLC_TB_HOME}/tb/if/aplc_ahb_if.sv
${APLC_TB_HOME}/tb/if/aplc_csr_if.sv

// DUT RTL
${APLC_RTL_HOME}/SLC_CAXIS.sv
${APLC_RTL_HOME}/SLC_RXFIFO.sv
${APLC_RTL_HOME}/SLC_DPCHK.sv
${APLC_RTL_HOME}/SLC_CCMD.sv
${APLC_RTL_HOME}/SLC_SCTRL_FRONT.sv
${APLC_RTL_HOME}/SLC_TXFIFO.sv
${APLC_RTL_HOME}/SLC_SAXIS.sv
${APLC_RTL_HOME}/SLC_TASKALLO.sv
${APLC_RTL_HOME}/SLC_TPIPE.sv
${APLC_RTL_HOME}/SLC_DPIPE.sv
${APLC_RTL_HOME}/SLC_SAXIM.sv
${APLC_RTL_HOME}/SLC_WBB.sv
${APLC_RTL_HOME}/SLC_SCTRL_BACK.sv
${APLC_RTL_HOME}/SLC_BANK.sv
${APLC_RTL_HOME}/APLC_LITE.sv

// Agent packages
${APLC_TB_HOME}/tb/uvc/spi_agent/aplc_spi_pkg.sv
${APLC_TB_HOME}/tb/uvc/ahb_agent/aplc_ahb_pkg.sv
${APLC_TB_HOME}/tb/uvc/csr_agent/aplc_csr_pkg.sv

// Environment package
${APLC_TB_HOME}/tb/env/aplc_env_pkg.sv

// Sequence package
${APLC_TB_HOME}/seq/aplc_seq_pkg.sv

// Test package
${APLC_TB_HOME}/tc/aplc_test_pkg.sv

// Testbench top
${APLC_TB_HOME}/tb/aplc_tb_top.sv
