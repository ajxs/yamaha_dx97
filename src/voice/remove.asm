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
; voice/remove.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the various subroutines used to remove notes.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; VOICE_REMOVE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Removes a voice with the specified note.
; This routine is called by both MIDI, and keyboard events.
;
; ARGUMENTS:
; Registers:
; * ACCB: The MIDI note number of the note to remove.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
voice_remove:                                   SUBROUTINE
; Since the voice status array entries are stored as words with the 14-bit
; pitch stored together with the voice status, it's possible to use only
; the most-significant byte of the pitch to find the correct voice.
    LDX     #table_midi_key_to_log_f
    ABX
    LDAA    0,x

; Jump to the appropriate function based upon the synth's selected polyphony.
    LDAB    mono_poly
    BEQ     voice_remove_poly
    JMP     voice_remove_mono


; ==============================================================================
; VOICE_REMOVE_POLY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Removes a voice with the specified note frequency when the synth is in
; polyphonic mode.
;
; ARGUMENTS:
; Registers:
; * ACCA: The MSB of the logarithmic frequency of the note to remove.
; The voice status array entries are stored as words with the 14-bit
; logarithmic frequency stored together with the voice status bits. This byte
; is used to search for the voice to remove.
;
; MEMORY MODIFIED:
; * voice_status;
; * sustain_status
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
voice_remove_poly:                              SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.voice_status_pointer:                          EQU #temp_variables
.pitch_eg_step_pointer:                         EQU #(temp_variables + 2)

; ==============================================================================
    LDAB    #EGS_VOICE_EVENT_OFF

    LDX     #pitch_eg_current_step
    STX     .pitch_eg_step_pointer

    LDX     #voice_status
    STX     .voice_status_pointer

.find_active_voice_loop:
; Check whether the MSB of the current voice's frequency is equal to the
; frequency being removed, indicating that this is the voice being stopped.
    CMPA    0,x
    BNE     .find_active_voice_loop_increment

; Test whether the voice being stopped is currently active.
    TIMX    #VOICE_STATUS_ACTIVE, 1
    BNE     .is_voice_sustained

.find_active_voice_loop_increment:
    INX
    INX
    STX     .voice_status_pointer

    LDX     .pitch_eg_step_pointer
    INX
    STX     .pitch_eg_step_pointer

    LDX     .voice_status_pointer

; The value in ACCB corresponds to the EGS 'Voice Event' field.
; Since the voice number is stored in fields 2-5, incrementing the index
; by 4 will increment the voice number field by one.
    ADDB    #4

; Test whether we're at iteration 16 by checking whether this value is
; above 64. This is done because the bit corresponding to
; 'EGS Voice Event Off' was previous set.
    BITB    #64
    BEQ     .find_active_voice_loop

; If this point has been reached, an active voice with the specified
; frequency cannot be found.
    BRA     .exit

.is_voice_sustained:
; Now that the voice has been found, test whether the sustain pedal is
; currently active. If so, the voice itself will be set inactive, but the
; voice will stay in its sustain phase.
    TIMD   #PEDAL_INPUT_SUSTAIN, sustain_status
    BNE     .voice_sustained

; If sustain is not active, deactivate the voice, and store the voice
; event deactivating the voice to the EGS chip.
    AIMX    #~VOICE_STATUS_ACTIVE, 1
    STAB    egs_key_event

; Set the pitch EG to its release stage.
    LDX     .pitch_eg_step_pointer
    LDAA    #4
    STAA    0,x

    BRA     .exit

.voice_sustained:
; Since the sustain pedal is depressed, set the voice status bit indicating
; that the voice is sustained, and reset the bit indicating it is active.
    OIMX    #VOICE_STATUS_SUSTAIN, 1
    AIMX    #~VOICE_STATUS_ACTIVE, 1

.exit:
    RTS


; ==============================================================================
; VOICE_REMOVE_MONO
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Removes a voice with the specified note frequency when the synth is in
; polyphonic mode.
;
; ARGUMENTS:
; Registers:
; * ACCA: The MSB of the logarithmic frequency of the note to remove.
; The voice status array entries are stored as words with the 14-bit
; logarithmic frequency stored together with the voice status bits. This byte
; is used to search for the voice to remove.
;
; MEMORY MODIFIED:
; * active_voice_count
; * note_frequency
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
voice_remove_mono:                              SUBROUTINE
    TST     active_voice_count

; Branch, and exit in the case that the voice count is zero, or less.
    BLE     .exit
    STAA    <note_frequency
    JSR     voice_remove_mono_get_active_voice

; The carry flag being set indicates a failure condition: That a voice
; with the specified note frequency cannot be found.
    BCS     .exit

; If the voice was found, decrement the active voice count, and proceed to
; deactivating the voice.
    DEC     active_voice_count
    BNE     voice_remove_mono_set_new_target_freq_and_exit

