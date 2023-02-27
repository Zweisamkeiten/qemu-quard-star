#!/bin/bash

SCRIPT_PATH=$(cd "$(dirname "$0")" || exit;pwd)
cd "$SCRIPT_PATH" || exit

riscv64-linux-gnu-gdb ../output/lowlevelboot/lowlevel_fw.elf -q -x "$SCRIPT_PATH"/lowlevelboot_gdbinit
