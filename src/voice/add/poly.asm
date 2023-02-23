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
; @TAKEN_FROM_DX7_FIRMWARE
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
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
; @WARNING: These temporary variable definitions are shared across all of the
; 'Voice Add' subroutines.
.voice_frequency_target_ptr:                    EQU #temp_variables
.voice_status_ptr:                              EQU #temp_variables + 2
.operator_sensitivity_ptr:                      EQU #temp_variables + 4
.operator_volume_ptr:                           EQU #temp_variables + 6
.voice_frequency_current:                       EQU #temp_variables + 8
.voice_frequency_new:                           EQU #temp_variables + 10
.voice_index:                                   EQU #temp_variables + 12
.voice_current:                                 EQU #temp_variables + 13
.find_inactive_voice_loop_index:                EQU #temp_variables + 14
.voice_buffer_offset:                           EQU #temp_variables + 15
.operator_status:                               EQU #temp_variables + 16
.operator_loop_index:                           EQU #temp_variables + 17

; ==============================================================================
    LDAA    #16
    STAA    .find_inactive_voice_loop_index

; Search for an entry in the voice key event array where bit 1 is 0.
; This indicates that the voice is currently inactive.
.find_inactive_voice_loop:
    LDX     #voice_status
    LDAB    voice_add_index
    ANDB    #15
    ASLB
    ABX
    LDAA    1,x

; Test whether the current voice has an active key event.
    BITA    #VOICE_STATUS_ACTIVE
    BEQ     .deactivate_found_active_voice

; Increment the loop index.
    INC     voice_add_index
    DEC     .find_inactive_voice_loop_index
    BNE     .find_inactive_voice_loop

; If this point is reached, it means no inactive voices have been found.
    RTS

.deactivate_found_active_voice:
; Send a 'Key Off' event to the EGS chip's 'Key Event' register, prior to
; sending the new 'Key On' event.

; Store the current offset into the voice buffers.
    STAB    .voice_buffer_offset

; Add '1', and shift the buffer offset value to the left to create the bitmask
; for sending a 'Key Off' event for this voice to the EGS chip.
    INCB
    ASLB
; Write the 'Key Off' event for this voice to the EGS chip.
    STAB    egs_key_event

    LDAA    #16
    STAA    .voice_index

; Increment the 'current voice' index so that the next 'Voice Add'
; command starts at the most likely free voice.
    INC     voice_add_index

; Setup pointers for the 'Voice Add' functionality.
    LDX     #voice_frequency_target
    STX     .voice_frequency_target_ptr

    LDX     #voice_status
    STX     .voice_status_ptr

; Test whether the portamento pedal is active.
    LDAA    pedal_status_current
    BITA    #PEDAL_INPUT_PORTA
    BEQ     .no_portamento

; Test whether the synth's portamento rate is at maximum (0xFF).
; If so, no pitch transition occurs.
    LDAA    <portamento_rate_scaled
    CMPA    #$FF
    BEQ     .no_portamento

; Check if the synth's portamento mode is set to 'Follow'.
; If this is the case, all of the currently active notes will 'follow' the
; pitch of the new note, gliding until the new target frequency is reached.
    TST     portamento_mode
    BEQ     .set_portamento_glissando_frequency

; If the synth's portamento mode is set to 'Follow', in which all active
; notes transition to the latest note event, update all of the voices that
; are currently being sustained by the sustain pedal, setting their target
; frequency to the new value. This will cause the main portamento handler to
; transition their pitches towards that of the new note.
.update_follow_portamento_frequency_loop:
    LDX     .voice_status_ptr
    LDAA    1,x

; Check if this voice is being active. If so, update its target pitch.
    BITA    #VOICE_STATUS_ACTIVE
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
; portamento, and glissando buffers are set, no pitch transition will occur.
    LDD     note_frequency
    STD     note_frequency_previous

