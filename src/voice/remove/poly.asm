; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; voice/remove/poly.asm
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; This file contains the subroutine for removing a voice when the synth is in
; polyphonic mode.
;
; ARGUMENTS:
; Registers:
; * ACCA: The number of the note to remove.
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
    LDX     #voice_status

; ACCB will serve as the 'Remove Voice Command', which will be sent to the EGS.
    LDAB    #EGS_VOICE_EVENT_OFF

.find_key_event_loop:
; Does the current entry in the 'Voice Key Events' buffer match the note
; being removed?
    CMPA    0,x
    BNE     .increment_loop_pointers

; Check if the matching key event is active.
; If not, advance the loop.
    TIMX    #VOICE_STATUS_ACTIVE, 1
    BNE     .deactivate_voice

.increment_loop_pointers:
; Increment the loop pointers, and voice number, then loop back.
    INX
    INX

; Increase the voice number in the 'Remove Voice Command' by one.
; This is done by adding 4, since the 'Voice #' field uses bytes 7..2.
    ADDB    #4

; If the voice index reaches 16, exit.
    BITB    #%1000000
    BEQ     .find_key_event_loop

; If this point has been reached, a matching voice was not found.
; @NOTE: This can naturally occur in the case that a MIDI controller sends a
; 'Key Down' event with a velocity of 0, which is interpreted as a 'Note Off'.
    RTS

.deactivate_voice:
; Mask the appropriate bit of the 'flag byte' of the voice status buffer entry
; to indicate a 'Key Off' event.
    AIMX    #~VOICE_STATUS_ACTIVE, 1,x

; Test whether sustain is active.
    TIMD    #PEDAL_INPUT_SUSTAIN, sustain_status
    BNE     .sustain_pedal_active

; If the sustain pedal is not active, send the 'Key Off' event to the EGS.
    STAB    egs_key_event

; Set this voice's pitch EG step to 4, to initiate the release phase.
; Get the correct index by shifting the 'Remove Voice Command' right twice.
; This will convert it to the voice number.
    LSRB
    LSRB
    LDX     #pitch_eg_current_step
    ABX
    LDAA    #4
    STAA    0,x

    RTS

.sustain_pedal_active:
; IX points to the voice status array.
; Set the 'Voice Sustained' bit.
    OIMX    #VOICE_STATUS_SUSTAIN, 1,x

    RTS
