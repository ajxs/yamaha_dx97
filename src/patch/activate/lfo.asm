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
; patch/activate/lfo.asm
; ==============================================================================
; DESCRIPTION:
; This file contains code, and definitions related to 'activation' of a patch's
; LFO settings.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_ACTIVATE_SCALE_LFO_SPEED
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; Parses, and scales the LFO speed value. This subroutine is called during
; the patch activation process.
;
; ARGUMENTS:
; Registers:
; * IX:   A pointer to the LFO speed, in patch memory.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; RETURNS:
; * ACCD: The scaled LFO speed value.
;
; ==============================================================================
patch_activate_parse_lfo_speed:                 SUBROUTINE
; If the LFO speed is set to zero, clamp it to a minimum of '267'. This is
; done so that the LFO software arithmetic works.
    LDAA    0,x
    BNE     .speed_above_zero

    INCA
    BRA     .clamp_at_minimum

.speed_above_zero:
    JSR     patch_convert_serialised_value_to_internal
; If the result is less than 160, branch.
    CMPA    #160
    BCS     .clamp_at_minimum

    TAB
    SUBB    #160
    LSRB
    LSRB
    ADDB    #11

    BRA     .exit

.clamp_at_minimum:
    LDAB    #11

.exit:
    MUL
    RTS


; ==============================================================================
; PATCH_ACTIVATE_LFO_DELAY_INCREMENT
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
; Processes the patch's LFO delay value to compute the LFO delay increment.
;
; ARGUMENTS:
; Registers:
; * IX:   A pointer to the synth's LFO speed value in patch memory.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; RETURNS:
; * ACCD: The parsed LFO delay value.
;
; ==============================================================================
patch_activate_lfo_delay_increment:             SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.delay_scaling_counter:                         EQU #temp_variables

; ==============================================================================
; Subtract the serialised LFO delay value from 99.
    LDAA    #99
    SUBA    1,x

    TAB
    ANDB    #%1110000

    LSRB
    LSRB
    LSRB
    LSRB
    SUBB    #7
    NEGB
    STAB    .delay_scaling_counter

    ANDA    #%1111
    ORAA    #%10000
    ASLA
    CLRB

.rotate_loop:
    LSRD
    DEC     .delay_scaling_counter
    BNE     .rotate_loop

    RTS


; ==============================================================================
; PATCH_ACTIVATE_LFO
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; This routine is responsible for parsing the serialised patch LFO data, and
; setting up the internal representation of the data used in internal LFO
; processing.
; @Note: The DX9 uses only a single field for modulation sensitivity.
;
; ==============================================================================
patch_activate_lfo:                             SUBROUTINE
    LDX     #patch_edit_lfo_speed
    JSR     patch_activate_parse_lfo_speed
    STD     <lfo_phase_increment

; Parse LFO delay.
    JSR     patch_activate_lfo_delay_increment
    STD     <lfo_delay_increment

; Parse the LFO Pitch Mod Depth.
    LDAA    2,x
    JSR     patch_convert_serialised_value_to_internal
    STAA    <lfo_mod_depth_pitch

; Parse the LFO Amp Mod Depth.
    LDAA    3,x
    JSR     patch_convert_serialised_value_to_internal
    STAA    <lfo_mod_depth_amp

; Parse the LFO waveform.
    LDAA    4,x
    STAA    lfo_waveform

; Parse the LFO Mod Sensitivity.
    LDAB    5,x
    LDX     #table_lfo_mod_sensitivity
    ABX
    LDAA    0,x
    STAA    lfo_mod_sensitivity

    RTS


; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; LFO Mod Sensitivity Table
; This table is used to translate serialised LFO Mod Sensitivity values
; into their internal representation.
; Length: 8
; ==============================================================================
table_lfo_mod_sensitivity:
    DC.B 0
    DC.B 10
    DC.B 20
    DC.B 33
    DC.B 55
    DC.B 92
    DC.B 153
    DC.B 255
