/*
 * QEMU RISC-V Quard Star Board
 *
 * Copyright (c) 2021 qiao qiming
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2 or later, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "qemu/osdep.h"
#include "qemu/units.h"
#include "qemu/log.h"
#include "qemu/error-report.h"
#include "qapi/error.h"
#include "hw/boards.h"
#include "hw/loader.h"
#include "hw/sysbus.h"
#include "hw/qdev-properties.h"
#include "hw/char/serial.h"
#include "target/riscv/cpu.h"
#include "hw/riscv/riscv_hart.h"
#include "hw/riscv/quard_star.h"
#include "hw/riscv/boot.h"
#include "hw/riscv/numa.h"
#include "chardev/char.h"
#include "sysemu/arch_init.h"
#include "sysemu/device_tree.h"
#include "sysemu/sysemu.h"

// 引入中断相关 IP
// qemu 7.0.0 QEMU RISC-V ACLINT Support
// https://patchwork.kernel.org/project/qemu-devel/cover/20210724122407.2486558-1-anup.patel@wdc.com/
// remove sifive_clint.c with RISC-V ACLINT
#include "hw/intc/riscv_aclint.h"
#include "hw/intc/riscv_aplic.h"

#include "hw/intc/sifive_plic.h"

// 定义内存相关资料
// CPU 内部的 一片 maskrom, 一片 sram, 一片 ddr 内存
// maskrom 用于 cpu 启动时固定执行其内部的代码
// sram 为早期启动代码是数据存放空间
// ddr 一般在真实板卡上是需要对应的控制器初始化后才能使用, 模拟可以直接配置为可使用的内存
// 该 tutorial 为追求真实, 不在早期启动时使用这片内存空间
static const MemMapEntry virt_memmap[] = {
  //                       base               size
    [QUARD_STAR_MROM]  = {        0x0,        0x8000 },
    [QUARD_STAR_SRAM]  = {     0x8000,        0x8000 },
  // 内核中断 CLINT(Core Local Interrupt) 和 外设中断控制器 PLIC(Platform-Level Interrupt Controller)
  // CLINT 在每个 smp 架构下每个 core 都有自己的私有中断, PLIC 则是 core 共用的 外部中断控制器
  //
  // RISC-V 规范规定，CLINT 的寄存器编址采用内存映射（memory
  // map）方式。
  // 具体寄存器编址采用 base + offset 的格式，且 base 由各个特定
  // platform 自己定义。针对 QEMU-virt，其 CLINT 的设计参考了
  // SFIVE，base 为 0x2000000。
    [QUARD_STAR_CLINT] = {  0x2000000,       0x10000 },
  // RISC-V 规范规定，PLIC 的寄存器编址采用内存映射（memory
  // map）方式。每个寄存器的宽度为 32-bit.
  // 具体寄存器编址采用 base + offset 的格式，且 base 由各个特定
  // platform 自己定义。针对 QEMU-virt，其 PLIC 的设计参考了
  // FU540-C000，base 为 0x0c000000。
    [QUARD_STAR_PLIC]  = {  0xc000000, QUARD_STAR_PLIC_SIZE(QUARD_STAR_CPUS_MAX * 2) },
  // 添加三个串口基地址 目的: 多个权限域中跑不同的系统 因此需要
  // 不同权限的串口打印输出
    [QUARD_STAR_UART0] = { 0x10000000,         0x100 },
    [QUARD_STAR_UART1] = { 0x10001000,         0x100 },
    [QUARD_STAR_UART2] = { 0x10002000,         0x100 },
    [QUARD_STAR_VIRTIO]= { 0x10100000,        0x1000 },
    [QUARD_STAR_FW_CFG]= { 0x10108000,          0x18 },
    [QUARD_STAR_FLASH] = { 0x20000000,     0x4000000 },
    [QUARD_STAR_DRAM]  = { 0x80000000,           0x0 },
};

#define QUARD_STAR_FLASH_SECTOR_SIZE (256 * KiB)

static PFlashCFI01 *quard_star_flash_create(RISCVVirtState *s,
                                       const char *name,
                                       const char *alias_prop_name)
{
    DeviceState *dev = qdev_new(TYPE_PFLASH_CFI01);

    qdev_prop_set_uint64(dev, "sector-length", QUARD_STAR_FLASH_SECTOR_SIZE);
    qdev_prop_set_uint8(dev, "width", 4);
    qdev_prop_set_uint8(dev, "device-width", 2);
    qdev_prop_set_bit(dev, "big-endian", false);
    qdev_prop_set_uint16(dev, "id0", 0x89);
    qdev_prop_set_uint16(dev, "id1", 0x18);
    qdev_prop_set_uint16(dev, "id2", 0x00);
    qdev_prop_set_uint16(dev, "id3", 0x00);
    qdev_prop_set_string(dev, "name", name);

    object_property_add_child(OBJECT(s), name, OBJECT(dev));
    object_property_add_alias(OBJECT(s), alias_prop_name,
                              OBJECT(dev), "drive");

    return PFLASH_CFI01(dev);
}

static void quard_star_flash_map(PFlashCFI01 *flash,
                            hwaddr base, hwaddr size,
                            MemoryRegion *sysmem)
{
    DeviceState *dev = DEVICE(flash);

    assert(QEMU_IS_ALIGNED(size, QUARD_STAR_FLASH_SECTOR_SIZE));
    assert(size / QUARD_STAR_FLASH_SECTOR_SIZE <= UINT32_MAX);
    qdev_prop_set_uint32(dev, "num-blocks", size / QUARD_STAR_FLASH_SECTOR_SIZE);
    sysbus_realize_and_unref(SYS_BUS_DEVICE(dev), &error_fatal);

    memory_region_add_subregion(sysmem, base,
                                sysbus_mmio_get_region(SYS_BUS_DEVICE(dev),
                                                       0));
}

static void quard_star_setup_rom_reset_vec(MachineState *machine, RISCVHartArrayState *harts,
                               hwaddr start_addr,
                               hwaddr rom_base, hwaddr rom_size,
                               uint64_t kernel_entry,
                               uint32_t fdt_load_addr)
{
    int i;
    uint32_t start_addr_hi32 = 0x00000000;

    if (!riscv_is_32bit(harts)) {
        start_addr_hi32 = start_addr >> 32;
    }
    /* reset vector */
    uint32_t reset_vec[10] = {
        0x00000297,                  /* 1:  auipc  t0, %pcrel_hi(fw_dyn) */
        0x02828613,                  /*     addi   a2, t0, %pcrel_lo(1b) */
        0xf1402573,                  /*     csrr   a0, mhartid  */
        0,
        0,
        0x00028067,                  /*     jr     t0 */
        start_addr,                  /* start: .dword */
        start_addr_hi32,
        fdt_load_addr,               /* fdt_laddr: .dword */
        0x00000000,
                                     /* fw_dyn: */
    };
    if (riscv_is_32bit(harts)) {
        reset_vec[3] = 0x0202a583;   /*     lw     a1, 32(t0) */
        reset_vec[4] = 0x0182a283;   /*     lw     t0, 24(t0) */
    } else {
        reset_vec[3] = 0x0202b583;   /*     ld     a1, 32(t0) */
        reset_vec[4] = 0x0182b283;   /*     ld     t0, 24(t0) */
    }

    /* copy in the reset vector in little_endian byte order */
    for (i = 0; i < ARRAY_SIZE(reset_vec); i++) {
        reset_vec[i] = cpu_to_le32(reset_vec[i]);
    }

    rom_add_blob_fixed_as("mrom.reset", reset_vec, sizeof(reset_vec),
                          rom_base, &address_space_memory);
}

