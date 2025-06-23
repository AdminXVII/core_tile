FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    autoconf \
    automake \
    bison \
    flex \
    libfl-dev \
    texinfo \
    device-tree-compiler \
    python3 \
    perl \
    ccache \
    g++ \
    libtool \
    pkg-config \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    libisl-dev \
    zlib1g-dev \
	gawk \ 
 && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/verilator/verilator.git /tmp/verilator && \
    cd /tmp/verilator && \
    git checkout v5.004 && \
    autoconf && \
    ./configure && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/verilator
RUN mkdir /rtl
RUN git clone --recursive https://github.com/bsc-loca/core_tile /rtl

RUN git clone --recursive https://github.com/riscv/riscv-gnu-toolchain.git /opt/riscv-gnu-toolchain

WORKDIR /opt/riscv-gnu-toolchain
RUN ./configure --prefix=/opt/riscv
RUN make linux; exit 0
RUN rm -rf /opt/riscv-gnu-toolchain
WORKDIR /
# RUN cd /opt/riscv-gnu-toolchain && \    
#         ./configure --prefix=/opt/riscv && \
#         make linux && \
# 	rm -rf /opt/riscv-gnu-toolchain

RUN cp /opt/riscv/bin/riscv64-unknown-linux-gnu-gcc /opt/riscv/bin/riscv64-unknown-elf-gcc

ENV PATH="/opt/riscv/bin:${PATH}"

WORKDIR /rtl
