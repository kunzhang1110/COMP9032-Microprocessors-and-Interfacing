; COMP9032
; Lab_3_Task_1: Positional Division
; written by Kun Zhang

.include "m2560def.inc"
.equ A = 40300
.equ B = 430
.def ALow = r16
.def AHigh = r17
.def BLow = r18
.def BHigh = r19
.def QLow = r20
.def QHigh = r21
.def bPLow = r22		
.def bPHigh = r23
.def zero = r15		;r15 to store constant zero

.macro add_16; M = M + N (ML, MH, NL, NH)
	add @0, @2
	adc @1, @3
.endmacro

.macro sub_16; M = M - N (ML, MH, NL, NH)
	sub @0, @2
	sbc @1, @3
.endmacro

.macro cp_16; compare M with N (ML, MH, NL, NH)
	cp @0, @2; 
	cpc @1, @3;
.endmacro

.macro ls_16; 16 bit shift left M (ML, MH)
	lsl @0
	rol @1
.endmacro

.macro rs_16; 16 bit shift right M (ML, MH)
	lsr @1			; for unsigned
	ror @0
.endmacro


.cseg
; set Z pointer to A and B
; set Y pointer to Q 

START:	ldi ZH, high(div<<1)
		ldi ZL, low(div<<1)
		ldi YH, high(Q)
		ldi YL, low(Q)
		ldi bPLow, 1
		clr bPHigh

LOAD:	lpm ALow, Z+
		lpm AHigh, Z+
		lpm BLow, Z+
		lpm BHigh, Z

LOOP1:	
		; while divdend > divisor
		cp_16 BLow, BHigh, ALow, AHigh
		brsh LOOP2				; use brge for signed values
		
		; while highest bit is not 0
		clr r24
		mov r24, BHigh
		ANDI r24,0x80	;isolate bit 7
		cpi r24,0x80
		breq LOOP2

		ls_16 BLow, BHigh	    ; divisor = divisor << 1
		ls_16 bPLow, bPHigh		; bPs = bPs <<1
		rjmp LOOP1



LOOP2:	
		cp_16 bPlow, bPHigh, zero, zero	;while bPos > 0
		breq STORE
		cp_16 ALow, AHigh, BLow, BHigh
		brsh CAL
L2_CT:
		rs_16 BLow, BHigh		
		rs_16 bPLow, bPHigh
		rjmp LOOP2

CAL:
		sub_16 ALow, AHigh, BLow, BHigh
		add_16 QLow, QHigh, bPLow, bPHigh
		rjmp L2_CT

STORE:	
		st	Y+, QLow			; store on SRAM
		st	Y, QHigh
		rjmp END

END:
		rjmp END

; store in programming flash
div:		.dw A
		.dw B

	


; store in data SRAM
.dseg
.org 0x200
Q: .byte 2		;Q for quotient 