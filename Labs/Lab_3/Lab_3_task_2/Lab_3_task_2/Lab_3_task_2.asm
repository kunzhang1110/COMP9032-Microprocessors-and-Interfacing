// Multiplication with values from keyboard
// a = b*c where a, b and c are 8-bit unsigned
// a is displayed in LED PORTC
// PORTF for keyboard
// written by Kun Zhang

.include "m2560def.inc"
.def row = r16 ; current row number
.def col = r17 ; current column number
.def rmask = r18 ; mask for current row during scan
.def cmask = r19 ; mask for current column during scan
.def temp1 = r20
.def temp2 = r21
.def value1 = r22
.def value2 = r23
.equ PORTLDIR = 0xF0 ; PL7-4: output, PL3-0, input
.equ INITCOLMASK = 0xEF ; scan from the leftmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK =0x0F ; for obtaining input from Port L
.equ loop_count = 0xFF

.macro flash_delay
		ldi r16, loop_count
		clr r17
loop:   cp r16, r17
		brsh done
		subi r17, -1
		nop
		rjmp loop
done
.endmacro

jmp	RESET	
; set up interrupt vector
.org OVF0addr
jmp Timer0OVF

; ISR for Timer0 Overflow
Timer0OVF:
		in temp2, SREG
		push temp2
		adiw r27:r26, 1
	
		; Check if 2 second
		cpi r26, low(488)		;488 = 0.5 s / 1024 us (16MHz clock)
		brne NotTwoSec
		cpi r27, high(488)	;
		brne NotTwoSec
		com temp1
		out PORTC, temp1
		clr r26	
		clr r27

NotTwoSec:
		rjmp EndTimer

EndTimer:
		pop temp2
		out SREG, temp2
		reti

RESET:
// PORTL is memory mapped and cannot use in/out; use sts/lds
// PORTL is defined as memory mapped address in m2560def.inc

		ldi temp1, PORTLDIR ; PL7:4/PL3:0, out/in
		sts DDRL, temp1
		ser temp1 ; PORTC is output
		out DDRC, temp1
		out PORTC, temp1
		ldi yl, low(value)
		ldi yh, high(value)
		clr r26
		clr r27		

keyboard:
		ldi cmask, INITCOLMASK ; initial column mask
		clr col ; initial column

colloop:
		cpi col, 4
		breq keyboard ; if all keys are scanned, repeat.
		sts PORTL, cmask ; otherwise, scan a column
		
		
		ldi temp1, 0xFF ; slow down the scan operation.
delay: 
		dec temp1
		brne delay

		lds temp1, PINL ; read PORTL
		andi temp1, ROWMASK ; get the keypad output value (PL3-0, 0x0X #1110)
		cpi temp1, 0x0F ; check if any row is low
		breq nextcol

								; if yes, find which row is low
		ldi rmask, INITROWMASK ; initialize for row check
		clr row ;

rowloop:
		cpi row, 4
		breq nextcol ; the row scan is over.
		mov temp2, temp1 ;temp1 (0x0X)
		and temp2, rmask ; check un-masked bit (1110 & 0001 = 0000)
		breq convert ; if bit is clear, the key is pressed
		inc row ; else move to the next row
		lsl rmask
		jmp rowloop

nextcol: ; if row scan is over
		lsl cmask ;shift left cmask (1110 -> 1101)
		inc col ; increase column value
		jmp colloop ; go to the next column

convert:
		cpi col, 3 ; If the pressed key is in col. 3
		breq letters ; we have a letter

						; If the key is not in col. 3 and
		cpi row, 3 ; if the key is in row3,
		breq symbols ; we have a symbol or 0
		mov temp1, row ; Otherwise we have a number in 1-9
		lsl temp1
		add temp1, row ;
		add temp1, col ; temp1 = row*3 + col
		subi temp1, -1
	//	subi temp1, -'1' ; Add the value of character ¡®1¡¯
		jmp convert_end

letters:
		ldi temp1, 'A'
		add temp1, row ; Get the ASCII value for the key
		jmp convert_end

symbols:
		cpi col, 0 ; Check if we have a star
		breq star
		cpi col, 1 ; or if we have zero
		breq zero
		ldi temp1, '#' ; if not we have hash
		jmp convert_end

star:
		ldi temp1, '*' ; Set to star
		jmp convert_end

zero:
		clr temp1

convert_end:
		mov r24, temp1		
		cpi r24, '#'
		breq get_values

				
wait_release:	; wait until button is released
		lds temp1, PINL ; read PORTL
		andi temp1, ROWMASK ; get the keypad output value (PL3-0, 0x0X #1110)
		cpi temp1, 0x0F ; check if any row is low
		brne wait_release
		st y+, r24
		out PORTC, r24 ; Write value to PORTC
		jmp keyboard ; Restart main loop


get_values:
		; get value of b
		clr r16	;first digit
		clr r17	;second digit
		clr r18 ;third digit
		clr value1
		clr value2
		ld temp2, -y		;load the last digit
		cpi temp2, '*'
		breq overflow_flash		; error
		mov r16, temp2		
		ld temp2, -y		;load the second digit
		cpi temp2, '*'
		breq get_val1		; calculate value 1
		mov r17, temp2
		ld temp2, -y		;load the first digit
		cpi temp2, '*'
		breq get_val1		; calculate value 1
		mov r18, temp2
		ld temp2, -y		; load *
		breq get_val1			

get_val1:
		ldi temp1, 100
		mul temp1, r18
		mov value1, r0
		ldi temp1, 10
		mul temp1, r17
		add value1, r0
		add value1, r16

		; get value of a
		clr r16	;first digit
		clr r17	;second digit
		clr r18 ;third digit

		ld temp2, -y		;load the last digit
		mov r16, temp2	
		cpi yl, 0
		breq get_val2
		ld temp2, -y		;load the second digit
		mov r17, temp2
		cpi yl, 0
		breq get_val2	; calculate value 1
		ld temp2, -y		;load the first digit
		mov r18, temp2



get_val2:
		ldi temp1, 100
		mul temp1, r18
		mov value2, r0
		ldi temp1, 10
		mul temp1, r17
		add value2, r0
		add value2, r16

multiply:
		mul value2, value1
		mov r16, r1
		cpi r16, 0
		brne overflow_flash
		out PORTC, r0

	rjmp end



overflow_flash:
		; setup Timer0
		clr temp1
		out TCCR0A, temp1		; normal mode
		ldi temp1, (1<<CS00|1<<CS01)
		out TCCR0B, temp1		; prescalar 64 = 1024 us
		ldi temp1, 1<<TOIE0
		sts TIMSK0, temp1		; Timer0 interrupt enable	
		sei 
		ser temp1
		out PORTC, temp1
flashing:
		rjmp flashing

end:
		rjmp end


.dseg
.org 0x0200
value:
		.byte 20