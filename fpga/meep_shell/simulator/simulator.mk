VERILATOR = verilator
MEEP_SIM_DIR = $(PROJECT_DIR)/fpga/meep_shell/simulator
VORTEX_DIR = $(PROJECT_DIR)/fpga/vortex

MEEP_SIMULATOR = $(PROJECT_DIR)/sim-meep

FLAGS ?=

VORTEX_DPI_DIR := $(VORTEX_DIR)/hw/dpi
VORTEX_SIM_INCLUDE_DIR := $(VORTEX_DIR)/sim/common
VORTEX_HEADERS := $(VORTEX_DIR)/build/hw/

THIRD_PARTY_DIR := $(VORTEX_DIR)/third_party

THIRD_PARTY_LIBS = -I$(THIRD_PARTY_DIR)/softfloat/source/include
THIRD_PARTY_LIBS += -I$(THIRD_PARTY_DIR)/ramulator/ext/spdlog/include
THIRD_PARTY_LIBS += -I$(THIRD_PARTY_DIR)/ramulator/ext/yaml-cpp/include
THIRD_PARTY_LIBS += -I$(THIRD_PARTY_DIR)/ramulator/src -fPIC

EXTRA_LDFLAGS = -shared $(THIRD_PARTY_DIR)/softfloat/build/Linux-x86_64-GCC/softfloat.a
EXTRA_LDFLAGS += -Wl,-rpath,$(THIRD_PARTY_DIR)/ramulator -L$(THIRD_PARTY_DIR)/ramulator -lramulator -pthread

MEEP_VERI_FLAGS = \
	$(foreach flag, $(FLAGS), -D$(flag)) \
	-DVERILATOR_GCC \
	+define+SV_DPI \
	+define+SIM_COMMIT_LOG \
	+define+SIM_COMMIT_LOG_DPI \
	+define+SIM_KONATA_DUMP \
	-F $(MEEP_SIM_DIR)/filelist.f \
	--top-module $(TOP_MODULE) \
	--unroll-count 256 \
	-Wno-lint -Wno-style -Wno-STMTDLY -Wno-fatal \
	-CFLAGS "-std=c++17 -I$(SPIKE_DIR)/riscv-isa-sim/ -I$(VORTEX_DPI_DIR) -I$(VORTEX_SIM_INCLUDE_DIR) -I$(VORTEX_HEADERS) $(THIRD_PARTY_LIBS)" \
	-LDFLAGS "-pthread -L$(SPIKE_DIR)/build/ -Wl,-rpath=$(SPIKE_DIR)/build/ -ldisasm -ldl $(EXTRA_LDFLAGS)" \
	--exe \
	--trace-fst \
	--trace-max-array 512 \
	--trace-max-width 256 \
	--trace-structs \
	--trace-params \
	--trace-underscore \
	--assert \
	--Mdir $(MEEP_SIM_DIR)/build \
	--savable

MEEP_VERI_OPTI_FLAGS = -O2 -CFLAGS "-O2"

MEEP_SIM_CPP_SRCS = $(SIM_CPP_SRCS) $(wildcard $(MEEP_SIM_DIR)/models/cxx/*.cpp)
MEEP_SIM_VERILOG_SRCS = $(SIM_VERILOG_SRCS) $(shell cat $(PROJECT_DIR)/fpga/common/filelist.f) $(wildcard $(PROJECT_DIR)/fpga/meep_shell/src/*) $(wildcard $(MEEP_SIM_DIR)/models/hdl/*.sv)

.patched:
		echo "Applying patches to axi and common_cells submodules"
		cp $(MEEP_SIM_DIR)/../../vortex-filelist.f $(MEEP_SIM_DIR)/../../vortex/filelist.f
		cd $(MEEP_SIM_DIR)/../../common/rtl/axi && git reset --hard HEAD && git apply $(MEEP_SIM_DIR)/../../common/patches/axi.patch && cd -
		cd $(MEEP_SIM_DIR)/../../common/rtl/common_cells && git reset --hard HEAD && git apply $(MEEP_SIM_DIR)/../../common/patches/common_cells.patch && cd -
		touch .patched

$(MEEP_SIMULATOR): $(MEEP_SIM_CPP_SRCS) bootrom.hex libdisasm $(MEEP_SIM_DIR)/veri_top.sv .patched
		mkdir -p $(VORTEX_DIR)/build/
		cd $(VORTEX_DIR)/build/ && ../configure --xlen=64
		cd $(VORTEX_DIR)/build/ && $(MAKE) -C hw
		cd $(VORTEX_DIR)/ && $(MAKE) -C third_party
		HPDCACHE_DIR=$(PROJECT_DIR)/rtl/dcache $(VERILATOR) --cc $(MEEP_VERI_FLAGS) $(VERI_OPTI_FLAGS) $(VERISIM_DIR)/veri_top.cpp $(MEEP_SIM_DIR)/veri_top.sv -o $(MEEP_SIMULATOR)
		$(MAKE) -C $(MEEP_SIM_DIR)/build -f V$(TOP_MODULE).mk $(MEEP_SIMULATOR)

clean-meep-simulator:
		rm -rf $(MEEP_SIM_DIR)/build $(MEEP_SIMULATOR) $(VORTEX_DIR)/build

clean:: clean-meep-simulator