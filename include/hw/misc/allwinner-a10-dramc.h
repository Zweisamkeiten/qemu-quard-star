/*
 * Allwinner A10 DRAM Controller emulation
 *
 * Copyright (C) 2022 Strahinja Jankovic <strahinja.p.jankovic@gmail.com>
 *
 *  This file is derived from Allwinner H3 DRAMC,
 *  by Niek Linnenbank.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef HW_MISC_ALLWINNER_A10_DRAMC_H
#define HW_MISC_ALLWINNER_A10_DRAMC_H

#include "qom/object.h"
#include "hw/sysbus.h"
#include "hw/register.h"

/**
 * @name Constants
 * @{
 */

/** Size of register I/O address space used by DRAMC device */
#define AW_A10_DRAMC_IOSIZE        (0x1000)

/** Total number of known registers */
#define AW_A10_DRAMC_REGS_NUM      (AW_A10_DRAMC_IOSIZE / sizeof(uint32_t))

/** @} */

/**
 * @name Object model
 * @{
 */

#define TYPE_AW_A10_DRAMC    "allwinner-a10-dramc"
OBJECT_DECLARE_SIMPLE_TYPE(AwA10DramControllerState, AW_A10_DRAMC)

/** @} */

/**
 * Allwinner A10 DRAMC object instance state.
 */
struct AwA10DramControllerState {
    /*< private >*/
    SysBusDevice parent_obj;
    /*< public >*/

    /** Maps I/O registers in physical memory */
    MemoryRegion iomem;

    /** Array of hardware registers */
    uint32_t regs[AW_A10_DRAMC_REGS_NUM];
};

#endif /* HW_MISC_ALLWINNER_A10_DRAMC_H */
