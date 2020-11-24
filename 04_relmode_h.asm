;Main objective of all this madness.
;
;Add a key function (Shift+4W) that stores the current reading as a "temp offset",
;and subtracts that offset from all subsequent readings.
;
; STATUS
;	- works on real metal !
;	- signed math is sloppy and possibly buggy.
;	- must not be used in auto-range mode (saved offset will be incorrect except on the initial range)
;
;Note : this must be loaded in the upper 4kB ROM bank, i.e. +0x1000:
; srec_cat orig.bin -bin 04_relmode_h.hex -intel -offset 0x1000 -contradictory-bytes=warn -o patch04h.bin
; or
; ./patchrom.sh orig.bin 04_relmode_h.hex 0x1000 patched_04.bin
;
; modified opcodes :
; 1157,1158
; 117A, 18AD,18AE,
; 19CB,19CC,19CD,
;
;
; ******* technique
; This consists of a few elements :
; 
; 1- Add a Shift+"4-wire ohm" keypress handler. 0x0E bytes available at end of 1100 page for stub

; 2- patch into "render_reading" for the offset subtraction (must jump to bigger window)
;
; 3- patch into "generate_annuns" to override the MATH annun always-off.
;
; 4- patch into "key_found" to disable relative mode when any key is pressed.

; it seems iRAM[39] contains just a sign flag, "99" for neg, "00" for pos. So we need
; to handle this like the ROM does when adding the ADC reading to the cal offset?
;
; iRAM[60] & 0x01 : bitflag, 1 if relmode active
; u8 *offs=&iRAM[61] : 4-byte PBCD offset
;

	cpu 8039

	org 0157h	;1157 : key_found
	;original opcode we clobbered:
	;call	sub_17E9
keyfound_patch:
	call keyfound_hook

	org 0159h	;1159 : original opcode restored, as guard
	mov	r1,#024h



;***************************************************

	org 017Ah	;117A : inside shift+K jmptable
keyjmp_shifted_patch:
	db 0F2h		;will cause jump to 11F2

	org 01F2h	;11f2-11ff window : 14 bytes
shiftk_stub:
	;sel	mb1	;asl smart enough to add this
	jmp	shiftk_handler


keyfound_hook:
	;any key : clear relflag. We can clobber r1 since it's overwritten when we ret to keyfound_continue
	mov	r1, #relflags
	clr a
	mov @r1, a

	; since we call'ed the _hook, we jmp to the original target in order to ret to the correct place (1159)
	jmp	keyfound_continue


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
	org 09CBh	;19CB: math annun hook.
	; orig code we clobber and replace had "SEL MB0" since it's calling rotl_annun4/8.
	;	clr	c		; 19cb
	;	call	rotl_annun8	; 19cc
annun_stub:
	; we want to guarantee we generate exactly 3 bytes here (call + nop).
	; ASL supports "ASSUME MB:0" since 1.42-bld178, but for a more standard fix, using "phase"
	; we pretend these are executing in MB0 thus asl will not emit "sel mb0".
	phase 01CBh
	call	annun_hook
	nop
	dephase

	org 09CEh	;19CE: original opcode
	;just used as a return point, and a guard;
	; luckily we don't need to restore r0 or A
annun_continue:
	mov	r0,#40H	; 19ce


	org 06C7h	;16C7-16CF window: 9 bytes !!
	; try to fit inside a window in MB0 (1000-17FF) to simplify MB0/1 management...
annun_hook:
	mov	r0, #relflags
	mov	a, @r0
	rrc a	; carry = bit0 = relmode_active
	jmp rotl_annun8	;it will ret to annun_continue, so we don't use more stack depth
	
	org 06D0h	;16D0: end of window, original opcode
	anl	P2, #0BFh


;***************************************************
	org	0A99H	;[1A99-1AFB] window (0x63 bytes)
shiftk_handler:
set_relflag:
		;set relmode only if Manual ranging is enabled.
		;see 0x19E8: manual range if (~(ram[40] & 0x02))
		; i.e. autorange if (ram[40] & 0x02)
	mov r0, #modeflags
	mov	a,@r0
	jb1	_shiftk_exit	;don't enable relmode

	mov	r0, #relflags
	mov	a, @r0
	orl	a, #1
	mov @r0, a

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
_shiftk_exit:
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
modeflags EQU 40H
relflags	EQU 60H
offs	EQU	61H
rotl_annun8 EQU 068CH
keyfound_continue EQU 07E9h	;17E9 actually