# APLC-Lite UVM Testbench Makefile
VCS       = vcs
VERDI     = verdi

SCRIPT_DIR    := $(shell pwd)
APLC_TB_HOME  := $(SCRIPT_DIR)/..
APLC_RTL_HOME := $(HOME)/ai_evaluation/claude_code/spec2tb/cc_APLC_Lite/rtl
VIP_AHB_HOME  := $(SCRIPT_DIR)/../../vip/yuu_ahb

export APLC_TB_HOME
export APLC_RTL_HOME
export VIP_AHB_HOME

TEST     ?= aplc_smoke_test
SEED     ?= $(shell date +%s)
SIM_DIR  ?= sim_work
GUI      ?= 0
DUMP     ?= 1
COV      ?= 0
XPROP    ?= 0
WAVE_FSDB ?= aplc_tb.fsdb

# -------------------- VCS Options --------------------
VCS_COMP_OPTS = \
    -full64 \
    -sverilog \
    -debug_access+all \
    -kdb \
    -lca \
    +incdir+$(APLC_TB_HOME)/tb/if \
    +incdir+$(APLC_TB_HOME)/tb/uvc/spi_agent \
    +incdir+$(APLC_TB_HOME)/tb/uvc/csr_agent \
    +incdir+$(APLC_TB_HOME)/tb/env \
    +incdir+$(APLC_TB_HOME)/seq \
    +incdir+$(APLC_TB_HOME)/tc \
    +incdir+$(APLC_TB_HOME)/reg \
    +incdir+$(VIP_AHB_HOME)/include \
    +incdir+$(VIP_AHB_HOME)/pkg/yuu_common/include \
    +incdir+$(VIP_AHB_HOME)/pkg/yuu_amba/include \
    +incdir+$(VIP_AHB_HOME)/src/sv \
    +incdir+$(VIP_AHB_HOME)/seq \
    -timescale=1ns/1ps \
    -ntb_opts uvm-1.2 \
    +define+UVM_NO_DPI \
    +define+YUU_UVM \
    +define+YUU_AHB_MAX_MASTER_NUM=0 \
    +define+YUU_AHB_MAX_SLAVE_NUM=1 \
    -LDFLAGS -Wl,--no-as-needed \
    -l compile.log

VCS_SIM_OPTS = \
    +UVM_TESTNAME=$(TEST) \
    +ntb_random_seed=$(SEED) \
    -l $(TEST).log

# Coverage
ifeq ($(COV),1)
VCS_COMP_OPTS += -cm line+cond+fsm+tgl+branch+assert
VCS_SIM_OPTS  += -cm line+cond+fsm+tgl+branch+assert
endif

# XPROP
ifeq ($(XPROP),1)
VCS_COMP_OPTS += -xprop=tmerge
endif

# Waveform dump (default on)
ifeq ($(DUMP),1)
VCS_COMP_OPTS += +define+DUMP_FSDB
endif

# GUI (default off)
ifeq ($(GUI),1)
VCS_SIM_OPTS += -gui=verdi
endif

# -------------------- Targets --------------------
.PHONY: comp sim wave clean cov_report

comp:
	@mkdir -p $(SIM_DIR)
	cd $(SIM_DIR) && $(VCS) $(VCS_COMP_OPTS) -f $(APLC_TB_HOME)/filelist/aplc_verif.f

sim: comp
	cd $(SIM_DIR) && ./simv $(VCS_SIM_OPTS) -gui=verdi

wave:
	cd $(SIM_DIR) && $(VERDI) -f $(APLC_TB_HOME)/filelist/aplc_verif.f -ssf $(WAVE_FSDB) -top tb -nologo &

cov_report:
	cd $(SIM_DIR) && urg -dir simv.vdb -report cov_report

clean:
	rm -rf $(SIM_DIR)
	rm -rf csrc simv* vc_hdrs.h ucli.key *.log *.vpd *.key *.vdb DVEfiles novas* *.fsdb verdiLog
