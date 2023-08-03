; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; voice/add.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the subroutines used to add a voice with a new note, in
; response to an incoming 'Note On' MIDI message, or a key being pressed.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PITCH_EG_PROCESS
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE:0xE616
; DESCRIPTION:
; Processes the pitch EG for all voices.
; This subroutine loads the levels of each of the synth's 16 voices, testing
; whether each of them is above, or below the final level for its current
; step. Adding or subtracting the pitch EG rate's corresponding increment
; accordingly.
;
; ==============================================================================
pitch_eg_process:                               SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.pitch_eg_voice_freq_pointer:                   EQU #interrupt_temp_variables
.pitch_eg_voice_step_pointer:                   EQU #interrupt_temp_variables + 2
.pitch_eg_next_frequency:                       EQU #interrupt_temp_variables + 4
.pitch_eg_increment:                            EQU #interrupt_temp_variables + 6
.pitch_eg_voice_index:                          EQU #interrupt_temp_variables + 8

; ==============================================================================
    LDX     #pitch_eg_current_frequency
    STX     <.pitch_eg_voice_freq_pointer

    LDX     #pitch_eg_current_step
    STX     <.pitch_eg_voice_step_pointer

    LDAB    #16
    STAB    <.pitch_eg_voice_index

.process_voice_loop:
; Check whether the current pitch EG step is '3'. This indicates that the
; pitch EG for this voice is has reached its 'sustain' value.
; When a voice is removed, the pitch EG step for that voice is set to '4',
; which places the voice's pitch EG into its 'release' phase.
; This check ensures that a voice that's in its 'note on' phase does not
; process the pitch EG past the sustain phase.
    LDAA    0,x
    CMPA    #3
    BNE     .is_eg_step_5

    JMP     .increment_pointers

.is_eg_step_5:
; As noted above, when a voice is removed its pitch EG step is set to '4'.
; This places the voice in its 'release' phase.
; This check ensures that if the voice has reached step '5' (the end), it
; will not be processed further.
    CMPA    #5
    BNE     .process_eg_stage

    JMP     .increment_pointers

.process_eg_stage:
; Load the pitch EG values, clamping the index at 3.
    LDX     #pitch_eg_parsed_rate

    CMPA    #3
    BCS     .load_pitch_eg_rate

    LDAA    #3

.load_pitch_eg_rate:
; The following section loads the current patch's parsed pitch EG rate,
; using ACCB as an index into the 4 entry array.
; This value is used to compute the 'Pitch EG increment' value, which is
; the delta for each iteration of processing the pitch EG.
; It then loads the current patch's parsed pitch EG level, using ACCB as an
; index into this array, and uses this to compute the 'next' EG level, which
; the current level is compared against.
    TAB
    ABX

; Load the pitch EG rate for this step.
    LDAB    0,x
    CLRA
    STD     <.pitch_eg_increment

; Load the pitch EG level for this step.
    LDAA    4,x
    CLRB
    LSRD
    STD     <.pitch_eg_next_frequency

; Compare the current pitch EG level against the 'next' level.
; If it is equal, the incrementing/decrementing step is skipped.
    LDX     <.pitch_eg_voice_freq_pointer
    LDX     0,x
    CPX     <.pitch_eg_next_frequency
    BEQ     .eg_step_finished

; Test whether the current level is above or below the final, target level.
    BCS     .pitch_eg_level_higher

; Subtract the increment value from the current level. If the value goes
; below 0, this means that the current step is finished.
    LDX     <.pitch_eg_voice_freq_pointer
    LDD     0,x
    SUBD    <.pitch_eg_increment
    BMI     .eg_step_finished

    CMPA    <.pitch_eg_next_frequency
    BHI     .eg_step_not_finished

    BRA     .eg_step_finished

.pitch_eg_level_higher:
; If the target pitch EG level is higher than the current level, add the
; pitch EG increment to the current level, and compare.
    LDX     <.pitch_eg_voice_freq_pointer
    LDD     0,x
    ADDD    <.pitch_eg_increment
    CMPA    <.pitch_eg_next_frequency

; If the value is still higher than the target, branch.
; Otherwise we know we're at the final level for this step.
    BCS     .eg_step_not_finished

.eg_step_finished:
; If this EG step has finished, store the 'next' pitch EG level in the
; 'current' level. This has the purpose of allowing the value to overflow,
; or underflow during the increment stage without causing any ill-effects.
    LDD     <.pitch_eg_next_frequency
    LDX     <.pitch_eg_voice_freq_pointer
    STD     0,x

; Increment the EG step. If the step is 6 after incrementing, set to 0.
    LDX     <.pitch_eg_voice_step_pointer
    LDAA    0,x
    INCA
    CMPA    #6
    BNE     .store_eg_step

    CLRA

.store_eg_step:
    STAA    0,x
    BRA     .increment_pointers

.eg_step_not_finished:
; If the current step is not finished, save the current level.
    LDX     <.pitch_eg_voice_freq_pointer
    STD     0,x

.increment_pointers:
; Increment the pointers to point to the next voice.
    LDX     <.pitch_eg_voice_freq_pointer
    INX
    INX
    STX     <.pitch_eg_voice_freq_pointer

    LDX     <.pitch_eg_voice_step_pointer
    INX
    STX     <.pitch_eg_voice_step_pointer

    DEC     .pitch_eg_voice_index
    BEQ     .exit

    JMP     .process_voice_loop

.exit:
    RTS
