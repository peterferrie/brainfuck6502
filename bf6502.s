; assemble with ACME
!to "bf1",plain
!CPU 6502
*=$300

; Title: BrainFuck 6502 Interpreter for the Apple ][ //e
;
; Platform: Apple ][ //e
; By: Peter Ferrie
; Date: Jul, 2015
; Description: 152 Byte Interpreter of BrainFuck
; License: BSD "Sharing is Caring!"
; Inspired by Michael Pohoreski's 187 Byte version
;
; Discussion:
; https://groups.google.com/d/msg/comp.emulators.apple2/Om3JKqDZoEA/cwa5U1Hr3TAJ
;
; Definition:
; http://en.wikipedia.org/wiki/Brainfuck
;
; >  ++pData;
; <  --pData;
; +  ++(*pData);
; -  --(*pData);
; .  putchar(*pData);
; ,  *pData=getchar();
; [  while (*pData) { // if( *pData == 0 ), pCode = find_same_depth ( ']' );
; ]  }                // if( *pData != 0 ), pCode = find_same_depth ( '[' );
;
; Reference Tests:
; http://esoteric.sange.fi/brainfuck/bf-source/prog/tests.b
;
; Examples:
; http://esoteric.sange.fi/brainfuck/bf-source/prog/
; http://esolangs.org/wiki/Brainfuck#Implementations
; http://www.muppetlabs.com/~breadbox/bf/standards.html
; http://software.xfx.net/utilities/vbbfck/index.php
; http://nesdev.parodius.com/6502.txt

; ===================================================================

OPCODE          =        $F0   ; Applesoft SPEED @ $F1, Flash mask $F3
OPFUNCPTR       =        $F8   ; Applesoft ROT @ $F9
                                 ; Applesoft Free soace $EB .. $EF
CUR_DEPTH       =        $EE   ; // current nested depth
NUM_BRACKET     =        $EF   ; // depth to find[]

BFPC            =        $3C   ; BFPC/pCode same as A1L/H
DATA            =        $40   ; DATA/pData same as A3L/H

HGR             =        $F3E2
HGR2            =        $F3D8

RDKEY           =        $FD0C

NXTA1           =        $FCBA
NXTA1_8         =        $FCC2 ; standard entry point is NXTA1 = $FCBA

STOR            =        $FE0B
STOR_6          =        $FE11 ; standard entry point is STOR = $FE0B

CLRTEXT         =        $C050
SETTEXT         =        $C051

RDKEY           =        $FD0C
COUT            =        $FDED ; trashes A, Y

; Used to read start address of $0806 = first Applesoft token
; If you use Applesoft as a helper text entry such as
;    0 "...brainfuck code..."
; You must manually move the BF code to $6000 via:
;     CALL -151
;     6000<806.900M
; You must also move the opcode table to $F0
;     300G

;       STA CLRTEXT     ; 8D 50 C0 ; Optional: C051 or C050

        JSR HGR2        ; 20 D8 F3 ; Clear top 8K of data
        JSR HGR         ; 20 E2 F3 ; Clear bot 8K of data

        STY BFPC        ; 84 3C    ;
        STY DATA        ; 84 40    ;
; Code needs to end with a zero byte 
; DEFAULT:  $60/$20 for   big code ($6000..$BFFF = 24K) / medium data ($2000..$5FFF = 16K)
; Optional: $08/$10 for small code ($0800..$0FFF =  2K) / large  data ($1000..$BFFF = 44K)
; Note: You will also need to zero memory if you use large data
        LDA #$60        ; A9 60    ; Start CODE buffer
        STA BFPC+1      ; 85 3D    ;
        LDA #$20        ; A9 20    ; Start DATA buffer
        STA DATA+1      ; 85 41    ;
FETCH
        LDA (BFPC),Y    ; B1 3C    ;
        BEQ EXIT        ; F0 1C    ;
        JSR INTERPRET   ; 20 20 03 ;

        JSR NXTA1_8     ; 20 C2 FC ;
        LDY #$00        ; A0 00    ; because COUT trashes Y
        BEQ FETCH       ; F0 F2    ; branch always
INTERPRET

        LDX #$07        ; A2 07    ; 8 Instructions
FIND_OP
        CMP OPCODE,X    ; D5 F0    ; table of opcodes (char)
        BNE NEXT        ; D0 06    ; ignore non-tokens, allows for comments
        LDA #$03        ; A9 03    ; high byte of this code address
        PHA             ; 48       ;
        LDA OPFUNCPTR,X ; B5 F8    ; function pointer table (address)
        PHA             ; 48       ;
NEXT
        DEX             ; CA       ;
        BPL FIND_OP     ; 10 F3    ;
        LDA (DATA),Y    ; B1 40    ; optimization: common code
        TAX             ; AA       ; cache value
EXIT
        RTS             ; 60       ; 1) exit to caller,
                                   ; 2) relative jsr to our bf_*(), or
                                   ; 3) exit our bf_*()

