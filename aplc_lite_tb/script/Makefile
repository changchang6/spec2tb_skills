# APLC-Lite Testbench Makefile
# VCS Simulation + Verdi Waveform

RTL_DIR   = $(HOME)/ai_evaluation/claude_code/rtm_gen/APLC-Lite/rtl
TB_DIR    = $(shell pwd)/..
WORK_DIR  = $(shell pwd)

VCS_HOME ?= $(HOME)/ProgramFiles/vcs_verdi2018/synopsys/vcs_201809/vcs/O-2018.09-SP2
VERDI_HOME = $(HOME)/ProgramFiles/vcs_verdi2018/synopsys/verdi_201809/verdi/Verdi_O-2018.09-SP2
export VCS_HOME

VCS      = vcs
VCS_FLAGS = -full64 -sverilog -debug_access+all -ntb_opts uvm-1.2 -kdb -lca \
            -P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab \
            $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a \
            -LDFLAGS -Wl,--no-as-needed \
            +incdir+$(TB_DIR)/tb/if \
            +incdir+$(TB_DIR)/tb/uvc/spi_agent \
            +incdir+$(TB_DIR)/tb/uvc/ahb_agent \
            +incdir+$(TB_DIR)/tb/uvc/csr_agent \
            +incdir+$(TB_DIR)/tb/env \
            +incdir+$(TB_DIR)/seq \
            +incdir+$(TB_DIR)/tc \
            +incdir+$(RTL_DIR) \
            +define+DUMP_FSDB \
            -f $(TB_DIR)/filelist/aplc_verif.f \
            -l compile.log

SIM_FLAGS = -l sim.log +UVM_VERBOSITY=UVM_LOW

UVM_TEST ?= aplc_smoke_test

.PHONY: compile sim smoke wave clean

compile:
	@echo "=== Compiling APLC-Lite TB ==="
	cd $(WORK_DIR) && $(VCS) $(VCS_FLAGS) -top aplc_tb_top 2>&1 | tee compile.log
	@echo "=== Compile done ==="

sim: compile
	@echo "=== Running simulation (test=$(UVM_TEST)) ==="
	cd $(WORK_DIR) && ./simv $(SIM_FLAGS) +UVM_TESTNAME=$(UVM_TEST) 2>&1 | tee sim.log
	@echo "=== Simulation done ==="

smoke: compile
	@echo "=== Running smoke test ==="
	cd $(WORK_DIR) && ./simv $(SIM_FLAGS) +UVM_TESTNAME=aplc_smoke_test 2>&1 | tee smoke.log
	@echo "=== Smoke test done ==="

wave:
	verdi -sv -f $(TB_DIR)/filelist/aplc_verif.f -ssf aplc.fsdb -top aplc_tb_top &

clean:
	rm -rf simv simv.daidir csrc ucli.key compile.log sim.log smoke.log
	rm -rf *.vpd *.vcd *.fsdb *.log *.key *.vpd DVEfiles
	rm -rf inter.vpd ucli.key novas* irun.log waves.shm

distclean: clean
	rm -rf *.vdb
