	;Example of I2C communication with the PIC12F1840
	;The slave in this case is an OLED display (SH1107)

	PROCESSOR PIC12F1840
	include <p12f1840.inc>
	__CONFIG _CONFIG1, _MCLRE_OFF  & _FOSC_INTOSC & _WDTE_OFF
	__CONFIG _CONFIG2, _LVP_OFF & _PLLEN_OFF
   			
	SLAVE_ADDR_W EQU b'01111000' ;slave address for write
	SLAVE_ADDR_R EQU b'01111001' ;slave address for read


	ORG 0 
	
	CALL INIT
	
	; Turns on the display
	CALL MSSP_SEND_START
	MOVLW SLAVE_ADDR_W
	CALL MSSP_SEND_BYTE
	MOVLW b'00000000' ; Control byte: Last control byte, data byte = command 
	CALL MSSP_SEND_BYTE
	MOVLW b'10101111' ; Data byte: TURN ON
	CALL MSSP_SEND_BYTE
	CALL MSSP_SEND_STOP

	; clear screen
	MOVLW b'00010000' ;start at page 15
	MOVWF 0x23
PAGE_LOOP
	CALL MSSP_SEND_START 
	MOVLW SLAVE_ADDR_W ;SLAVE ADDRESS
	CALL MSSP_SEND_BYTE
	MOVLW b'10000000' ; Next two bytes are a data byte and another control byte, COMMAND
	CALL MSSP_SEND_BYTE
	MOVLW b'00000000' ;memory lower 4 bits
	CALL MSSP_SEND_BYTE
	MOVLW b'10000000'; Next two bytes are a data byte and another control byte, COMMAND
	CALL MSSP_SEND_BYTE
	MOVLW b'00010010'  ;memory HIGHER 3 bits
	CALL MSSP_SEND_BYTE
	MOVLW b'10000000' ; Next two bytes are a data byte and another control byte, COMMAND
	CALL MSSP_SEND_BYTE
	MOVLW b'10110000' ;start at page 16
	ADDWF 0x23,0
	DECF WREG,0
	CALL MSSP_SEND_BYTE
	MOVLW b'01000000'
	CALL MSSP_SEND_BYTE
	MOVLW b'01000000' ;repeat 64 times
	MOVWF 0x22
REPEAT
	MOVLW b'11111111' ;Pattern
	CALL MSSP_SEND_BYTE
	DECFSZ 0x22, 1
	GOTO REPEAT    
	CALL MSSP_SEND_STOP
	DECFSZ 0x23,1
	GOTO PAGE_LOOP
	RETURN



	GOTO $


	
INIT
	;RA1 = input (SCL)
	;RA2 = input (SDA)
	;RA5 = output (RST)
	BANKSEL PORTA
	CLRF PORTA
	BANKSEL LATA
	CLRF LATA
	BANKSEL ANSELA
	CLRF ANSELA
	MOVLW b'00000110' 
	TRIS 5 ;TRISA

	BANKSEL OSCCON
	MOVLW B'01101000' ;0 = no 4XPLL, 1101 = 4 MHz HF, 00 = Clock defined in CONFIG1
	MOVWF OSCCON
	
	;The Baud Rate Generator (BRG) reload value
	;Resulting baudrate will be (Fosc/(4*(SSP1ADD + 1)) = 4000000/40 = 100 kHz
	BANKSEL SSP1ADD
	MOVLW b'00001001' 
	MOVWF SSP1ADD
	
	BANKSEL SSP1CON1
	MOVLW b'00101000' ; I2C Master mode. configure SDA/SCL.
	MOVWF SSP1CON1 
	
	;RESET 
	BANKSEL PORTA
	BCF PORTA, RA5 
	BSF PORTA, RA5 ;set RST high

	RETURN


	;================= MSSP routines ========================
	; Those routines are are slave-agnostic 

	; Byte is expected in W register
MSSP_SEND_BYTE	
	BANKSEL SSP1BUF
	MOVWF SSP1BUF 
	CALL MSSP_WAIT_ACK
	CALL MSSP_WAIT
	RETURN

	; Byte is returned in W
MSSP_READ_BYTE	
	BANKSEL SSP1CON2    	
	BSF SSP1CON2, RCEN 
	CALL MSSP_WAIT	 ; Waits SSP1IF to be set, then clears it
	BANKSEL SSP1STAT ;BF=1 -> buffer has been read
	BTFSS SSP1STAT, BF ;Bit Test f, Skip if Set  
	BRA $-1
	BANKSEL SSP1BUF ;read it (automatically clears BF)
	MOVF SSP1BUF,0
	RETURN

;Waiting for MSSP module to be ready
;by checking PIR1 - SSP1IF bit has been set
;then the bit is cleared
MSSP_WAIT
	BANKSEL PIR1
	BTFSS PIR1, SSP1IF
	BRA $-1
	BCF PIR1,SSP1IF
	RETURN

; Waiting for an ACK from the slave
; By checking the ACKSTAT bit of SSP1CON2. 0 = ACK was received
MSSP_WAIT_ACK
	BANKSEL SSP1CON2
	BTFSC SSP1CON2, ACKSTAT  
	BRA $-1
	RETURN

MSSP_SEND_NACK
	BANKSEL SSP1CON2
	BSF SSP1CON2, ACKDT ;nack value sent to slave (0)
	BSF SSP1CON2, ACKEN ; initiate NACK
	RETURN

; Initiate START condition & wait for MSSP	
MSSP_SEND_START 	
	BANKSEL SSP1CON2
	BSF SSP1CON2,SEN 
	CALL MSSP_WAIT
	RETURN

; Initiate RESTART condition & wait for MSSP
MSSP_SEND_RESTART
	BANKSEL SSP1CON2
	BSF SSP1CON2,RSEN ; Generate RESTART Condition
	CALL MSSP_WAIT
	RETURN

; Initiate STOP condition & wait for MSSP
MSSP_SEND_STOP
	BANKSEL SSP1CON2
	BSF SSP1CON2,PEN
	CALL MSSP_WAIT
	RETURN
 
	END