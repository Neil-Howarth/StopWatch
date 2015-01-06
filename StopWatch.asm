;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Neil Howarth
; 11/21/14
; CPE 310: MicroProcessors I
; Stopwatch project
; Using timer0 create a stopwatch through putty on Arduino
; The goal is to count overflows so that the resolution is seconds. 

;;;;;;;;;;;;;;;; MACROS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.include "m328pdef.inc"
.org 0

.macro set_sp ; initialize the stack
	ldi r16,low(ramend)
	out spl, r16
	ldi r16,high(ramend)
	out sph, r16
.endm

.macro init_uart ; initialze uart
	.equ fcpu = 16000000
	.equ baud = 9600 ; 115200
	.equ mybaud = fcpu/(16*baud)-1

	ldi r16,low(mybaud)
	sts ubrr0l, r16
	ldi r16,high(mybaud)
	sts ubrr0h, r16
.endm

.macro set_zptr ; set the z pointer to point at a chosen location
	ldi zl,low(@0<<1)
	ldi zh,high(@0<<1)
.endm

.macro init_txrx ; initialize transmit and receive
	ldi r16,(1<<rxen0)|(1<<txen0)
	sts ucsr0b,r16
.endm

.macro init_T0 ; initialize T0
	ldi r16,(1<<CS00)|(1<< CS02)
	out TCCR0B, r16 ; Timer clock = system clock/1024
	ldi r16, 1<<TOV0
	out TIFR0, r16 ; clear TOV0/ clear pending interupts
.endm

.macro hex2dec ;convert hex to an decimal value in ascii

	mov r26, @0  ; a 2 digit number in a register
	ser r27

	l10:
	inc r27
	subi r26,10
	brcc l10
	subi r26,-10

	set_zptr asc_table
	mov r17,r26
	andi r17,0x0F
	add Zl,r17
	lpm r17,z ; r17 holds the ones digit

	set_zptr asc_table
	mov r18,r27
	andi r18,0x0F
	add Zl,r18
	lpm r18,z ; r18 holds the tens digit

.endm

.macro tx_reg ; transmit the ascii register value to putty
	tx:
	lds r20,ucsr0a
	sbrs r20,udre0
	rjmp tx
	sts udr0,@0
.endm

;;;;;;;;;;;;;;;; MAIN ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

init_uart
init_txrx

; part 1 - display string

set_zptr str
rcall transmit_str

; part 2 - receive a character and start the timer

rcall receive
rjmp main

; part 3 - when the number of overflows is one second, increment the number of seconds and clear the overflow

; part 4 - monitor the RXC0 flag, make a keystroke to stop the timer

main:
	init_T0
	ldi r23,0 ; overflow counter
	ldi r24,0 ; second counter
	ldi r25,0 ; minute counter
	
	lds r16,udr0 

loop:

	in r16, TIFR0
	sbrs r16, TOV0
	rjmp loop
	ldi r16, (1<<TOV0)
	out TIFR0,r16 
	inc r23 ; increase # of overflows
	cpi r23, 61 ; 61 overflows takes 1 second
	brne loop
	inc r24 ; +1 seconds
	eor r23, r23 ; reset overflows

	lds r16,ucsr0a

	cpi r24, 60 ; check if 60 seconds have passed
	brne endloop
	
	eor r24,r24 ; reset seconds
	inc r25 ; +1 minutes

	endloop:

sbrs r16,rxc0 ; skip if something was received
RJMP loop

; part 5 - display the time in MM:SS

	;print minutes
	hex2dec r25
	tx_reg r18
	tx_reg r17

	;print colon
	set_zptr colon
	rcall transmit_str

	;print seconds
	hex2dec r24
	tx_reg r18
	tx_reg r17

here: rjmp here ; absorbing loop / end of program

;;;;;;;;;;;;;;;; SubFunctions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

transmit_str: ; transmits a string from flash to putty
	lds r20,ucsr0a
	sbrs r20,udre0
	rjmp transmit_str
	lpm r20,z+
	sts udr0,r20
	cpi r20,0
	brne transmit_str
ret

receive: ; receives a character from putty
	lds r21,ucsr0a
	sbrs r21,rxc0
	rjmp receive
	lds r16,udr0
ret

;;;;;;;;;;;;;;;; Strings ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.org 0x100

colon: .db ":",0

str:	.db "Press any key to start the clock: ",0

asc_table: .db "0123456789ABCDEF",0



