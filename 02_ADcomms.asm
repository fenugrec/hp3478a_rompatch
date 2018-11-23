;neutralizes comms to skip "AD LINK" self test
;
;This one is more complex.
;Need to patch 2 things :
; 1) TX loop, just bypass to get the correct return code
; 2) RX loop, need to fake ADC data and get return code

	cpu 8039

	org 0563H
synctx_patch:
	jmp 059BH



	org 0605H
syncrx_patch:
	mov	r0,#2DH	;clear 4 bytes at 0x2D
	mov	r1,#4
	clr a
fakedata_loop:
	mov	@r0,a
	inc	r0
	djnz	r1,fakedata_loop
	jmp	05ABH