static void quard_star_machine_init(MachineState *machine)
{
    const MemMapEntry *memmap = virt_memmap;
    RISCVVirtState *s = RISCV_VIRT_MACHINE(machine);
    MemoryRegion *system_memory = get_system_memory();
    MemoryRegion *main_mem = g_new(MemoryRegion, 1);
    MemoryRegion *sram_mem = g_new(MemoryRegion, 1);
    MemoryRegion *mask_rom = g_new(MemoryRegion, 1);
    int i, j, base_hartid, hart_count;
    char *plic_hart_config, *soc_name;
    size_t plic_hart_config_len;
    DeviceState *mmio_plic=NULL, *virtio_plic=NULL;

    if (QUARD_STAR_SOCKETS_MAX < riscv_socket_count(machine)) {
        error_report("number of sockets/nodes should be less than %d",
            QUARD_STAR_SOCKETS_MAX);
        exit(1);
    }

    for (i = 0; i < riscv_socket_count(machine); i++) {
        if (!riscv_socket_check_hartids(machine, i)) {
            error_report("discontinuous hartids in socket%d", i);
            exit(1);
        }

        base_hartid = riscv_socket_first_hartid(machine, i);
        if (base_hartid < 0) {
            error_report("can't find hartid base for socket%d", i);
            exit(1);
        }

        hart_count = riscv_socket_hart_count(machine, i);
        if (hart_count < 0) {
            error_report("can't find hart count for socket%d", i);
            exit(1);
        }

    // 构造虚拟 cpu, 在 qemu 中各个 cpu 核心为线程模拟 创建子线程
        soc_name = g_strdup_printf("soc%d", i);
        object_initialize_child(OBJECT(machine), soc_name, &s->soc[i],
                                TYPE_RISCV_HART_ARRAY);
        g_free(soc_name);
        object_property_set_str(OBJECT(&s->soc[i]), "cpu-type",
                                machine->cpu_type, &error_abort);
        object_property_set_int(OBJECT(&s->soc[i]), "hartid-base",
                                base_hartid, &error_abort);
        object_property_set_int(OBJECT(&s->soc[i]), "num-harts",
                                hart_count, &error_abort);
        sysbus_realize(SYS_BUS_DEVICE(&s->soc[i]), &error_abort);

        /* Per-socket MTIMER CLINT */
        riscv_aclint_swi_create(memmap[QUARD_STAR_CLINT].base,
                                0, machine->smp.cpus, false);
        riscv_aclint_mtimer_create(memmap[QUARD_STAR_CLINT].base +
                i * memmap[QUARD_STAR_CLINT].size + RISCV_ACLINT_SWI_SIZE,
            RISCV_ACLINT_DEFAULT_MTIMER_SIZE, base_hartid, hart_count,
            RISCV_ACLINT_DEFAULT_MTIMECMP, RISCV_ACLINT_DEFAULT_MTIME,
            RISCV_ACLINT_DEFAULT_TIMEBASE_FREQ, true);

        /* Per-socket plic interrupt controller */
        plic_hart_config_len =
            (strlen(QUARD_STAR_PLIC_HART_CONFIG) + 1) * hart_count;
        plic_hart_config = g_malloc0(plic_hart_config_len);
        for (j = 0; j < hart_count; j++) {
            if (j != 0) {
                strncat(plic_hart_config, ",", plic_hart_config_len);
            }
            strncat(plic_hart_config, QUARD_STAR_PLIC_HART_CONFIG,
                plic_hart_config_len);
            plic_hart_config_len -= (strlen(QUARD_STAR_PLIC_HART_CONFIG) + 1);
        }

        s->plic[i] = sifive_plic_create(
            memmap[QUARD_STAR_PLIC].base + i * memmap[QUARD_STAR_PLIC].size,
            plic_hart_config, hart_count, base_hartid,
            QUARD_STAR_PLIC_NUM_SOURCES,
            ((1U << QUARD_STAR_PLIC_NUM_PRIO_BITS) - 1),
            QUARD_STAR_PLIC_PRIORITY_BASE,
            QUARD_STAR_PLIC_PENDING_BASE,
            QUARD_STAR_PLIC_ENABLE_BASE,
            QUARD_STAR_PLIC_ENABLE_STRIDE,
            QUARD_STAR_PLIC_CONTEXT_BASE,
            QUARD_STAR_PLIC_CONTEXT_STRIDE,
            memmap[QUARD_STAR_PLIC].size);

        g_free(plic_hart_config);

        if (i == 0) {
            mmio_plic = s->plic[i];
            virtio_plic = s->plic[i];
        }
        if (i == 1) {
            virtio_plic = s->plic[i];
        }
    }

  // 初始化 maskrom, sram, ddr
    memory_region_init_ram(main_mem, NULL, "riscv_quard_star_board.dram",
                           machine->ram_size, &error_fatal);
    memory_region_add_subregion(system_memory, memmap[QUARD_STAR_DRAM].base,
        main_mem);

    memory_region_init_ram(sram_mem, NULL, "riscv_quard_star_board.sram",
                           memmap[QUARD_STAR_SRAM].size, &error_fatal);
    memory_region_add_subregion(system_memory, memmap[QUARD_STAR_SRAM].base,
        sram_mem);

    memory_region_init_rom(mask_rom, NULL, "riscv_quard_star_board.mrom",
                           memmap[QUARD_STAR_MROM].size, &error_fatal);
    memory_region_add_subregion(system_memory, memmap[QUARD_STAR_MROM].base,
                                mask_rom);

    // 加载 maskrom 的固件到 mrom 区域, 使用汇编代码编写编译器生成的二进制指令数据
    // 将 cpu hart id 值加载到 a0 寄存器, 设备树文件基地址加载到 a1 寄存器, 然后跳转
    // 到下级代码的运行地址 (这里定义为 0x0地址, 现在如此形成循环)
    // 按照 riscv abi 规范 a0 寄存器为0号参数, a1 为1号参数, 本质为函数调用
    // 将 cpu id 和下级设备树基地址传入下级代码
    quard_star_setup_rom_reset_vec(machine, &s->soc[0], virt_memmap[QUARD_STAR_FLASH].base,
                              virt_memmap[QUARD_STAR_MROM].base,
                              virt_memmap[QUARD_STAR_MROM].size,
                              0x0, 0x0);

    // call serial_mm_init 创建串口实例, 该串口仿真 ns16550a 定义
    // 串口需要使用中断
    serial_mm_init(system_memory, memmap[QUARD_STAR_UART0].base,
                   0, qdev_get_gpio_in(DEVICE(mmio_plic), QUARD_STAR_UART0_IRQ), 399193,
                   serial_hd(0), DEVICE_LITTLE_ENDIAN);
    serial_mm_init(system_memory, memmap[QUARD_STAR_UART1].base,
                   0, qdev_get_gpio_in(DEVICE(mmio_plic), QUARD_STAR_UART1_IRQ), 399193,
                   serial_hd(1), DEVICE_LITTLE_ENDIAN);
    serial_mm_init(system_memory, memmap[QUARD_STAR_UART2].base,
                   0, qdev_get_gpio_in(DEVICE(mmio_plic), QUARD_STAR_UART2_IRQ), 399193,
                   serial_hd(2), DEVICE_LITTLE_ENDIAN);

      for (i = 0; i < QUARD_STAR_COUNT; i++) {
        sysbus_create_simple("virtio-mmio",
            memmap[QUARD_STAR_VIRTIO].base + i * memmap[QUARD_STAR_VIRTIO].size,
            qdev_get_gpio_in(DEVICE(virtio_plic), QUARD_STAR_IRQ + i));
    }

    s->fw_cfg = fw_cfg_init_mem_wide(memmap[QUARD_STAR_FW_CFG].base + 8, 
                                     memmap[QUARD_STAR_FW_CFG].base,  8, 
                                     memmap[QUARD_STAR_FW_CFG].base + 16,
                                     &address_space_memory);
    fw_cfg_add_i16(s->fw_cfg, FW_CFG_NB_CPUS, (uint16_t)machine->smp.cpus);
    rom_set_fw(s->fw_cfg);

    s->flash = quard_star_flash_create(s, "quard-star.flash0", "pflash0");
    pflash_cfi01_legacy_drive(s->flash, drive_get(IF_PFLASH, 0, 0));
    quard_star_flash_map(s->flash, virt_memmap[QUARD_STAR_FLASH].base,
                         virt_memmap[QUARD_STAR_FLASH].size, system_memory);

}

