; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; pitch_bend.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions, and code related to handling the synth's
; pitch bend features.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PITCH_BEND_PROCESS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Updates the 'Pitch Bend base frequency' periodically as part of the OCF
; interrupt handler. This frequency is loaded to the EGS' pitch modulation
; register as part of the pitch modulation update routine.
;
; ARGUMENTS:
; Memory:
; * analog_input_pitch_bend: The front-panel pitch bender's analog input.
;
; MEMORY MODIFIED:
; * pitch_bend_frequency
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
pitch_bend_process:                             SUBROUTINE
; This XOR operation converts a positive polarity value to a value in the range
; of 0 and 127, and a negative polarity value to a value between 0 and -127.
    LDAA    analog_input_pitch_bend
    EORA    #%10000000

; The values 1, and 0xFF are ignored.
; These values are 1 unit away from the resting point. This operation is likely
; used as a filter against spurious reads.
    CMPA    #1
    BGT     .store_value_with_correct_polarity

    CMPA    #$FF
    BLT     .store_value_with_correct_polarity

; If the value previously read was '1' unit away from the zero point, clear it.
    CLRA

.store_value_with_correct_polarity:
    STAA    <pitch_bend_amount

; Use the pitch bend range value as an index to load the maximum pitch bend
; amount from the table.
    LDX     #table_pitch_bend_range_scale
    LDAB    pitch_bend_range
    ABX
    LDAB    0,x

; Test if the pitch bend range is at the maximum possible amount.
    CMPB    #$FF
    BNE     .scale_pitch_bend_input_by_range

; Test if the front-panel pitch bend wheel input is at the maximum positive,
; or negative value.
    CMPA    #$7F
    BEQ     .scale_pitch_bend_and_store

    CMPA    #$80
    BEQ     .scale_pitch_bend_and_store

; If the pitch bend range value is at its maximum possible value, and the
; front-panel wheel input is at the maximum positive or negative value, clear
; the range value, since no scaling is necessary.
    CLRB

.scale_pitch_bend_and_store:
    LSRD
    BRA     .is_pitch_bend_positive

.scale_pitch_bend_input_by_range:
; This section scales the pitch bend input amount by the specified range.
; Test if bit 7 is set, indicating the bend polarity is negative.
    TSTA
    BMI     .bend_polarity_is_negative

; If the polarity is positive, shift the input value and multiply by the range.
    ASLA
    MUL
    BRA     .scale_value

.bend_polarity_is_negative:
; Invert the value, since a value of 0xFF is the resting point of the front
; panel pitch-bend wheel.
    COMA

    ASLA
    MUL
    COMA
    COMB

.scale_value:
    LSRD
    LSRD

.is_pitch_bend_positive:
    TST     pitch_bend_amount
    BPL     .store_frequency_and_exit

    ORAA    #%11000000

.store_frequency_and_exit:
    STD     <pitch_bend_frequency

    RTS


; ==============================================================================
; This table contains the coefficient corresponding to the pitch bend range by
; which the front-panel pitch bend wheel input value is scaled to yield the
; final pitch modulation amount.
; ==============================================================================
table_pitch_bend_range_scale:
    DC.B 0
    DC.B $16
    DC.B $2B
    DC.B $41
    DC.B $56
    DC.B $6B
    DC.B $81
    DC.B $97
    DC.B $AC
    DC.B $C2
    DC.B $D7
    DC.B $EC
    DC.B $FF
