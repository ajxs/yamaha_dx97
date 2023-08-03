; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; ui/print/osc_frequency.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the code used to print the value of the oscillator
; frequency.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI_PRINT_OSC_FREQ_GET_THOUSANDS
; ==============================================================================
; @PRIVATE
; DESCRIPTION:
; Finds the number of 'thousands' in the fixed frequency representation.
;  This value will be returned in the associated temporary variable.
;
; ARGUMENTS:
; Registers:
; * ACCD: The fixed frequency representation.
;    This value will be modified by the operation.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCD: The remainder of the fixed frequency representation after the
;    thousands have been removed.
;
; ==============================================================================
ui_print_osc_freq_get_thousands:                SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.freq_thousands:                                EQU #temp_variables

; ==============================================================================
    SUBD    #1000
    BCS     .re_add_thousand

    INC     .freq_thousands
    BRA     ui_print_osc_freq_get_thousands

.re_add_thousand:
    ADDD    #1000

    RTS


; ==============================================================================
; UI_PRINT_OSC_FREQ_GET_HUNDREDS
; ==============================================================================
; @PRIVATE
; DESCRIPTION:
; Finds the number of 'hundreds' in the fixed frequency representation.
;  This value will be returned in the associated temporary variable.
;
; ARGUMENTS:
; Registers:
; * ACCD: The fixed frequency representation.
;    This value will be modified by the operation.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCD: The remainder of the fixed frequency representation after the
;    hundreds have been removed.
;
; ==============================================================================
ui_print_osc_freq_get_hundreds:                 SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.freq_hundreds:                                 EQU #(temp_variables + 1)

; ==============================================================================
    SUBD    #100
    BCS     .re_add_hundred

    INC     .freq_hundreds
    BRA     ui_print_osc_freq_get_hundreds

.re_add_hundred:
    ADDD    #100

    RTS


; ==============================================================================
; UI_PRINT_OSC_FREQ_GET_TENS
; ==============================================================================
; @PRIVATE
; DESCRIPTION:
; Finds the number of 'tens' in the fixed frequency representation.
;  This value will be returned in the associated temporary variable.
;
; ARGUMENTS:
; Registers:
; * ACCD: The fixed frequency representation.
;    This value will be modified by the operation.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCD: The remainder of the fixed frequency representation after the
;    tens have been removed.
;
; ==============================================================================
ui_print_osc_freq_get_tens:                     SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.freq_tens:                                     EQU #(temp_variables + 2)

; ==============================================================================
    SUBD    #10
    BCS     .re_add_ten

    INC     .freq_tens
    BRA     ui_print_osc_freq_get_tens

.re_add_ten:
    ADDD    #10

    RTS


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_OSC_FREQ
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the oscillator frequency to the LCD.
;
; ==============================================================================
ui_print_parameter_value_osc_freq:              SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.freq_thousands:                                EQU #temp_variables
.freq_hundreds:                                 EQU #(temp_variables + 1)
.freq_tens:                                     EQU #(temp_variables + 2)
.freq_coarse:                                   EQU #(temp_variables + 3)

; ==============================================================================
; Print the equals sign, and set the destination pointer at the correct
; place for the following LCD operations.
    LDAA    #'=
    LDX     #(lcd_buffer_next + 24)
    STAA    0,x
    INX
    STX     <memcpy_ptr_dest

; These variables are used to print the individual digits of the frequency.
    CLR     .freq_thousands
    CLR     .freq_hundreds
    CLR     .freq_tens

    JSR     patch_operator_get_ptr_to_selected
    LDAA    PATCH_OP_MODE,x
    BNE     .osc_mode_fixed

    LDAA    PATCH_OP_FREQ_COARSE,x
    BEQ     .ratio_coarse_freq_zero

; For coarse frequencies above 0, the final operator ratio value displayed is
;   (100 * FREQ_COARSE) + (FREQ_COARSE * FREQ_FINE)
    LDAB    PATCH_OP_FREQ_FINE,x
    ADDB    #100
    MUL

    BSR     ui_print_osc_freq_get_thousands
    BSR     ui_print_osc_freq_get_hundreds

    PSHB
    LDAA    .freq_thousands
    LDAB    #10
    MUL

    ADDB    .freq_hundreds
    TBA
    JSR     lcd_print_number_three_digits
    LDAB    #'.
    JSR     lcd_store_character_and_increment_ptr
    PULA
    JSR     lcd_print_number_two_digits
    JMP     lcd_update

.ratio_coarse_freq_zero:
; For a coarse frequency of 0, the final operator ratio =
;   50 + ((FREQ_COARSE + 1 ) * (FREQ_FINE >> 1))
    CLRA
    JSR     lcd_print_number_three_digits
    LDAB    #'.
    JSR     lcd_store_character_and_increment_ptr

    LDAA    PATCH_OP_FREQ_FINE,x
    LSRA
    ADDA    #50

    JSR     lcd_print_number_two_digits
    JMP     lcd_update

