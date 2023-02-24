#!/bin/bash

SHELL_FOLDER=$(cd "$(dirname "$0")" || exit; pwd)

# nographic C-A x for exit & C-A c for monitor
"$SHELL_FOLDER"/output/qemu/bin/qemu-system-riscv64 \
  -M virt                                           \
  -m 1G                                             \
  -smp 4                                            \
  -bios ./opensbi/build/platform/generic/firmware/fw_payload.bin \
  -nographic --parallel none -s -S

