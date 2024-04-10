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
; PORTAMENTO_CONVERT_INCOMING_MIDI_VALUE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD00B
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
; DESCRIPTION:
; This subroutine is where the current portamento frequency for each of the
; synth's voices is updated, and loaded to the EGS chip.
; This is called periodically as part of the OCF interrupt routine.
; @NOTE: As in the DX7 ROM, this subroutine processes half of the synth's
; 16 voices with each call, alternating each time.
; In the DX9 ROM this subroutine is called once every two interrupts.
; The effect is the same: The portamento for each individual voice is processed
; once every two interrupts.
;
; MEMORY MODIFIED:
; * voice_frequency_target
; * voice_frequency_current_portamento
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
.voice_frequency_portamento_ptr:                EQU #interrupt_temp_variables + 2
.voice_frequency_glissando_ptr:                 EQU #interrupt_temp_variables + 4
.voice_frequency_target_ptr:                    EQU #interrupt_temp_variables + 6
.egs_voice_frequency_ptr:                       EQU #interrupt_temp_variables + 8
.voice_final_portamento_frequency:              EQU #interrupt_temp_variables + 10
.voice_current_glissando_frequency:             EQU #interrupt_temp_variables + 12
.voice_loop_index:                              EQU #interrupt_temp_variables + 14
; These two variables double as both the portamento increment/decrement, and
; the 'next' portamento frequency written to the voice registers.
.portamento_frequency_decrement                 EQU #interrupt_temp_variables + 15
.portamento_frequency_next_lsb:                 EQU #interrupt_temp_variables + 16

; ==============================================================================
; This flag acts as a 'toggle' switch to control which voices are processed.
; If this flag is set, then process voices 8-15, then clear the flag.
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

    LDX     #voice_frequency_current_portamento
    ABX
    STX     <.voice_frequency_portamento_ptr

    LDX     #voice_frequency_current_glissando
    ABX
    STX     <.voice_frequency_glissando_ptr

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
    LDX     <.voice_frequency_portamento_ptr
    LDD     0,x

; Check whether this voice's current portamento frequency is above or below
; the voice's target frequency.
; If *(voice_frequency_current[B]) - *(voice_frequency_target[B]) < 0, branch.
    SUBD    <.voice_final_portamento_frequency
    BMI     .frequency_below_target

; If the current glissando frequency is above the target frequency,
; calculate the portamento frequency decrement, and subtract it from the
; current frequency.
    LDAB    <portamento_rate_scaled

; Calculate the frequency decrement.
    TST     portamento_glissando_enabled
    BEQ     .glissando_disabled

    LDAA    #3
    BRA     .get_frequency_decrement

.glissando_disabled:
    LSRA
    LSRA
    INCA

.get_frequency_decrement:
    MUL
    STD     <.portamento_frequency_decrement

; Subtract the portamento frequency decrement from this voice's current
; portamento frequency.
    LDX     <.voice_frequency_portamento_ptr
    LDD     0,x
    SUBD    <.portamento_frequency_decrement

; If subtracting the decrement causes the resulting pitch to be below the
; target pitch value, clamp at the target pitch.
    XGDX
    CPX     <.voice_final_portamento_frequency
    XGDX
    BCC     .portamento_down_store_frequency

    LDD     <.voice_final_portamento_frequency

.portamento_down_store_frequency:
    LDX     <.voice_frequency_portamento_ptr
    STD     0,x
    STD     <.voice_final_portamento_frequency

; Increment pointer.
    INX
    INX
    STX     <.voice_frequency_portamento_ptr

    TST     portamento_glissando_enabled
    BNE     .glissando_enabled

    JMP     .add_pitch_eg_frequency

.glissando_enabled:
    LDX     <.voice_frequency_glissando_ptr

; Store the voice's current glissando frequency.
    LDD     0,x
    STD     <.voice_current_glissando_frequency

; Subtract the current glissando frequency from the final portamento target
; frequency to determine whether it is currently ABOVE, or BELOW the
; target pitch.
    SUBD    <.voice_final_portamento_frequency
    BMI     .frequency_below_target_glissando_enabled

; This magic number most likely represents the minimum frequency step
; made in the portamento pitch transition.
; The following lines test whether the difference in target, and current
; frequencies are below this threshold.
; Most likely this number represents a semitone:
;  0x154 = (85 << 2).
;  85 * 12 = 1020.
    SUBD    #$154

