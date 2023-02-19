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
; portamento.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the code, and definitions related to the synth's
; portamento functionality.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PORTAMENTO_CONVERT_INCOMING_MIDI_VALUE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Converts an incoming portamento time value received via a MIDI control code
; message to the synth's internal format.
;
; ARGUMENTS:
; Registers:
; * ACCA: The value to scale.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; RETURNS:
; * ACCD: The scaled value.
;
; ==============================================================================
portamento_convert_incoming_midi_value:         SUBROUTINE
    LDAB    #200
    MUL
    RTS


; ==============================================================================
; PORTAMENTO_CALCULATE_RATE
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @REMADE_FOR_6_OP
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
; DESCRIPTION:
; This subroutine is where the current portamento frequency for each of the
; synth's voices is updated, and loaded to the EGS chip.
; This is called periodically as part of the OCF interrupt routine.
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
.voice_pitch_eg_current_freq_ptr:               EQU #interrupt_temp_registers
.voice_current_frequency_ptr:                   EQU #interrupt_temp_registers + 2
.egs_voice_frequency_ptr:                       EQU #interrupt_temp_registers + 4
.voice_target_frequency_ptr:                    EQU #interrupt_temp_registers + 6
.voice_final_portamento_frequency               EQU #interrupt_temp_registers + 8
.voice_portamento_increment                     EQU #interrupt_temp_registers + 10
.voice_loop_index:                              EQU #interrupt_temp_registers + 12
.master_tune                                    EQU #interrupt_temp_registers + 13

; ==============================================================================
    CLRA
    LDAB    master_tune
    LSLD
    LSLD
    STD     .master_tune

; This flag acts as a 'toggle' switch to control which voices are processed.
; If this flag is set, then process voices 8-15, then clear the flag.
; If this flag is not set, process voices 0-7, then set the flag.
; ACCB is used as an index into the 32 byte voice buffers, so setting
; it to '16' will start the processing at voice 8.
    TST     portamento_voice_toggle
    BNE     .process_voices_8_to_15
    COM     portamento_voice_toggle
    CLRB
    BRA     .setup_pointers

.process_voices_8_to_15:
    CLR     portamento_voice_toggle
    LDAB    #16

.setup_pointers:
; Initialiase the pointers used within the function.
    LDX     #pitch_eg_current_frequency
    ABX
    STX     <.voice_pitch_eg_current_freq_ptr

; Set the pointer to the portamento frequency buffer.
    LDX     #voice_frequency_current
    ABX
    STX     <.voice_current_frequency_ptr

; Set the pointer to the EGS voice frequency register.
    LDX     #egs_voice_frequency
    ABX
    STX     <.egs_voice_frequency_ptr

; Set the pointer to the voice target frequency buffer.
    LDX     #voice_frequency_target
    ABX
    STX     <.voice_target_frequency_ptr

; Set up the loop index.
    LDAA    #8
    STAA    <.voice_loop_index

.process_voice_loop:
; Store the current voice's target frequency as this voice's portamento
; final frequency. This value will be used in the calculations below.
    LDD     0,x
    STD     <.voice_final_portamento_frequency

; Load this voice's CURRENT portamento frequency into ACCD.
    LDX     <.voice_current_frequency_ptr
    LDD     0,x

; Check whether this voice's current portamento pitch is above or below
; the voice's target pitch.
; If *(0xVOICE_PITCH_PORTA[B]) - *(VOICE_PITCH_TARGET[B]) < 0, branch.
    SUBD    <.voice_final_portamento_frequency
    BMI     .frequency_below_target

; If the current glissando frequency is above the target frequency,
; calculate the portamento frequency decrement, and subtract it from the
; current frequency.
    LDAB    <portamento_rate_scaled

    LSRA
    LSRA
    INCA

    MUL

    STD     <.voice_portamento_increment

; Subtract the portamento frequency decrement from this voice's current
; portamento frequency.
    LDX     <.voice_current_frequency_ptr
    LDD     0,x
    SUBD    <.voice_portamento_increment

; If subtracting the decrement causes the resulting pitch to be below the
; target pitch value, clamp at the target pitch.
    XGDX
    CPX     <.voice_final_portamento_frequency
    XGDX
    BCC     .store_decremented_frequency

    LDD     <.voice_final_portamento_frequency

.store_decremented_frequency:
    LDX     <.voice_current_frequency_ptr
    STD     0,x
    STD     <.voice_final_portamento_frequency

; Increment pointer.
    INX
    INX
    STX     <.voice_current_frequency_ptr

    JMP     .add_pitch_eg_frequency

.frequency_below_target:
; Calculate the pitch increment.
    LDAB    <portamento_rate_scaled

    NEGA
    LSRA
    LSRA
    INCA

    MUL

; Add the portamento frequency decrement to this voice's current
; portamento frequency.
    LDX     <.voice_current_frequency_ptr
    ADDD    0,x

; If adding the increment causes the resulting pitch to be above the
; target pitch value, clamp at the target pitch.
    XGDX
    CPX     <.voice_final_portamento_frequency
    XGDX
    BCS     .store_incremented_frequency

    LDD     <.voice_final_portamento_frequency

.store_incremented_frequency:
    LDX     <.voice_current_frequency_ptr
    STD     0,x
    STD     <.voice_final_portamento_frequency
    INX
    INX
    STX     <.voice_current_frequency_ptr

.add_pitch_eg_frequency:
; Add the voice's Pitch EG value to the calculated portamento frequency.
    LDX     <.voice_pitch_eg_current_freq_ptr
    ADDD    0,x
    SUBD    #$1BA8

; If the result after this subtraction would be negative, clamp at 0.
    BCC     .increment_pitch_eg_pointer

    LDD     #0

.increment_pitch_eg_pointer:
    INX
    INX
    STX     <.voice_pitch_eg_current_freq_ptr

; Add the master tune offset, and then store this final pitch value to
; the EGS pitch buffer.
    ADDD    .master_tune
    LDX     <.egs_voice_frequency_ptr
    STAA    0,x
    INX
    STAB    0,x
    INX
    STX     <.egs_voice_frequency_ptr

; Increment voice target frequency pointer.
    LDX     <.voice_target_frequency_ptr
    INX
    INX
    STX     <.voice_target_frequency_ptr

; Decrement the loop index.
    DEC     .voice_loop_index
    BEQ     .exit

    JMP     .process_voice_loop

.exit:
    RTS
