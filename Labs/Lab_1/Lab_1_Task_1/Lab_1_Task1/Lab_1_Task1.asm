; written by Kun Zhang z5086704@zmail.unsw.edu.au
; last modified: Aug 4, 2015
; Lab 1 COMP9032


;Task 1

.include "m64def.inc"
.def a = r16
.def b = r17

loop:	cp	a, b	;compare a and b
		breq end	;if a==b, loop ends
		cp a, b
		brlo else	;if a<b
		sub a,b		;if a>b, a = a - b
		rjmp loop
else:	sub b,a;	; b = b - a
		rjmp loop

end:	nop	