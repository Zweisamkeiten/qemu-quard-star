#!/bin/bash

BUILD_FOLDER=$(cd "$(dirname "$0")" || exit;pwd)

if [[ ! -d "$BUILD_FOLDER/output/qemu" ]]; then
  ./configure --prefix="$BUILD_FOLDER"/output/qemu  --target-list=riscv64-softmmu --enable-gtk  --enable-virtfs --disable-gio --enable-debug
fi

make -j"$(nproc)"
make install

CROSS_PREFIX=/usr/bin/riscv64-linux-gnu
if [ ! -d "$BUILD_FOLDER/output/lowlevelboot" ]; then  
  mkdir -p "$BUILD_FOLDER"/output/lowlevelboot
fi  

cd lowlevelboot || exit

$CROSS_PREFIX-gcc -x assembler-with-cpp -c startup.s -o "$BUILD_FOLDER"/output/lowlevelboot/startup.o
$CROSS_PREFIX-gcc -nostartfiles -T./boot.lds -Wl,-Map="$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.map -Wl,--gc-sections "$BUILD_FOLDER"/output/lowlevelboot/startup.o -o "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.elf
$CROSS_PREFIX-objcopy -O binary -S "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.elf "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.bin
$CROSS_PREFIX-objdump --source --demangle --disassemble --reloc --wide "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.elf > "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.lst

cd "$BUILD_FOLDER"/output/lowlevelboot || exit

rm -rf fw.bin
dd of=fw.bin bs=1k count=64k if=/dev/zero
dd of=fw.bin bs=1k conv=notrunc seek=0 if=lowlevel_fw.bin

cd "$BUILD_FOLDER" || exit
