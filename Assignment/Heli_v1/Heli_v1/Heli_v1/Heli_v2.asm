; DESCRIPTION
; The program is a emulator that controlls a helicopter flying in a confined
; space. The area is 50*50*10 (m3). The helicpoter starts at the center of 
; the hall (25, 25, 0)

.include "m2560def.inc"

; Predefine registers and values ==============================================
.def	flag = r20
.def	cov_val = r21	; converted keyboard input
.def	landing = r22
.def    zero_reg = r23
.def	temp1 = r24
.def	temp2 = r25
.equ	TIME_CONSTANT_1S = 950	; TIME_CONSTANT_1S is close to 1 s/(4*256) us

; Predefine LCD ---------------------
.equ	LCD_CTRL_PORT = PORTA		; LCD control ports
.equ	LCD_CTRL_DDR = DDRA
.equ	LCD_RS = 7					; LCD bits
.equ	LCD_E = 6
.equ	LCD_RW = 5
.equ	LCD_BE = 4

.equ	LCD_DATA_PORT = PORTF	; LCD data ports
.equ	LCD_DATA_DDR = DDRF
.equ	LCD_DATA_PIN = PINF

; Predefine Keyboard ---------------------
.def	row = r16 ; current row number
.def	col = r17 ; current column number
.def	rmask = r18 ; mask for current row during scan
.def	cmask = r19 ; mask for current column during scan
.equ	PORTLDIR = 0xF0 ; PL7-4: output, PL3-0, input
.equ	INITCOLMASK = 0xEF ; scan from the leftmost column,
.equ	INITROWMASK = 0x01 ; scan from the top row
.equ	ROWMASK =0x0F ; for obtaining input from Port L

; Define variables =============================================================
.dseg
content:
	.byte	5
sec_count:		; store counter to count 0.5s
	.byte	2
second:			; how many 0.5 seconds from start
	.byte	2
distance:
	.byte	2

; Setup interrupt vectors ------------------------------------------------
.cseg
.org 0
		jmp		RESET
.org	OVF3addr
		jmp		TIMER3OVF


; Define Macros =============================================================
; clear variables
.macro Clear
	ldi		yl, low(@0)
	ldi		yh,	high(@0)
	clr		temp1
	st		y+, temp1
	st		y, temp1
.endmacro

; store values ----------------------
.macro STORE
.if @0 > 63
		sts @0, @1
.else
		out @0, @1
.endif
.endmacro

; LOAD value into register---------------------
.macro LOAD
.if @1 > 63
		lds @0, @1
.else
		in @0, @1
.endif
.endmacro

; perform lcd command ------------------------
.macro do_lcd_command
		ldi r16, @0
		rcall lcd_command
		rcall lcd_wait
.endmacro

; display data ------------------------
.macro do_lcd_data
		ldi r16, @0
		rcall lcd_data
		rcall lcd_wait
.endmacro

; display data in register -----------------
.macro do_lcd_data_reg
		mov r16, @0
		rcall lcd_data
		rcall lcd_wait
.endmacro

; integer_division -------------------
.macro integer_division_Two_digit
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
		integer_division_Two_digit @0, 10				; divide by 10			
		subi	temp1, -'0'					; convert to ASCII
		subi	temp2, -'0'					; convert to ASCII
		do_lcd_data_reg temp2				; display first digit
		do_lcd_data_reg temp1				; display second digit
.endmacro

.macro integer_division_Three_digit_by_100 
// @0:  low byte register; @1 high byte register
// remainder in r3:r2
// quotient in r1:r0
		
		clr		r0
		clr		r1
		clr		r20
		ldi		r18, 100		; r19:r18 divisor
		ldi		r19, 0

div_16_10:
		movw	r1:r0, @1:@0	; copy dividend to answer r1:r0
		ldi		r20, 17			; bit counter
		sub		r2, r2			; clear remainder and carry
		clr		r3
div_16_loop:
		rol		r0				; rotate answer to the left
		rol		r1
		dec		r20				; decrement counter
		breq	div_16_done		; if 16 bits are done
		rol		r2				; shift remainder to the left
		rol		r3
		sub		r2, r18			; subtract divisor from remainder
		sbc		r3, r19
		brcc	div_16_skip		; if less than 0
		add		r2, r18			; add divisor back
		adc		r3, r19
		clc
		rjmp	div_16_loop
div_16_skip: 
		sec
		rjmp	div_16_loop
