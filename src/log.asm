; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; ==============================================================================
; voice/add.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the subroutines used to add a voice with a new note, in
; response to an incoming 'Note On' MIDI message, or a key being pressed.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; Logarithmic Curve Table.
; Used in parsing various operator values.
; Length: 100.
; ==============================================================================
table_curve_log:
    DC.B $7F
    DC.B $7A
    DC.B $76
    DC.B $72
    DC.B $6E
    DC.B $6B
    DC.B $68
    DC.B $66
    DC.B $64
    DC.B $62
    DC.B $60
    DC.B $5E
    DC.B $5C
    DC.B $5A
    DC.B $58
    DC.B $56
    DC.B $55
    DC.B $54
    DC.B $52
    DC.B $51
    DC.B $4F
    DC.B $4E
    DC.B $4D
    DC.B $4C
    DC.B $4B
    DC.B $4A
    DC.B $49
    DC.B $48
    DC.B $47
    DC.B $46
    DC.B $45
    DC.B $44
    DC.B $43
    DC.B $42
    DC.B $41
    DC.B $40
    DC.B $3F
    DC.B $3E
    DC.B $3D
    DC.B $3C
    DC.B $3B
    DC.B $3A
    DC.B $39
    DC.B $38
    DC.B $37
    DC.B $36
    DC.B $35
    DC.B $34
    DC.B $33
    DC.B $32
    DC.B $31
    DC.B $30
    DC.B $2F
    DC.B $2E
    DC.B $2D
    DC.B $2C
    DC.B $2B
    DC.B $2A
    DC.B $29
    DC.B $28
    DC.B $27
    DC.B $26
    DC.B $25
    DC.B $24
    DC.B $23
    DC.B $22
    DC.B $21
    DC.B $20
    DC.B $1F
    DC.B $1E
    DC.B $1D
    DC.B $1C
    DC.B $1B
    DC.B $1A
    DC.B $19
    DC.B $18
    DC.B $17
    DC.B $16
    DC.B $15
    DC.B $14
    DC.B $13
    DC.B $12
    DC.B $11
    DC.B $10
    DC.B $F
    DC.B $E
    DC.B $D
    DC.B $C
    DC.B $B
    DC.B $A
    DC.B 9
    DC.B 8
    DC.B 7
    DC.B 6
    DC.B 5
    DC.B 4
    DC.B 3
    DC.B 2
    DC.B 1
    DC.B 0
