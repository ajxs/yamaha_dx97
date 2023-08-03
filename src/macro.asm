; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; macro.asm
; ==============================================================================
; DESCRIPTION:
; This file contains all macro definitions.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; DASM HD6303 MACROS
; As found at:
; https://github.com/dasm-assembler/dasm/blob/master/test/broken6303hack.asm
; ==============================================================================
    .MAC hack
        dc.b {1}     ; opcode
        dc.b {2}     ; immediate value
        dc.b {3}     ; zero-page address
    .ENDM

    .MAC aimd
        hack $71,{1},{2}
    .ENDM

    .MAC aimx
        hack $61,{1},{2}
    .ENDM

    .MAC oimd
        hack $72,{1},{2}
    .ENDM

    .MAC oimx
        hack $62,{1},{2}
    .ENDM

    .MAC eimd
        hack $75,{1},{2}
    .ENDM

    .MAC eimx
        hack $65,{1},{2}
    .ENDM

    .MAC timd
        hack $7b,{1},{2}
    .ENDM

    .MAC timx
        hack $6b,{1},{2}
    .ENDM


; ==============================================================================
; Long Delay Macro.
; Delay by decrementing IX so it wraps around, then decrement until zero.
; @TAKEN_FROM_DX7_FIRMWARE
;
; REGISTERS MODIFIED:
; * IX
;
; ==============================================================================
    .MAC DELAY_LONG
        PSHX
        LDX     #0
.delay_long_loop$:
        DEX
        BNE     .delay_long_loop$
        PULX
    .ENDM


; ==============================================================================
; Delay Short Macro.
; Delay by using a BRN instruction targeting the next memory address.
; @TAKEN_FROM_DX9_FIRMWARE
; ==============================================================================
    .MAC DELAY_SHORT
        BRN     *+2
    .ENDM


; ==============================================================================
; Delay Single Macro.
; Emits a single delay cycle.
; ==============================================================================
    .MAC DELAY_SINGLE
        PSHX
        PULX
    .ENDM


; ==============================================================================
; Resets the status of the synth's operators.
; Sets all of the synth's operators as being enabled.
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
    .MAC RESET_OPERATOR_STATUS
        LDAA    #$3F
        STAA    patch_edit_operator_status
    .ENDM


; ==============================================================================
; Cycles a button's 'sub-function'.
; This will increment the sub-function up to its maximum value, and then loop
; around to zero.
;
; ARGUMENTS:
; * 1: The variable holding the sub-function.
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
    .MAC TOGGLE_BUTTON_SUB_FUNCTION
        LDAA    {1}
        INCA
        ANDA    #1
        STAA    {1}
    .ENDM

; ==============================================================================
; Cycles a button's 'sub-function' from 0-2.
; This will increment the sub-function up to its maximum value of 2, and then
; wraps back around to a value of zero.
;
; ARGUMENTS:
; * 1: The variable holding the sub-function.
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
    .MAC CYCLE_3_BUTTON_SUB_FUNCTIONS
        LDAA    {1}
        INCA
        CMPA    #3
        BCS     .store_sub_function_value
        CLRA
.store_sub_function_value:
        STAA    {1}
    .ENDM


; ==============================================================================
; Clears the specified number of bytes in the specified buffer.
;
; ARGUMENTS:
; * 1: The buffer to be cleared.
; * 2: The number of bytes to clear.
;
; REGISTERS MODIFIED:
; * IX
;
; ==============================================================================
    .MAC CLEAR_BUFFER
        LDX     #{1}
.clear_buffer_loop:
        CLR     0,x
        INX
        CPX     #({1} + {2})
        BNE     .clear_buffer_loop
    .ENDM