static void quard_star_machine_instance_init(Object *obj)
{
}

static void quard_star_machine_class_init(ObjectClass *oc, void *data)
{
    MachineClass *mc = MACHINE_CLASS(oc);

  // 定义机器的特定属性, 例如 CPU 型号, RAM 大小, 以及最重要的实例初始化方法 quard_star_machine_init()
    mc->desc = "RISC-V Quard Star board";
  // 实例初始化方法
    mc->init = quard_star_machine_init;
  // 最大支持 smp(对称多处理器) 核心数量
    mc->max_cpus = QUARD_STAR_CPUS_MAX;
    mc->default_cpu_type = TYPE_RISCV_CPU_BASE;
    mc->pci_allow_0_address = true;
    mc->possible_cpu_arch_ids = riscv_numa_possible_cpu_arch_ids;
    mc->cpu_index_to_instance_props = riscv_numa_cpu_index_to_props;
    mc->get_default_cpu_node_id = riscv_numa_get_default_cpu_node_id;
    mc->numa_mem_supported = true;
}

/* 注册板卡到系统内, 并定义名称 */
/* 以下所有可以使用预定义的宏生成 */
/* DEFINE_MACHINE("quard-star") */
static const TypeInfo quard_star_machine_typeinfo = {
    .name       = MACHINE_TYPE_NAME("quard-star"),
    .parent     = TYPE_MACHINE,
  // class_init 函数会在所有父类的 init 方法调用完成后调用
  // 类的初始化在所有对象实例之前
    .class_init = quard_star_machine_class_init,
    .instance_init = quard_star_machine_instance_init,
    .instance_size = sizeof(RISCVVirtState),
};

static void quard_star_machine_init_register_types(void)
{
    type_register_static(&quard_star_machine_typeinfo);
}

type_init(quard_star_machine_init_register_types)
