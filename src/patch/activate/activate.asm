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
; patch/activate/activate.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the routine for patch 'activation'.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_ACTIVATE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; This subroutine is responsible for 'activating' the patch that is currently
; loaded into the synth's edit buffer.
; This subroutine loads the relevant patch data to the EGS, and OPS voice
; chips, which are responsible for performing the actual voice synthesis.
;
; Most of the functionality in this function is performed on a 'per-operator'
; basis, with a callback function being loaded, and called once for each of
; the four operators.
;
; ==============================================================================
patch_activate:                                 SUBROUTINE
    PSHA
    PSHB
    PSHX

; Load the operator EG rates.
    LDX     #patch_activate_operator_eg_rate
    JSR     patch_activate_call_function_per_operator

; Load the operator EG levels.
    LDX     #patch_activate_operator_eg_level
    JSR     patch_activate_call_function_per_operator

; Load the operator keyboard scaling.
    LDX     #patch_activate_operator_parse_keyboard_scaling
    JSR     patch_activate_call_function_per_operator

; Load the operator detune.
    LDX     #patch_activate_operator_detune
    JSR     patch_activate_call_function_per_operator

; Load the operator frequency.
    LDX     #patch_activate_operator_frequency
    JSR     patch_activate_call_function_per_operator

; Load operator keyboard rate scaling.
    LDX     #patch_activate_operator_keyboard_scaling
    JSR     patch_activate_call_function_per_operator

; Load operator keyboard velocity sensitivity.
    LDX     #patch_activate_operator_velocity_sensitivity
    JSR     patch_activate_call_function_per_operator

    JSR     patch_activate_pitch_eg

; Load algorithm, and feedback levels to the OPS chip.
    JSR     patch_activate_mode_algorithm_feedback
    JSR     patch_activate_lfo
    JSR     portamento_calculate_rate

    PULX
    PULB
    PULA

    RTS


; ==============================================================================
; PATCH_ACTIVATE_CALL_FUNCTION_PER_OPERATOR
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @REMADE_FOR_6_OP
; DESCRIPTION:
; This subroutine is used to call a particular function once per each of the
; synth's six operators. It is used during the 'patch activation' routine.
;
; ARGUMENTS:
; Registers:
; * IX:   The callback function that will be called once for each of the
;         synth's six operators.
;
; MEMORY MODIFIED:
; * patch_activate_operator_number: The current operator number the callback
; function is being called for.
; * patch_activate_operator_offset: The 'offset' for the operator currently
; being processed.
; Since the operator data in the patch buffer consists of six sequential
; structures of 17 bytes, this offset is incremented by 17 with each iteration
; of the operator loop, and used as an offset into the operator data array in
; the patch edit buffer.
;
; ==============================================================================
patch_activate_call_function_per_operator:      SUBROUTINE
; The operator number, and offset are adjacent variables.
; This operation saves both onto the stack.
; @TODO: Why is this performed?
    LDD     <patch_activate_operator_number
    PSHA
    PSHB

    CLRA
    CLRB
    STD     <patch_activate_operator_number

.call_function_per_operator_loop:
    PSHX
    JSR     0,x
    PULX
    INC     patch_activate_operator_number

; Add this value to the offset to increment the offset to the next operator.
; Once this has reached 60, all four operators have been processed.
    LDAB    #PATCH_DX7_PACKED_OP_STRUCTURE_SIZE
    ADDB    <patch_activate_operator_offset
    STAB    <patch_activate_operator_offset
    CMPB    #(PATCH_DX7_PACKED_OP_STRUCTURE_SIZE * 6)
    BNE     .call_function_per_operator_loop

; Restore these two variables.
    PULB
    PULA
    STD     <patch_activate_operator_number

    RTS


; ==============================================================================
; PATCH_ACTIVATE_LOAD_MODE_ALGORITHM_FEEDBACK_TO_OPS
; ==============================================================================
; @REMADE_FOR_6_OP
; DESCRIPTION:
; Called as part of the 'Patch Activation' routine.
; This subroutine loads the 'Mode', 'Algorithm', and 'Feedback' values from
; the current patch to the OPS chip.
;
; ==============================================================================
patch_activate_mode_algorithm_feedback:         SUBROUTINE
    LDAB    patch_edit_algorithm
; Shift this value left 3 times, and combine with the feedback value to
; create the combined value to load to the OPS.
    ASLB
    ASLB
    ASLB
    ORAB    patch_edit_feedback

