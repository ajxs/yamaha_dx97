; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; portamento.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the code, and definitions related to the synth's
; portamento functionality.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PORTAMENTO_CALCULATE_RATE
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Calculates the correct portamento frequency scale rate corresponding to a
; patch's portamento time.
; This value is then stored internally, and used in various voice-related
; calculations.
;
; MEMORY MODIFIED:
; * portamento_rate_scaled
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
portamento_calculate_rate:                      SUBROUTINE
; The 'Portamento Time' value (0-99) is subtracted from a value of 99
; to yield the index into the table.
    LDAB    #99
    SUBB    portamento_time

    LDX     #table_pitch_eg_rate
    ABX
    LDAB    0,x
    STAB    <portamento_rate_scaled

    RTS


; ==============================================================================
; PORTAMENTO_PROCESS
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @CHANGED_FOR_6_OP
; @CALLED_DURING_OCF_HANDLER
; DESCRIPTION:
; This subroutine is where the current portamento frequency for each of the
; synth's voices is updated, and loaded to the EGS chip.
; This is called periodically as part of the OCF interrupt routine.
; @NOTE: As in the DX7 ROM, this subroutine processes half of the synth's
; 16 voices with each call, alternating each time.
; In the DX9 ROM this subroutine is called once every two interrupts.
; @NOTE: Glissando functionality has been removed from this subroutine.
; Unfortunately, with its lower clock rate, the DX9 isn't able to properly
; process glissando.
;
; MEMORY MODIFIED:
; * voice_frequency_target
; * voice_frequency_current
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
portamento_process:                             SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.pitch_eg_frequency_current_ptr:                EQU #interrupt_temp_variables
.voice_frequency_current_ptr:                   EQU #interrupt_temp_variables + 2
.voice_frequency_target_ptr:                    EQU #interrupt_temp_variables + 4
.egs_voice_frequency_ptr:                       EQU #interrupt_temp_variables + 6
.voice_final_portamento_frequency:              EQU #interrupt_temp_variables + 8
.portamento_frequency_decrement                 EQU #interrupt_temp_variables + 10
.voice_loop_index:                              EQU #interrupt_temp_variables + 12

; ==============================================================================
; This flag acts as a 'toggle' switch to control which voices are processed.
; If this flag is set, process voices 8-15, then clear the flag.
; If this flag is not set, process voices 0-7, then set the flag.
; ACCB is used as an index into the 32 byte voice buffers, so setting
; it to '16' will start the processing at voice 8.
    COM     portamento_voice_toggle
    BPL     .process_voices_8_to_15

    CLRB
    BRA     .setup_pointers

.process_voices_8_to_15:
    LDAB    #16

.setup_pointers:
; Initialiase the pointers used within the routine.
    LDX     #pitch_eg_current_frequency
    ABX
    STX     <.pitch_eg_frequency_current_ptr

    LDX     #voice_frequency_current
    ABX
    STX     <.voice_frequency_current_ptr

    LDX     #egs_voice_frequency
    ABX
    STX     <.egs_voice_frequency_ptr

    LDX     #voice_frequency_target
    ABX
    STX     <.voice_frequency_target_ptr

; Set up the loop index.
    LDAA    #8
    STAA    <.voice_loop_index

.process_voice_loop:
; Store the current voice's target frequency as this voice's portamento
; final frequency. This value will be used in the calculations below.
    LDD     0,x
    STD     <.voice_final_portamento_frequency

; Load this voice's CURRENT portamento frequency into ACCD.
    LDX     <.voice_frequency_current_ptr
    LDD     0,x

; Check whether this voice's current portamento frequency is above or below
; the voice's target frequency.
; If *(voice_frequency_current[B]) - *(voice_frequency_target[B]) < 0, branch.
    SUBD    <.voice_final_portamento_frequency
    BMI     .frequency_below_target

; If the current portamento frequency is above the target frequency,
; calculate the portamento frequency decrement, and subtract it from the
; current frequency.
    LDAB    <portamento_rate_scaled

; Calculate the frequency decrement.
    LSRA
    LSRA
    INCA

    MUL
    STD     <.portamento_frequency_decrement

; Subtract the portamento frequency decrement from this voice's current
; portamento frequency.
    LDX     <.voice_frequency_current_ptr
    LDD     0,x
    SUBD    <.portamento_frequency_decrement

; If subtracting the decrement causes the resulting frequency to be below the
; target frequency value, clamp at the target frequency.
    XGDX
    CPX     <.voice_final_portamento_frequency
    XGDX
    BCC     .store_decremented_frequency

    LDD     <.voice_final_portamento_frequency

.store_decremented_frequency:
    LDX     <.voice_frequency_current_ptr
    STD     0,x
    STD     <.voice_final_portamento_frequency

; Increment pointer.
    INX
    INX
    STX     <.voice_frequency_current_ptr

    BRA     .add_pitch_eg_frequency

.frequency_below_target:
; If the current portamento frequency is below the target frequency, calculate
; the frequency increment, and add it to the current frequency.
    LDAB    <portamento_rate_scaled

    NEGA
    LSRA
    LSRA
    INCA

    MUL

; Add the portamento frequency decrement to this voice's current
; portamento frequency.
    LDX     <.voice_frequency_current_ptr
    ADDD    0,x

; If adding the increment causes the resulting frequency to be above the
; target frequency value, clamp at the target frequency.
    XGDX
    CPX     <.voice_final_portamento_frequency
    XGDX
    BCS     .store_incremented_frequency

    LDD     <.voice_final_portamento_frequency

.store_incremented_frequency:
    LDX     <.voice_frequency_current_ptr
    STD     0,x
    STD     <.voice_final_portamento_frequency

; Increment pointer.
    INX
    INX
    STX     <.voice_frequency_current_ptr

.add_pitch_eg_frequency:
; Add the voice's current Pitch EG level to the portamento frequency.
    LDX     <.pitch_eg_frequency_current_ptr
    ADDD    0,x
    SUBD    #$1BA8

; If the result after this subtraction would be negative, clamp at 0.
    BCC     .increment_pitch_eg_ptr

    LDD     #0

.increment_pitch_eg_ptr:
    INX
    INX
    STX     <.pitch_eg_frequency_current_ptr

; Add the master tune offset, and then store this final frequency value to
; the EGS frequency buffer.
    ADDD    master_tune
    LDX     <.egs_voice_frequency_ptr
    STAA    0,x
    INX
    STAB    0,x
    INX
    STX     <.egs_voice_frequency_ptr

; Increment voice target frequency pointer.
    LDX     <.voice_frequency_target_ptr
    INX
    INX
    STX     <.voice_frequency_target_ptr

; Decrement the loop index.
    DEC     .voice_loop_index
    BNE     .process_voice_loop

    RTS
