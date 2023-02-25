display/z $x5
display/z $x6
display/z $x7

set disassemble-next-line on
lay src
b sbi_init
b sbi_domain_finalize
target remote : 1234
c
s
