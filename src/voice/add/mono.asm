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
; voice/add/mono.asm
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; This file contains the subroutines used for playing new notes when the
; synth is in monophonic mode.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; VOICE_ADD_MONO
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; This subroutine handes 'adding' a new voice event when the synth is in
; monophonic mode.
; It handles the behaviour of the synth's portamento in monophonic mode.
; If there was already an active note, the portamento direction is updated based
; upon the new note being added.
; If there are already multiple active notes, the portamento target frequency
; is tested to determine whether it needs to be updated based upon the new note
; being played.
;
; ARGUMENTS:
; Memory:
; * note_number: The number of the new note being added.
; * note_frequency: The frequency of the new note being added.
;
; MEMORY MODIFIED:
; * voice_status
; * active_voice_count
; * portamento_direction
; * note_number_previous
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
voice_add_mono:                                 SUBROUTINE
    LDX     #voice_status

; Test whether the active voice count is already at the maximum of 16.
; If so, exit.
    LDAB    <active_voice_count
    CMPB    #16
    BEQ     .exit

    LDAB    #16

; In MONO mode, the active key event is CLEARED when removed.
; This occurs in the VOICE_REMOVE subroutine.
; This loop searches for a clear inactive voice status entry.
.find_inactive_voice_loop:
    TST     0,x
    BEQ     .found_inactive_voice

; Increment the voice status pointer.
    INX
    INX
    DECB
    BNE     .find_inactive_voice_loop

; If this point is reached, it means no inactive voices have been found.
    RTS

.found_inactive_voice:
; Write ((NOTE_KEY << 8) & 2) to the first entry in the 'Voice Event'
; buffer to indicate that this voice is actively playing this note.
    LDAA    <note_number
    LDAB    #VOICE_STATUS_ACTIVE
    STD     0,x

; Increment the active voice count.
    INC     active_voice_count
    LDAA    <active_voice_count

; If there's more than one active voice at this point, the existing
; portamento needs to be taken into account.
    CMPA    #1
    BNE     voice_add_mono_multiple_voices

; If there's only one active voice, initialise the LFO.
    VOICE_ADD_INITIALISE_LFO

; The following section will send a 'Key Off' event to the EGS chip's
; 'Key Event' register, prior to sending the new 'Key On' event.
    LDAB    #EGS_VOICE_EVENT_OFF
    STAB    egs_key_event

; The voice's target frequency, and 'Previous Key' data is stored here.
; If portamento is not currently active, the target frequency will be set a
; second time, together with the voice frequency buffers specific to
; portamento, and glissando.
    BSR     voice_add_mono_store_key_and_frequency

; Test whether the portamento rate is at its maximum (0xFF).
    LDAA    <portamento_rate_scaled
    CMPA    #$FF
    BEQ     .no_portamento

; Test whether the synth's portamento mode is 'Fingered', in which case
; there won't be any portamento if there's a single voice.
    TST     portamento_mode
    BEQ     .no_portamento

; Test whether the portamento pedal is active.
    TIMD    #PEDAL_INPUT_PORTA, pedal_status_current
    BNE     .reset_pitch_eg_frequency

.no_portamento:
; If there's no portamento. The portamento and glissando frequency buffers
; will be set to the same value as the current voice's target frequency.
; The effect of this will be that there is no voice transition computed by
; the 'portamento_process' subroutine, which is responsible for updating the
; synth's voice frequency periodically.
    BSR     voice_add_mono_clear_porta_frequency

.reset_pitch_eg_frequency:
; Reset the current pitch EG level to its initial value.
; In the DX7, the final value, and the initial value are identical.
; So when adding a voice, the initial level is set to the final value.
    LDAA    pitch_eg_parsed_level_final
    CLRB
    LSRD
    STD     pitch_eg_current_frequency

; Reset the 'Current Pitch EG Step' for this voice.
    CLR     pitch_eg_current_step

