; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; patch/activate/operator_frequency.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the routine for 'activation' of the individual operator
; frequencies.
; This includes the relevant data tables for parsing the frequency values.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_ACTIVATE_OPERATOR_FREQUENCY
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Constructs the final frequency value for the specified operator, and loads it
; to the EGS chip.
;
; ARGUMENTS:
; Memory:
; * patch_activate_operator_offset: The offset of the current operator in the
; synth's patch memory.
; * patch_activate_operator_number: The number of the operator currently being
; activated.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
patch_activate_operator_frequency:              SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.operator_pointer:                              EQU #temp_variables
.operator_coarse_freq:                          EQU #temp_variables + 2
.operator_fine_freq_offset:                     EQU #temp_variables + 4

; ==============================================================================
    LDX     #patch_buffer_edit
    LDAB    <patch_activate_operator_offset
    ABX
    STX     .operator_pointer

    LDAB    PATCH_OP_MODE,x
    BNE     .osc_mode_fixed

; Use the serialised 'Op Freq Coarse' value (0-31) as an index into the
; coarse frequency lookup table.
; Store the resulting coarse freq value in a temporary variable.
    LDAB    18,x
    ASLB
    LDX     #table_operator_frequency_coarse
    ABX
    LDD     0,x
    STD     .operator_coarse_freq

; Parse the fine operator frequency.
; Store 'Op Freq Fine' (0-99) * 2 as a temporary variable.
; This value will be used as an index into the fine frequency lookup table.
; The resulting value will be added to the coarse frequency to produce
; the final result.
    LDX     .operator_pointer
    LDAB    PATCH_OP_FREQ_FINE,x
    LDAA    #2
    MUL
    STD     .operator_fine_freq_offset

    LDD     #table_operator_frequency_fine
    ADDD    .operator_fine_freq_offset
    STD     .operator_pointer
    LDX     .operator_pointer
    LDD     0,x

; The final ratio frequency value is:
; Ratio_Frequency = 0x232C + FREQ_COARSE + FREQ_FINE.
    ADDD    .operator_coarse_freq
    ADDD    #$232C

; The final frequency value is a 14-bit integer, shifted left two bits.
; Bit 0 holds the flag indicating whether this is a fixed frequency value.
; Clear this bit to indicate this operator uses a ratio frequency.
    ANDB    #%11111110
    JMP     .load_operator_frequency_to_egs

; Use the serialised 'Op Freq Coarse' value (0-31) % 3, as an index
; into the fixed frequency lookup table.
; Store the resulting frequency value in a temporary variable.
.osc_mode_fixed:
    LDX     .operator_pointer
    LDAB    PATCH_OP_FREQ_COARSE,x
    ANDB    #%11
    ASLB

    LDX     #table_operator_frequency_fixed
    ABX
    LDD     0,x
    STD     .operator_coarse_freq

; Scale the fine fixed frequency by multipying by 136.
    LDX     .operator_pointer
    LDAA    PATCH_OP_FREQ_FINE,x
    LDAB    #136
    MUL

; The final fixed frequency value is:
; Fixed_Frequency = 0x16AC + FREQ_FIXED + FREQ_FINE.
    ADDD    #$16AC
    ADDD    .operator_coarse_freq

; The final frequency value is a 14-bit integer, shifted left two bits.
; Bit 0 holds the flag indicating whether this is a fixed frequency value.
; Set this bit to indicate this operator uses a fixed frequency.
    ORAB    #1

.load_operator_frequency_to_egs:
    PSHB
    LDAB    patch_activate_operator_number
    ASLB
    LDX     #egs_operator_frequency
    ABX

; Write the 16-bit pitch, and fixed-frequency flag value to the EGS.
    STAA    0,x
    PULB
    STAB    1,x
    RTS


; ==============================================================================
; Operator coarse frequency value table.
; These are the values for the coarse operator frequency used to construct the
; final operator frequency loaded to the EGS chip.
; Length: 32
; ==============================================================================
table_operator_frequency_coarse:
    DC.W $F000
    DC.W 0
    DC.W $1000
    DC.W $195C
    DC.W $2000
    DC.W $2528
    DC.W $295C
    DC.W $2CEC
    DC.W $3000
    DC.W $32B8
    DC.W $3528
    DC.W $375A
    DC.W $395C
    DC.W $3B34
    DC.W $3CEC
    DC.W $3E84
    DC.W $4000
    DC.W $4168
    DC.W $42B8
    DC.W $43F8
    DC.W $4528
    DC.W $4648
    DC.W $475A
    DC.W $4860
    DC.W $495C
    DC.W $4A4C
    DC.W $4B34
    DC.W $4C14
    DC.W $4CEC
    DC.W $4DBA
    DC.W $4E84
    DC.W $4F44

; ==============================================================================
; Operator fine frequency value table.
; These are the values for the fine operator frequency used to construct the
; final operator frequency loaded to the EGS chip.
; Length: 100
; ==============================================================================
table_operator_frequency_fine:
    DC.W 0
    DC.W $3A
    DC.W $75
    DC.W $AE
    DC.W $E7
    DC.W $120
    DC.W $158
    DC.W $18F
    DC.W $1C6
    DC.W $1FD
    DC.W $233
    DC.W $268
    DC.W $29D
    DC.W $2D2
    DC.W $306
    DC.W $339
    DC.W $36D
    DC.W $39F
    DC.W $3D2
    DC.W $403
    DC.W $435
    DC.W $466
    DC.W $497
    DC.W $4C7
    DC.W $4F7
    DC.W $526
    DC.W $555
    DC.W $584
    DC.W $5B2
    DC.W $5E0
    DC.W $60E
    DC.W $63B
    DC.W $668
    DC.W $695
    DC.W $6C1
    DC.W $6ED
    DC.W $719
    DC.W $744
    DC.W $76F
    DC.W $799
    DC.W $7C4
    DC.W $7EE
    DC.W $818
    DC.W $841
    DC.W $86A
    DC.W $893
    DC.W $8BC
    DC.W $8E4
    DC.W $90C
    DC.W $934
    DC.W $95C
    DC.W $983
    DC.W $9AA
    DC.W $9D1
    DC.W $9F7
    DC.W $A1D
    DC.W $A43
    DC.W $A69
    DC.W $A8F
    DC.W $AB4
    DC.W $AD9
    DC.W $AFE
    DC.W $B22
    DC.W $B47
    DC.W $B6B
    DC.W $B8F
    DC.W $BB2
    DC.W $BD6
    DC.W $BF9
    DC.W $C1C
    DC.W $C3F
    DC.W $C62
    DC.W $C84
    DC.W $CA7
    DC.W $CC9
    DC.W $CEA
    DC.W $D0C
    DC.W $D2E
    DC.W $D4F
    DC.W $D70
    DC.W $D91
    DC.W $DB2
    DC.W $DD2
    DC.W $DF3
    DC.W $E13
    DC.W $E33
    DC.W $E53
    DC.W $E72
    DC.W $E92
    DC.W $EB1
    DC.W $ED0
    DC.W $EEF
    DC.W $F0E
    DC.W $F2D
    DC.W $F4C
    DC.W $F6A
    DC.W $F88
    DC.W $FA6
    DC.W $FC4
    DC.W $FE2
    DC.W $1000


; ==============================================================================
; Fixed Frequency Lookup Table.
; ==============================================================================
table_operator_frequency_fixed:
    DC.W 0
    DC.W $3526
    DC.W $6A4C
    DC.W $9F74
