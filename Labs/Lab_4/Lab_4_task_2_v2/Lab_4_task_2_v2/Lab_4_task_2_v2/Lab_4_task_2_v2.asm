// Update speed every 0.5 second
// PD2 (INT2) OpO read pin
// PE3 (OC3A) Motor Input
.include "m2560def.inc"


// Pre-defined values
.def	temp1 = r24
.def	temp2 = r25
.equ	TIME_CONSTANT = 976	; TIME_CONSTANT = X s/1024 us

.equ LCD_CTRL_PORT = PORTA
.equ LCD_CTRL_DDR = DDRA
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4


.equ LCD_DATA_PORT = PORTF
.equ LCD_DATA_DDR = DDRF
.equ LCD_DATA_PIN = PINF


// Define variables ------------------------------------------------------------
.dseg
Start_Count:
		.byte	2
Second_Counter:
		.byte	2
Hole_Counter:
		.byte   1

// Define macros ------------------------------------------------------------
.macro Clear
	ldi		yl, low(@0)
	ldi		yh,	high(@0)
	clr		temp1
	st		y+, temp1
	st		y, temp1
.endmacro

; STORE value into register
.macro STORE
.if @0 > 63
		sts @0, @1
.else
		out @0, @1
.endif
.endmacro

; LOAD value into register
.macro LOAD
.if @1 > 63
		lds @0, @1
.else
		in @0, @1
.endif
.endmacro

.macro do_lcd_command
		ldi r16, @0
		rcall lcd_command
		rcall lcd_wait
.endmacro
.macro do_lcd_data
		ldi r16, @0
		rcall lcd_data
		rcall lcd_wait
.endmacro
.macro do_lcd_data_reg
		mov r16, @0
		rcall lcd_data
		rcall lcd_wait
.endmacro

.macro integer_division
//@0:	Dividend (register); @1:	Divisor (immediate)
//temp1: remainder; temp2: quotient
		mov		temp1, @0
		clr		temp2
div:	cpi		temp1, @1
		brsh	div_1
		rjmp	div_marcro_end
div_1:	inc		temp2
		subi	temp1, @1
		rjmp	div
div_marcro_end:
.endmacro

.macro immediate_division
//@0:	Dividend (register); @1:	Divisor (immediate)
//temp1: remainder; temp2: quotient
		mov		temp1, @0
		clr		temp2
div:	cpi		temp1, @1
		brsh	div_1
		rjmp	div_marcro_end
div_1:	inc		temp2
		subi	temp1, @1
		rjmp	div
div_marcro_end:
.endmacro


.macro	display_Number
//@0:	binary number
		integer_division @0, 0xA
		subi	temp1, -'0'					; convert to ASCII
		subi	temp2, -'0'					; convert to ASCII
		do_lcd_command 0b00000001			; clear display
		do_lcd_data_reg temp2				; display first digit
		do_lcd_data_reg temp1				; display second digit
.endmacro



// Initial address setting ----------------------------------------
.cseg
.org 0x0000
		jmp	RESET
.org	INT2addr
		jmp		EXT_INT2
.org	OVF0addr
		jmp		TIMER0OVF


// External overflow ISR ----------------------------------------
EXT_INT2:
// Increment hole counter
		push	temp1
		push	temp2
		in		temp1, SREG
		push	temp1
		push	yh
		push	yl

		ldi		yl, low(Hole_Counter)
		ldi		yh, high(Hole_Counter)
		ld		temp1, y
		subi	temp1,-1 				; increment counter
		st		y, temp1
		cpi		temp1, 1
		breq	Save_Start
		cpi		temp1, 40				; 10 resolutions
		breq	Upadate_Display
		rjmp	EXT2_end


Save_Start:
		ldi		yl, low(Second_Counter)
		ldi		yh, high(Second_Counter)
		ld		temp1, y+
		ld		temp2, y
		ldi		yl, low(Start_Count)
		ldi		yh, high(Start_Count)
		st		y+, temp1			; store counter value
		st		y, temp2
		rjmp	EXT2_end

Upadate_Display:
		ldi		yl, low(Second_Counter)
		ldi		yh, high(Second_Counter)
		ld		temp1, y+
		ld		temp2, y
		ldi		yl, low(Start_Count)
		ldi		yh, high(Start_Count)
		ld		r20, y+
		ld		r21, y
		sub		temp1, r20
		sbc		temp2, r21					

;		integer_division	temp1, 4		; divide hole counter by 4
		display_Number		temp1			; display resolution
		Clear	Second_Counter
		Clear	Hole_Counter

		rjmp	EXT2_end
EXT2_end:
		pop		yl
		pop		yh
		pop		temp1
		out		SREG, temp1
		pop		temp2
		pop		temp1
		reti