div_16_done:
.endmacro

.macro display_Number_Three_digit
// @0:  low byte register; @1 high byte register
		integer_division_Three_digit_by_100 @0, @1	; divide number by 100
		mov		r21, r0
		integer_division_Two_digit r2, 10	; divide remainder by 10
		subi	temp1, -'0'					; convert to ASCII
		subi	temp2, -'0'					; convert to ASCII
		subi	r21, -'0'					; convert to ASCII
		do_lcd_data_reg r21					; display first digit
		do_lcd_data_reg temp2				; display second digit
		do_lcd_data_reg temp1				; display third digit
.endmacro


; Timer 3 Overflow ISR =====================================================
TIMER3OVF:
		push	temp1						; save registers
		push	temp2
		in		temp1, SREG
		push	temp1
		push	yh
		push	yl



		ldi		yl, low(sec_count)			; load secound_count
		ldi		yh, high(sec_count)
		ld		temp1, y+
		ld		temp2, y
		adiw	temp2:temp1,1 				; increment second_count
		cpi		temp1, low(TIME_CONSTANT_1S)	; check if it is TIME
		brne	NOTTIME
		cpi		temp2, high(TIME_CONSTANT_1S)
		brne	NOTTIME
		call	update						; update values
		call	display						; display new values
		Clear	sec_count
		rjmp	ENDOVF

NOTTIME:									; if not save second_count
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


; RESET ======================================================================
RESET:
		cli
		clr		zero_reg	; put 0 in zero_reg
		// Initialize Stack Pointer -------------
		ldi		temp1, low(RAMEND)
		out		SPL, temp1
		ldi		temp1, high(RAMEND)
		out		SPH, temp1
	
		// Initialize LCD -------------------
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
		do_lcd_command 0b00001100 ; Cursor on, bar, no blink
		

		// Display start ----------------------------
		do_lcd_command 0b00000001	; clear display	
		do_lcd_data 'S'
		do_lcd_data 't'
		do_lcd_data 'a'
		do_lcd_data 'r'
		do_lcd_data 't'
		do_lcd_data ':'

		// Initialize Keyboard Ports ------------ 
		ldi temp1, PORTLDIR ; PL7:4/PL3:0, out/in
		sts DDRL, temp1

		// Initialize LED PORTC 
		ser	temp1
		out	DDRC, temp1
	;	out	PORTC, temp1
		
		// Keyboard scanning loop ----------------
on_ground:
		// Initially on ground
		rcall	Get_Keyboard
		cpi		cov_val, '#'	; check if hash is pressed
		breq	take_off		; then take off
		rjmp	on_ground


take_off:
		// Initialize Display Contents (25, 25, 0)
		ldi		yl, low(content)
		ldi		yh, high(content)
		ldi		temp1,25
		st		y+, temp1			; x position
		st		y+, temp1			; y
		clr		temp1				
		st		y+, temp1			; z
		ldi		temp1, 'U'
		st		y+, temp1			; direction
		ldi		temp1,2
		st		y, temp1			; speed

		// Setup Timer3 --------------
		ldi		temp1, 0b00001000	; set PE3 as output
		out		DDRE, temp1

		ldi		temp1, 60	; OCR compare value
		sts		OCR3AL, temp1
		ldi		temp1, 0x00
		sts		OCR3AH, temp1

		ldi		temp1, (1 << CS31|1 << CS30)		; set Timer3 to Phase Correct PWM; prescale = 64/4us
		sts		TCCR3B, temp1
		ldi		temp1, (1<<WGM30)|(1<<COM3A1) ; clear up-counting match, set down match
		sts		TCCR3A, temp1

		ldi		temp1, 1<< TOIE3		; Timer 3 enable
		sts		TIMSK3, temp1
		sei

		// macro update direction content
		.macro	update_direction
				ldi		yl, low(content)
				ldi		yh, high(content)
				ldi		temp1, @0
				adiw	yh:yl, 3
				st		y, temp1
		.endmacro