; Now that the voice has been found, test whether the sustain pedal is
; currently active. If so, the voice itself will be set inactive, but the
; voice will stay in its sustain phase.
    LDX     #voice_status
    TST     sustain_status
    BMI     .voice_sustained

; Set the pitch EG to its release stage.
    LDAA    #4
    STAA    pitch_eg_current_step

; Set the current voice's status entry to 'inactive', and send the 'Key Off'
; event signal to the EGS chip.
    AIMX    #~VOICE_STATUS_ACTIVE, 1
    LDAB    #EGS_VOICE_EVENT_OFF
    STAB    egs_key_event
    BRA     .exit

.voice_sustained:
; Since the sustain pedal is depressed, set the voice status bit indicating
; that the voice is sustained, and reset the bit indicating it is active.
    OIMX    #VOICE_STATUS_SUSTAIN, 1
    AIMX    #~VOICE_STATUS_ACTIVE, 1

.exit:
    RTS


; ==============================================================================
; VOICE_REMOVE_MONO_SET_NEW_TARGET_FREQ_AND_EXIT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; If there are still active voices after removing the current one, this
; subroutine is called to set the portamento target frequency accordingly.
;
; ARGUMENTS:
; Registers:
; * IX:   A pointer to the entry in the voice status array for the voice to be
;         deactivated.
;
;
; MEMORY MODIFIED:
; * voice_status
; * note_frequency
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
voice_remove_mono_set_new_target_freq_and_exit: SUBROUTINE
    LDD     #0
    STD     0,x
    JSR     voice_remove_mono_get_porta_target_note

; Store the new target frequency, and mask the lowest two bits.
    STD     <note_frequency
    ANDB    #%11111100
    STD     voice_frequency_target

; Test whether there is only one voice remaining after removing the active one.
    LDAA    <active_voice_count
    CMPA    #1
    BNE     .exit

; If the decremented voice count is now equal to '1', clear the target note, and
; set voice#0 to the target frequency.
; IX now points at the next target note.
    LDD     #0
    STD     0,x
    LDD     <note_frequency
    STD     voice_status

.exit:
    RTS


; ==============================================================================
; VOICE_REMOVE_MONO_GET_ACTIVE_VOICE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Searches through the voice status array to find a currently active voice
; matching the specified frequency.
; This is used when removing a voice in monophonic mode.
;
; ARGUMENTS:
; Memory:
; * note_frequency: The frequency to search for.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * IX:   A pointer to the index of the voice status entry matching the
;         specified frequency.
; * CC:C: The carry flag is set to indicate the failure condition of not being
;         able to find the matching voice.
;
; ==============================================================================
voice_remove_mono_get_active_voice:             SUBROUTINE
    LDAB    #16
    LDX     #voice_status

.get_active_voice_loop:
    LDAA    0,x
    CMPA    <note_frequency
    BEQ     .exit

    INX
    INX
    DECB
    BNE     .get_active_voice_loop

; If the loop reaches zero without finding the active voice with the
; specified note, set the carry flag to indicate a failure condition.
    SEC

.exit:
    RTS


; ==============================================================================
; VOICE_REMOVE_MONO_GET_PORTA_TARGET_NOTE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Based upon the portamento direction, and the current portamento target
; frequency, finds the next target frequency. This is used when removing a
; currently playing note in mono mode.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCD: The value of the voice status entry of the next portamento target.
; * IX:   A pointer to the next portamento target note.
;
; ==============================================================================
voice_remove_mono_get_porta_target_note:        SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.target_note_index:                             EQU #temp_variables

; ==============================================================================
    CLRB
    LDX     #voice_status
    CLR     porta_current_target_freq

; If porta direction is down, set the current target value to 0xFF, so
; that it is easy to compare if the next found value is lower.
    TST     portamento_direction
    BNE     .get_porta_target_note_loop

    COM     porta_current_target_freq

; Based upon the portamento direction, loop over each of the 16 voices,
; testing which note should be the next target. If the direction of
; portamento is 'down', find the lowest note, otherwise find the highest.
.get_porta_target_note_loop:
    LDAA    0,x

; If inactive, advance to the next entry.
    BEQ     .get_porta_target_note_loop_advance
    TST     portamento_direction

; Branch if porta direction is 'down'.
    BEQ     .get_porta_target_note_lower
    CMPA    <porta_current_target_freq

; if the current highest is higher than this note, advance the loop.
    BCS     .get_porta_target_note_loop_advance
    BRA     .set_porta_target_note

.get_porta_target_note_lower:
    CMPA    <porta_current_target_freq

; If the current lowest is lower than this note, advance the loop.
    BHI     .get_porta_target_note_loop_advance

.set_porta_target_note:
    STAA    <porta_current_target_freq
    STAB    .target_note_index

.get_porta_target_note_loop_advance:
    INX
    INX
    INCB
    CMPB    #16
    BNE     .get_porta_target_note_loop

; Use the found note index to look up, and return the status array entry.
    LDX     #voice_status
    LDAB    .target_note_index
    ASLB
    ABX
    LDD     0,x

    RTS
