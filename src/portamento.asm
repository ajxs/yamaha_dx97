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
.current_voice_ptr:                                     EQU #interrupt_temp_variables
.voice_target_frequency:                        EQU #interrupt_temp_variables + 2
.portamento_frequency_decrement                 EQU #interrupt_temp_variables + 4
.voice_loop_index:                              EQU #interrupt_temp_variables + 6

; ==============================================================================
; This flag acts as a 'toggle' switch to control which voices are processed.
; If this flag is set, process voices 8-15, then clear the flag.
; If this flag is not set, process voices 0-7, then set the flag.
; ACCB is used as an index into the 32 byte voice buffers, so setting
; it to '16' will start the processing at voice 8.
    COM     portamento_voice_toggle
    BPL     .process_voices_8_to_15

    CLRB
    BRA     .setup_voice_ptr

.process_voices_8_to_15:
    LDAB    #16

.setup_voice_ptr:
; This pointer indexes the current voice.
; It is used to index the voice frequency buffers, pitch EG frequency,
; and the EGS voice frequency buffer.
    LDX     #voice_frequency_target
    ABX
    STX     <.current_voice_ptr

; Set up the loop index.
    LDAA    #8
    STAA    <.voice_loop_index

.process_voice_loop:
; At this point IX contains the voice frequency pointer.
; Store the current voice's target frequency for use in the arithmetic below.
    LDD     0,x
    STD     <.voice_target_frequency

; Check whether this voice's current portamento frequency is above or below
; the voice's target frequency.
; If *(voice_frequency_current[B]) - *(voice_frequency_target[B]) < 0, branch.
    LDD     32,x
    SUBD    <.voice_target_frequency
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

; Subtract the frequency decrement from this voice's current frequency.
    LDD     32,x
    SUBD    <.portamento_frequency_decrement

; If subtracting the decrement causes the resulting frequency to be below the
; target frequency value, clamp at the target frequency.
    XGDX
    CPX     <.voice_target_frequency
    XGDX
    BCC     .store_final_frequency

    LDD     <.voice_target_frequency
    BRA     .store_final_frequency

.frequency_below_target:
; If the current portamento frequency is below the target frequency, calculate
; the frequency increment, and add it to the current frequency.
    LDAB    <portamento_rate_scaled

    NEGA
    LSRA
    LSRA
    INCA

    MUL

; Add the portamento frequency increment to this voice's current frequency.
    ADDD    32,x

; If adding the increment causes the resulting frequency to be above the
; target frequency value, clamp at the target frequency.
    XGDX
    CPX     <.voice_target_frequency
    XGDX
    BCS     .store_final_frequency

    LDD     <.voice_target_frequency

.store_final_frequency:
    STD     32,x
    STD     <.voice_target_frequency

; Add the voice's current Pitch EG level to the portamento frequency.
    ADDD    64,x
    SUBD    #$1BA8

; If the result after this subtraction would be negative, clamp at 0.
    BCC     .update_egs_voice_frequency

    LDD     #0

.update_egs_voice_frequency:
; Add the master tune offset, and then write this final frequency value to
; the EGS frequency buffer.
    ADDD    master_tune

; Note that the EGS voice frequency buffer is adjacent to these voice buffers,
; so it can be indexed with IX. This optimisation was copied from the DX9 ROM.
    STAA    96,x
    NOP
    STAB    97,x

; Increment the voice pointer.
    INX
    INX
    STX     <.current_voice_ptr

; Decrement the loop index.
    DEC     .voice_loop_index
    BNE     .process_voice_loop

    RTS
