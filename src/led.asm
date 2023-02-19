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
LED_DIGIT_2                                     EQU %10100100

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
    DC.B LED_DIGIT_2
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
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Prints the currently selected patch number to the synth's LED display.
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

; The patch number is set to 128 after initialising the patch.
; If this is the case print '00' to the LEDs.
; Otherwise proceed to printing the LED number normally.
    BPL     .jumpoff

    LDAA    #LED_DIGIT_0
    LDAB    #0
    BRA     led_write_digit_1_lookup_digit_2

; The patch number is set to '20' when finished receiving a bulk patch dump
; over the cassette interface.
    CMPB    #20
    BNE     .jumpoff

; In the case that the patch number was '20', subtract '21' to set it to 0xFF,
; which will clear the LEDs.
    SUBB    #21

.jumpoff:
; Increment the patch number since its internal representation is 0-indexed.
; This will be used to jump to functions based upon whether the number is
; below '10', '20', or equal to '20'.
    INCB
    JSR     jumpoff

    DC.B led_print_patch_number_below_10 - *
    DC.B 10
    DC.B led_print_patch_number_below_20 - *
    DC.B 20
    DC.B led_print_patch_number_20 - *
    DC.B 0


; ==============================================================================
; LED_PRINT_PATCH_NUMBER_BELOW_10
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Prints the currently selected patch number if it below '10'
;
; ==============================================================================
led_print_patch_number_below_10:
; Load the LED code for a blank 7-segment display (0xFF) for LED1.
    LDAA    #$FF
    BRA     led_write_digit_1_lookup_digit_2


; ==============================================================================
; LED_PRINT_PATCH_NUMBER_BELOW_20
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Prints the currently selected patch number if it below '20'
;
; ==============================================================================
led_print_patch_number_below_20:
; Load the 7-segment display LED code for '1' (0xF9) for LED1.
; Subtract '10' from the number to get the number to print to LED2.
    LDAA    #LED_DIGIT_1
    SUBB    #10
    BRA     led_write_digit_1_lookup_digit_2


; ==============================================================================
; LED_PRINT_PATCH_NUMBER_20
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Prints the currently selected patch number if it is '20'
;
; ==============================================================================
led_print_patch_number_20:
; Load the 7-segment display LED code for '2' (0xA4) for LED1.
; Clear ACCB, and then fall-through to lookup digit 2.
    LDAA    #LED_DIGIT_2
    CLRB
; Fall-through below.

; ==============================================================================
; LED_WRITE_DIGIT_1_LOOKUP_DIGIT_2
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Prints the first digit of the LED, and looks up digit 2 based upon the
; value passed in ACCB.
;
; ARGUMENTS:
; Registers:
; * ACCA: The LED digit data to write to the first LED digit.
;         This data is obtained from the LED mapping table.
; * ACCB: The number to write to the second LED digit.
;         This will be looked up from the LED mapping table.
;
; ==============================================================================
led_write_digit_1_lookup_digit_2:               SUBROUTINE
    STAA    led_contents
    TST     patch_compare_mode_active
    BNE     .lookup_digit_2

    STAA    <led_1

.lookup_digit_2:
; Lookup the second digit in the LED mapping table.
    LDX     #table_led_digit_map
    ABX
    LDAA    0,x

; If the active patch has been edited, don't perform a check for whether
; the patch compare mode is active.
    TST     patch_current_modified_flag
    BEQ     .write_digit_2_contents

; If the compare mode is active, mask bit 7 of the second LED digit to
; display the compare mode marker.
    TST     patch_compare_mode_active
    BNE     .write_digit_2_contents

    ANDA    #%1111111

.write_digit_2_contents:
    STAA    led_contents+1
    TST     patch_compare_mode_active
    BNE     .write_digit_1_lookup_digit_2_exit

    STAA    <led_2

.write_digit_1_lookup_digit_2_exit:
    RTS
