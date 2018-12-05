.include "m2560def.inc"
.dseg
.org 0x0200
A1: .byte 0x2F
A2: .byte 2
A3: .byte 4

.cseg
main:		
		ldi zh, high(B<<1)
		ldi zl, low(B<<1)
		ldi xh, high(A1)
		ldi xl, low(A1)
		ldi r18, 'x'		;load r18 with value 'x'
		lpm r17, z+
		st x+, r17
loop:	
		cpi r17, 0
		breq end
		nop
		cp r17, r18
		breq replace


resume:
		lpm r17, z+
		st x+, r17
		rjmp loop

replace:
		mov r20, zh
		mov r21, zl
		ldi zh, high(D<<1)
		ldi zl, low(D<<1)
		lpm r16, z
		mov r17, r16
		st x+, r17
		mov zh, r20
		mov zl, r21
		adiw zh:zl, 1
		rjmp loop

end:
		rjmp end
	
.org 0x0300			;word address
B: .DB "A COMP9032 lab group", "has", "x", "student", 0
D: .DB "2"