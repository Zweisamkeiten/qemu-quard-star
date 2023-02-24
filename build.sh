#!/bin/bash

MAKEJOBS=$(nproc)
CROSS_PREFIX=riscv64-linux-gnu
BUILD_FOLDER=$(cd "$(dirname "$0")" || exit;pwd)

if [[ ! -d "$BUILD_FOLDER/output/qemu" ]]; then
  ./configure --prefix="$BUILD_FOLDER"/output/qemu  --target-list=riscv64-softmmu --enable-gtk  --enable-virtfs --disable-gio --enable-debug
fi

make -j"$MAKEJOBS"
make install

CROSS_PREFIX=/usr/bin/riscv64-linux-gnu
if [ ! -d "$BUILD_FOLDER/output/lowlevelboot" ]; then  
  mkdir -p "$BUILD_FOLDER"/output/lowlevelboot
fi  

cd lowlevelboot || exit

$CROSS_PREFIX-gcc -x assembler-with-cpp -march=rv64g -c startup.S -o "$BUILD_FOLDER"/output/lowlevelboot/startup.o
$CROSS_PREFIX-ld -T./boot.ld --gc-sections -Map="$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.map "$BUILD_FOLDER"/output/lowlevelboot/startup.o -o "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.elf
$CROSS_PREFIX-objcopy -O binary -S "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.elf "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.bin
$CROSS_PREFIX-objdump --source --demangle --disassemble --reloc --wide "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.elf > "$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.lst

cd "$BUILD_FOLDER"/output/lowlevelboot || exit

# 编译 OpenSBI
if [ ! -d "$BUILD_FOLDER/output/opensbi" ]; then
  mkdir -p "$BUILD_FOLDER/output/opensbi"
fi

cd "$BUILD_FOLDER"/opensbi || exit
make -j"$MAKEJOBS" CROSS_COMPILE="$CROSS_PREFIX-" PLATFORM=quard_star
cp -r "$BUILD_FOLDER/opensbi/build/platform/quard_star/firmware"/*.bin "$BUILD_FOLDER/output/opensbi/"

# 生成 sbi.dtb
cd "$BUILD_FOLDER"/dts || exit
if [ -a "$BUILD_FOLDER"/output/opensbi/quard_star_sbi.dtb ]; then
  rm "$BUILD_FOLDER/output/opensbi/quard_star_sbi.dtb"
fi
dtc -I dts -O dtb -o "$BUILD_FOLDER/output/opensbi/quard_star_sbi.dtb" quard_star_sbi.dts

# 合成 firmware 固件
if [ ! -d "$BUILD_FOLDER/output/firmware" ]; then
  mkdir -p "$BUILD_FOLDER/output/firmware"
fi
cd "$BUILD_FOLDER"/output/firmware || exit

rm -rf fw.bin
dd of=fw.bin bs=1k count=64k if=/dev/zero
dd of=fw.bin bs=1k conv=notrunc seek=0 if="$BUILD_FOLDER"/output/lowlevelboot/lowlevel_fw.bin
dd of=fw.bin bs=1k conv=notrunc seek=512 if="$BUILD_FOLDER"/output/opensbi/quard_star_sbi.dtb
dd of=fw.bin bs=1k conv=notrunc seek=2k if="$BUILD_FOLDER"/output/opensbi/fw_jump.bin

cd "$BUILD_FOLDER" || exit