.set_portamento_glissando_frequency:
; If portamento is currently enabled, the 'current' portamento, and
; glissando frequencies for the new note will be set to the target frequency
; of the previous note pressed.
; In the event that there is no portamento. The portamento and glissando
; pitch buffers will have been set to the current voice's target frequency
; above. The effect of this is that there will be no frequency transition.
; After these buffers have been set, the 'new' current frequency is set, which
; will be loaded to the EGS below.
    JSR     voice_add_poly_set_portamento_frequency
    STD     .voice_frequency_new

; Load the target frequency buffer, add offset, and store the target
; frequency for the current voice.
    LDX     .voice_frequency_target_ptr
    LDAB    .voice_buffer_offset
    ABX
    LSRB
    STAB    .voice_current

; Store the frequency of this note as the previous frequency.
    LDD     note_frequency
    STD     0,x
    STD     note_frequency_previous

; Load the new frequency to the EGS here.
; It will be loaded again below. However if the portamento pedal is active
; this will be the place the frequency is initially loaded.
    JSR     voice_add_load_frequency_to_egs

.set_voice_status:
; Set the status of the current voice.
; This is a 16-bit value in the format: (Key_Number << 8) | Flags.
; The flags field has two bits:
;  * '0b10' : This voice is actively playing a note.
;  * '0b1'  : This voice is being sustained.
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
; If the synth's LFO delay is not set to 0, reset the LFO delay accumulator.
    LDAA    patch_edit_lfo_delay
    BEQ     .is_lfo_sync_enabled

    LDD     #0
    STD     <lfo_delay_accumulator
    CLR     lfo_delay_fadein_factor

.is_lfo_sync_enabled:
; If 'LFO Key Sync' is enabled, reset the LFO phase accumulator to its
; maximum positive value to coincide with the 'Key On' event.
    LDAA    patch_edit_lfo_sync
    BEQ     .write_frequency_to_egs

    LDD     #$7FFF
    STD     <lfo_phase_accumulator

.write_frequency_to_egs:
    LDAA    .voice_buffer_offset
    LSRA

; The key frequency is stored again in this subroutine call.
    LDX     <note_frequency
    JSR     voice_add_operator_level_voice_frequency

; Construct a 'Note On' event for this voice from the buffer offset, same
; as before, and load it to the EGS voice event register.
    LDAB    .voice_buffer_offset
    ASLB
    INCB
    STAB    egs_key_event

    RTS


; ==============================================================================
; VOICE_ADD_POLY_SET_PORTAMENTO_FREQUENCY
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; This subroutine sets the current portamento, and glissando frequency values
; for the current voice from the frequency of the 'last' note.
; @Note: This subroutine shares the same temporary variables as its caller.
;
; ARGUMENTS:
; Memory:
; * note_frequency_previous
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCD: The 'previous' note frequency.
;
; ==============================================================================
voice_add_poly_set_portamento_frequency:        SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
; @WARNING: These temporary variable definitions are shared across all of the
; 'Voice Add' subroutines.
.voice_frequency_target_ptr:                    EQU #temp_variables
.voice_status_ptr:                              EQU #temp_variables + 2
.operator_sensitivity_ptr:                      EQU #temp_variables + 4
.operator_volume_ptr:                           EQU #temp_variables + 6
.voice_frequency_current:                       EQU #temp_variables + 8
.voice_frequency_new:                           EQU #temp_variables + 10
.voice_index:                                   EQU #temp_variables + 12
.voice_current:                                 EQU #temp_variables + 13
.find_inactive_voice_loop_index:                EQU #temp_variables + 14
.voice_buffer_offset:                           EQU #temp_variables + 15
.operator_status:                               EQU #temp_variables + 16
.operator_loop_index:                           EQU #temp_variables + 17

; ==============================================================================
    LDAB    .voice_buffer_offset
    LDX     #voice_frequency_current_portamento
    ABX

; This 'load IX, add B to index, push, repeat, store, pull' routine
; here avoids needing to load ACCD twice.
    PSHX
    LDX     #voice_frequency_current_glissando
    ABX
    LDD     note_frequency_previous

; Store 14-bit key log frequency.
    STD     0,x
    PULX
    STD     0,x

    RTS
