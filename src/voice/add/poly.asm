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
; voice/add/poly.asm
; ==============================================================================
; DESCRIPTION:
; This subroutine handes 'adding' a new voice event when the synth is in
; polyphonic mode.
;
; ARGUMENTS:
; Memory:
; * note_frequency: The frequency of the new note being added.
;
; MEMORY MODIFIED:
; * voice_status
; * voice_add_index
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================

    .PROCESSOR HD6303

voice_add_poly:                                 SUBROUTINE
; Loop through the 16 entries in the voice status buffer, testing each
; to find a free voice.
; The voice number offset is not reset each time, and resumes at the same
; place it did in the last 'Note On' event. This variable is initialised on
; device reset.
    LDAA    #16
    LDAB    <voice_add_index

.find_inactive_voice_loop:
; Test the status of each voice to find one that is marked as inactive.
    LDX     #voice_status
    ABX
    TIMX   #VOICE_STATUS_ACTIVE, 1
    BEQ     .found_inactive_voice

    INCB
    INCB
    ANDB    #%11110 ; ACCB % 32.
    DECA
    BNE     .find_inactive_voice_loop

; This point is reached if there are no free voices.
    JMP     .exit

.found_inactive_voice:
; Store ACCB into the 'Buffer Offset' value. This value will be the
; current voice number * 2, used as an offset into the voice buffers.

; Shift the buffer offset value to the left, and add '1' to create the
; bitmask for sending a 'Note Off' event for this voice to the EGS chip.
    STAB    <voice_add_index
    INCB
    ASLB
    STAB    egs_key_event

; Store the target frequency for this voice.
    LDD     <note_frequency
    STD     32,x

; The following section tests all of the remaining voices to find another
; one that is inactive. Once it is found, the target, and current frequency
; for this voice is updated to that of the newly added note.

; The decrementing loop counter is set to 15, rather than the full 16, so that
; the loop through the array will not wrap all the way around to the new
; 'Note On' voice.
; @TODO: Understand why this happens.
    LDAA    #15
; The loop through the voices starts at the previously free voice index.
    LDAB    <voice_add_index

.find_second_inactive_voice_loop:
; Increment the voice offset, and perform ACCB % 32 to ensure it doesn't
; exceed the total offset.
    INCB
    INCB
    ANDB    #%11110

; Test if the current voice is active.
; If it is inactive, proceed to setting the frequency for this voice.
    LDX     #voice_status
    ABX
    TIMX   #VOICE_STATUS_ACTIVE, 1
    BEQ     .set_second_voice_frequency

; Decrement the loop index.
    DECA
    BNE     .find_second_inactive_voice_loop
    BRA     .set_voice_status

.set_second_voice_frequency:
    LDD     <note_frequency
    STD     32,x
    STD     64,x

.set_voice_status:
; Load the previously stored voice number index, and use this as an offset
; into the voice status array.
; Update the voice status, and store the 14-bit frequency for the new note.
    LDX     #voice_status
    LDAB    <voice_add_index
    ABX
    LDD     <note_frequency
    ORAB    #VOICE_STATUS_ACTIVE
    STD     0,x

; Reset the LFO Delay.
    TST     patch_edit_lfo_delay
    BEQ     .store_frequency_to_egs

    LDD     #0
    STD     <lfo_delay_accumulator
    STD     <lfo_delay_fadein_factor

.store_frequency_to_egs:
    LDAA    <voice_add_index

; Convert the voice index variable to the voice number value by shifting right.
    LSRA

; @TODO: ?
; Store the note frequency, and key on event to the EGS chip.
    LDX     <note_frequency
    JSR     voice_add_operator_level_voice_frequency
    LDAA    <voice_add_index
    ASLA
    INCA
    STAA    egs_key_event
    LDAB    <voice_add_index

; Increment this index value so it is in the most likely position to find
; an available voice in the next 'Note On' event.
    INCB
    INCB
    ANDB    #%11110
    STAB    <voice_add_index

.exit:
    RTS
