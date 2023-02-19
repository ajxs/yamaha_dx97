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
; patch/validate.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions and code used for validating incoming patches.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_VALIDATE
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Validates the patch data currently loaded into the synth's 'Edit Buffer'.
; This subroutine iterates over all of the patch data, comparing it to a
; table of valid maximum values. If the value being compared exceeds the
; maximum value, it will be set to the maximum.
;
; ==============================================================================
patch_validate:                                 SUBROUTINE
    LDAB    #4
    LDX     #patch_buffer_edit
    STX     <memcpy_ptr_src

.validate_operator_loop:
; Validate an individual operator.
; Reloads the table of maximum values with each iteration to start loading
; the maximum values from the start of the table.
    LDX     #table_max_patch_values
    STX     <memcpy_ptr_dest
    PSHB
    LDAB    #15
    BSR     patch_validate_fix_max_values
    PULB
    DECB
    BNE     .validate_operator_loop

; Validate the remaining non-operator values.
    LDAB    #10
    BRA     patch_validate_fix_max_values


; ==============================================================================
; PATCH_VALIDATE_FIX_MAX_VALUES
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
;
; ==============================================================================
patch_validate_fix_max_values:                  SUBROUTINE
    LDX     <memcpy_ptr_dest
    LDAA    0,x
    INX
    STX     <memcpy_ptr_dest
    LDX     <memcpy_ptr_src

; Test whether the patch data byte exceeds the maximum value.
; If so, set it to the maximum value. If not, branch.
    CMPA    0,x
    BCC     .increment_pointer
    STAA    0,x

.increment_pointer:
    INX
    STX     <memcpy_ptr_src
    DECB
    BNE     patch_validate_fix_max_values

    RTS

; ==============================================================================
; Maximum patch value table.
; This table contains the maximum values for each of the values in a patch.
; This is used for validation of incoming data.
; ==============================================================================
table_max_patch_values:
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B 7
    DC.B 3
    DC.B $63
    DC.B $1F
    DC.B $63
    DC.B $E
    DC.B 7
    DC.B 7
    DC.B 1
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B 5
    DC.B 7
    DC.B $18
