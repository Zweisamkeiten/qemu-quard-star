#!/bin/bash

MAKEJOBS=$(nproc)
CROSS_PREFIX=/usr/bin/riscv64-linux-gnu
SCRIPT_PATH=$(cd "$(dirname "$0")" || exit;pwd)
WORKSPACE=$(cd .. || exit; pwd)
OUTPUTPATH="$WORKSPACE"/output
QEMU_PATH=$(cd ../.. || exit; pwd)
OPENSBI_PATH="$QEMU_PATH"/roms/opensbi
UBOOT_PATH="$QEMU_PATH"/roms/u-boot
DTS_PATH="$WORKSPACE"/dts
TRUSTED_DOMAIN_PATH="$WORKSPACE"/trusted_domain

blue=$(tput setaf 2)
normal=$(tput sgr0)

printf "%s\n" "${blue}BUILD QEMU${normal}"
cd "$QEMU_PATH" || exit
if [[ ! -d "$OUTPUTPATH/qemu" ]]; then
  ./configure --prefix="$OUTPUTPATH/qemu" --target-list=riscv64-softmmu --enable-gtk --enable-virtfs --disable-gio --enable-debug
fi

make -j"$MAKEJOBS"
make install

cd "$WORKSPACE" || exit

printf "%s\n" "${blue}BUILD lowlevelboot${normal}"
if [ ! -d "$OUTPUTPATH/lowlevelboot" ]; then
  mkdir -p "$OUTPUTPATH/lowlevelboot"
fi

cd "$WORKSPACE/lowlevelboot" || exit

$CROSS_PREFIX-gcc -x assembler-with-cpp -c startup.S -o "$OUTPUTPATH"/lowlevelboot/startup.o
$CROSS_PREFIX-ld -T./boot.ld --gc-sections -Map="$OUTPUTPATH"/lowlevelboot/lowlevel_fw.map "$OUTPUTPATH"/lowlevelboot/startup.o -o "$OUTPUTPATH"/lowlevelboot/lowlevel_fw.elf
$CROSS_PREFIX-objcopy -O binary -S "$OUTPUTPATH"/lowlevelboot/lowlevel_fw.elf "$OUTPUTPATH"/lowlevelboot/lowlevel_fw.bin
$CROSS_PREFIX-objdump --source --demangle --disassemble --reloc --wide "$OUTPUTPATH"/lowlevelboot/lowlevel_fw.elf > "$OUTPUTPATH"/lowlevelboot/lowlevel_fw.lst

# 编译 OpenSBI
printf "%s\n" "${blue}BUILD OpenSBI${normal}"
if [ ! -d "$OUTPUTPATH/opensbi" ]; then
  mkdir -p "$OUTPUTPATH/opensbi"
fi

cd "$OPENSBI_PATH" || exit
make -j"$MAKEJOBS" CROSS_COMPILE="$CROSS_PREFIX-" PLATFORM=quard_star
cp -r "$OPENSBI_PATH/build/platform/quard_star/firmware"/fw_jump.bin "$OUTPUTPATH/opensbi/fw_jump.bin"
cp -r "$OPENSBI_PATH/build/platform/quard_star/firmware"/fw_jump.elf "$OUTPUTPATH/opensbi/fw_jump.elf"
$CROSS_PREFIX-objdump --source --demangle --disassemble --reloc --wide "$OUTPUTPATH"/opensbi/fw_jump.elf > "$OUTPUTPATH"/opensbi/fw_jump.lst

# 生成 sbi.dtb
printf "%s\n" "${blue}BUILD sbi_dtb${normal}"
cd "$DTS_PATH" || exit
if [ -a "$OUTPUTPATH"/opensbi/quard_star_sbi.dtb ]; then
  rm "$OUTPUTPATH"/opensbi/quard_star_sbi.dtb
fi
dtc -I dts -O dtb -o "$OUTPUTPATH"/opensbi/quard_star_sbi.dtb quard_star_sbi.dts

