#!/bin/bash

BIN_PATH=$(cd "$(dirname "$0")"/../output/qemu/bin/ || exit; pwd)
QEMU_PATH=$(cd ../.. || exit; pwd)

cd "$QEMU_PATH" || exit
# nographic C-A x for exit & C-A c for monitor
"$BIN_PATH"/qemu-system-riscv64                     \
  -M virt                                           \
  -m 1G                                             \
  -smp 4                                            \
  -bios ./roms/opensbi/build/platform/generic/firmware/fw_payload.bin \
  -nographic --parallel none

