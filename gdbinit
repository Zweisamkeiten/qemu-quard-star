display/z $x5
display/z $x6
display/z $x7

set disassemble-next-line on
lay src
b sbi_init
b fdt_ipi_init
b mswi_ipi_clear
target remote : 1234
c
s
