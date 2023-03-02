load virtio 0:1 0x84000000 /Image
load virtio 0:1 0x8c000000 /quard_star.dtb
:: 从内存中加载
:: 需要设置 fdt_addr
booti 0x84000000 - 0x8c000000
:: 从 flash 中加载
:: booti 0x84000000 - 0xb0000000
