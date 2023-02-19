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
; voice/voice.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions, and code related to the allocation, and
; manipulation of the synth's individual voices.
;
; Note the difference in nomenclature regarding 'voice's from the DX7's manual,
; and technical literature. What the DX7 literature typically refers to as a
; 'voice' is more commonly known as a 'patch' in more modern synthesisers.
; In order to avoid confusion, the more modern nomenclature of 'patch' to
; refer to saved voice settings, and 'voice' to refer to an individual note are
; used.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; Voice status bitmasks
; These bitmasks are used to determine the status of an individual voice in the
; voice status array.
; ==============================================================================
VOICE_STATUS_SUSTAIN:                           EQU %1
VOICE_STATUS_ACTIVE:                            EQU %10


; ==============================================================================
; EGS voice event bitmasks
; These signals are sent to the 'EGS Key Event' register to activate, or
; deactivate a specific voice.
; ==============================================================================
EGS_VOICE_EVENT_ON:                             EQU 1
EGS_VOICE_EVENT_OFF:                            EQU 2


; ==============================================================================
; Length: 128.
; ==============================================================================
table_midi_key_to_log_f:
    DC.B 0, 0, 1, 2, 4, 5, 6
    DC.B 8, 9, $A, $C, $D, $E
    DC.B $10, $11, $12, $14, $15
    DC.B $16, $18, $19, $1A, $1C
    DC.B $1D, $1E, $20, $21, $22
    DC.B $24, $25, $26, $28, $29
    DC.B $2A, $2C, $2D, $2E, $30
    DC.B $31, $32, $34, $35, $36
    DC.B $38, $39, $3A, $3C, $3D
    DC.B $3E, $40, $41, $42, $44
    DC.B $45, $46, $48, $49, $4A
    DC.B $4C, $4D, $4E, $50, $51
    DC.B $52, $54, $55, $56, $58
    DC.B $59, $5A, $5C, $5D, $5E
    DC.B $60, $61, $62, $64, $65
    DC.B $66, $68, $69, $6A, $6C
    DC.B $6D, $6E, $70, $71, $72
    DC.B $74, $75, $76, $78, $79
    DC.B $7A, $7C, $7D, $7E, $80
    DC.B $81, $82, $84, $85, $86
    DC.B $88, $89, $8A, $8C, $8D
    DC.B $8E, $90, $91, $92, $94
    DC.B $95, $96, $98, $99, $9A
    DC.B $9C, $9D, $9E, $A0, $A1
    DC.B $A2, $A4, $A5, $A6, $A8


; ==============================================================================
; VOICE_CONVERT_MIDI_NOTE_TO_LOG_FREQ
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; This is the main subroutine responsible for converting the key number value
; shared by the keyboard controller, and MIDI input, to the frequency value
; used internally by the EGS chip. The resulting frequency value is represented
; in logarithmic format, with 1024 values per octave.
;
; The conversion works by using the note number as an index into a lookup
; table, from which the most-significant byte of the pitch is retrieved. The
; lower byte is then created by shifting this value.
;
; The mechanism used in this subroutine is referenced in patent US4554857:
; "It is known in the art that a frequency number expressed in logarithm can
; be obtained by frequently adding data of two low bits of the key code KC to
; lower bits (e.g., Japanese Patent Preliminary Publication No. 142397/1980)."
;
; ARGUMENTS:
; Registers:
; * ACCB: The note number value to get the logarithmic frequency value for.
;
; MEMORY MODIFIED:
; * note_frequency, note_frequency_low
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
voice_convert_midi_note_to_log_freq:            SUBROUTINE
    LDX     #table_midi_key_to_log_f
    ABX
    LDAA    0,x
    STAA    <note_frequency

; Create the lower-byte of the 14-bit logarithmic frequency.
    LDAB    #3
    ANDA    #%11
    STAA    <note_frequency_low

.create_lsb_loop:
    ORAA    <note_frequency_low
    ASLA
    ASLA
    DECB
    BNE     .create_lsb_loop

; Truncate to the final 14-bit value.
    ANDA    #%11111100
    STAA    <note_frequency_low
    RTS


; ==============================================================================
; VOICE_UDPATE_SUSTAIN_STATUS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Tests to see whether the status of the sustain pedal has transition from
; active to inactive. If this is the case, this subroutine tests all voices to
; determine if they are currently sustained, and if so sends an update to the
; EGS to end the sustain.
;
; ARGUMENTS:
; Memory:
; * pedal_status_current: Used to determine the current sustain pedal status.
;
; MEMORY MODIFIED:
; * voice_status
; * sustain_status
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
voice_update_sustain_status:                    SUBROUTINE
; Mask the sustain pedal status.
    LDAA    <pedal_status_current
    ANDA    #PEDAL_INPUT_SUSTAIN

; Invert the sustain pedal status, and perform a logical AND between the
; inverted updated status, and the previous.
; If the result is 1 it indicates that the sustain pedal status has changed
; from an 'On' state, to an 'Off' state.
    PSHA
    COMA
    ANDA    <sustain_status
    BEQ     .exit

; Update each voice in the EGS to disable sustain.
    LDX     #voice_status
    LDAB    #EGS_VOICE_EVENT_OFF

; Test each voice to determine if they are marked as being sustained.
; If so, update the voice status array, and send the voice event signal to
; the EGS turn the voice off.
.test_voice_loop:
    TIMX    #VOICE_STATUS_SUSTAIN, 1
    BEQ     .increment_loop_counter
    STAB    egs_key_event
    DELAY_SHORT

.increment_loop_counter:
    INX
    INX

; Since the voice number field is stored in bits 2-5, increment the index by
; four to increment the voice number.
    ADDB    #4
    CMPB    #66
    BNE     .test_voice_loop

.exit:
    PULA
    STAA    <sustain_status

    RTS


; =============================================================================
; VOICE_SET_KEY_TRANSPOSE_BASE_FREQUENCY
; =============================================================================
; DESCRIPTION:
; This subroutine calculates the 'key transpose' base logarithmic frequency.
; This value is used in calculating the final frequency value for notes sent
; to the EGS chip.
;
; This differs from the method used in the DX7. The DX7 simply adds the base
; transpose note to each note number being played before calculating the
; new note's frequency.
;
; MEMORY MODIFIED:
; * key_transpose_base_frequency
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; =============================================================================
voice_set_key_transpose_base_frequency:         SUBROUTINE
    LDAB    patch_edit_key_transpose
; '48' is the note number for C3.
; This is the minimum value for the key transpose setting, with the default
; value of '12' in the init patch buffer corresponding to 48 + 12 = C4.
    ADDB    #48

    BSR     voice_convert_midi_note_to_log_freq

    LDD     <note_frequency

; This value represents the logarithmic frequency of C4.
    SUBD    #$4EA8
    STD     <key_transpose_base_frequency

    RTS


; =============================================================================
; This macro calculates the 'base' logarithmic frequency used in various
; voice routines. It is calculated from the master tune and key transpose
; frequency, and used when adding voices.
; =============================================================================
    .MAC GET_VOICE_BASE_FREQUENCY
        CLRA
        LDAB    master_tune
        LSLD
        LSLD
        ADDD    <key_transpose_base_frequency
    ; @TODO: What is this magic number?
        ADDD    #$2458
    .ENDM
