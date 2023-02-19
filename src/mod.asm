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
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
; ==============================================================================
mod_amp_update:                                 SUBROUTINE
; Scale the mod wheel input by its specified range.
    LDAA    mod_wheel_range
    JSR     patch_convert_serialised_value_to_internal
    LDAB    analog_input_mod_wheel
    MUL
    STAA    <mod_wheel_input_scaled

; Scale the breath controller input by its specified range.
    LDAA    breath_control_range
    JSR     patch_convert_serialised_value_to_internal
    LDAB    analog_input_breath_controller
    MUL
    STAA    <breath_controller_input_scaled

    CLRA
    TST     mod_wheel_eg_bias
    BEQ     .is_breath_control_eg_bias_enabled

    LDAA    mod_wheel_range
    JSR     patch_convert_serialised_value_to_internal

.is_breath_control_eg_bias_enabled:
    TST     breath_control_eg_bias
    BEQ     .store_total_bias_amount

; If breath control EG bias is enabled, add the MSB of the scaled range value
; to this register.
    STAA    <mod_amount_total
    LDAA    breath_control_range
    JSR     patch_convert_serialised_value_to_internal
    ADDA    <mod_amount_total
    BCC     .store_total_bias_amount

    LDAA    #$FF

.store_total_bias_amount:
    COMA
    STAA    <mod_amount_total

    CLRA
    TST     mod_wheel_eg_bias
    BEQ     loc_D6CE

    LDAA    <mod_wheel_input_scaled

loc_D6CE:
    TST     breath_control_eg_bias
    BEQ     loc_D6D9

    ADDA    <breath_controller_input_scaled
    BCC     loc_D6D9

    LDAA    #$FF

loc_D6D9:
    ADDA    <mod_amount_total
    BCC     loc_D6DF

    LDAA    #$FF

loc_D6DF:
    COMA
    STAA    <mod_amount_total
    CLRA
    TST     mod_wheel_amp
    BEQ     loc_D6EA

    LDAA    <mod_wheel_input_scaled

loc_D6EA:
    TST     breath_control_amp
    BEQ     .get_scaled_depth_factor

    ADDA    <breath_controller_input_scaled
    BCC     .get_scaled_depth_factor

    LDAA    #$FF

.get_scaled_depth_factor:
; Scale the LFO amp modulation depth by the LFO scale-in factor.
    PSHA
    LDAA    <lfo_mod_depth_amp
    LDAB    <lfo_delay_fadein_factor
    MUL

; Add the amp mod amount to the MSB of the product.
    PULB
    ABA
    BCC     loc_D701

; If the product overflows, clamp at 0xFF.
    LDAA    #$FF

loc_D701:
; If the amp mod factor overflows, clamp at 0xFF.
; Otherwise branch.
    ADDA    <mod_amount_total
    BCC     .calculate_lfo_amp_mod

    LDAA    #$FF

.calculate_lfo_amp_mod:
    SUBA    <mod_amount_total
; Invert LFO amplitude, then invert polarity?
    LDAB    <lfo_amplitude
    COMB
    EORB    #$80
    MUL
    ADDA    <mod_amount_total
    BCC     .send_amp_mod_to_egs

    LDAA    #$FF

.send_amp_mod_to_egs:
    COMA
    LDX     #table_egs_amp_mod_input
    TAB
    ABX
    LDAA    0,x
    STAA    egs_amp_mod

    RTS


