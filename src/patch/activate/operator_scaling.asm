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
; @TAKEN_FROM_DX7_FIRMWARE
; @REMADE_FOR_6_OP
; DESCRIPTION:
; Loads the 'Keyboard Rate Scaling' value for the current operator, and combines
; it with the 'Amp Mod Sensitivity' value to create the 'combined' value
; expected by the EGS' internal registers.
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
; ==============================================================================
patch_activate_operator_keyboard_scaling:       SUBROUTINE
    LDX     #patch_buffer_edit
    LDAB    <patch_activate_operator_offset
    ABX

    LDAB    #PATCH_OP_RATE_SCALING
    ABX
; Load KBD_RATE_SCALING into ACCB.
    LDAB    0,x
; Load AMP_MOD_SENS into ACCA.
    LDAA    1,x

; Combine the values into the format expected by the EGS.
    ASLA
    ASLA
    ASLA
    ABA

; Store the combined value in the appropriate EGS register.
    LDAB    patch_activate_operator_number
    LDX     #egs_operator_keyboard_scaling
    ABX
    STAA    0,x

    RTS


; ==============================================================================
; PATCH_ACTIVATE_OPERATOR_PARSE_KEYBOARD_SCALING
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @REMADE_FOR_6_OP
; DESCRIPTION:
; Parses the serialised keyboard scaling values, and constructs the operator
; keyboard scaling curve for the selected operator.
;
; ARGUMENTS:
; Memory:
; * patch_activate_operator_number: The operator number being activated.
; * patch_activate_operator_offset: The offset of the current operator in
;     patch memory.
;
; MEMORY MODIFIED:
; * operator_keyboard_scaling
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
patch_activate_operator_parse_keyboard_scaling: SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.breakpoint_frequency:                          EQU  #temp_variables
.depth_left:                                    EQU  #temp_variables + 1
.depth_right:                                   EQU  #temp_variables + 2
.curve_table_pointer_left:                      EQU  #temp_variables + 3
.curve_table_pointer_right:                     EQU  #temp_variables + 5
.keyboard_scaling_polarity:                     EQU  #temp_variables + 7
.operator_output_level:                         EQU  #temp_variables + 8
.operator_current_pointer:                      EQU  #temp_variables + 9
.scale_curve_index:                             EQU  #temp_variables + 11

; ==============================================================================
    LDX     #patch_buffer_edit
    LDAB    <patch_activate_operator_offset
    ABX
    STX     .operator_current_pointer

; Load the breakpoint.
    LDAB    PATCH_OP_LVL_SCL_BREAK_POINT,x
    PSHX

; Add 20 on account of the lowest breakpoint value being A(-1).
; This is the 21st note starting from C(-2).
    ADDB    #20
    LDX     #table_midi_key_to_log_f
    ABX
    LDAA    0,x
    LSRA
    LSRA
    STAA    .breakpoint_frequency

; Restore the pointer to the current operator.
    PULX

; Load, and scale the left depth.
    LDAA    PATCH_OP_LVL_SCL_LT_DEPTH,x
    JSR     patch_convert_serialised_value_to_internal
    STAA    .depth_left

; Load, and scale the right depth.
    LDAA    PATCH_OP_LVL_SCL_RT_DEPTH,x
    JSR     patch_convert_serialised_value_to_internal
    STAA    .depth_right

; Load the left curve value into A, and parse.
; The result, returned in CCR[z], will be 0 if the curve is negative.
    LDAA    PATCH_OP_LVL_SCL_LT_CURVE,x
    JSR     patch_get_pointer_to_scaling_curve_left

; Is the left curve negative?
    BEQ     .left.curve_is_negative

; The keyboard scaling polarity value for both left, and right curves is
; stored in this variable. Bit 6 indicates the polarity of the left curve,
; with 1 indicating it's positive. Bit 7 indicates the polarity of the
; right curve.
    LDAB    #%1000000
    BRA     .load_curve_right

.left.curve_is_negative:
    CLRB

.load_curve_right:
    STAB    .keyboard_scaling_polarity
    LDAA     PATCH_OP_LVL_SCL_RT_CURVE,x
    JSR      patch_get_pointer_to_scaling_curve_right
    BEQ     .parse_operator_output_level

; Set bit 7 in the keyboard scaling polarity register if the right curve
; is non-negative.
    LDAB    #%10000000
    ADDB    .keyboard_scaling_polarity
    STAB    .keyboard_scaling_polarity

.parse_operator_output_level:
    LDAB    PATCH_OP_OUTPUT_LEVEL,x
    LDX     #table_curve_log
    ABX
    LDAA    0,x
    STAA    .operator_output_level