; If the difference between the glissando TARGET, and CURRENT frequencies
; is less than the minimum threshold, no change is made to the current
; glissando frequency.
    BPL     .glissando_difference_more_than_half_step

    JMP     .load_glissando_frequency

.glissando_difference_more_than_half_step:
; Reload the current glissando pitch.
; The next glissando pitch will now be calculated.
; First a semitone is subtracted from the current glissando frequency.
    LDD     0,x
    SUBD    #$154
    BRA     .get_next_glissando_frequency

.frequency_below_target:
; If the current glissando pitch is below the target pitch, calculate
; the portamento pitch increment, and add it to the current pitch.
    LDAB    <portamento_rate_scaled

    TST     portamento_glissando_enabled
    BEQ     .frequency_below_target_glissando_disabled

    LDAA    #3
    BRA     .get_frequency_increment

.frequency_below_target_glissando_disabled:
    NEGA
    LSRA
    LSRA
    INCA

.get_frequency_increment:
    MUL

; Add the portamento frequency decrement to this voice's current
; portamento frequency.
    LDX     <.voice_frequency_portamento_ptr
    ADDD    0,x

; If adding the increment causes the resulting pitch to be above the
; target pitch value, clamp at the target pitch.
    XGDX
    CPX     <.voice_final_portamento_frequency
    XGDX
    BCS     .store_frequency_increment

    LDD     <.voice_final_portamento_frequency

.store_frequency_increment:
    LDX     <.voice_frequency_portamento_ptr
    STD     0,x
    STD     <.voice_final_portamento_frequency
    INX
    INX
    STX     <.voice_frequency_portamento_ptr

    TST     portamento_glissando_enabled
    BEQ     .add_pitch_eg_frequency

.frequency_below_target_glissando_enabled:
; The following lines test whether the difference in target, and current
; frequencies are below the minimum threshold.
    LDX     <.voice_frequency_glissando_ptr
    LDD     0,x
    STD     <.voice_current_glissando_frequency
    LDD     <.voice_final_portamento_frequency
    SUBD    0,x
    SUBD    #$154

; If the difference between the glissando TARGET, and CURRENT frequencies
; is less than the minimum threshold, no change is made to the current
; glissando frequency.
    BMI     .load_glissando_frequency

; Reload the current glissando pitch.
; The next glissando pitch will now be calculated.
; First a semitone is added to the current glissando frequency.
    LDD     0,x
    ADDD    #$155

.get_next_glissando_frequency:
; The following lines calculate the NEXT glissando frequency for this voice.
; The MSB of the CURRENT frequency value with a semitone added/subtracted
; is stored as the MSB of the NEXT frequency. This value is then converted
; into the 14-bit logarithmic frequency value sent to the EGS chip.
; For more information on this process, refer to the other voice conversion
; subroutines.
    STAA    <.portamento_frequency_decrement
    INCA
    ANDA    #3
    BNE     .get_glissando_frequency_lsb

    LDAA    <.portamento_frequency_decrement
    INCA
    STAA    <.portamento_frequency_decrement

.get_glissando_frequency_lsb:
    LDAA    <.portamento_frequency_decrement
    LDAB    #3
    ANDA    #3
    STAA    <.portamento_frequency_next_lsb

; The following loop is responsible for creating the LSB of the 14-bit
; logarithmic frequency.
.get_glissando_frequency_lsb_loop:
    ORAA    <.portamento_frequency_next_lsb
    ASLA
    ASLA
    DECB
    BNE     .get_glissando_frequency_lsb_loop

    STAA    <.portamento_frequency_next_lsb

; Reload the newly calculated NEXT glissando frequency, and store it in
; the final glissando frequency register which will be loaded to the EGS.
    LDD     <.portamento_frequency_decrement
    STD     0,x
    BRA     .increment_glissando_ptr

.load_glissando_frequency:
    LDD     <.voice_current_glissando_frequency

.increment_glissando_ptr:
; Increment the voice pointers.
    LDX     <.voice_frequency_glissando_ptr
    INX
    INX
    STX     <.voice_frequency_glissando_ptr

.add_pitch_eg_frequency:
; Add the voice's Pitch EG value to the calculated portamento frequency.
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

; Add the master tune offset, and then store this final pitch value to
; the EGS pitch buffer.
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
    BEQ     .exit

    JMP     .process_voice_loop

.exit:
    RTS
