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