//Timer 0 overflow ISR ----------------------------------------
TIMER0OVF:
// Calculate speed and display on LCD
		push	temp1
		push	temp2
		in		temp1, SREG
		push	temp1
		push	yh
		push	yl

		ldi		yl, low(Second_Counter)
		ldi		yh, high(Second_Counter)
		ld		temp1, y+
		ld		temp2, y
		adiw	temp2:temp1,1 				; increment counter
		st		y, temp2
		st		-y, temp1

ENDOVF:
		pop		yl
		pop		yh
		pop		temp1
		out		SREG, temp1
		pop		temp2
		pop		temp1
		reti

// Initial setup  -------------------------------------------------------
RESET:
		cli								; disable interrupts
		// Setup INT2
		ldi		temp1, 2 << ISC20		; falling edge triggered
		sts		EICRA, temp1
		in		temp1, EIMSK			; Enable INT2
		ori		temp1, 1 << INT2
		out		EIMSK, temp1

		// Setup Timer0 
		clr		temp1					; normal operating mode
		out		TCCR0A, temp1
		ldi		temp1, 0x03				; Prescale 64 = 1024 ms
		out		TCCR0B, temp1
		ldi		temp1, 1<< TOIE0		; Timer 0 enable
		sts		TIMSK0, temp1


		// Initialize Stack Pointer
		ldi		temp1, low(RAMEND)
		out		SPL, temp1
		ldi		temp1, high(RAMEND)
		out		SPH, temp1

		// Initialize LCD
		ser r16
		STORE LCD_DATA_DDR, r16
		STORE LCD_CTRL_DDR, r16
		clr r16
		STORE LCD_DATA_PORT, r16
		STORE LCD_CTRL_PORT, r16
		do_lcd_command 0b00111000 ; 2x5x7
		rcall sleep_5ms
		do_lcd_command 0b00111000 ; 2x5x7
		rcall sleep_1ms
		do_lcd_command 0b00111000 ; 2x5x7
		do_lcd_command 0b00111000 ; 2x5x7
		do_lcd_command 0b00001000 ; display off
		do_lcd_command 0b00000001 ; clear display
		do_lcd_command 0b00000110 ; increment, no display shift
		do_lcd_command 0b00001110 ; Cursor on, bar, no blink

		sei
		jmp		MAIN



// Main loop ------------------------------------------------------
MAIN:

		// Setup counter 3 (16-bit)
		ldi		temp1, 0b00001000	; set PE3 as output
		out		DDRE, temp1

		ldi		temp1, 0x4A	; OCR compare value
		sts		OCR3AL, temp1
		ldi		temp1, 0x00
		sts		OCR3AH, temp1

		ldi		temp1, 1 << CS30		; set Timer3 to Phase Correct PWM
		sts		TCCR3B, temp1
		ldi		temp1, (1<<WGM30)|(1<<COM3A1)
		sts		TCCR3A, temp1
		sei								;enable global interrupt
		rjmp	DUMMY

DUMMY:
		rjmp DUMMY



// Define sub-routines --------------------------------------------
.macro lcd_set
		sbi LCD_CTRL_PORT, @0
.endmacro

.macro lcd_clr
		cbi LCD_CTRL_PORT, @0
.endmacro

;
; Send a command to the LCD (r16)
;

lcd_command:
		STORE LCD_DATA_PORT, r16
		rcall sleep_1ms
		lcd_set LCD_E
		rcall sleep_1ms
		lcd_clr LCD_E
		rcall sleep_1ms
		ret

lcd_data:
		STORE LCD_DATA_PORT, r16
		lcd_set LCD_RS
		rcall sleep_1ms
		lcd_set LCD_E
		rcall sleep_1ms
		lcd_clr LCD_E
		rcall sleep_1ms
		lcd_clr LCD_RS
		ret

lcd_wait:
		push r16
		clr r16
		STORE LCD_DATA_DDR, r16
		STORE LCD_DATA_PORT, r16
		lcd_set LCD_RW
lcd_wait_loop:
		rcall sleep_1ms
		lcd_set LCD_E
		rcall sleep_1ms
		LOAD r16, LCD_DATA_PIN
		lcd_clr LCD_E
		sbrc r16, 7
		rjmp lcd_wait_loop
		lcd_clr LCD_RW
		ser r16
		STORE LCD_DATA_DDR, r16
		pop r16
		ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
		push r24
		push r25
		ldi r25, high(DELAY_1MS)
		ldi r24, low(DELAY_1MS)
delayloop_1ms:
		sbiw r25:r24, 1
		brne delayloop_1ms
		pop r25
		pop r24
		ret

sleep_5ms:
		rcall sleep_1ms
		rcall sleep_1ms
		rcall sleep_1ms
		rcall sleep_1ms
		rcall sleep_1ms
		ret
