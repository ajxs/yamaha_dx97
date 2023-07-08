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
; @TAKEN_FROM_DX7_FIRMWARE:0xD43B
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; This subroutine handes 'adding' a new voice event when the synth is in
; polyphonic mode.
;
; ARGUMENTS:
; Memory:
; * note_number: The number of the new note being added.
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
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
; @WARNING: These temporary variable definitions are shared across all of the
; 'Voice Add' subroutines.
.voice_frequency_target_ptr:                    EQU #temp_variables
.voice_status_ptr:                              EQU #temp_variables + 2
.operator_sensitivity_ptr:                      EQU #temp_variables + 4
.operator_volume_ptr:                           EQU #temp_variables + 6
.voice_frequency_initial:                       EQU #temp_variables + 8
.voice_index:                                   EQU #temp_variables + 10
.voice_buffer_offset:                           EQU #temp_variables + 11
.operator_status:                               EQU #temp_variables + 12
.operator_loop_index:                           EQU #temp_variables + 13

; ==============================================================================
    LDAA    #16
    STAA    .voice_index

; Search for an inactive voice in the voice status array.
.find_inactive_voice_loop:
    LDX     #voice_status
    LDAB    voice_add_index
    ANDB    #15                     ; B = B % 16.
    ASLB
    ABX

; Test whether the current voice's 'Active' flag is set.
    TIMX    #VOICE_STATUS_ACTIVE, 1
    BEQ     .found_inactive_voice

; Increment the loop index.
    INC     voice_add_index
    DEC     .voice_index
    BNE     .find_inactive_voice_loop

; If this point is reached, it means no inactive voices have been found.
    RTS

.found_inactive_voice:
; Clear timer interrupt.
    LDAA    <timer_ctrl_status
    PSHA
    CLR     timer_ctrl_status

; Store the current offset into the voice buffers.
    STAB    .voice_buffer_offset

; Send a 'Key Off' event to the EGS. This possibly resets the envelope.
; Add '1', and shift the buffer offset value left to create the bitmask
; for sending a 'Key Off' event for this voice to the EGS chip.
    INCB
    ASLB
    STAB    egs_key_event

; Increment the 'current voice' index so that the next 'Voice Add'
; command starts at the most likely voice to be free.
    INC     voice_add_index

; Setup pointers for the 'Voice Add' functionality.
    LDX     #voice_frequency_target
    STX     .voice_frequency_target_ptr

    LDX     #voice_status
    STX     .voice_status_ptr

; Test whether the portamento pedal is active.
; Note that this line is pulled high when no pedal is inserted.
    TIMD    #PEDAL_INPUT_PORTA, pedal_status_current
    BEQ     .no_portamento

; Test whether the synth's portamento rate is at maximum (0xFF).
; If so, no pitch transition occurs.
    LDAA    <portamento_rate_scaled
    CMPA    #$FF
    BEQ     .no_portamento

; Check if the synth's portamento mode is set to 'Retain'.
; If this is the case, any active notes will retain their current pitch.
    TST     portamento_mode
    BEQ     .initialise_new_note_frequency

; If the synth's portamento mode is set to 'Follow', all active notes will
; transition in pitch to the latest note event.
; This loop updates all of the voices that are currently being sustained,
; setting their target frequency to the new value. This will cause the main
; portamento handler to transition their pitch towards the new note.
    LDAA    #16
    STAA    .voice_index

.update_follow_portamento_frequency_loop:
    LDX     .voice_status_ptr

; Check if this voice is being active. If so, update its target pitch.
    TIMX    #VOICE_STATUS_ACTIVE, 1
    BNE     .update_follow_portamento_frequency_loop_pointer

; The new key log frequency is stored in the 'Target Frequency' entry for
; this voice.
    LDX     .voice_frequency_target_ptr
    LDD     note_frequency
    STD     0,x

.update_follow_portamento_frequency_loop_pointer:
; Increment the voice status array pointer.
    LDAB    #2
    LDX     .voice_status_ptr
    ABX
    STX     .voice_status_ptr

; Increment the target pitch pointer, and decrement the voice index.
    LDX     .voice_frequency_target_ptr
    ABX
    STX     .voice_frequency_target_ptr

    DEC     .voice_index
    BNE     .update_follow_portamento_frequency_loop

    BRA     .set_voice_status

.no_portamento:
; In the event that there is no portamento, the 'previous' note frequency is set
; to the current target pitch. The effect of this is that when the
; portamento, and glissando buffers are initialised with the 'new' note
; frequency in the block below, no pitch transition will occur.
    LDD     note_frequency
    STD     note_frequency_previous

