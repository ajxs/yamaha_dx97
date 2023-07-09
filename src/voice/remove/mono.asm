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
; voice/remove/mono.asm
; ==============================================================================
; DESCRIPTION:
; This file contains code related to removing a voice when the synth is in
; monophonic mode.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; VOICE_REMOVE_MONO
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; Removes a voice with the specified note frequency when the synth is in
; polyphonic mode.
;
; ARGUMENTS:
; Registers:
; * ACCA: The number of the note to remove.
;
; MEMORY MODIFIED:
; * active_voice_count
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
voice_remove_mono:                              SUBROUTINE
    JSR     voice_remove_mono_find_voice_with_key
    TSTA
    BEQ     .exit

; In mono mode, the associated entry in the voice event buffer is cleared.
    LDD     #0
    STD     0,x

; Ensure that the number of voices is valid before decrementing it.
    TST     active_voice_count
    BEQ     .exit

    DEC     active_voice_count
    BNE     .multiple_active_voices

; If the sustain pedal is active, exit without sending the 'Note Off' event.
    TIMD    #PEDAL_INPUT_SUSTAIN, sustain_status
    BNE     .exit

; Set the Pitch EG for this voice to its release stage.
    LDAA    #4
    STAA    pitch_eg_current_step

; Write 'Key Off' event to EGS.
    LDAB    #EGS_VOICE_EVENT_OFF
    STAB    egs_key_event

.exit:
    RTS

.multiple_active_voices:
; Since there's still active voices after removing this one, the
; following section deals with finding the pitch of the 'last' active key,
; and depending on the legato direction, finding the lowest, or highest
; note remaining, and setting its frequency as the new target.
; This will cause the synth's portamento to transition towards this
; pitch in the 'portamento_process' subroutine.
    JSR     voice_remove_mono_find_active_key_event

    LDAA    <portamento_direction
    BNE     .portamento_moving_upwards

; If the portamento direction was down, find the next lowest note to return to.
    JSR     voice_remove_mono_find_lowest_note
    BRA     .store_portamento_target_frequency

.portamento_moving_upwards:
; If the portamento direction was up, find the next highest note to return to.
    JSR     voice_remove_mono_find_highest_note

.store_portamento_target_frequency:
    LDAB    <note_number_previous

; Now that the key for the portamento to transition to has been found,
; calculate and store the new target frequency.
    JSR     voice_transpose_and_convert_note_to_log_freq
    LDD     <note_frequency
    STD     voice_frequency_target

; Test if the portamento rate is instantaneous.
    LDAA    <portamento_rate_scaled
    CMPA    #$FF
    BEQ     .no_portamento

; Test if the portamento mode is 'Fingered'.
; If not, it means that the frequency is not going to transition back.
; @TODO: Test this.
    TST     portamento_mode
    BEQ     .portamento_mode_full_time

; Test whether the pedal is inactive.
; If so, set the portamento/glissando frequency to the new target to exit
; without any pitch transition.
    TIMD    #PEDAL_INPUT_PORTA, pedal_status_current
    BEQ     .no_portamento

.portamento_mode_full_time:
    RTS

.no_portamento:
    LDD     voice_frequency_target
    STD     voice_frequency_current_portamento
    STD     voice_frequency_current_glissando

    RTS

; ==============================================================================
; VOICE_REMOVE_MONO_FIND_VOICE_WITH_KEY
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE:0xD69F
; @CHANGED_FOR_6_OP
; @PRIVATE
; DESCRIPTION:
; Searches each word-length entry in the voice status buffer to find an entry
; matching the specified key.
;
; ARGUMENTS:
; Registers:
; * ACCA: The number of the note to find.
;
; RETURNS:
; * ACCA: The match, or zero if not found.
; * ACCB: The voice number the match was found in, or zero if not found.
; * IX:   A pointer to the location in the voice event buffer.
;
; ==============================================================================
voice_remove_mono_find_voice_with_key:          SUBROUTINE
    LDAB    #16
    LDX     #voice_status

