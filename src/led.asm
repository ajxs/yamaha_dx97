; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; led.asm
; ==============================================================================
; DESCRIPTION:
; This file contains all definitions, and subroutines used to interact with the
; synth's LED display.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; LED Constants
; ==============================================================================
LED_DIGIT_0                                     EQU %11000000
LED_DIGIT_1                                     EQU %11111001

; ==============================================================================
; LED segment mapping table.
; These values represent the codes for rendering the numbers 0-9 on the synth's
; two 7-segment LEDs.
; This is primarily used when printing the patch number to the LED display.
; Note: Digit '9' differs from the DX7: The bottom segment on the DX9 is lit.
;
; Each bit in these bitmasks corresponds to a segment of the LED:
;  0:  Top
;  1:  Right top
;  2:  Right bottom
;  3:  Bottom
;  4:  Left bottom
;  5:  Left top
;  6:  Middle
;  7:  -
; ==============================================================================
table_led_digit_map:
    DC.B LED_DIGIT_0
    DC.B LED_DIGIT_1
    DC.B %10100100
    DC.B %10110000
    DC.B %10011001
    DC.B %10010010
    DC.B %10000010
    DC.B %11111000
    DC.B %10000000
    DC.B %10010000

; ==============================================================================
; LED Hex digit segment mapping table.
; These values represent the codes for rendering the hexadecimal digits A-F
; on the synth's two 7-segment LEDs.
; This segment should immediately follow the numerical digit map.
; ==============================================================================
table_led_hex_digit_map:
    DC.B %10001000                              ; 'A'
    DC.B %10000000                              ; 'B'
    DC.B %11000110                              ; 'C'
    DC.B %11000000                              ; 'D'
    DC.B %10000110                              ; 'E'
    DC.B %10001110                              ; 'F'


; ==============================================================================
; LED_GET_DIGITS_HEX
; ==============================================================================
; @NEW_FUNCTIONALITY
; DESCRIPTION:
; Gets the LED segment codes required to represent a single byte as two
; hexadecimal digits on the synth's LED display.
;
; ARGUMENTS:
; Registers:
; * ACCA: The byte to represent.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; RETURNS:
; * ACCA+ACCB: The two hexadecimal LED segment codes.
;
; ==============================================================================
led_get_digits_hex:                             SUBROUTINE
; Look up the hexadecimal digit for the low-nibble.
    TAB
    ANDB    #$F
    LDX     #table_led_digit_map
    ABX
    LDAB    0,x

    PSHB

; Look up the hexadecimal digit for the high-nibble.
    TAB
    LSRB
    LSRB
    LSRB
    LSRB
    LDX     #table_led_digit_map
    ABX
    LDAA    0,x

    PULB

    RTS


; ==============================================================================
; LED_PRINT_PATCH_NUMBER
; ==============================================================================
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Prints the currently selected patch number to the synth's LED display.
; This has been altered from the original to take advantage of the lower patch
; count. This version only prints numbers up to '10', with any patch index
; above '10' being printed as '00'. This scenario occurs when receiving
; incoming single patches.
;
; ARGUMENTS:
; Memory:
; * patch_index_current: The patch number that will be printed.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
led_print_patch_number:                         SUBROUTINE
    LDAB    patch_index_current
    INCB

    CMPB    #10
    BEQ     .patch_index_10

    BCS     .patch_index_below_10

; For any value above '10', print '00'.
    LDAA    #LED_DIGIT_0
    LDAB    #LED_DIGIT_0
    BRA     .print_value

.patch_index_10:
    LDAA    #LED_DIGIT_1
    LDAB    #LED_DIGIT_0
    BRA     .print_value

.patch_index_below_10:
    LDAA    #$FF

; Lookup the second digit in the LED mapping table.
    LDX     #table_led_digit_map
    ABX
    LDAB    0,x

.print_value:
    STD     led_contents

    STAA    <led_1

; If the compare mode is active, mask bit 7 of the second LED digit to
; display the compare mode marker.
    TST     patch_compare_mode_active
    BNE     .write_led2_and_exit

    ANDB    #%1111111

.write_led2_and_exit:
    STAB    <led_2

    RTS
