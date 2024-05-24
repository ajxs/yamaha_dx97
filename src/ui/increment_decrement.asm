; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; ui/input/increment_decrement.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE36B
; DESCRIPTION:
; Handles incrementing, or decrementing the actively selected edit parameter.
; This subroutine is triggered by the main front-panel 'Yes/No' button input
; handler.
;
; ARGUMENTS:
; Registers:
; * ACCA: The UI Input Mode.
; * ACCB: The triggering button code. In this case, either YES(1), or NO(2).
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI_INCREMENT_DECREMENT
; ==============================================================================
ui_increment_decrement_parameter:               SUBROUTINE
    TST     patch_compare_mode_active
    BEQ     .load_parameter_address

; This ensures that if 'Compare Mode' is active, only function parameters can
; be modified using the increment/decrement functionality.
    LDX     ui_active_param_address
    CPX     #null_edit_parameter
    BCS     .exit

.load_parameter_address:
    LDX     ui_active_param_address

; Decrement ACCB to convert it to a boolean value.
; 0 = Yes/Up, 1 = Down/No.
    DECB
    BNE     .decrement_parameter

; Increment the value of the actively edited parameter.
; If it is currently at its maximum, exit.
    LDAA    0,x
    CMPA    ui_active_param_max_value
    BEQ     .exit

    INCA
    BRA     ui_update_numeric_parameter

.decrement_parameter:
; Decrement the value of the actively edited parameter.
; If it is already at zero, exit.
    LDAA    0,x
    BEQ     .exit

    DECA
    BRA     ui_update_numeric_parameter

.exit:
    RTS
