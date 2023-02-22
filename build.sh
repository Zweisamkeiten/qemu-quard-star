#!/bin/bash

BUILD_FOLDER=$(cd "$(dirname "$0")" || exit;pwd)

if [[ ! -d "$BUILD_FOLDER/output/qemu" ]]; then
  ./configure --prefix="$BUILD_FOLDER"/output/qemu  --target-list=riscv64-softmmu --enable-gtk  --enable-virtfs --disable-gio --enable-debug
fi

make -j"$(nproc)"
make install
