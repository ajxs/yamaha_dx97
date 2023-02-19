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
; voice/add.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the subroutines used to add a voice with a new note, in
; response to an incoming 'Note On' MIDI message, or a key being pressed.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; VOICE_ADD
; ==============================================================================
; DESCRIPTION:
; This subroutine is the main entry point to 'adding' a new voice event.
; It is effectively the entry point to actually playing a note over one of the
; synth's voices. This function branches to more specific functions, depending
; on whether the synth is in monophonic, or polyphonic mode.
; This subroutine is where a note keycode is converted to the EGS chip's
; internal representation of pitch. The various voice buffers related to pitch
; transitions are set, and reset here.
;
; ARGUMENTS:
; Registers:
; * ACCB: The note number to add to the new voice.
;
; ==============================================================================
voice_add:                                      SUBROUTINE
    JSR     voice_convert_midi_note_to_log_freq

    LDAB    mono_poly
    BNE     .synth_in_mono_mode

    JMP     voice_add_poly

.synth_in_mono_mode:
    JMP     voice_add_mono


; ==============================================================================
; VOICE_ADD_OPERATOR_LEVEL_VOICE_FREQUENCY
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; Loads the operator scaling, and frequency for a new note to the EGS chip.
; Tests whether the current portamento settings mean the new note frequency
; should not be loaded immediately.
;
; ARGUMENTS:
; Registers:
; * IX:   The frequency for the new note.
; * ACCA: The zero-indexed voice number.
;
; ==============================================================================
voice_add_operator_level_voice_frequency:       SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.new_voice_frequency:                           EQU #temp_variables
.new_voice_number:                              EQU #(temp_variables + 2)
.operator_index:                                EQU #(temp_variables + 3)

; ==============================================================================
    STX     .new_voice_frequency
    STAA    .new_voice_number
    CLRB
    STAB    .operator_index

.load_operator_level_loop:
    LDX     #operator_enabled_status

; Get the one's complement negation of ACCB to invert the index order
; from 0-3 to 3-0.
    COMB
    ANDB    #%11
    ABX

; Load the individual operator enabled status.
    LDAA    0,x
    ANDA    #1
    BNE     .operator_enabled

; If the operator is disabled, set the volume to 0xFF.
    LDAA    #$FF
    BRA     .store_operator_level_to_egs

.operator_enabled:
    LDX     #operator_keyboard_scaling
    LDAB    .operator_index
    LDAA    #29
    MUL
    ABX

; Calculate the index from which keyboard scaling is calculated.
    LDAB    .new_voice_frequency
    ADDB    #32
    ADDB    <key_transpose_base_frequency

; Subtract 62, and clamp at 0 if the result is negative.
    SUBB    #62
    BCC     .clamp_operator_level_high

    CLRB

.clamp_operator_level_high:
; If this value is above 112, clamp.
    CMPB    #112
    BLS     .calculate_key_scaling_index
    LDAB    #112

.calculate_key_scaling_index:
; Shift the resulting value twice to the right to reduce it to a valid
; index between 0-28, the range of the operator keyboard scaling array.
; Load the operator keyboard scaling level from the array.
; Add 2 to this value, and if it overflows, clamp at 0xFF.
    LSRB
    LSRB
    ABX
    LDAA    0,x
    ADDA    #2
    BCC     .store_operator_level_to_egs

    LDAA    #$FF

.store_operator_level_to_egs:
    PSHA
    LDX     #egs_operator_level

; Multiply the index in ACCB by 16, since there are 16 entries per operator,
; then add the index of the voice being added.
    LDAA    #16
    LDAB    .operator_index
    MUL
    ADDB    .new_voice_number
    ABX

; Write the calculated operator level to the EGS.
    PULA
    STAA    0,x
    LDAB    .operator_index
    INCB
    STAB    .operator_index

; Check if all operator levels have been loaded.
    CMPB    #4
    BNE     .load_operator_level_loop

; Load the pitch of the new note to the EGS.
; Test if the synth is in Monophonic mode. If so, test the portamento
; mode to determine whether the new note's frequency should be loaded
; immediately, or whether it should be updated in the portamento routine.
    TST     mono_poly

; Branch if the synth is in mono mode.
    BNE     .synth_in_mono_mode

.test_if_porta_active:
; Test whether the portamento pedal is active.
; If not, proceed to loading the new frequency immediately.
    TIMD    #PEDAL_INPUT_PORTA, pedal_status_current
    BEQ     .load_note_frequency_to_egs

; Test whether the portamento increment is at it's maximum, and therefore
; portamento would be immediate.
; If so, proceed to loading the new note frequency immediately.
    LDAA    <portamento_rate_scaled
    CMPA    #$FF
    BNE     .exit

.load_note_frequency_to_egs:
    LDX     #egs_voice_frequency
    LDAB    .new_voice_number
    ASLB
    ABX

; Calculate the final logarithmic frequency value to load to the EGS.
    GET_VOICE_BASE_FREQUENCY
    ADDD    .new_voice_frequency

; Store the voice pitch to the EGS chip.
    STAA    0,x
    STAB    1,x

.exit:
    RTS

.synth_in_mono_mode:
; Test whether the portamento mode is 'Fingered'.
; If so, load the new note's frequency immediately.
    TST     portamento_mode
    BEQ     .test_if_porta_active
    BRA     .load_note_frequency_to_egs
