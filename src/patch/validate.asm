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
; @TAKEN_FROM_DX9_FIRMWARE
; @REMADE_FOR_6_OP
; DESCRIPTION:
; Validates the patch data currently loaded into the synth's 'Edit Buffer'.
; This subroutine iterates over all of the patch data, comparing it to a
; table of valid maximum values. If the value being compared exceeds the
; maximum value, it will be set to the maximum.
;
; ==============================================================================
patch_validate:                                 SUBROUTINE
    LDAB    #6
    LDX     #patch_buffer_edit
    STX     <memcpy_ptr_src

.validate_operator_loop:
; Validate an individual operator.
; Reloads the table of maximum values with each iteration to start loading
; the maximum values from the start of the table.
    LDX     #table_max_patch_values
    STX     <memcpy_ptr_dest
    PSHB
    LDAB    #PATCH_DX7_UNPACKED_OP_STRUCTURE_SIZE
    BSR     patch_validate_fix_max_values
    PULB
    DECB
    BNE     .validate_operator_loop

; Validate the remaining non-operator values.
    LDAB    #19
    BRA     patch_validate_fix_max_values


; ==============================================================================
; PATCH_VALIDATE_FIX_MAX_VALUES
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @REMADE_FOR_6_OP
; DESCRIPTION:
; Validates patch data against a table of maximum values.
; If an individual byte of patch data exceeds the maximum as specified in the
; table, it is cleared to 0.
;
; ARGUMENTS:
; Registers:
; * ACCB: The number of bytes to validate
;
; Memory:
; * memcpy_ptr_src:  A pointer to the patch data to be validated.
;                    This pointer is incremented with each validation.
; * memcpy_ptr_dest: A pointer to the data to validate against.
;                    This pointer is incremented with each validation.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
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
; EG Rate.
    DC.B 99
    DC.B 99
    DC.B 99
    DC.B 99
; EG Level.
    DC.B 99
    DC.B 99
    DC.B 99
    DC.B 99
; Keyboard Scaling Breakpoint.
    DC.B 99
; Left/Right Scaling Depth.
    DC.B 99
    DC.B 99
; Left/Right Scaling Curve.
    DC.B 3
    DC.B 3
; Keyboard Rate Scaling.
    DC.B 7
; Amp Mod Sensitivity.
    DC.B 3
; Key Velocity Sensitivity.
    DC.B 7
; Operator Output Level.
    DC.B 99
; Operator Mode.
    DC.B 1
; Operator Frequency Coarse.
    DC.B 31
; Operator Frequency Fine.
    DC.B 99
; Operator Detune.
    DC.B 14

; Pitch EG Rate.
    DC.B 99
    DC.B 99
    DC.B 99
    DC.B 99

; Pitch EG Level.
    DC.B 99
    DC.B 99
    DC.B 99
    DC.B 99

; Algorithm.
    DC.B 31
; Feedback
    DC.B 7
; Oscillator Sync.
    DC.B 1
; LFO Speed.
    DC.B 99
; LFO Delay.
    DC.B 99
; LFO Pitch Mod Depth.
    DC.B 99
; LFO Amp Mod Depth.
    DC.B 99
; LFO Sync.
    DC.B 1
; LFO Waveform.
    DC.B 5
; Pitch Mod Sensitivity.
    DC.B 7
; Key Transpose.
    DC.B 48
