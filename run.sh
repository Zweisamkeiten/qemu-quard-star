#!/bin/bash

SHELL_FOLDER=$(cd "$(dirname "$0")" || exit; pwd)

# nographic C-A x for exit & C-A c for monitor
"$SHELL_FOLDER"/output/qemu/bin/qemu-system-riscv64 \
  -M quard-star                                     \
  -m 1G                                             \
  -smp 2                                            \
  -drive if=pflash,bus=0,unit=0,format=raw,file="$SHELL_FOLDER"/output/firmware/fw.bin \
  -nographic --parallel none