table_egs_amp_mod_input:
    DC.B $FF, $FF, $E0, $CD, $C0    ; 0
    DC.B $B5, $AD, $A6, $A0, $9A    ; 5
    DC.B $95, $91, $8D, $89, $86    ; 10
    DC.B $82, $80, $7D, $7A, $78    ; 15
    DC.B $75, $73, $71, $6F, $6D    ; 20
    DC.B $6B, $69, $67, $66, $64    ; 25
    DC.B $62, $61, $60, $5E, $5D    ; 30
    DC.B $5B, $5A, $59, $58, $56    ; 35
    DC.B $55, $54, $53, $52, $51    ; 40
    DC.B $50, $4F, $4E, $4D, $4C    ; 45
    DC.B $4B, $4A, $49, $48, $47    ; 50
    DC.B $46, $46, $45, $44, $43    ; 55
    DC.B $42, $42, $41, $40, $40    ; 60
    DC.B $3F, $3E, $3D, $3D, $3C    ; 65
    DC.B $3B, $3B, $3A, $39, $39    ; 70
    DC.B $38, $38, $37, $36, $36    ; 75
    DC.B $35, $35, $34, $33, $33    ; 80
    DC.B $32, $32, $31, $31, $30    ; 85
    DC.B $30, $2F, $2F, $2E, $2E    ; 90
    DC.B $2D, $2D, $2C, $2C, $2B    ; 95
    DC.B $2B, $2A, $2A, $2A, $29    ; 100
    DC.B $29, $28, $28, $27, $27    ; 105
    DC.B $26, $26, $26, $25, $25    ; 110
    DC.B $24, $24, $24, $23, $23    ; 115
    DC.B $22, $22, $22, $21, $21    ; 120
    DC.B $21, $20, $20, $20, $1F    ; 125
    DC.B $1F, $1E, $1E, $1E, $1D    ; 130
    DC.B $1D, $1D, $1C, $1C, $1C    ; 135
    DC.B $1B, $1B, $1B, $1A, $1A    ; 140
    DC.B $1A, $19, $19, $19, $18    ; 145
    DC.B $18, $18, $18, $17, $17    ; 150
    DC.B $17, $16, $16, $16, $15    ; 155
    DC.B $15, $15, $15, $14, $14    ; 160
    DC.B $14, $13, $13, $13, $13    ; 165
    DC.B $12, $12, $12, $12, $11    ; 170
    DC.B $11, $11, $11, $10, $10    ; 175
    DC.B $10, $10, $F, $F, $F       ; 180
    DC.B $F, $E, $E, $E, $E, $D     ; 185
    DC.B $D, $D, $D, $C, $C, $C     ; 191
    DC.B $C, $B, $B, $B, $B, $A     ; 197
    DC.B $A, $A, $A, 9, 9, 9        ; 203
    DC.B 9, 8, 8, 8, 8, 8, 7        ; 209
    DC.B 7, 7, 7, 6, 6, 6, 6        ; 216
    DC.B 6, 5, 5, 5, 5, 5, 4        ; 223
    DC.B 4, 4, 4, 4, 3, 3, 3        ; 230
    DC.B 3, 3, 2, 2, 2, 2, 2        ; 237
    DC.B 2, 1, 1, 1, 1, 1, 0        ; 244
    DC.B 0, 0, 0, 0, 0              ; 251


; ==============================================================================
; MOD_PITCH_UPDATE
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; Calculates the final pitch modulation amount, and writes it to the
; associated EGS register.
;
; ==============================================================================
mod_pitch_update:                               SUBROUTINE
    CLRA

; If the mod wheel is not assigned to any modulation destination, store '0' for
; the scaled mod wheel input.
    TST     mod_wheel_assign
    BEQ     .store_scaled_mod_wheel_input

    LDAA    mod_wheel_range
    JSR     patch_convert_serialised_value_to_internal
    LDAB    analog_input_mod_wheel
    MUL

.store_scaled_mod_wheel_input:
    STAA    <mod_wheel_input_scaled

    TST     breath_control_assign
    BEQ     .get_scaled_depth_factor

    LDAA    breath_control_range
    JSR     patch_convert_serialised_value_to_internal
    LDAB    analog_input_breath_controller
    MUL
    ADDA    <mod_wheel_input_scaled
    BCC     .get_scaled_depth_factor

; If this value overflows, clamp at 0xFF.
    LDAA    #$FF

.get_scaled_depth_factor:
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
    LDAA    lfo_mod_sensitivity
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