# 编译 trusted_domain
printf "%s\n" "${blue}BUILD trusted_domain${normal}"
if [ ! -d "$OUTPUTPATH/trusted_domain" ]; then
  mkdir "$OUTPUTPATH/trusted_domain"
fi

cd "$TRUSTED_DOMAIN_PATH" || exit
$CROSS_PREFIX-gcc -x assembler-with-cpp -c startup.S -o "$OUTPUTPATH"/trusted_domain/startup.o
$CROSS_PREFIX-ld -T./link.ld --gc-sections -Map="$OUTPUTPATH"/trusted_domain/trusted_fw.map "$OUTPUTPATH"/trusted_domain/startup.o -o "$OUTPUTPATH"/trusted_domain/trusted_fw.elf
$CROSS_PREFIX-objcopy -O binary -S "$OUTPUTPATH"/trusted_domain/trusted_fw.elf "$OUTPUTPATH"/trusted_domain/trusted_fw.bin
$CROSS_PREFIX-objdump --source --demangle --disassemble --reloc --wide "$OUTPUTPATH"/trusted_domain/trusted_fw.elf > "$OUTPUTPATH"/trusted_domain/trusted_fw.lst

# 编译 u-boot
printf "%s\n" "${blue}BUILD uboot${normal}"
if [ ! -d "$OUTPUTPATH"/uboot ]; then
  mkdir "$OUTPUTPATH"/uboot
fi

cd "$UBOOT_PATH" || exit

make CROSS_COMPILE="$CROSS_PREFIX-" qemu-quard-star_defconfig
make CROSS_COMPILE="$CROSS_PREFIX-" -j"$MAKEJOBS"
cp "$UBOOT_PATH"/u-boot "$OUTPUTPATH"/uboot/u-boot.elf
cp "$UBOOT_PATH"/u-boot.map "$OUTPUTPATH"/uboot/u-boot.map
cp "$UBOOT_PATH"/u-boot.bin "$OUTPUTPATH"/uboot/u-boot.bin
$CROSS_PREFIX-objdump --source --demangle --disassemble --reloc --wide "$OUTPUTPATH"/uboot/u-boot.elf > "$OUTPUTPATH"/uboot/u-boot.lst

# 生成 uboot.dtb
printf "%s\n" "${blue}BUILD uboot-dtb${normal}"
cd "$DTS_PATH" || exit
if [ -a "$OUTPUTPATH"/uboot/quard_star_uboot.dtb ]; then
  rm "$OUTPUTPATH"/uboot/quard_star_uboot.dtb
fi
dtc -I dts -O dtb -o "$OUTPUTPATH"/uboot/quard_star_uboot.dtb quard_star_uboot.dts

# 合成 firmware 固件
printf "%s\n" "${blue}BUILD firmware${normal}"
if [ ! -d "$OUTPUTPATH/firmware" ]; then
  mkdir -p "$OUTPUTPATH/firmware"
fi
cd "$OUTPUTPATH"/firmware || exit

rm -rf fw.bin
dd of=fw.bin bs=1k count=64k if=/dev/zero
dd of=fw.bin bs=1k conv=notrunc seek=0 if="$OUTPUTPATH"/lowlevelboot/lowlevel_fw.bin
dd of=fw.bin bs=1k conv=notrunc seek=512 if="$OUTPUTPATH"/opensbi/quard_star_sbi.dtb
dd of=fw.bin bs=1k conv=notrunc seek=1K if="$OUTPUTPATH"/uboot/quard_star_uboot.dtb
dd of=fw.bin bs=1k conv=notrunc seek=2k if="$OUTPUTPATH"/opensbi/fw_jump.bin
dd of=fw.bin bs=1k conv=notrunc seek=4k if="$OUTPUTPATH"/trusted_domain/trusted_fw.bin
dd of=fw.bin bs=1k conv=notrunc seek=8k if="$OUTPUTPATH"/uboot/u-boot.bin

cd "$SCRIPT_PATH" || exit

