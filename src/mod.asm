; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; mod.asm
; ==============================================================================
; DESCRIPTION:
; Contains the subroutines used for loading amp, and pitch modulation to the
; EGS chip.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; MOD_AMP_UPDATE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD698
; @CALLED_DURING_OCF_HANDLER
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; This subroutine calculates the total amplitude modulation input.
; This tests the various modulation sources (Mod Wheel/Breath Controller) for
; whether EG Bias is enabled, and contributes their input accordingly.
; The overall arithmetic formula used here isn't well understood.
; It's totally arbitrary, and calculates the index into a LUT, from which the
; value sent to the EGS is retrieved.
;
; ==============================================================================
mod_amp_update:                                 SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.mod_wheel_input_scaled:                        EQU #interrupt_temp_variables
.breath_controller_input_scaled:                EQU #interrupt_temp_variables + 1
.mod_amount_total:                              EQU #interrupt_temp_variables + 2

; ==============================================================================
; Scale the mod wheel input by its specified range.
    LDAA    mod_wheel_range
    JSR     patch_convert_serialised_value_to_internal
    LDAB    analog_input_mod_wheel
    MUL
    STAA    .mod_wheel_input_scaled

; Scale the breath controller input by its specified range.
    LDAA    breath_control_range
    JSR     patch_convert_serialised_value_to_internal
    LDAB    analog_input_breath_controller
    MUL
    STAA    .breath_controller_input_scaled

; Set up EG Bias offset.
; The effect of the following code is that if the EG Bias for a particular
; modulation source (Mod Wheel/Breath Controller) is enabled, the range for
; that source will contribute to the total modulation amount.
    CLRA

    TST     mod_wheel_eg_bias
    BEQ     .is_breath_control_eg_bias_enabled

; Convert the 0-99 variable range to 0-255.
    LDAA    mod_wheel_range
    JSR     patch_convert_serialised_value_to_internal

.is_breath_control_eg_bias_enabled:
    TST     breath_control_eg_bias
    BEQ     .store_total_bias_amount

    STAA    .mod_amount_total

; Convert the 0-99 variable range to 0-255.
    LDAA    breath_control_range
    JSR     patch_convert_serialised_value_to_internal

    ADDA    .mod_amount_total
    BCC     .store_total_bias_amount

    LDAA    #$FF        ; Clamp at 0xFF.

.store_total_bias_amount:
    COMA
    STAA    .mod_amount_total

; Set up the EG Biased input.
; The following section tests whether EG Bias is enabled for a particular
; source. If so, the scaled input is added to the total.
    CLRA

; If EG Bias for this modulation source is enabled, add the scaled input value.
    TST     mod_wheel_eg_bias
    BEQ     .is_breath_control_eg_bias_enabled_2

    LDAA    .mod_wheel_input_scaled

.is_breath_control_eg_bias_enabled_2:
; If EG Bias for this modulation source is enabled, add the scaled input value.
    TST     breath_control_eg_bias
    BEQ     .add_current_total_to_bias_input

    ADDA    .breath_controller_input_scaled
    BCC     .add_current_total_to_bias_input

    LDAA    #$FF        ; Clamp at 0xFF.

.add_current_total_to_bias_input:
    ADDA    .mod_amount_total
    BCC     .store_total_with_bias_input

    LDAA    #$FF        ; Clamp at 0xFF.

.store_total_with_bias_input:
    COMA
    STAA    .mod_amount_total

; Test whether amplitude modulation is enabled for each modulation source.
; If so, the scaled input for each is added to the total amp modulation input.
    CLRA
    TST     mod_wheel_amp
    BEQ     .is_breath_control_amp_mod_enabled

    LDAA    .mod_wheel_input_scaled

.is_breath_control_amp_mod_enabled:
    TST     breath_control_amp
    BEQ     .get_scaled_lfo_depth_factor

    ADDA    .breath_controller_input_scaled
    BCC     .get_scaled_lfo_depth_factor

    LDAA    #$FF        ; Clamp at 0xFF.

; The following section calculates the total LFO amp modulation.

.get_scaled_lfo_depth_factor:
; Scale the LFO amp modulation depth by the LFO scale-in factor.
    PSHA
    LDAA    <lfo_mod_depth_amp
    LDAB    <lfo_delay_fadein_factor
    MUL

    PULB
    ABA
    BCC     .add_scaled_lfo_fadein_factor_to_total

    LDAA    #$FF        ; Clamp at 0xFF.

.add_scaled_lfo_fadein_factor_to_total:
    ADDA    .mod_amount_total
    BCC     .calculate_lfo_amp_mod

    LDAA    #$FF        ; Clamp at 0xFF.

.calculate_lfo_amp_mod:
    SUBA    .mod_amount_total

; Invert the LFO amplitude by getting a one's complement of the value,
; and then inverting the sign-bit.
    LDAB    <lfo_amplitude
    COMB
    EORB    #$80

    MUL
    ADDA    .mod_amount_total
    BCC     .write_amp_mod_to_egs

    LDAA    #$FF        ; Clamp at 0xFF.

.write_amp_mod_to_egs:
    COMA

    LDX     #table_egs_amp_mod_input
    TAB
    ABX
    LDAA    0,x
    STAA    egs_amp_mod

    RTS