; Store a starting index into the scaling curve.
    LDAA    #KEYBOARD_SCALE_CURVE_LENGTH
    STAA    .scale_curve_index

    LDX     #operator_keyboard_scaling_2
    LDAB    patch_activate_operator_number
    LDAA    #KEYBOARD_SCALE_CURVE_LENGTH
    MUL
    ABX

; The following loop computes the 43 byte keyboard scaling curve for the
; currently selected operator.
; It checks whether each index is above, or below the breakpoint, loading
; the scaling curve accordingly. It then multiplies the scaling curve value
; by the appropriate depth value to compute the final keyboard scaling
; value. This value is then stored in the 43 byte keyboard scaling curve.
.create_scaling_curve_loop:
    STX     .operator_current_pointer
    LDAB    .scale_curve_index
    SUBB    .breakpoint_frequency

; Is this index into the parsed curve data above the breakpoint?
; If ACCB > .breakpoint_frequency, branch.
    BHI     .set_scaling_curve_right

    LDX     .curve_table_pointer_left

; Get two's compliment negation of ACCB to invert the index into the
; curve data. Inverting the curve.
    NEGB
    ABX

; Get product of curve * depth.
    LDAB    0,x
    LDAA    .depth_left
    MUL

; Branch if product is non-negative.
    TSTA
    BPL     .get_left_curve_polarity

    LDAA    #127

.get_left_curve_polarity:
    LDAB    .keyboard_scaling_polarity
    ASLB
    BRA     .is_curve_positive

.set_scaling_curve_right:
; Load ACCB from CURVE[ACCB].
    LDX     .curve_table_pointer_right
    ABX
    LDAB    0,x
    LDAA    .depth_right

; Get product of curve * depth.
    MUL
    TSTA

; If the MSB of the result is less than 127, clamp.
    BPL     .get_right_curve_polarity
    LDAA    #127

.get_right_curve_polarity:
    LDAB    .keyboard_scaling_polarity

.is_curve_positive:
    BPL     .curve_is_negative

    NEGA
    ADDA    .operator_output_level
    BPL     .store_curve_data

    CLRA
    BRA     .store_curve_data

.curve_is_negative:
    ADDA    .operator_output_level
    BPL     .store_curve_data

    LDAA    #127

.store_curve_data:
    ASLA

    LDX     .operator_current_pointer
    DEX

    STAA    0,x
    DEC     .scale_curve_index
    BNE     .create_scaling_curve_loop

    RTS


; ==============================================================================
; PATCH_GET_POINTER_TO_SCALING_CURVE_LEFT
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; Gets a pointer to the left keyboard scaling curve for an operator.
; After the function call CCR[z] will be set if curve is negative.
; @Note: This subroutine shares the same temporary variables as the
; keyboard scaling activation function.
;
; RETURNS:
; * CCR[z]: The zero flag will be set if this curve is negative.
;
; ==============================================================================
patch_get_pointer_to_scaling_curve_left:        SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.curve_table_pointer_left:                      EQU  #temp_variables + 3
.curve_table_pointer_right:                     EQU  #temp_variables + 5

; ==============================================================================
    PSHX

; If the curve value is 0, or 3 this indicates that the EG curve is linear.
    TSTA
    BEQ     .curve_is_linear

    CMPA    #3
    BEQ     .curve_is_linear

    LDX     #table_curve_keyboard_scaling_exponential
    BRA     .store_left_curve_pointer

.curve_is_linear:
    LDX     #table_curve_keyboard_scaling_linear

.store_left_curve_pointer:
    STX     .curve_table_pointer_left
    PULX

; Tests whether this is a positive, or negative curve.
    BITA    #2
    RTS


; ==============================================================================
; PATCH_GET_POINTER_TO_SCALING_CURVE_RIGHT
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; Gets a pointer to the right keyboard scaling curve for an operator.
; After the function call CCR[z] will be set if curve is negative.
; @Note: This subroutine shares the same temporary variables as the
; keyboard scaling activation function.
;
; RETURNS:
; * CCR[z]: The zero flag will be set if this curve is negative.
;
; ==============================================================================
patch_get_pointer_to_scaling_curve_right:       SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.curve_table_pointer_left:                      EQU  #temp_variables + 3
.curve_table_pointer_right:                     EQU  #temp_variables + 5

; ==============================================================================
    PSHX

; If the curve value is 0, or 3 this indicates that the EG curve is linear.
    TSTA
    BEQ     .curve_is_linear

    CMPA    #3
    BEQ     .curve_is_linear

    LDX     #table_curve_keyboard_scaling_exponential
    BRA     .store_right_curve_pointer

.curve_is_linear:
    LDX     #table_curve_keyboard_scaling_linear

.store_right_curve_pointer:
    STX     .curve_table_pointer_right
    PULX

; Tests whether this is a positive, or negative curve.
    BITA    #2
    RTS
