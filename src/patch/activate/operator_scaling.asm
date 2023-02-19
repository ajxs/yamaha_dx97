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
; patch/activate/operator_scaling.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the routine for 'activation' of the individual operator
; keyboard scaling.
; This file includes the associated data tables.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_ACTIVATE_OPERATOR_KEYBOARD_SCALING
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
patch_activate_operator_keyboard_scaling:       SUBROUTINE
    LDX     #patch_edit_op_4_kbd_scaling_level
    LDAB    <patch_activate_operator_offset
    ABX
    LDAA    1,x
    ASLA
    ASLA
    ASLA
    LDAB    0,x
    ANDB    #7
    ABA
    LDX     #egs_operator_keyboard_scaling
    LDAB    <patch_activate_operator_number
    ABX
    STAA    0,x

    RTS


; ==============================================================================
; PATCH_ACTIVATE_OPERATOR_PARSE_KEYBOARD_SCALING
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
patch_activate_operator_parse_keyboard_scaling: SUBROUTINE
    LDX     #patch_edit_op_4_kbd_scaling_rate
    LDAB    <patch_activate_operator_offset
    ABX
    LDAA    0,x
    JSR     patch_convert_serialised_value_to_internal
    STAA    <keyboard_scaling_scaled_rate

; Load OSC FREQ COARSE?
    LDAB    3,x
    CMPB    #20

; If less than 20, branch.
    BCS     loc_D32E

    LDAA    #99
    SUBA    3,x
    BRA     loc_D334

loc_D32E:
    LDX     #table_operator_keyboard_scaling_D361
    ABX
    LDAA    0,x

loc_D334:
    ASLA
    STAA    <keyboard_scaling_unknown
    LDX     #operator_keyboard_scaling
    LDAB    <patch_activate_operator_number
    LDAA    #29
    MUL
    ABX
    STX     <copy_ptr_dest
    CLRB

loc_D343:
    PSHB
    LDX     #table_operator_keyboard_scaling_D375
    ABX
    LDAA    0,x
    LDAB    <keyboard_scaling_scaled_rate
    MUL
    ADDA    <keyboard_scaling_unknown
    BCC     loc_D353

    LDAA    #$FF

loc_D353:
    LDX     <copy_ptr_dest
    STAA    0,x
    INX
    STX     <copy_ptr_dest
    PULB
    INCB
    CMPB    #$1D
    BNE     loc_D343

    RTS

table_operator_keyboard_scaling_D361:
    DC.B $7F, $7A, $76, $72, $6E    ; 0
    DC.B $6B, $68, $66, $64, $62    ; 5
    DC.B $60, $5E, $5C, $5A, $58    ; 10
    DC.B $56, $55, $54, $52, $51    ; 15

table_operator_keyboard_scaling_D375:
    DC.B 0, 1, 2, 3, 4, 5, 6        ; 0
    DC.B 7, 8, 9, $B, $E, $10       ; 7
    DC.B $13, $17, $1C, $21, $27    ; 13
    DC.B $2F, $39, $43, $50, $5F    ; 18
    DC.B $71, $86, $A0, $BE, $E0    ; 23
    DC.B $FF                        ; 28
