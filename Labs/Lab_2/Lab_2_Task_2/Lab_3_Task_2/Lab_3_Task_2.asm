; COMP032
; Lab_3_Task_2: String to Integer Conversion
; written by Kun Zhang

.include "m2560def.inc"
;.equ	STR_SIZE = 6

.cseg
string:
		.db	"239"

main:
		; set up SP
		ldi	yl, low(RAMEND)
		ldi yh, high(RAMEND)
		out SPL, yl
		out SPH, yh
		
	
		; get string's address	
		ldi zl, low(string<<1)		
		ldi zh, high(string<<1)
		rcall atoi

		; get integer's address 
		ldi yl, low(integer)		
		ldi yh, high(integer)
		st	y+, r17
		st  y, r18 
		rjmp end

atoi:	push yl
		push yh

		; store string on stack
		clr r16			; i counter
		clr r17			; r18:r17 used to store converted 
		clr r18			; integer
		clr r20			; register to hold constant 

loop:	;check conditoin
		;cpi r16, STR_SIZE
		;brsh epi
		
		lpm r19, z+		; r19 used to store single character
		cpi r19, '0'	; if c < '0'
		brlo epi
		
		ldi r20, '9'	; if c > '9'
		cp  r20, r19	
		brlo epi

		ldi r20, 0xFF	; if n >= 0xFFFF
		cp	r17, r20
		cpc	r18, r20
		brsh epi

		; conversion
		ldi r20, 10
		mul r17, r20
		mov r22, r1
		mov r21, r0
		mul r18, r20
		add r22, r0		;r22:r21 holds n * 10
		mov r18, r22
		mov r17, r21
		

		; c - '0'
		subi r19, '0'

		;add
		ldi r20, 0
		add r17, r19
		adc r18, r20

		; i ++
		inc r16
		rjmp loop

epi:	
		pop yl
		pop yh
		ret

end:
		rjmp end

.dseg
.org 0x200
integer:
		.byte 2		;2 byte integer