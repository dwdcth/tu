
jg.o:     file format elf64-x86-64


Disassembly of section .text:

0000000000000000 <main>:
   0:	83 f8 00             	cmp    $0x0,%eax
   3:	0f 8f 09 00 00 00                	jg     e <main+0xe>
   5:	48 c7 c0 01 00 00 00 	mov    $0x1,%rax
   c:	89 c3                	mov    %eax,%ebx
   e:	83 f8 01             	cmp    $0x1,%eax
  11:	0f 8f f5 ff ff ff                	jg     c <main+0xc>