// flying while getting keyboard input ============================================
flying:
		rcall	Get_Keyboard	; get key board input in con_val
		
		cpi		cov_val, '1'	;	down
		breq	fly_down
		cpi		cov_val, '2'	;	forward
		breq	fly_forward
		cpi		cov_val, '3'	;	up
		breq	fly_up
		cpi		cov_val, '4'	;	left
		breq	fly_left		
		cpi		cov_val, '5'	;	backward
		breq	fly_backward			
		cpi		cov_val, '6'	;	right
		breq	fly_right			
		cpi		cov_val, 'C'	;	increase speed
		breq	fly_faster_0	
		cpi		cov_val, 'D'	;	decrease speed
		breq	fly_slower_0		
		cpi		cov_val, '*'	;	hover/resume
		breq	fly_star_0
		cpi		cov_val, '#'	;	land
		breq	land
		rjmp	flying

		// update content
fly_down:
		update_direction 'D'
		rjmp flying

fly_forward:
		update_direction 'F'
		rjmp flying

fly_up:
		update_direction 'U'	
		rjmp flying

fly_left:
		update_direction 'L'	
		rjmp flying

fly_backward:
		update_direction 'B'	
		rjmp flying

fly_right:
		update_direction 'R'	
		rjmp flying

fly_faster_0:
		jmp		fly_faster

fly_slower_0:
		jmp		fly_slower

fly_star_0:
		jmp		fly_star

land:	
		ldi		landing, 'T'	; set landing flag to True
		update_direction 'D'
		ldi		yl, low(content)
		ldi		yh, high(content)
		adiw	yh:yl, 4
		ldi		temp1,1
		st		y, temp1
		rjmp	flying

fly_faster:
		ldi		yl, low(content)
		ldi		yh, high(content)
		adiw	yh:yl, 4
		ld		temp1, y
		inc		temp1
		cpi		temp1,4
		brsh	fly_faster_set
		; increase motor speed
		lds		temp2, OCR3AL
		subi	temp2, -10
		sts		OCR3AL, temp2
fly_faster_resume:
		st		y, temp1
		rjmp flying	
fly_faster_set:
		; change motor speed to highest
		ldi		temp2, 80
		sts		OCR3AL, temp2
		ldi		temp1,4		; set speed to 4
		rjmp	fly_faster_resume	

fly_slower:
		ldi		yl, low(content)
		ldi		yh, high(content)
		adiw	yh:yl,4
		ld		temp1,y
		dec		temp1
		cpi		temp1,2
		brlo	fly_slower_set
		; decrease motor speed
		lds		temp2, OCR3AL
		subi	temp2, 10
		sts		OCR3AL, temp2
fly_slower_resume:
		st		y, temp1
		rjmp flying	
fly_slower_set:
		; change motor speed to lowest
		ldi		temp2, 50
		sts		OCR3AL, temp2
		ldi		temp1, 1
		rjmp	fly_slower_resume	

fly_star:
		ldi		yl, low(content)
		ldi		yh, high(content)
		adiw	yh:yl, 3
		cpi		flag, 0
		breq	hover		; if flag is empty then hover
							; else resume previous direction
		mov		temp1, flag
		clr		flag
		rjmp	fly_star_save
hover:
		ld		flag, y		; save direction in flag
		ldi		temp1, 'H'
fly_star_save:
		st		y, temp1
		rjmp	flying


// Define functions ==============================================================
// Landed and display total time and distance --------------------
Land_Display:
		push	r16
		push	r17
		push	yl
		push	yh
		
		clr		temp1
		sts		TCCR3A, temp1
		do_lcd_command 0b00000001	; clear contents

		; display distance
		do_lcd_data	'D'
		do_lcd_data	'i'
		do_lcd_data	's'
		do_lcd_data	't'
		do_lcd_data	'a'
		do_lcd_data	'n'
		do_lcd_data	'c'
		do_lcd_data	'e'
		do_lcd_data	':'
		ldi		yl, low(distance)
		ldi		yh, high(distance)
		ld		temp1, y+
		ld		temp2, y
		adiw	temp2:temp1, 1
		mov		r16, temp1
		mov		r17, temp2
		display_Number_Three_digit r16, r17
		do_lcd_data	'm'
		do_lcd_command 0b11000000	; next line

		; display time
		do_lcd_data	'D'
		do_lcd_data	'u'
		do_lcd_data	'r'
		do_lcd_data	'a'
		do_lcd_data	't'
		do_lcd_data	'i'
		do_lcd_data	'o'
		do_lcd_data	'n'
		do_lcd_data	':'
		ldi		yl, low(second)
		ldi		yh, high(second)
		ld		temp1, y+
		ld		temp2, y
		adiw	temp2:temp1, 1
		mov		r16, temp1
		mov		r17, temp2
		display_Number_Three_digit r16, r17
		do_lcd_data	's'