.osc_mode_fixed:
; Save the coarse oscillator frequency.
; This will be used later to determine how many digits lie before the decimal
; point when printing the value.
; The value is clamped at 4, since there are only 4 actual valid values for a
; fixed frequency: 1hz = 0, 10hz = 1, 100hz = 2, 1000hz.
; The second entry in the table is 1023. If the coarse freq is 100hz then
; this will print as: 102.3xx
    LDAB    PATCH_OP_FREQ_COARSE,x
    ANDB    #3
    STAB    .freq_coarse

    LDAB    PATCH_OP_FREQ_FINE,x

; Use the patch's fixed frequency value as an index into this table, and
; load the resulting value into ACCD.
    LDX     #fixed_frequency_fine_values_print
    ASLB
    ABX
    LDD     0,x

; Print the 'thousands' digit.
    JSR     ui_print_osc_freq_get_thousands
    PSHB
    LDAB    .freq_thousands
; Offset the number value with ASCII '0' to convert to an ASCII value.
    ADDB    #'0
    JSR     lcd_store_character_and_increment_ptr
    PULB

    TEST_WHETHER_TO_PRINT_PERIOD #0

; Print the 'hundreds' digit.
    JSR     ui_print_osc_freq_get_hundreds
    PSHB
    LDAB    .freq_hundreds
    ADDB    #'0
    JSR     lcd_store_character_and_increment_ptr
    PULB

    TEST_WHETHER_TO_PRINT_PERIOD #1

; Print the 'tens' digit.
    JSR     ui_print_osc_freq_get_tens
    PSHB
    LDAB    .freq_tens
    ADDB    #'0
    JSR     lcd_store_character_and_increment_ptr
    PULB

    TEST_WHETHER_TO_PRINT_PERIOD #2

; Print the final digit.
    ADDB    #'0
    JSR     lcd_store_character_and_increment_ptr

; Print 'Hz'.
; This value is the hex literal for 'Hz'. This value is used on account of
; dasm not supporting loading a string using STD.
    LDD     #$487A
    STD     0,x

    JMP     lcd_update


; ==============================================================================
; Tests whether to print the decimal place period.
; This is used after printing each digit in a fixed oscillator frequency.
;
; ARGUMENTS:
; * 1: The coarse oscillator frequency value to compare against.
;
; REGISTERS MODIFIED:
; * IX
;
; ==============================================================================
    .MACRO TEST_WHETHER_TO_PRINT_PERIOD
; Redefine this variable, since macros reset local label definitions.
; This has no effect on the actual generated machine code.
.freq_coarse:                                   EQU #(temp_variables + 3)

        PSHB
        LDAB    .freq_coarse
        CMPB    {1}
        BNE     .proceed_without_printing_period$

        LDAB    #'.
        JSR     lcd_store_character_and_increment_ptr
.proceed_without_printing_period$:
        PULB

    .ENDM

; ==============================================================================
; Fine Frequency Values Table.
; @TAKEN_FROM_DX7_FIRMWARE
; ==============================================================================
fixed_frequency_fine_values_print:
    DC.W $3E8
    DC.W $3FF
    DC.W $417
    DC.W $430
    DC.W $448
    DC.W $462
    DC.W $47C
    DC.W $497
    DC.W $4B2
    DC.W $4CE
    DC.W $4EB
    DC.W $508
    DC.W $526
    DC.W $545
    DC.W $564
    DC.W $585
    DC.W $5A5
    DC.W $5C7
    DC.W $5EA
    DC.W $60D
    DC.W $631
    DC.W $656
    DC.W $67C
    DC.W $6A2
    DC.W $6CA
    DC.W $6F2
    DC.W $71C
    DC.W $746
    DC.W $771
    DC.W $79E
    DC.W $7CB
    DC.W $7FA
    DC.W $829
    DC.W $85A
    DC.W $88C
    DC.W $8BF
    DC.W $8F3
    DC.W $928
    DC.W $95F
    DC.W $997
    DC.W $9D0
    DC.W $A0A
    DC.W $A46
    DC.W $A84
    DC.W $A9C
    DC.W $B02
    DC.W $B44
    DC.W $B87
    DC.W $BCC
    DC.W $C12
    DC.W $C5A
    DC.W $CA4
    DC.W $CEF
    DC.W $D3C
    DC.W $D8B
    DC.W $DDC
    DC.W $E2F
    DC.W $E83
    DC.W $EDA
    DC.W $F32
    DC.W $F8D
    DC.W $FEA
    DC.W $1049
    DC.W $10AA
    DC.W $110D
    DC.W $1173
    DC.W $11DB
    DC.W $1245
    DC.W $12B2
    DC.W $1322
    DC.W $1394
    DC.W $1409
    DC.W $1480
    DC.W $14FA
    DC.W $1577
    DC.W $15F7
    DC.W $167A
    DC.W $1700
    DC.W $178A
    DC.W $1816
    DC.W $18A6
    DC.W $1939
    DC.W $19CF
    DC.W $1A69
    DC.W $1B06
    DC.W $1BA7
    DC.W $1C4C
    DC.W $1CF5
    DC.W $1DA2
    DC.W $1E52
    DC.W $1F07
    DC.W $1FC0
    DC.W $207E
    DC.W $213F
    DC.W $220E
    DC.W $22D1
    DC.W $23A0
    DC.W $2475
    DC.W $254E
    DC.W $262C
