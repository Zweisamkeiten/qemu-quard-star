#!/bin/bash

BIN_PATH=$(cd "$(dirname "$0")"/../output/qemu/bin/ || exit; pwd)

# nographic C-A x for exit & C-A c for monitor
gdb -q --args "$BIN_PATH"/qemu-system-riscv64       \
  -M quard-star                                     \
  -m 1G                                             \
  -smp 1                                            \
  -nographic --parallel none

