#!/bin/bash

riscv64-linux-gnu-gdb opensbi/build/platform/quard_star/firmware/fw_jump.elf -q -x gdbinit