.initialise_new_note_frequency:
; This sets the 'initial' starting frequency of the new note.
; If portamento is enabled, the initial frequency will be the frequency of the
; previous note. This will cause the pitch to transition to the new note.
; Otherwise the initial frequency will be the new note frequency.
    BSR     voice_add_poly_set_initial_frequency

; The 'previous' new note frequency is now set as the 'initial' frequency
; of the new note to be added. This frequency value will be sent to the EGS.
    STD     .voice_frequency_initial

; Load the target frequency buffer, add offset, and store the target
; frequency for the current voice.
    LDX     .voice_frequency_target_ptr
    LDAB    .voice_buffer_offset
    ABX
    LSRB
    STAB    .voice_index        ; Used in the 'voice_add_load...' subroutine.

; Set the target frequency of this voice to the new note's frequency.
    LDD     note_frequency
    STD     0,x

; Set the 'previous note' frequency to the new note frequency.
    STD     note_frequency_previous

; Load the 'initial' note frequency to the EGS here.
; In the case that portamento is active, this will be the 'previous' note
; frequency. Otherwise it will be the 'new' note frequency.
; Note that if the portamento pedal is inactive, the 'initial' note frequency
; be initialised to the 'new' note frequency, and loaded to the EGS again.
    JSR     voice_add_load_frequency_to_egs

.set_voice_status:
; Set the status of the new voice.
; Refer to this array's documentation in 'ram.asm' for more information.
    LDX     #voice_status
    LDAB    .voice_buffer_offset
    ABX
    LDAA    <note_number
    LDAB    #VOICE_STATUS_ACTIVE
    STD     0,x

; Reset the current pitch EG level to its initial value.
; In the DX7, the final value, and the initial value are identical. So when
; adding a voice, the initial level is set to the final value.
    LDX     #pitch_eg_current_frequency
    LDAB    .voice_buffer_offset
    ABX

    LDAA    pitch_eg_parsed_level_final
    CLRB
    LSRD
    STD     0,x

; Reset the 'Current Pitch EG Step' for this voice.
    LDX     #pitch_eg_current_step
    LDAB    .voice_buffer_offset
    LSRB
    ABX
    CLR     0,x

; Initialise the LFO.
    VOICE_ADD_INITIALISE_LFO

; If the portamento pedal is inactive, the 'new' note frequency will be loaded
; to the EGS in the following subroutine call.
; Otherwise, the previously loaded 'initial' value will be used.
; The effect of this is to make the note pitch transition instantaneous when
; a portamento pedal is inserted, but not active.
    LDAA    .voice_buffer_offset
    LSRA
    LDX     <note_frequency
    JSR     voice_add_operator_level_voice_frequency

; Construct a 'Note On' event for this voice from the buffer offset, same
; as before, and load it to the EGS voice event register.
    LDAB    .voice_buffer_offset
    ASLB
    INCB
    STAB    egs_key_event

; Reset the timer-control/status register to re-enable timer interrupts.
    PULA
    STAA    <timer_ctrl_status

    RTS


; ==============================================================================
; VOICE_ADD_POLY_SET_INITIAL_FREQUENCY
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE:0xD4CA
; @CHANGED_FOR_6_OP
; @PRIVATE
; DESCRIPTION:
; This subroutine sets the 'initial' frequency for the new note.
; This involves setting the current portamento, and glissando frequency values
; for the new note's voice. If portamento is enabled, this frequency value will
; be that of the previously added voice. Otherwise it will be the frequency
; of the new note.
;
; ARGUMENTS:
; Memory:
; * note_frequency_previous: The 'initial' frequency value.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCD: The 'initial' note frequency.
;
; ==============================================================================
voice_add_poly_set_initial_frequency:           SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
; @WARNING: These temporary variable definitions are shared across all of the
; 'Voice Add' subroutines.
.voice_frequency_target_ptr:                    EQU #temp_variables
.voice_status_ptr:                              EQU #temp_variables + 2
.operator_sensitivity_ptr:                      EQU #temp_variables + 4
.operator_volume_ptr:                           EQU #temp_variables + 6
.voice_frequency_initial:                       EQU #temp_variables + 8
.voice_index:                                   EQU #temp_variables + 10
.voice_buffer_offset:                           EQU #temp_variables + 11
.operator_status:                               EQU #temp_variables + 12
.operator_loop_index:                           EQU #temp_variables + 13

; ==============================================================================
    LDAB    .voice_buffer_offset
    LDX     #voice_frequency_current_portamento
    ABX

; This 'load IX, add B to index, push, repeat, store, pull' routine
; here avoids the need to load ACCD twice.
    PSHX
    LDX     #voice_frequency_current_glissando
    ABX
    LDD     note_frequency_previous

; Store 14-bit key log frequency.
    STD     0,x
    PULX
    STD     0,x

    RTS