dummy:	
		rjmp dummy

		pop		yh
		pop		yl
		pop		r17
		pop		r16
		ret

// update current status -------------------------------------------
update:
		push	r16
		push	r17
		push	r18
		push	r19
		push	r20
		push	yl
		push	yh

		ldi		yl, low(content)
		ldi		yh, high(content)		
		ld		r16, y+		; x
		ld		r17, y+		; y
		ld		r18, y+		; z
		ld		r19, y+		; direction
		ld		r20, y		; speed

		cpi		landing, 'T'	; if landing
		breq	update_LAND
		cpi		r19,'U'
		breq	update_UP
		cpi		r19,'D'
		breq	update_DOWN
		cpi		r19,'L'
		breq	update_LEFT
		cpi		r19,'R'
		breq	update_RIGHT
		cpi		r19,'F'
		breq	update_FORWARD
		cpi		r19,'B'
		breq	update_BACKWARD
		rjmp	store_update

update_LAND:
		subi	r18, 1	; z = z - 1
		cpi		r18, 0
		breq	landed
		rjmp	store_update
landed:	call	Land_Display

update_UP:
		add		r18, r20	; z = z + speed
		rjmp	store_update
update_DOWN:
		sub		r18, r20	; z = z - speed
		rjmp	store_update	
update_LEFT:
		sub		r16, r20	; x = x - speed		
		rjmp	store_update	
update_RIGHT:
		add		r16, r20	; x = x + speed
		rjmp	store_update		
update_FORWARD:
		add		r17, r20	; y = y + speed	
		rjmp	store_update	
update_BACKWARD:
		sub		r17, r20	; y = y - speed	

store_update:
		st		y , r20
		st		-y, r19
		st		-y, r18
		st		-y, r17
		st		-y, r16

check_update:
		; if <0 the value register will be greater than 128
		cpi		r16, 50
		brsh	crash_set_x
		cpi		r17, 50
		brsh	crash_set_y
		cpi		r18, 10
		brsh	crash_set_z

		; update time -----------------------
		ldi		yl, low(second)
		ldi		yh, high(second)
	
		ld		temp1, y+
		ld		temp2, y
		adiw	temp2:temp1, 1
		st		y, temp2
		st		-y, temp1

		; update distance -----------------
		ldi		yl, low(distance)
		ldi		yh, high(distance)
		ld		r16, y+
		ld		r17, y
		add		r16, r20
		adc		r17, zero_reg
		st		y, r17
		st		-y, r16

		pop		yh
		pop		yl
		pop		r20
		pop		r19
		pop		r18
		pop		r17
		pop		r16
		ret

crash_set_x:
		cpi		r16, 128			; if <0 the value register will be greater than 128
		brsh	crash_set_x_neg
		ldi		r16, 50
		jmp		crash_end
crash_set_x_neg:
		ldi		r16, 0
		jmp		crash_end

crash_set_y:
		cpi		r17, 128			; if <0 the value register will be greater than 128
		brsh	crash_set_y_neg
		ldi		r17, 50
		jmp		crash_end
crash_set_y_neg:
		ldi		r17, 0
		jmp		crash_end

crash_set_z:
		cpi		r18, 128			; if <0 the value register will be greater than 128
		brsh	crash_set_z_neg
		ldi		r18, 10
		jmp		crash_end
crash_set_z_neg:
		ldi		r18, 0
		jmp		crash_end

crash_end:
		ldi		yl, low(content)
		ldi		yh, high(content)
		st		y+, r16
		st		y+, r17
		st		y+, r18

		call	Crash


// display current status ------------------------------
display:
		push temp1
		push yl
		push yh
		clr temp1
		do_lcd_command 0b00000001	; clear contents
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		do_lcd_command 0b00010100	; cursor shifts right (blank)				
		do_lcd_data	'P'
		do_lcd_data	'O'
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		do_lcd_command 0b00010100	; cursor shifts right (blank)	
		do_lcd_command 0b00010100	; cursor shifts right (blank)			
		do_lcd_data	'D'	
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		do_lcd_data	'S'
		do_lcd_data	'P'	
		do_lcd_data	'D'			
		do_lcd_command 0b11000000	; next line

		do_lcd_data	'('
		ldi		yl, low(content)
		ldi		yh, high(content)
		ld		temp1, y+		; x
		display_Number temp1
		do_lcd_data	','
		ld		temp1, y+		;y
		display_Number temp1
		do_lcd_data ','
		ld		temp1, y+		;z
		display_Number temp1
		do_lcd_data	')'
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		ld		temp1, y+		; direction
		do_lcd_data_reg temp1
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		ld		temp1, y+		; speed
		subi	temp1,-'0'		; convert to ASCII
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		do_lcd_data_reg temp1
		do_lcd_command 0b00010100	; cursor shifts right (blank)

		pop yh
		pop yl
		pop temp1
		ret

