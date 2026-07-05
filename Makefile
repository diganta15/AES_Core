# ============================================================================
# Makefile for aes_core testbench
#   make        - compile + run the testbench (default)
#   make sim    - compile only
#   make run    - run the compiled testbench
#   make wave   - open the VCD dump in gtkwave (if installed)
#   make synth  - run the Yosys generic synthesis script, print stats
#   make clean  - remove generated files
# ============================================================================

RTL_DIR   := rtl
TB_DIR    := tb
SIM_DIR   := sim
SYNTH_DIR := synth

RTL_SRCS  := $(RTL_DIR)/sbox.v \
             $(RTL_DIR)/mix_columns.v \
             $(RTL_DIR)/sub_bytes.v \
             $(RTL_DIR)/shift_rows.v \
             $(RTL_DIR)/key_expand.v \
             $(RTL_DIR)/aes_core.v

TB_SRC    := $(TB_DIR)/aes_tb.v

SIM_OUT   := $(SIM_DIR)/aes_sim
VCD_FILE  := aes_tb.vcd

IVERILOG  := iverilog
VVP       := vvp
VFLAGS    := -g2012

.PHONY: all sim run wave synth clean

all: run

$(SIM_OUT): $(RTL_SRCS) $(TB_SRC)
	mkdir -p $(SIM_DIR)
	$(IVERILOG) $(VFLAGS) -o $(SIM_OUT) $(RTL_SRCS) $(TB_SRC)

sim: $(SIM_OUT)

run: $(SIM_OUT)
	cd $(SIM_DIR) && $(VVP) aes_sim

wave: run
	cd $(SIM_DIR) && gtkwave $(VCD_FILE) &

synth:
	cd $(SYNTH_DIR) && yosys -s synth.ys

clean:
	rm -f $(SIM_OUT) $(SIM_DIR)/$(VCD_FILE)