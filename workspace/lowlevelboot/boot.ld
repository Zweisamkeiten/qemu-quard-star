OUTPUT_ARCH( "riscv" )

ENTRY( _start )

MEMORY
{
	flash (rxai!w) : ORIGIN = 0x20000000, LENGTH = 512k
  sram  (rxaiw)  : ORIGIN = 0x00008000, LENGTH = 32k
}

SECTIONS
{
  .text :
  {
		PROVIDE(_text_start = .);
    KEEP(*(.text))
		PROVIDE(_text_end = .);
  } >flash

  
  .sram :
  {
    _pen = .;
    KEEP(*(.sram))
  } >sram
}
