;Main objective of all this madness.
;
;Add a key function (Shift+4W) that stores the current reading as a "temp offset",
;and subtracts that offset from all subsequent readings.
;
; STATUS
;	- works in MAME ! except for TODO items
;	- signed math is sloppy and possibly buggy.
;	- changing ranges / modes keeps the same display offset but becomes meaningless.
; TODO
;	- test on real metal
;	- test "MATH" annun on real metal

;
;Note : this must be loaded in the upper 4kB ROM bank, i.e. +0x1000:
; srec_cat orig.bin -bin 04_relmode_h.hex -intel -offset 0x1000 -contradictory-bytes=warn -o patch04h.bin
;
;
; ******* technique
; Add a shift+K handler. 0x0E bytes available at end of 1100 page for stub
; add shiftk handler (?? bytes)
; patch into "render_reading" for the offset subtraction (?? bytes)
;
; it seems [39] contains just a sign flag, "99" for neg, "00" for pos. So we need
; to handle this like the ROM does when adding the ADC reading to the cal offset?
;
; iRAM[60] & 0x01 : bitflag, 1 if relmode active
; u8 *offs=&iRAM[61] : 4-byte PBCD offset

	cpu 8039

	org 017Ah	;117A : inside shift+K jmptable
keyjmp_shifted_patch:
	db 0F2h

	org 01F2h	;11f2
shiftk_stub:
	;sel	mb1	;asl smart enough to add this
	jmp	shiftk_handler


;***************************************************
	org	08ADh	;18AD : render_reading
render_reading:
	;we patch over the first 2 bytes so we'll have to take care of those opcodes later
	jmp	render_hook

	org 08AFh	;18AF : original opcode
	;just used as a return point, and a guard,
	;in case the assembler adds a "sel mb" opcode above, which would clobber this.
render_continue:
	clr	f1


;***************************************************
	org	0A99H	;[1A99-1AFB] window (99 bytes)
shiftk_handler:
toggle_annun:
	;assume annunciator bits are stored in the same order as they appear on-screen.
	mov	r0, #ann_msb
	mov	a, @r0
	xrl	a, #ann_math
	mov	@r0, a
toggle_relflag:	
	mov	r0, #relflags
	mov	a, @r0
	xrl	a, #1
	mov @r0, a
	jb0	get_reading
_shiftk_exit:
	retr

	;copy the reading and 9's complement if required
get_reading:
	;there's no "memcpy" in this 4kB bank unfortunately.
	mov	r0, #offs	;dest
	mov	r1, #reading
	mov	r2, #3
cploop:
	mov	a, @r1
	mov @r0, a
	inc	r0
	inc r1
	djnz	r2,cploop
_cp_finished
	;check sign of reading and fixup if negative
	mov r0, #reading_sign
	mov	a, @r0
	jz	_shiftk_exit
	mov	r0, #offs + 2
	call	fixup
	retr	;key handlers have a retr

;***************************************************
;called from the render_reading stub
render_hook:
	;these are the 2 opcodes clobbered by the stub jmp
	clr	f0
	cpl	f0
	mov	r0, #relflags
	mov	a, @r0
	jb0	do_relmode	;only do math if enabled
	jmp	render_continue

do_relmode:
;again, fixup reading if negative:
	mov	r0, #reading_sign
	mov	a, @r0
	jz	sub_offset
	mov	r0, #reading + 2
	call	fixup
;also, doesn't seem to be a reusable "subtract_BCD" function in this 4kB bank.
;Algo copied from @0F28
sub_offset:
	mov	r0, #reading + 3
	mov	r1, #offs + 3
	mov	r2, #04H
	clr	c
_subloop:
	mov	a,@r1
	addc	a,#65H
	cpl	a
	add	a,@r0
	da	a
	mov	@r0,a
	cpl	c
	dec	r0
	dec	r1
	djnz	r2,_subloop
;fixup as "9's complement" if result is negative
	;after subloop, a=@[reading], and r0=&reading-1
	jb7	sub_fixup
	mov	@r0, #0
	jmp	render_continue
sub_fixup
	mov	@r0, #99H
	mov	r0,#reading + 2
	call	fixup
	jmp	render_continue

;9's complement. r0 points to end of value to be fixed
fixup:
	mov	r2,#3
_fixloop:	mov	a,@r0
	add	a,#66H
	cpl	a
	mov	@r0,a
	dec	r0
	djnz	r2,_fixloop
	ret

	org	0AFCh	;end of window
guard_1AFC
	db	0FFH	;original opcode. Same idea, just a guard to prevent clobbering

;***************************************************

reading_sign	EQU	39H
reading	EQU	3AH
relflags	EQU 60H
offs	EQU	61H

ann_msb	EQU 53H
ann_math	EQU 08H	;bitmask for MATH annunciator (5th from the left)