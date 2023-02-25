#!/bin/bash

MAKEJOBS=$(nproc)
CROSS_PREFIX=/usr/bin/riscv64-linux-gnu
SCRIPT_PATH=$(cd "$(dirname "$0")" || exit;pwd)
WORKSPACE=$(cd .. || exit; pwd)
OUTPUTPATH="$WORKSPACE"/output
QEMU_PATH=$(cd ../.. || exit; pwd)
OPENSBI_PATH="$QEMU_PATH"/roms/opensbi

cd "$QEMU_PATH" || exit
if [[ ! -d "$OUTPUTPATH/qemu" ]]; then
  ./configure --prefix="$OUTPUTPATH/qemu" --target-list=riscv64-softmmu --enable-gtk --enable-virtfs --disable-gio --enable-debug
fi

make -j"$MAKEJOBS"
make install

cd "$WORKSPACE" || exit

# 编译 OpenSBI
if [ ! -d "$OUTPUTPATH/opensbi" ]; then
  mkdir -p "$OUTPUTPATH/opensbi"
fi

cd "$OPENSBI_PATH" || exit
make -j"$MAKEJOBS" CROSS_COMPILE="$CROSS_PREFIX-" PLATFORM=generic

cd "$SCRIPT_PATH" || exit