.find_voice_loop:
    CMPA    0,x
    BEQ     .voice_found

    INX
    INX
    DECB
    BNE     .find_voice_loop

; If the key is not found, return 0.
    CLRA
; Fall-through to exit.

.voice_found:
    RTS


; ==============================================================================
; VOICE_REMOVE_MONO_FIND_ACTIVE_KEY_EVENT
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE:0xD6B4
; @PRIVATE
; DESCRIPTION:
; Searches through the 'Voice Status Buffer', searching for the first entry with
; a non-cleared 'Note' field. This is used during the process of removing a
; voice when the synth is in monophonic mode.
;
; MEMORY MODIFIED:
; * note_number_previous: The found entry is stored here.
;
; RETURNS:
; * ACCB: The voice number where the entry was found, or zero if not found.
;
; ==============================================================================
voice_remove_mono_find_active_key_event:        SUBROUTINE
    LDAB    #16
    LDX     #voice_status

.find_active_key_event_loop:
    LDAA    0,x
    BNE     .active_entry_found

    INX
    INX
    DECB
    BNE     .find_active_key_event_loop

    RTS

.active_entry_found:
    STAA    <note_number_previous
    INX
    INX

    RTS


; ==============================================================================
; VOICE_REMOVE_MONO_FIND_HIGHEST_NOTE
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE:0xD6C8
; @PRIVATE
; DESCRIPTION:
; Searches through the 'Voice Events' buffer searching the active voice event
; with the highest key number.
; This is used when removing a voice in monophonic mode.
;
; ARGUMENTS:
; Registers:
; * ACCB: The starting index for the search for the highest note.
;
; MEMORY MODIFIED:
; * note_number_previous
;
; ==============================================================================
voice_remove_mono_find_highest_note:            SUBROUTINE
    DECB
    BNE     .is_voice_event_inactive

    RTS

.is_voice_event_inactive:
    LDAA    0,x
    BEQ     .increment_index

; If the current entry's key number is higher than the presently stored
; entry, store this key number instead.
    SUBA    <note_number_previous
    BMI     .increment_index

    BSR     voice_remove_mono_set_portamento_target_note

.increment_index:
    INX
    INX
    BRA     voice_remove_mono_find_highest_note


; ==============================================================================
; VOICE_REMOVE_MONO_FIND_LOWEST_NOTE
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE:0xD6DA
; @PRIVATE
; DESCRIPTION:
; Searches through every entry in the 'Voice Events' buffer searching for the
; active voice event with the lowest key number.
; This is used when removing a voice in monophonic mode.
;
; ARGUMENTS:
; Registers:
; * ACCB: The starting index for the search for the highest note.
;
; MEMORY MODIFIED:
; * note_number_previous
;
; ==============================================================================
voice_remove_mono_find_lowest_note:             SUBROUTINE
    DECB
    BNE     .is_voice_event_inactive

    RTS

.is_voice_event_inactive:
    LDAA    0,x
    BEQ     .increment_index

; If the current entry's key number is lower than the presently stored
; entry, store this key number instead.
    SUBA    <note_number_previous
    BPL     .increment_index

    BSR     voice_remove_mono_set_portamento_target_note

.increment_index:
    INX
    INX
    BRA     voice_remove_mono_find_lowest_note


; ==============================================================================
; VOICE_REMOVE_MONO_SET_PORTAMENTO_TARGET_NOTE
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE:0xD6EC
; @CHANGED_FOR_6_OP
; @PRIVATE
; DESCRIPTION:
; Sets the new portamento 'target' note.
; This subroutine is used when the synth is in 'Fingered' portamento mode, and
; the second note has been released. This is going to cause the pitch to
; transition back to the previously triggered note.
;
; Registers:
; * IX:   The portamento 'target' note.
;
; MEMORY MODIFIED:
; * note_number_previous
;
; ==============================================================================
voice_remove_mono_set_portamento_target_note:   SUBROUTINE
    LDAA    0,x
    STAA    <note_number_previous
    RTS
