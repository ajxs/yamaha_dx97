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
; voice/remove/poly.asm
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; This file contains the subroutine for removing a voice when the synth is in
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
; * voice_status
; * pitch_eg_current_step
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================

    .PROCESSOR HD6303

voice_remove_poly:                              SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.pitch_eg_current_step_ptr:                     EQU #temp_variables
.voice_status_ptr:                              EQU #temp_variables + 2
.remove_voice_command_byte:                     EQU #temp_variables + 4

; ==============================================================================
    LDX     #voice_status
    STX     .voice_status_ptr

    LDX     #pitch_eg_current_step
    STX     .pitch_eg_current_step_ptr

    LDAB    #EGS_VOICE_EVENT_OFF

.find_key_event_loop:
    STAB    .remove_voice_command_byte
    LDX     .voice_status_ptr

; Does the current entry in the 'Voice Key Events' buffer match the note
; being removed?
    CMPA    0,x
    BNE     .increment_loop_pointers

; Check if the matching key event is active.
; If not, advance the loop.
    LDAB    1,x
    BITB    #VOICE_STATUS_ACTIVE
    BNE     .is_sustain_pedal_active

.increment_loop_pointers:
; Increment the loop pointers, and voice number, then loop back.
    INX
    INX
    STX     .voice_status_ptr

    LDX     .pitch_eg_current_step_ptr
    INX
    STX     .pitch_eg_current_step_ptr

; Increase the voice number in the 'Remove Voice Event' command by one.
; This is done by adding 4, since this field uses bytes 7..2.
    LDAB    .remove_voice_command_byte
    ADDB    #4

; If the index exceeds 16, exit.
    BITB    #%1000000
    BEQ     .find_key_event_loop

; If this point has been reached, a matching voice was not found.
    RTS

.is_sustain_pedal_active:
    TIMD    #PEDAL_INPUT_SUSTAIN, sustain_status
    BNE     .sustain_pedal_active

; Mask the appropriate bit of the 'flag byte' of the Key Event buffer entry
; to indicate a 'Key Off' event.
    LDAA    1,x
    ANDA    #~VOICE_STATUS_ACTIVE
    STAA    1,x

; The following lines set this voice's pitch EG step to 4, to indicate
; that it's in the release phase.
    LDAA    #4
    LDX     .pitch_eg_current_step_ptr
    STAA    0,x

    LDAB    .remove_voice_command_byte
    STAB    egs_key_event

    RTS

.sustain_pedal_active:
; IX points to the voice status array.
; Set the 'Voice Sustained' bit.
    LDAA    #VOICE_STATUS_SUSTAIN
    ORAA    1,x

; Clear the 'Voice Active' bit.
    ANDA    #~VOICE_STATUS_ACTIVE
    STAA    1,x

    RTS
