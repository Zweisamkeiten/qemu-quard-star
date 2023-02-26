#!/bin/bash

BIN_PATH=$(cd "$(dirname "$0")"/../output/qemu/bin/ || exit; pwd)
WORKSPACE=$(cd .. || exit; pwd)
OUTPUTPATH="$WORKSPACE"/output

DEFAULT_VC="1280x720"

# nographic C-A x for exit & C-A c for monitor
"$BIN_PATH"/qemu-system-riscv64                     \
  -M quard-star                                     \
  -m 1G                                             \
  -smp 8                                            \
  -drive if=pflash,bus=0,unit=0,format=raw,file="$OUTPUTPATH"/firmware/fw.bin \
  --parallel none                                   \
  --serial vc:$DEFAULT_VC --serial vc:$DEFAULT_VC --serial vc:$DEFAULT_VC --monitor vc:$DEFAULT_VC \
  --parallel none #-s -S

