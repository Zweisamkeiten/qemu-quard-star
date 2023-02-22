#!/bin/bash

SHELL_FOLDER=$(cd "$(dirname "$0")" || exit; pwd)

# nographic C-A x for exit & C-A c for monitor
gdb -q --args "$SHELL_FOLDER"/output/qemu/bin/qemu-system-riscv64 \
  -M quard-star                                     \
  -m 1G                                             \
  -smp 1                                            \
  -nographic --parallel none

