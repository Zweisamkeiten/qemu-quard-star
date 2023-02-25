#!/bin/bash

SCRIPT_PATH=$(cd "$(dirname "$0")" || exit;pwd)
QEMU_PATH=$(cd ../.. || exit; pwd)

cd "$QEMU_PATH" || exit
riscv64-linux-gnu-gdb ./roms/opensbi/build/platform/quard_star/firmware/fw_jump.elf -q -x "$SCRIPT_PATH"/gdbinit
