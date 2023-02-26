#!/bin/bash

SCRIPT_PATH=$(cd "$(dirname "$0")" || exit;pwd)
QEMU_PATH=$(cd ../.. || exit; pwd)

cd "$QEMU_PATH" || exit
riscv64-linux-gnu-gdb ./roms/u-boot/u-boot -q -x "$SCRIPT_PATH"/uboot_gdbinit
