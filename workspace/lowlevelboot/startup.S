.macro loop,cunt                        # 定义一个简单loop宏cunt是loop参数
  li		t1,	0xffff                      # 加载立即数到t1
  li		t2,	\cunt                       # 加载立即数到t2
1:
	nop                                   # 空指令nop
	addi  t1, t1, -1                      # t1--
	bne		t1, x0, 1b                      # 判断t1是否等于0，不是就跳转前以符号1处（b是向前的意思）
  li	  t1,	0xffff                      # 加载立即数到t1
	addi  t2, t2, -1                      # t2--
	bne		t2, x0, 1b                      # 判断t2是否等于0，不是就跳转前一个符号1处（b是向前的意思）
.endm                                   # 宏结束

 # 定义一个简单load_data宏（这里我们按word拷贝数据，实际上64位可以按double word来拷贝，效率更高）*/
 # _src_start为源地址，_dst_start为目标地址，_dst_end为目标结束地址
.macro load_data,_src_start,_dst_start,_dst_end
  bgeu	\_dst_start, \_dst_end, 2f      # 判断目标结束地址大于起始地址，即是否合法
1:
	lw    t0, (\_src_start)               # 加载源地址内数据到t0
	sw    t0, (\_dst_start)               # 写入t0到目标地址内
	addi  \_src_start, \_src_start, 4     # 源地址+4
	addi  \_dst_start, \_dst_start, 4     # 目标地址+4
	bltu  \_dst_start, \_dst_end, 1b      # 判断是否已到达结束地址，未到达则循环到上前一个符号1
2:
.endm

  .section .sram
	.globl  _pen
	.type	_pen,%object
_pen:
	.word   2

	.section .text
	.globl _start
	.type _start,@function

_start:
  csrr  a0, mhartid
	beq		a0, zero, _no_wait              # 判断是否为 hart0, 由 hart0 加载引导固件, 其余 hart 进入 loop 状态

_loop:
	loop	0x1000
	la		t0, _pen
	lw		t0, 0(t0)
	beq		t0, zero, _run                  # 判断 _pen 标志位是否允许跳出 _loop
	j     _loop

_no_wait:
	la		t0, _pen
	la		t1, 1
	sw		t1, 0(t0)                       # hart0 进入加载状态 将其余 hart 标志位置 1 锁住在 loop 状态

	# load opensbi_fw.bin 
	# [0x20200000:0x20400000] --> [0xbff80000:0xc0000000]
  li		a0,	0x202
	slli	a0,	a0, 20                      # a0 = 0x20200000
  li		a1,	0xbff
	slli	a1,	a1, 20                      # a1 = 0xbff00000
  li		a2,	0x800
	slli	a2,	a2, 8                       # a2 = 0x800000
  add   a1, a1, a2                      # a1 = 0xbff80000
  add   a2, a1, a2                      # a2 = 0xc0000000
	load_data a0,a1,a2                    # 拷贝 0x20200000 到 0xbff80000 */

	# load qemu_sbi.dtb
	# [0x20080000:0x20100000] --> [0xbff00000:0xbff80000]
  li		a0,	0x2008
	slli	a0,	a0, 16                      # a0 = 0x20080000
  li		a1,	0xbff
	slli	a1,	a1, 20                      # a1 = 0xbff00000
  li		a2,	0x800
	slli	a2,	a2, 8                       # a2 = 0x80000
  add   a2, a1, a2                      # a2 = 0xbff80000
	load_data a0,a1,a2                    # 拷贝 0x20080000 到 0xbff00000 */

  # load trusted_fw.bin
	# [0x20400000:0x20800000] --> [0xbf800000:0xbfc00000]
  li		a0,	0x204
	slli	a0,	a0, 20                      # a0 = 0x20400000
  li		a1,	0xbf8
	slli	a1,	a1, 20                      # a1 = 0xbf800000
  li		a2,	0xbfc
	slli	a2,	a2, 20                      # a2 = 0xbfc00000
	load_data a0,a1,a2

  # load qemu_uboot.dtb
  # [0x20100000:0x20180000] --> [0xb0000000:0xb0080000]
  li		a0,	0x201
	slli	a0,	a0, 20                      # a0 = 0x20100000
	li		a1,	0xb00
	slli	a1,	a1, 20                      # a1 = 0xb0000000
  li		a2,	0x800
	slli	a2,	a2, 8                       # a2 = 0x80000
  add   a2, a1, a2                      # a2 = 0xb0080000
	load_data a0,a1,a2

	# load u-boot.bin
	# [0x20800000:0x20C00000] --> [0xb0200000:0xb0600000]
  li		a0,	0x208
	slli	a0,	a0, 20                      # a0 = 0x20800000
  li		a1,	0xb02
	slli	a1,	a1, 20                      # a1 = 0xb0200000
  li		a2,	0xb06
	slli	a2,	a2, 20                      # a2 = 0xb0600000
	load_data a0,a1,a2

_run:
  csrr  a0, mhartid
  li		a1,	0xbff
	slli	a1,	a1, 20                      # a1 = 0xbff00000
	li		t0,	0x800
	slli	t0,	t0, 8                       # t0 = 0x800000
	add 	t0,	a1, t0                      # t0 = 0xbff80000
  la		t1, _pen
	sw		zero, 0(t1)                     # hart0 加载 完成, 为其余 hart 解锁
  jr    t0                              # 此时a0中为core的hart id，a1中设备树dtb的所在的起始地址，t0为opensbi程序所在的ddr地址，jr跳转进入opensbi程序

.end
