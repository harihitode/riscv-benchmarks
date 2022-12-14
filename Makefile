#=======================================================================
# UCB VLSI FLOW: Makefile for riscv-bmarks
#-----------------------------------------------------------------------
# Yunsup Lee (yunsup@cs.berkeley.edu)
#

XLEN ?= 32

default: all

src_dir = .

instname = riscv-bmarks
instbasedir = $(UCB_VLSI_HOME)/install

#--------------------------------------------------------------------
# Sources
#--------------------------------------------------------------------

bmarks = \
	median \
	qsort \
	rsort \
	towers \
	vvadd \
	multiply \
	mm \
	dhrystone \
	spmv \
	mt-vvadd \
	mt-matmul \
	mt-mm \
	mt-mask-sfilter \
	mt-csaxpy \
	mt-histo \

bmarks_host = \
	median \
	mt-vvadd \
	qsort \
	towers \
	vvadd \
	multiply \
	spmv \
	vec-vvadd \
	vec-cmplxmult \
	vec-matmul \

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

HOST_OPTS = -std=gnu99 -DPREALLOCATE=0 -DHOST_DEBUG=1
HOST_COMP = gcc $(HOST_OPTS)

RISCV_PREFIX ?= ~/llvm-riscv-15/bin/
RISCV_GCC ?= $(RISCV_PREFIX)clang
RISCV_GCC_OPTS ?= -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf -nodefaultlibs -g --target=riscv32 -march=rv32imac -mabi=ilp32 -DSP
RISCV_LINK ?= $(RISCV_PREFIX)clang -v
RISCV_LINK_MT ?= $(RISCV_GCC) -T $(src_dir)/common/test-mt.ld
RISCV_LINK_OPTS ?= -nostdlib -lclang_rt.builtins -T $(src_dir)/common/test.ld -L$(HOME)/llvm-riscv-15/lib/clang/15.0.3/lib/riscv32-unknown-elf/ --target=riscv32 -march=rv32imac -mabi=ilp32
RISCV_OBJDUMP ?= $(RISCV_PREFIX)llvm-objdump --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.data
RISCV_SIM ?= spike

VPATH += $(addprefix $(src_dir)/, $(bmarks))
VPATH += $(src_dir)/common

incs  +=  -I$(src_dir)/riscv-pk/machine -I$(src_dir)/libamf/src -I$(src_dir)/common $(addprefix -I$(src_dir)/, $(bmarks)) -I$(HOME)/newlib-cygwin/newlib/libc/include
objs  :=

include $(patsubst %, $(src_dir)/%/bmark.mk, $(bmarks))

#------------------------------------------------------------
# Build and run benchmarks on riscv simulator

bmarks_riscv_bin  = $(addsuffix .riscv,  $(bmarks))
bmarks_riscv_dump = $(addsuffix .riscv.dump, $(bmarks))
bmarks_riscv_out  = $(addsuffix .riscv.out,  $(bmarks))

bmarks_defs   = -DPREALLOCATE=1 -DHOST_DEBUG=0
bmarks_cycles = 80000

$(bmarks_riscv_dump): %.riscv.dump: %.riscv
	$(RISCV_OBJDUMP) $< > $@

$(bmarks_riscv_out): %.riscv.out: %.riscv
	$(RISCV_SIM) $< > $@

%.o: %.c
	$(RISCV_GCC) $(RISCV_GCC_OPTS) $(bmarks_defs) \
	             -c $(incs) $< -o $@

%.o: %.S
	$(RISCV_GCC) $(RISCV_GCC_OPTS) $(bmarks_defs) -D__ASSEMBLY__=1 \
	             -c $(incs) $< -o $@

ifdef HWACHA
riscv: $(bmarks_riscv_dump) $(bmarks_riscv_hex)
	make -C hwacha
else
riscv: $(bmarks_riscv_dump) $(bmarks_riscv_hex)
endif

run-riscv: $(bmarks_riscv_out)
	echo; perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
	       $(bmarks_riscv_out); echo;

junk += $(bmarks_riscv_bin) $(bmarks_riscv_dump) $(bmarks_riscv_hex) $(bmarks_riscv_out)

#------------------------------------------------------------
# Build and run benchmarks on host machine

bmarks_host_bin = $(addsuffix .host, $(bmarks_host))
bmarks_host_out = $(addsuffix .host.out, $(bmarks_host))

$(bmarks_host_out): %.host.out: %.host
	./$< > $@

host: $(bmarks_host_bin)
run-host: $(bmarks_host_out)
	echo; perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
	       $(bmarks_host_out); echo;

junk += $(bmarks_host_bin) $(bmarks_host_out)

#------------------------------------------------------------
# Default

all: riscv

#------------------------------------------------------------
# Install

date_suffix = $(shell date +%Y-%m-%d_%H-%M)
install_dir = $(instbasedir)/$(instname)-$(date_suffix)
latest_install = $(shell ls -1 -d $(instbasedir)/$(instname)* | tail -n 1)

install:
	mkdir $(install_dir)
	cp -r $(bmarks_riscv_bin) $(bmarks_riscv_dump) $(install_dir)

install-link:
	rm -rf $(instbasedir)/$(instname)
	ln -s $(latest_install) $(instbasedir)/$(instname)

#------------------------------------------------------------
# Clean up

clean:
	rm -rf $(objs) $(junk)