; Test whether oscillator sync is enabled.
; If so, add '32' to this value to create the correct bitmask to load to
; the OPS register.
    LDAA    #%110000
    TST     patch_edit_oscillator_sync
    BNE     .load_mode_alg_to_ops
    ADDA    #%100000

.load_mode_alg_to_ops:
; Load ACCA+ACCB to these two adjacent OPS registers.
    STD     <ops_mode
    RTS


; ==============================================================================
; @TODO: Remove
; Algorithm Conversion Table
; This table is used to convert algorithms between the DX9 format, and the
; original DX7 format used in SysEx transmission, and in patch activation.
; Each index contains the DX7/OPS algorithm corresponding to the index
; number's algorithm on the DX9.
; ==============================================================================
table_algorithm_conversion:
    DC.B 0
    DC.B 13
    DC.B 7
    DC.B 6
    DC.B 4
    DC.B 21
    DC.B 30
    DC.B 31


; ==============================================================================
; PATCH_ACTIVATE_OPERATOR_DETUNE
; ==============================================================================
; @REMADE_FOR_6_OP
; DESCRIPTION:
; Loads operator detune values to the EGS operator detune buffer.
; Note: This subroutine differs from how the DX7's implementation in how it
; calculates the final value. The DX7 version looks up the value in a table,
; while this subroutine gets a one's complement version of the value in the
; case it is negative.
; According to the 'DX7 Technical Analysis' book, bit 3 of the EGS detune
; buffer is the 'sign' bit, and the higher bits are ignored.
;
; ARGUMENTS:
; Memory:
; * patch_activate_operator_number: The operator number being activated.
; * patch_activate_operator_offset: The offset of the current operator in
;     patch memory.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCD: The scaled value.
;
; ==============================================================================
patch_activate_operator_detune:                 SUBROUTINE
; Load the current operator's detune value.
    LDX     #patch_buffer_edit
    LDAB    <patch_activate_operator_offset
    ABX
    LDAA    PATCH_OP_DETUNE,x

; If the operator detune value is below 7, get it's one's complement.
; Otherwise subtract 7, to create a value essentially between -7 - 7.
    CMPA    #7
    BCC     .detune_value_positive

    COMA
    BRA     .load_detune_value_to_egs

.detune_value_positive:
    SUBA    #7

.load_detune_value_to_egs:
    LDX     #egs_operator_detune
    LDAB    <patch_activate_operator_number
    ABX
    STAA    0,x

    RTS


; ==============================================================================
; PATCH_ACTIVATE_OPERATOR_VELOCITY_SENSITIVITY
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @REMADE_FOR_6_OP
; DESCRIPTION:
; Parses the 'Key Velocity Sensitivity' for the currently selected operator.
; Once this value is transformed, it's stored in the global 'Op Sens' buffer.
;
; ARGUMENTS:
; Memory:
; * patch_activate_operator_number: The operator number being activated.
; * patch_activate_operator_offset: The offset of the current operator in
;     patch memory.
;
; MEMORY MODIFIED:
; * patch_operator_velocity_sensitivity
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; This transformation is equivalent to:
; def transform_key_vel_sens(op_kvs):
;     B = op_kvs * 32
;     A = (op_kvs << 1) | 0xF0
;     A = (~A) & 0xFF
;
;     return (A << 8) | B
;
; Values:
;  0: 3840
;  1: 3360
;  2: 2880
;  3: 2400
;  4: 1920
;  5: 1440
;  6: 960
;  7: 480
;
; ==============================================================================
patch_activate_operator_velocity_sensitivity:   SUBROUTINE
    LDX     #patch_buffer_edit
    LDAB    <patch_activate_operator_offset
    ABX

; Load KEY_VEL_SENS into A.
; Multiply by 32, and push.
    LDAA    PATCH_OP_KEY_VEL_SENS,x
    LDAB    #32
    MUL
    PSHB

; Parse operator sensitivity HIGH.
    LDAA    PATCH_OP_KEY_VEL_SENS,x
    ASLA
    ORAA    #%11110000
    COMA

; Store the parsed operator keyboard velocity sensitivity.
    LDX     #patch_operator_velocity_sensitivity
    LDAB    patch_activate_operator_offset
    ASLB
    ABX
    PULB
    STAA    0,x
    STAB    1,x

    RTS
