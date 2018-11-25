;disable ROM checksum entirely
;
;Only recommended for development use !
;Note : this must be loaded in the upper 4kB ROM bank, i.e. +0x1000:
; srec_cat orig.bin -bin 03_ckdis.hex -intel -offset 0x1000 -contradictory-bytes=warn -o patch03.bin

	cpu 8039

	org 00057H	;actually 0x1057
ck_disable:
	jmp 005FH
