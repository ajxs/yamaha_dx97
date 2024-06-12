; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; patch/lfo.asm
; ==============================================================================
; DESCRIPTION:
; This file contains code, and definitions related to the synth's LFO.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; LFO Sample+Hold prime numbers.
; ==============================================================================
LFO_SAMPLE_AND_HOLD_PRIME_1:                    EQU 179
LFO_SAMPLE_AND_HOLD_PRIME_2:                    EQU 11

; ==============================================================================
; LFO_PROCESS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD5D2
; CHANGED_FOR_6_OP
; @CALLED_DURING_OCF_HANDLER
; DESCRIPTION:
; Calculates, and stores the instantaneous amplitude of the synth's LFO at its
; current phase, depending on the LFO delay, and LFO type.
;
; MEMORY MODIFIED:
; * lfo_delay_accumulator
; * lfo_delay_fadein_factor
; * lfo_sample_and_hold_update_flag
; * lfo_phase_accumulator
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
lfo_process:                                    SUBROUTINE
    LDD     <lfo_delay_accumulator
    ADDD    <lfo_delay_increment

; After adding the increment, does this overflow?
; If the carry bit is set on account of the delay accumulator overflowing,
; clamp the LFO delay accumulator at 0xFFFF.
    BCC     .store_delay_accumulator

; If the LFO delay accumulator has overflowed its 16-bit register, then
; the 'Fade In' accumulator becomes active. This counter constitutes a
; 'scale factor' for the overall LFO modulation amount.
; The LFO delay accumulator is clamped at 0xFFFF. Once this
; value overflows 16-bits once it is effectively locked at 0xFFFF until
; reset by the voice add trigger.
    LDD     #$FFFF

.store_delay_accumulator:
    STD     <lfo_delay_accumulator

; Test whether the LFO Delay accumulator is at its maximum (0xFFFF), by adding
; '1', and testing whether the result overflows.
; If so, process the delay fadein factor.
    ADDD    #1
    BNE     .increment_accumulator

    LDD     <lfo_delay_fadein_factor
    ADDD    <lfo_delay_increment
    BCC     .store_fadein_factor

    LDD     #$FFFF

.store_fadein_factor:
    STD     <lfo_delay_fadein_factor

.increment_accumulator:
; Increment the LFO phase accumulator.
    LDD     <lfo_phase_accumulator
    ADDD    <lfo_phase_increment

; If the LFO phase accumulator overflows after adding the LFO phase
; increment, set the flag to update the Sample and Hold LFO amplitude.
    BVC     .update_sample_and_hold

    OIMD    #%10000000, lfo_sample_and_hold_update_flag
    BRA     .store_phase_accumulator

.update_sample_and_hold:
    AIMD   #%1111111, lfo_sample_and_hold_update_flag

.store_phase_accumulator:
    STD     <lfo_phase_accumulator

; Jump to the specific LFO shape functions.
    LDX     #table_lfo_functions
    LDAB    lfo_waveform
    ANDB    #%111
    ASLB
    ABX
    LDX     0,x
    JMP     0,x

table_lfo_functions:
    DC.W lfo_process_tri
    DC.W lfo_process_saw_down
    DC.W lfo_process_saw_up
    DC.W lfo_process_square
    DC.W lfo_process_sin
    DC.W lfo_process_sh
    DC.W lfo_process_sh
    DC.W lfo_process_sh

; ==============================================================================
; LFO_PROCESS_TRI
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD60D
; DESCRIPTION:
; Calculates the instantaneous amplitude of the synth's LFO at its current
; phase when the 'Triangle' shape is selected.
; This computes, and stores the final LFO amplitude, which is used in the
; various modulation processes.
; This subroutine will proceed to store the calculated LFO amplitude.
;
; ARGUMENTS:
; Registers:
; * ACCA: The most-significant byte of the LFO phase accumulator.
;
; ==============================================================================
lfo_process_tri:                                SUBROUTINE
    LDD     <lfo_phase_accumulator

; For the Triangle LFO The two-byte LFO phase accumulator is shifted to the
; left. If the carry bit is set, it indicates that the accumulator is in the
; second half of its full period. In this case the one's complement of the
; accumulator's MSB  is taken to invert the wave vertically.
; 128 is then added to centre the wave vertically around 0.
    LSLD
    BCC     .center_triangle_and_store

    COMA

.center_triangle_and_store:
; Add 0x80 so that the wave is correctly oriented vertically, with 0 as the
; 'centre' value.
    ADDA    #$80
    BRA     lfo_process_store_amplitude


; ==============================================================================
; LFO_PROCESS_SAW_DOWN
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD617
; DESCRIPTION:
; Calculates the instantaneous amplitude of the synth's LFO at its current
; phase when the 'Saw Down' shape is selected.
; The LFO phase accumulator register can be inverted to achieve a decreasing
; saw wave.
; This subroutine will proceed to store the calculated LFO amplitude.
;
; ARGUMENTS:
; Registers:
; * ACCA: The most-significant byte of the LFO phase accumulator.
;
; ==============================================================================
lfo_process_saw_down:                           SUBROUTINE
    COMA
; Fall-through below.