; Send the frequency, and amplitude information to the EGS registers,
; then send a 'KEY ON' event for Voice #0.
    CLRA
    LDX     <note_frequency
    JSR     voice_add_operator_level_voice_frequency

    LDAA    #EGS_VOICE_EVENT_ON
    STAA    egs_key_event

.exit:
    RTS


; ==============================================================================
; VOICE_ADD_MONO_MULTIPLE_VOICES
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Handles adding a new voice event when the synth is in monophonic mode, and
; there is now more than one active voice.
; This subroutine is responsible for parsing the legato direction, and setting
; the voice frequency buffers accordingly.
;
; ARGUMENTS:
; Registers:
; * ACCA: The number of active voices.
;
; MEMORY MODIFIED:
; * portamento_direction
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
voice_add_mono_multiple_voices:                 SUBROUTINE
    CMPA    #2
    BNE     .above_two_voices

; Compute the portamento direction by subtracting the last note key from
; the new note.
; If the carry flag is clear after this operation, it indicates that the
; new note is higher than the last.
    LDAA    <note_number
    SUBA    <note_number_previous
    BCC     .new_note_higher

    CLR     portamento_direction
    BRA     .update_last_note

.new_note_higher:
    LDAA    #1
    STAA    <portamento_direction

.update_last_note:
; The voice's target frequency, and 'Previous Key' data is stored here.
; If portamento is not currently active, the target frequency will be set a
; second time, together with the voice frequency buffers specific to
; portamento, and glissando.
    BSR     voice_add_mono_store_key_and_frequency

; Test whether the portamento rate is at its maximum (0xFF).
; If portamento rate is at maximum, ignore portamento. The voice's target
; frequency is set here, and then the subroutine returns.
    LDAA    <portamento_rate_scaled
    CMPA    #$FF
    BEQ     voice_add_mono_clear_porta_frequency

; Test whether the synth's portamento mode set to 'Fingered'.
    TST     portamento_mode
    BEQ     .exit

; Test whether the synth's portamento pedal is active.
; If portamento is not active, clear the portamento and glissando target
; frequencies here, by setting them to this voice's target frequency.
    TIMD    #PEDAL_INPUT_PORTA, pedal_status_current
    BEQ     voice_add_mono_clear_porta_frequency

.exit:
    RTS

.above_two_voices:
; If there's more than two active voices, check the legato direction,
; and then check whether the new note is further in that direction than the
; previous. If so, the legato target note will need to be updated.
    LDAA    <portamento_direction
    BEQ     .is_new_note_lower

; If the current legato direction is upwards, and the new note is HIGHER,
; then update the stored 'Last Key Event'. Otherwise exit.
    LDAA    <note_number
    SUBA    <note_number_previous
    BCS     .exit

    BRA     .update_last_note

.is_new_note_lower:
; If the current legato direction is downwards, and the new note is LOWER,
; then update the stored 'Last Key Event'. Otherwise exit.
    LDAA    <note_number
    SUBA    <note_number_previous
    BCC     .exit

    BRA     .update_last_note


; ==============================================================================
; VOICE_ADD_MONO_CLEAR_PORTA_FREQUENCY
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; If there is no portamento, this subroutine sets the target frequency for
; voice#0, then sets the same frequency in the associatged portamento, and
; glissando frequency buffers. The effect of this is effectively disabling any
; pitch transition for this voice.
;
; ==============================================================================
voice_add_mono_clear_porta_frequency:           SUBROUTINE
    LDD     voice_frequency_target
    STD     voice_frequency_current_portamento
    STD     voice_frequency_current_glissando

    RTS


; ==============================================================================
; VOICE_ADD_MONO_STORE_KEY_AND_FREQUENCY
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Stores the currently triggered key note in the register for the PREVIOUS
; key note. This is used when adding a voice in monophonic mode.
; This falls-through to set the target pitch for the first voice.
;
; ==============================================================================
voice_add_mono_store_key_and_frequency:         SUBROUTINE
    LDAA    <note_number
    STAA    <note_number_previous

    LDD     <note_frequency
    STD     voice_frequency_target

    RTS
