OUTPUT_ARCH( "riscv" )

ENTRY( _start )

MEMORY
{
	ddr (rxai!w) : ORIGIN = 0xbf800000, LENGTH = 7M
}

SECTIONS
{
  .text :
  {
    KEEP(*(.text))
  } >ddr
}