; ==============================================================================
; LFO_PROCESS_SAW_UP
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD618
; DESCRIPTION:
; Calculates the instantaneous amplitude of the synth's LFO at its current
; phase when the 'Saw Up' shape is selected.
; The most-significant byte of the LFO phase accumulator register can be used
; as an increasing saw wave value.
; This subroutine will proceed to store the calculated LFO amplitude.
;
; ARGUMENTS:
; Registers:
; * ACCA: The most-significant byte of the LFO phase accumulator.
;
; ==============================================================================
lfo_process_saw_up:                             SUBROUTINE
    BRA     lfo_process_store_amplitude


; ==============================================================================
; LFO_PROCESS_SQUARE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD61A
; DESCRIPTION:
; Calculates the instantaneous amplitude of the synth's LFO at its current
; phase when the 'Square' shape is selected.
; This subroutine will proceed to store the calculated LFO amplitude.
;
; ARGUMENTS:
; Registers:
; * ACCA: The most-significant byte of the LFO phase accumulator.
;
; ==============================================================================
lfo_process_square:                             SUBROUTINE
; Perform a logical AND operation with the most significant bit of the
; phase accumulator MSB to determine whether it is in the first or second
; half of its full period.
; If it is in the first half, return a positive polarity signal (127).
; If not, return a negative polarity.
    ANDA    #%10000000
    BMI     .store_value

    LDAA    #$7F

.store_value:
    BRA     lfo_process_store_amplitude


; ==============================================================================
; LFO_PROCESS_SIN
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD622
; DESCRIPTION:
; Calculates the instantaneous amplitude of the synth's LFO at its current
; phase when the 'Sine' shape is selected.
; This subroutine will proceed to store the calculated LFO amplitude.
;
; ARGUMENTS:
; Registers:
; * ACCA: The most-significant byte of the LFO phase accumulator.
;
; ==============================================================================
lfo_process_sin:                                SUBROUTINE
    TAB

; The following sequence computes the index into the Sine LFO LUT.
; This performs a modulo operation limiting the accumulator to the length of
; the sine table (64), and then inverts the resulting index horizontally if
; the accumulator value had bit 6 set.
; The corresponding instantaneous amplitude is then looked up in the Sine LFO
; table. If bit 7 of the accumulator's MSB is set, indicating that the
; accumulator was in the second-half of its phase, then the one's complement
; of the amplitude is computed to invert the amplitude.
    ANDB    #%111111
    BITA    #%1000000
    BEQ     .lookup_value

    EORB    #%111111

.lookup_value:
    LDX     #table_lfo_sin
    ABX
    LDAB    0,x
    TSTA

; If bit 7 of the accumulator MSB is set, indicating the LFO is in the
; second-half of its phase, then invert the wave amplitude.
    BPL     .store_value

    COMB

.store_value:
    TBA
    BRA     lfo_process_store_amplitude


; ==============================================================================
; LFO_PROCESS_SH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD638
; DESCRIPTION:
; Calculates the instantaneous amplitude of the synth's LFO at its current
; phase when the 'Sample and Hold' shape is selected.
; The sample+hold functionality periodically 'samples' a new pseudo-random
; value according to the LFO speed.
; To 'sample' a value the current 'Sample+Hold Accumulator' value is multiplied
; by a prime number (179), and the lower-byte has another prime (11) added to
; it. The effect is an inexpensive pseudo-random value.
; Note: The numbers used here match those in the DX7. The DX9 used a different
; value for addition, for unknown reasons.
; This subroutine will proceed to store the calculated LFO amplitude.
;
; ARGUMENTS:
; Registers:
; * ACCA: The most-significant byte of the LFO phase accumulator.
;
; ==============================================================================
lfo_process_sh:                                 SUBROUTINE
; Test the 'Update Flag' to determine whether to 'sample' a new value.
    TST     lfo_sample_and_hold_update_flag
    BPL     .exit

    LDAA    lfo_sample_hold_accumulator
    LDAB    #LFO_SAMPLE_AND_HOLD_PRIME_1
    MUL

    ADDB    #LFO_SAMPLE_AND_HOLD_PRIME_2
    STAB    lfo_sample_hold_accumulator
    TBA
    BRA     lfo_process_store_amplitude

.exit:
    RTS


; ==============================================================================
; LFO_PROCESS_STORE_AMPLITUDE
; ==============================================================================
; DESCRIPTION:
; This is where the final calculated amplitude for the LFO is stored.
; This is essentially the end of the LFO processing subroutines. All of the
; LFO subroutines eventually terminate here, with the exception of when the
; Sample+Hold subroutine exits early.
;
; ==============================================================================
lfo_process_store_amplitude:
    STAA    <lfo_amplitude
    RTS


; ==============================================================================
; LFO Sine Lookup Table
; Length: 64
; ==============================================================================
table_lfo_sin:
    DC.B 2, 5, 8, $B, $E, $11       ; 0
    DC.B $14, $17, $1A, $1D, $20    ; 6
    DC.B $23, $26, $29, $2C, $2F    ; 11
    DC.B $32, $35, $38, $3A, $3D    ; 16
    DC.B $40, $43, $45, $48, $4A    ; 21
    DC.B $4D, $4F, $52, $54, $56    ; 26
    DC.B $59, $5B, $5D, $5F, $61    ; 31
    DC.B $63, $65, $67, $69, $6A    ; 36
    DC.B $6C, $6E, $6F, $71, $72    ; 41
    DC.B $73, $75, $76, $77, $78    ; 46
    DC.B $79, $7A, $7B, $7C, $7C    ; 51
    DC.B $7C, $7D, $7D, $7E, $7E    ; 56
    DC.B $7F, $7F, $7F              ; 61