BF_IF                   ;          ; if( *pData == 0 ) pc = ']'
        INC CUR_DEPTH   ; E6 EE    ; *** depth++
        TXA             ; 8A       ; optimization: common code
        BNE EXIT        ; D0 FA    ; optimization: BEQ .1, therefore BNE RTS
INC_BRACKET
        INX             ; E8       ; *** inc stack
-                                  ; Sub-Total Bytes #101
        JSR NXTA1_8     ; 20 C2 FC ; optimization: INC A1L, BNE +2, INC A1H, RTS
        LDA (BFPC), Y   ; B1 3C    ;
        CMP #'['        ; C9 5B    ; ***
        BEQ INC_BRACKET ; F0 F6    ;
        CMP #']'        ; C9 5D    ; ***
        BNE -           ; D0 F3    ;
        DEX             ; CA       ; *** dec stack
        BNE -           ; D0 F0    ;
        BEQ EXIT        ; F0 E7    ;
BF_FI                   ;          ; if( *pData != 0 ) pc = '['
        DEC CUR_DEPTH   ; C6 EE    ; depth--
        INY             ; C8       ; compensate for unconditional NXTA1_8
        LDX CUR_DEPTH   ; A6 EE    ; match_depth = depth
--
        INX             ; E8       ;
        INX             ; E8       ; *** inc stack
DEC_BRACKET
        DEX             ; CA       ; *** dec stack
-
        LDA BFPC        ; A5 3C    ;
        BNE +           ; D0 02    ;
        DEC BFPC+1      ; C6 3D    ;
+
        DEC BFPC        ; C6 3C    ;

        LDA (BFPC),Y    ; B1 3C    ;
        CMP #']'        ; C9 5D    ;
        BEQ DEC_BRACKET ; F0 F1    ;
        CMP #'['        ; C9 5B    ;
        BNE -           ; D0 EE    ;
        CPX CUR_DEPTH   ; E4 EE    ;
        BNE --          ; D0 E7    ;
        BEQ EXIT        ; F0 C7    ;
BF_IN
        JSR RDKEY       ; 20 0C FD ; trashes Y
BF_OUT
        EOR #$80        ; 49 80    ; convert 7-bit ASCII to 8-bit Apple Text for output
                                   ; convert 8-bit Apple Text to 7-bit ASCII for input
        BPL STORE_DATA  ; 10 13    ; always for input
        JMP COUT        ; 4C ED FD ; trashes A, Y
BF_NEXT
        JMP STOR_6      ; 4C 11 FE ; optimization: INC A3L, BNE +2, INC A3H, RTS
BF_PREV
        LDA DATA        ; A5 40    ;
        BNE +           ; D0 02    ;
        DEC DATA+1      ; C6 41    ;
+
        DEC DATA        ; C6 40    ;
        RTS             ; 60       ;
BF_INC
        INX             ; E8       ; optimization: n+2-1 = n+1
        INX             ; E8       ; optimization: n+2-1 = n+1
BF_DEC
        DEX             ; CA       ;
        TXA             ; 8A       ;
STORE_DATA
        STA (DATA),Y    ; 91 40    ;
        RTS             ; 60       ;

!pseudopc $F0 {
OPCODE  !text ",.[<]>-+";          ; sorted: 2B 2C 2D 2E 3C 3E 5B 5D
OPFUNCPTR               ;          ; by usage: least commonly called to most
        !byte <BF_IN  -1; 4D       ; ,
        !byte <BF_OUT -1; 54       ; .
        !byte <BF_IF  -1; 59       ; [
        !byte <BF_PREV-1; 3A       ; <
        !byte <BF_FI  -1; 7F       ; ]
        !byte <BF_NEXT-1; 37       ; >
        !byte <BF_DEC -1; 46       ; -
        !byte <BF_INC -1; 43       ; +
}

