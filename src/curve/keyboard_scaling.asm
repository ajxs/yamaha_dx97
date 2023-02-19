; ==============================================================================
; Exponential Keyboard Scaling Curve Table.
; Used when parsing the operator keyboard scaling.
; Length: 36.
; ==============================================================================
table_curve_keyboard_scaling_exponential:
    DC.B 0, 1, 2, 3, 4, 5, 6
    DC.B 7, 8, 9, $B, $E, $10
    DC.B $13, $17, $1C, $21, $27
    DC.B $2F, $39, $43, $50, $5F
    DC.B $71, $86, $A0, $BE, $E0
    DC.B $FF, $FF, $FF, $FF, $FF
    DC.B $FF, $FF, $FF

; ==============================================================================
; Linear Keyboard Scaling Curve Table.
; Used when parsing the operator keyboard scaling.
; Length: 36.
; ==============================================================================
table_curve_keyboard_scaling_linear:
    DC.B 0, 8, $10, $18
    DC.B $20, $28, $30, $38, $40
    DC.B $48, $50, $58, $60, $68
    DC.B $70, $78, $80, $88, $90
    DC.B $98, $A0, $A8, $B2, $B8
    DC.B $C0, $C8, $D0, $D8, $E0
    DC.B $E8, $F0, $F8, $FF, $FF
    DC.B $FF, $FF
