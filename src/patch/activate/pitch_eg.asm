; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; patch/activate/pitch_eg.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the routine for 'activation' of the pitch EG.
; This file includes the associated data tables.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_ACTIVATE_PITCH_EG_VALUES
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; Parses the current patch's pitch EG rate, and level values. These are then
; stored in the synth's RAM, since they are needed for the synth's various
; voice operations.
;
; ==============================================================================
patch_activate_pitch_eg:                        SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.parsed_pitch_eg_values_pointer:                EQU #temp_variables

; ==============================================================================
    LDX     #pitch_eg_parsed_rate
    STX     .parsed_pitch_eg_values_pointer

; ACCA is used as the loop index for both loops.
    CLRA

.parse_eg_rate_loop:
; Use ACCB as an index into the current patch's Pitch EG rate values.
    LDX     #patch_edit_pitch_eg
    TAB
    ABX
    LDAB    0,x
    INCA

; Use this value as an index into the pitch EG rate table, and load the
; corresponding value.
    LDX     #table_pitch_eg_rate
    ABX
    LDAB    0,x

; Store the parsed EG rate value.
    LDX     .parsed_pitch_eg_values_pointer
    STAB    0,x
    INX
    STX     .parsed_pitch_eg_values_pointer

    CMPA    #4
    BNE     .parse_eg_rate_loop

.parse_pitch_eg_level_loop:
    LDX     #patch_edit_pitch_eg

; Use ACCB as an index into the current patch's Pitch EG level values.
    TAB
    ABX
    LDAB    0,x
    INCA

; Use this value as an index into the pitch EG level table, and load the
; corresponding value.
    LDX     #table_pitch_eg_level
    ABX
    LDAB    0,x

; Store the parsed EG level value.
    LDX     .parsed_pitch_eg_values_pointer
    STAB    0,x
    INX
    STX     .parsed_pitch_eg_values_pointer

    CMPA    #8
    BNE     .parse_pitch_eg_level_loop

    RTS


; ==============================================================================
; This is used to scale the patch pitch EG rate values from
; their serialised 0-99 range, to the 0-255 range used internally.
; ==============================================================================
table_pitch_eg_rate:
    DC.B 1, 2, 3, 3, 4, 4, 5
    DC.B 5, 6, 6, 7, 7, 8, 8
    DC.B 9, 9, $A, $A, $B, $B
    DC.B $C, $C, $D, $D, $E, $E
    DC.B $F, $10, $10, $11, $12
    DC.B $12, $13, $14, $15, $16
    DC.B $17, $18, $19, $1A, $1B
    DC.B $1C, $1E, $1F, $21, $22
    DC.B $24, $25, $26, $27, $29
    DC.B $2A, $2C, $2E, $2F, $31
    DC.B $33, $35, $36, $38, $3A
    DC.B $3C, $3E, $40, $42, $44
    DC.B $46, $48, $4A, $4C, $4F
    DC.B $52, $55, $58, $5B, $5E
    DC.B $62, $66, $6A, $6E, $73
    DC.B $78, $7D, $82, $87, $8D
    DC.B $93, $99, $9F, $A5, $AB
    DC.B $B2, $B9, $C1, $CA, $D3
    DC.B $E8, $F3, $FE, $FF


; ==============================================================================
; This table is used to scale the patch pitch EG level values from their
; 0-99 range,to the 0-255 range of values required for the final
; frequency calculation.
; ==============================================================================
table_pitch_eg_level:
    DC.B 0, $C, $18, $21, $2B
    DC.B $34, $3C, $43, $48, $4C
    DC.B $4F, $52, $55, $57, $59
    DC.B $5B, $5D, $5F, $60, $61
    DC.B $62, $63, $64, $65, $66
    DC.B $67, $68, $69, $6A, $6B
    DC.B $6C, $6D, $6E, $6F, $70
    DC.B $71, $72, $73, $74, $75
    DC.B $76, $77, $78, $79, $7A
    DC.B $7B, $7C, $7D, $7E, $7F
    DC.B $80, $81, $82, $83, $84
    DC.B $85, $86, $87, $88, $89
    DC.B $8A, $8B, $8C, $8D, $8E
    DC.B $8F, $90, $91, $92, $93
    DC.B $94, $95, $96, $97, $98
    DC.B $99, $9A, $9B, $9C, $9D
    DC.B $9E, $9F, $A0, $A1, $A2
    DC.B $A3, $A6, $A8, $AB, $AE
    DC.B $B1, $B5, $BA, $C1, $C9
    DC.B $D2, $DC, $E7, $F3, $FF