; ==============================================================================
; This lookup table contains the values sent to the EGS Amplitude Modulation
; register. Refer to the 'Yamaha DX7 Technical Analysis' document page 63 for a
; detailed look at what level of modulation the final values correspond to.
; ==============================================================================
table_egs_amp_mod_input:
    DC.B $FF, $FF, $E0, $CD, $C0
    DC.B $B5, $AD, $A6, $A0, $9A
    DC.B $95, $91, $8D, $89, $86
    DC.B $82, $80, $7D, $7A, $78
    DC.B $75, $73, $71, $6F, $6D
    DC.B $6B, $69, $67, $66, $64
    DC.B $62, $61, $60, $5E, $5D
    DC.B $5B, $5A, $59, $58, $56
    DC.B $55, $54, $53, $52, $51
    DC.B $50, $4F, $4E, $4D, $4C
    DC.B $4B, $4A, $49, $48, $47
    DC.B $46, $46, $45, $44, $43
    DC.B $42, $42, $41, $40, $40
    DC.B $3F, $3E, $3D, $3D, $3C
    DC.B $3B, $3B, $3A, $39, $39
    DC.B $38, $38, $37, $36, $36
    DC.B $35, $35, $34, $33, $33
    DC.B $32, $32, $31, $31, $30
    DC.B $30, $2F, $2F, $2E, $2E
    DC.B $2D, $2D, $2C, $2C, $2B
    DC.B $2B, $2A, $2A, $2A, $29
    DC.B $29, $28, $28, $27, $27
    DC.B $26, $26, $26, $25, $25
    DC.B $24, $24, $24, $23, $23
    DC.B $22, $22, $22, $21, $21
    DC.B $21, $20, $20, $20, $1F
    DC.B $1F, $1E, $1E, $1E, $1D
    DC.B $1D, $1D, $1C, $1C, $1C
    DC.B $1B, $1B, $1B, $1A, $1A
    DC.B $1A, $19, $19, $19, $18
    DC.B $18, $18, $18, $17, $17
    DC.B $17, $16, $16, $16, $15
    DC.B $15, $15, $15, $14, $14
    DC.B $14, $13, $13, $13, $13
    DC.B $12, $12, $12, $12, $11
    DC.B $11, $11, $11, $10, $10
    DC.B $10, $10, $F, $F, $F
    DC.B $F, $E, $E, $E, $E, $D
    DC.B $D, $D, $D, $C, $C, $C
    DC.B $C, $B, $B, $B, $B, $A
    DC.B $A, $A, $A, 9, 9, 9
    DC.B 9, 8, 8, 8, 8, 8, 7
    DC.B 7, 7, 7, 6, 6, 6, 6
    DC.B 6, 5, 5, 5, 5, 5, 4
    DC.B 4, 4, 4, 4, 3, 3, 3
    DC.B 3, 3, 2, 2, 2, 2, 2
    DC.B 2, 1, 1, 1, 1, 1, 0
    DC.B 0, 0, 0, 0, 0


; ==============================================================================
; MOD_PITCH_UPDATE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD821
; @CALLED_DURING_OCF_HANDLER
; DESCRIPTION:
; Calculates the final pitch modulation amount, and writes it to the
; associated EGS register.
;
; ==============================================================================
mod_pitch_update:                               SUBROUTINE
; ==============================================================================
.mod_wheel_input_scaled:                        EQU #interrupt_temp_variables

; ==============================================================================
    CLRA

; If the mod wheel is not assigned to any modulation destination, store '0' for
; the scaled mod wheel input.
    TST     mod_wheel_pitch
    BEQ     .store_scaled_mod_wheel_input

    LDAA    mod_wheel_range
    JSR     patch_convert_serialised_value_to_internal
    LDAB    analog_input_mod_wheel
    MUL

.store_scaled_mod_wheel_input:
    STAA    .mod_wheel_input_scaled

    TST     breath_control_pitch
    BEQ     .get_scaled_lfo_depth_factor

    LDAA    breath_control_range
    JSR     patch_convert_serialised_value_to_internal
    LDAB    analog_input_breath_controller
    MUL
    ADDA    .mod_wheel_input_scaled
    BCC     .get_scaled_lfo_depth_factor

; If this value overflows, clamp at 0xFF.
    LDAA    #$FF

.get_scaled_lfo_depth_factor:
; ACCA now contains the sum of the scaled mod wheel, and breath controller
; inputs. Clamped at 0xFF.
    PSHA

    LDAA    <lfo_mod_depth_pitch
    LDAB    <lfo_delay_fadein_factor
    MUL

; Get the total LFO modulation factor in ACCA. This is the lfo delay fade-in
; factor multiplied with the modulation depth.
; Restore the scaled modulation input to ACCB.
    PULB
; Add these together, and clamp at 0xFF.
    ABA
    BCC     .scale_by_lfo_amplitude

    LDAA    #$FF

.scale_by_lfo_amplitude:
    PSHA
    LDAA    lfo_pitch_mod_sensitivity
    LDAB    <lfo_amplitude
    BMI     .lfo_amplitude_negative

    MUL
    PULB
    MUL
    BRA     .write_pitch_mod_to_egs

.lfo_amplitude_negative:
    NEGB
    MUL
    PULB
    MUL
    COMA
    COMB
    ADDD    #1

.write_pitch_mod_to_egs:
    ASRA
    RORB
    ADDD    <pitch_bend_frequency
    STAA    egs_pitch_mod_high
    STAB    egs_pitch_mod_low

    RTS
