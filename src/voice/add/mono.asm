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
; * note_frequency: The frequency of the new note being added.
;
; MEMORY MODIFIED:
; * voice_status
; * active_voice_count
; * portamento_direction
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================

    .PROCESSOR HD6303

voice_add_mono:                                 SUBROUTINE
    LDX     #voice_status

; Test whether there are currently other active voices. This is relevant to
; determine how the synth should handle portamento.
; If there are no voices currently active, immediately add the new voice.
    LDAA    <active_voice_count
    BEQ     .add_new_voice

; If there are currently 16 active voices, exit.
    CMPA    #16
    BEQ     .exit_no_voices_available

; Loop through all the voices until a free entry is found.
    LDAB    #16
.find_free_voice_loop:
; Since the voice status format in 'Mono' mode clears a voice entry when it
; is not active, test whether the MSB of each entry is 'zero' to determine
; whether it is free.
    TST     0,x
    BEQ     .add_new_voice

    INX
    INX
    DECB
    BNE     .find_free_voice_loop

.exit_no_voices_available:
; If this point is reached, it means no free voice slot is available.
    RTS

.add_new_voice:
; Store the 14-bit pitch, and voice status in the free voice status entry.
    LDD     <note_frequency
    ORAB    #VOICE_STATUS_ACTIVE
    STD     0,x

; Reset LFO delay, and LFO fadein.
    TST     patch_edit_lfo_delay
    BEQ     .increment_voice_count

    LDD     #0
    STD     <lfo_delay_accumulator
    STD     <lfo_delay_fadein_factor

.increment_voice_count:
    LDX     #voice_status
    LDAA    <active_voice_count
    INCA
    STAA    <active_voice_count

; Check if there's more than one voice after incrementing the voice count.
    CMPA    #1
    BNE     voice_add_mono_multiple_active_voices

; This section covers the case where no other voice was active when this
; new voice was added.
; @TODO: Unsure why the 'Off' event is sent here.
    LDAA    #EGS_VOICE_EVENT_OFF
    STAA    egs_key_event

; Save the new frequency to the 'Target Voice Frequency' buffer.
    LDD     <note_frequency
    STD     32,x

; Test whether the portamento mode is 'Fingered' or 'Full-Time'.
; If 'Full-Time', don't update the 'Current' frequency, as the previous
; could still be in transition.
    TST     portamento_mode
    BEQ     .send_voice_data_to_egs

    STD     64,x

.send_voice_data_to_egs:
    CLRA
    LDX     <note_frequency
    JSR     voice_add_operator_level_voice_frequency

; Send the 'Voice On' event to the EGS chip.
    LDAA    #EGS_VOICE_EVENT_ON
    STAA    egs_key_event

    RTS


; ==============================================================================
; VOICE_ADD_MONO_MULTIPLE_ACTIVE_VOICES
; ==============================================================================
; DESCRIPTION:
; @TODO
; ==============================================================================
voice_add_mono_multiple_active_voices:          SUBROUTINE
    CMPA    #2
    BNE     .more_than_two_voices_active

    LDD     <note_frequency
; IX  currently points at the Voice Status array.
; Subtract the active voice's current note frequency from that of the new note.
    SUBD    0,x

; If the new note being added is higher than the previous active note, set
; the portamento directon to '1'.
    BCC     .portamento_direction_up

    CLR     portamento_direction
    BRA     .update_voice_target_frequencies

.portamento_direction_up:
    LDAA    #1
    STAA    <portamento_direction

.update_voice_target_frequencies:
; Update the voice target frequency, and the portamento target frequency.
    LDD     <note_frequency
    STAA    <porta_current_target_freq
    STD     32,x

    RTS

.more_than_two_voices_active:
; The current section handles the case that there are more than two active
; voices after incrementing the voice count.
; Test the portamento direction, and the target frequency to determine
; whether the newly added note overrides the previous target frequency.

; Test the portamento direction. Branch if 'downwards'.
    LDAA    <portamento_direction
    BEQ     .more_than_two_voices_active_porta_down

    LDAA    <note_frequency
    SUBA    <porta_current_target_freq

; If the carry bit is set, it indicates that the current portamento target
; frequency is higher than the new note. In this case, don't update the
; portamento target frequency.
    BCS     .exit_frequency_not_updated
    BRA     .update_voice_target_frequencies

.more_than_two_voices_active_porta_down:
    LDAA    <note_frequency
    SUBA    <porta_current_target_freq

; If the carry bit is clear, it indicates that the current portamento target
; frequency is lower than the new note. In this case, don't update the
; portamento target frequency.
    BCC     .exit_frequency_not_updated
    BRA     .update_voice_target_frequencies

.exit_frequency_not_updated:
; If this is reached, it indicates that (based upon the portamento direction)
; the new note should not be set as the new portamento target because it is
; either not higher, or lower than the current target.
    RTS
