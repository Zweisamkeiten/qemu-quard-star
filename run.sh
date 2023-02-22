#!/bin/bash

SHELL_FOLDER=$(cd "$(dirname "$0")" || exit; pwd)

"$SHELL_FOLDER"/output/qemu/bin/qemu-system-riscv64 \
  -M quard-star                                     \
  -m 1G                                             \
  -smp 4                                            \
  -nographic --parallel none

