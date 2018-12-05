; written by Kun Zhang z5086704@zmail.unsw.edu.au
; last modified: Aug 11, 2015
; Lab 1 COMP9032

.include "m2560def.inc"


;Task 2
.def a = r16
.def n = r17
.def i = r18
.def j = r19
.def sum_lo = r20
.def sum_hi = r21
.def ai_lo =r22
.def ai_hi = r23

;initialize variables
clr sum_lo
clr sum_hi

ldi a,0x05
ldi n,0x03
ldi i,0x01

main:	
outer_loop:	
		cp n,i		
		brlo end		;if i>n, loop ends
		ldi j,0x01		;set counter j = 1
		mov ai_lo, a	;ai = a
		clr ai_hi		;
		rjmp inner_loop

resume:	add sum_lo, ai_lo	;sum += ai
		adc sum_hi, ai_hi
		inc i				;i++
		rjmp outer_loop		

inner_loop:
		cp j,i		
		brge resume	        ;if j>=i, break to outer loop
		
		mul	ai_lo,a		        ;r1:r0 = ai*a
		movw ai_hi:ai_lo,r1:r0	;store in ai
		mul ai_hi,a				;r1:r0 = prd_hi*a
		add ai_lo,r0	
		adc ai_hi,r1			;ai *= a
		
		inc j					; jm++
		rjmp inner_loop
		
end:
		rjmp end


/* C code

#include <stdio.h>

void task2(const int ,const int , int );
int sum=0;
const int a = 5;
const int n = 3;
int i=1,j,ai;

void main(){

	
	i = 1;
	while(i<=n){
		j = 1;
		ai = a;
		while(j<i){
			ai *= a;
			j += 1;
		}
		sum += ai;		
		i += 1;
		printf("%d\n",sum);
	}

	getchar();
}

*/

	


