// Display character on LCD from Keyboard Input
// written by Kun Zhang
// referencing code from Lecture Material


.include "m2560def.inc"
// Keyboard Predefined
.def row = r16 ; current row number
.def col = r17 ; current column number
.def rmask = r18 ; mask for current row during scan
.def cmask = r19 ; mask for current column during scan
.def temp1 = r20
.def temp2 = r21
.def value1 = r22
.def value2 = r23
.def count = r24
.equ PORTLDIR = 0xF0 ; PL7-4: output, PL3-0, input
.equ INITCOLMASK = 0xEF ; scan from the leftmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK =0x0F ; for obtaining input from Port L
.equ loop_count = 0xFF


// LCD Predefined
.equ LCD_CTRL_PORT = PORTA
.equ LCD_CTRL_DDR = DDRA
.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4


.equ LCD_DATA_PORT = PORTF
.equ LCD_DATA_DDR = DDRF
.equ LCD_DATA_PIN = PINF


// MACROS
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

// MAIN PROGRAM STARTS -----------------------------------------------
.org 0
		jmp RESET

RESET:
	// Initiate LCD --------------------------------------------------
		ldi r16, low(RAMEND)
		out SPL, r16
		ldi r16, high(RAMEND)
		out SPH, r16

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
		clr count

	// Setup Keypad ---------------------------------------------------
		ldi temp1, PORTLDIR ; PL7:4/PL3:0, out/in
		sts DDRL, temp1
keyboard:
		ldi cmask, INITCOLMASK ; initial column mask
		clr col ; initial column

colloop:
		cpi col, 4
		breq keyboard ; if all keys are scanned, repeat.
		sts PORTL, cmask ; otherwise, scan a column
		
		
		ldi temp1, 0x0F ; slow down the scan operation.
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
		subi temp1, -'1' ; Add the value of character ¡®0¡¯
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
		ldi temp1, '0'

convert_end:
		lds temp2, PINL ; read PORTL
		andi temp2, ROWMASK ; get the keypad output value (PL3-0, 0x0X #1110)
		cpi temp2, 0x0F ; check if any row is low
		brne convert_end
		cpi count, 16
		breq next_line
		cpi count, 32
		breq clear_all
display:
		do_lcd_data_reg temp1
		inc count
		rjmp keyboard

next_line:
		do_lcd_command 0b11000000
		rjmp display

clear_all:
		do_lcd_command 0b00000001
		clr count
		rjmp display		



// Define Functions -----------------------------------------------------
.macro lcd_set
		sbi LCD_CTRL_PORT, @0
.endmacro

.macro lcd_clr
		cbi LCD_CTRL_PORT, @0
.endmacro

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