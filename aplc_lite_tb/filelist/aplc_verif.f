// APLC_LITE UVM Testbench File List

// AHB interface (no SVA, modified from VIP)
${APLC_TB_HOME}/tb/if/ahb_intf_no_sva.sv

// TB interfaces
${APLC_TB_HOME}/tb/if/spi_intf.sv
${APLC_TB_HOME}/tb/if/csr_intf.sv

// AHB slave package (wraps VIP slave agent)
${APLC_TB_HOME}/tb/uvc/ahb_slv_pkg.sv

// SPI agent package
${APLC_TB_HOME}/tb/uvc/spi_agent/spi_agent_pkg.sv

// CSR agent package
${APLC_TB_HOME}/tb/uvc/csr_agent/csr_agent_pkg.sv

// Register model package
${APLC_TB_HOME}/reg/aplc_reg_pkg.sv

// Environment package
${APLC_TB_HOME}/tb/env/aplc_env_pkg.sv

// Sequence package
${APLC_TB_HOME}/seq/aplc_seq_pkg.sv

// Test package
${APLC_TB_HOME}/tc/aplc_tc_pkg.sv

// TB top
${APLC_TB_HOME}/tb/tb.sv

// RTL
${APLC_RTL_HOME}/APLC_LITE.sv
${APLC_RTL_HOME}/SLC_TASKALLO.sv
${APLC_RTL_HOME}/SLC_BANK.sv
${APLC_RTL_HOME}/SLC_CAXIS.sv
${APLC_RTL_HOME}/SLC_RXFIFO.sv
${APLC_RTL_HOME}/SLC_DPCHK.sv
${APLC_RTL_HOME}/SLC_CCMD.sv
${APLC_RTL_HOME}/SLC_SCTRL_FRONT.sv
${APLC_RTL_HOME}/SLC_TXFIFO.sv
${APLC_RTL_HOME}/SLC_SAXIS.sv
${APLC_RTL_HOME}/SLC_TPIPE.sv
${APLC_RTL_HOME}/SLC_DPIPE.sv
${APLC_RTL_HOME}/SLC_SAXIM.sv
${APLC_RTL_HOME}/SLC_WBB.sv
${APLC_RTL_HOME}/SLC_SCTRL_BACK.sv
