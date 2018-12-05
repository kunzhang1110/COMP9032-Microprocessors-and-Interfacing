// LED flashing with 2s delay
// terminates when button is pressed
// Version 1: using macro to generate delay
// PORTC for LED
// PB0 (INT0) for Button(PB0)
// written by Kun Zhang

.include "m2560def.inc"

.equ clk_freq = 16000000  ;clock frequcy in Hz
.def temp = r16
.def led = r17			; current led state
.def iL = r24			; counter
.def iH = r25






jmp	RESET	
; set up interrupt vector
.org INT0addr
jmp EXT_INT0
.org OVF0addr
jmp Timer0OVF


; ISR of INT0
EXT_INT0:						; for STK600
		clr temp		
		out PORTC, temp
		rjmp END


/*EXT_INT0:
		clr temp		
		out PORTC, temp
		rjmp END*/

Timer0OVF:
		sei						;enable further interrupts
		in temp, SREG
		push temp
		adiw iH:iL, 1
	
		; Check if 2 second
		cpi iL, low(1907)		;2000 = 2 s / 1024 us (16MHz clock)
		brne NotTwoSec
		cpi iH, high(1907)	;
		brne NotTwoSec
		com led
		out PORTC, led
		clr iL
		clr iH

NotTwoSec:
		rjmp EndTimer

EndTimer:
		pop temp
		out SREG, temp
		reti



RESET:	
		; set PORTC as output
		ser temp
		out DDRC, temp
		clr led
		out PORTC, led
		; setup INT0 (PB0)
		ldi temp, (2<<ISC00)	; set INT0 as falling edge triggered
		sts EICRA, temp
		ldi temp, (1<<INT0)		; enable INT0
		out EIMSK, temp			
		; setup Timer0
		clr temp
		out TCCR0A, temp		; normal mode
		ldi temp, (1<<CS00|1<<CS01)
		out TCCR0B, temp		; prescalar 64 = 1024 us
		ldi temp, 1<<TOIE0
		sts TIMSK0, temp		; Timer0 interrupt enable		
		sei						; global interrupt

LOOP:
		rjmp loop

END:
		rjmp END