// Crash --------------------------------------------
Crash:	
		clr		temp1
		sts		TCCR3A, temp1

		do_lcd_command 0b00000001	; clear contents
		do_lcd_data	'O'
		do_lcd_data	'o'
		do_lcd_data	'p'
		do_lcd_data	's'
		do_lcd_data	'!'
		do_lcd_data	'C'
		do_lcd_data	'R'
		do_lcd_data	'A'
		do_lcd_data	'S'
		do_lcd_data	'H'
		do_lcd_data	'E'
		do_lcd_data	'D'
		do_lcd_data	'!'

		do_lcd_command 0b11000000	; next line
		do_lcd_data	'P'
		do_lcd_data	'O'
		do_lcd_command 0b00010100	; cursor shifts right (blank)
		do_lcd_data	'('
		ldi		yl, low(content)
		ldi		yh, high(content)
		ld		temp1, y+		; x
		display_Number temp1
		do_lcd_data	','
		ld		temp1, y+		;y
		display_Number temp1
		do_lcd_data ','
		ld		temp1, y+		;z
		display_Number temp1
		do_lcd_data	')'
		
crash_flash:
		ser	r17
		out	PORTC, r17
		call sleep_long
		do_lcd_command 0b00011100	;  dislpay shifts right (blank)
		call sleep_long	
		do_lcd_command 0b00011100	;  dislpay shifts right (blank)
		call sleep_long	
		do_lcd_command 0b00011100	;  dislpay shifts right (blank)
		clr	r17
		out	PORTC, r17	
		call sleep_long	
		do_lcd_command 0b00011000	;  dislpay shifts left (blank)
		call sleep_long	
		do_lcd_command 0b00011000	;  dislpay shifts left (blank)
		call sleep_long	
		do_lcd_command 0b00011000	;  dislpay shifts left (blank)
		rjmp crash_flash
		ret


// Return keyboard input value -------------------------
Get_Keyboard:

		push	row
		push	col
		push	rmask
		push	cmask
		push	temp1
		push	temp2

		clr		row
		clr		col
		clr		rmask
		clr		cmask
		clr		temp1
		clr		temp2
		clr		cov_val

keyboard:
		ldi cmask, INITCOLMASK ; initial column mask
		clr col ; initial column

colloop:
		cpi col, 4
		breq keyboard ; if all keys are scanned, repeat.
		sts PORTL, cmask ; otherwise, scan a column
		
		
		ldi temp1, 0x5F ; slow down the scan operation.
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
		rjmp rowloop

nextcol: ; if row scan is over
		lsl cmask ;shift left cmask (1110 -> 1101)
		inc col ; increase column value
		rjmp colloop ; go to the next column

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
		rjmp convert_end

letters:
		ldi temp1, 'A'
		add temp1, row ; Get the ASCII value for the key
		rjmp convert_end

symbols:
		cpi col, 0 ; Check if we have a star
		breq star
		cpi col, 1 ; or if we have zero
		breq zero
		ldi temp1, '#' ; if not we have hash
		rjmp convert_end

star:
		ldi temp1, '*' ; Set to star
		rjmp convert_end

zero:
		ldi temp1, '0'

convert_end:
		lds temp2, PINL ; read PORTL
		andi temp2, ROWMASK ; get the keypad output value (PL3-0, 0x0X #1110)
		cpi temp2, 0x0F ; check if any row is low
		brne convert_end
		mov	cov_val,temp1

		pop		temp2
		pop		temp1
		pop		cmask
		pop		rmask
		pop		col
		pop		row
		ret


// LCD functions -----------------------------------------------------
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

// Delay functions -------------------------------------------------
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU/4/1000 - 4

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

sleep_long:	; r16 = 80 400ms
		push r16
		ldi	r16, 80
sleep_long_loop:
		rcall sleep_5ms
		subi r16, 1
		brne  sleep_long_loop
		pop	r16
		ret