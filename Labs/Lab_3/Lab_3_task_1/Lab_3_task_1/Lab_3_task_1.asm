// LED flashing with 2s delay
// terminates when button is pressed
// Version 1: using macro to generate delay
// PORTC for LED
// PB0 (INT0) for Button(PB0)
// written by Kun Zhang

.include "m2560def.inc"

.equ clk_freq = 16000000  ;clock frequcy in Hz
.equ limit_A = 100
.equ limit_B = 1331

.def iH = r27
.def iL = r26
.def jH = r25
.def jL = r24
.def countH = r21
.def countL = r20
.def temp = r16

		jmp	RESET	
; set up interrupt vector
.org INT0addr
		rjmp EXT_INT0


.macro	twoSecDelay
		clr iH					; 1 cycle
		clr iL					; 1
 m_loop:
		ldi ZH,high(A<<1)		;1	
		ldi ZL,low(A<<1)		;1	
		lpm countL, Z+			;3
		lpm countH, Z			;3
		cp iL, countL			;1
		cpc iH, countH			;1
		brsh done				;1, 2
		clr jH					;1
		clr jL					;1
 in_loop:					;
		ldi ZH,high(B<<1)		;1
		ldi ZL,low(B<<1)		;1
		lpm countL, Z+			;3
		lpm countH, Z			;3
		cp jL, countL			;1
		cpc jH, countH			;1
		brsh m_loop1				;1, 2
		adiw jH:jL, 1			;1
		nop						;1
		rjmp in_loop			;2
// not branch 15*B; branch 12; total = 15*B + 12
 m_loop1:
		adiw iH:iL, 1			;2
		nop						;1
		rjmp m_loop				;2
// not branch (13 + 15*B + 12 + 5) *A; branch 12
// not branch 30*A + 15*A*B; branch 12; total = 15*A + 30*A*B + 12 = 2*clk_freq
// Let A =1000, then B = 1064 if clock frequecy if 16M
	done:	
.endmacro

; ISR of INT0
EXT_INT0:						; for STK600
		ser temp		
		out PORTC, temp
		rjmp END

/*EXT_INT0:
		clr temp		
		out PORTC, temp
		rjmp END*/

RESET:	
		; set PORTC as output
		ser temp
		out DDRC, temp
		
		; set INT0 (PB0)
		ldi temp, (2<<ISC00)	; set INT0 as falling edge triggered
		sts EICRA, temp
		ldi temp, (1<<INT0)		; enable INT0
		out EIMSK, temp			
		sei						; global interrupt


LOOP:
		clr temp
		out PORTC, temp
		twoSecDelay
		ser temp
		out PORTC, temp
		twoSecDelay
		rjmp LOOP


END:
		rjmp END


A:
		.dw	limit_A
B:
		.dw limit_B
