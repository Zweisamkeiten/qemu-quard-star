#!/bin/bash

MAKEJOBS=$(nproc)
CROSS_PREFIX=riscv64-linux-gnu
BUILD_FOLDER=$(cd "$(dirname "$0")" || exit;pwd)

if [[ ! -d "$BUILD_FOLDER/output/qemu" ]]; then
  ./configure --prefix="$BUILD_FOLDER"/output/qemu  --target-list=riscv64-softmmu --enable-gtk  --enable-virtfs --disable-gio --enable-debug
fi

make -j"$MAKEJOBS"
make install

# 编译 OpenSBI
if [ ! -d "$BUILD_FOLDER/output/opensbi" ]; then
  mkdir -p "$BUILD_FOLDER/output/opensbi"
fi

cd "$BUILD_FOLDER"/opensbi || exit
make -j"$MAKEJOBS" CROSS_COMPILE="$CROSS_PREFIX-" PLATFORM=generic

cd "$BUILD_FOLDER" || exit
