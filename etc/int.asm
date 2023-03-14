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
; int.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the code related to integer conversion.
; This was cut from the DX9/7 ROM on account of not being needed, however it
; may prove useful for someone else at some point.
; ==============================================================================

    .PROCESSOR HD6303

; @PUT THESE IN ram.asm
; These variables are used during the conversion of a stored integer into its
; ASCII representation. They are used to hold the powers-of-ten of an integer.
; For more specific information, refer to the documentation in the
; 'int_convert_to_string' subroutine.
int_convert_to_string_output:                   DS 4
int_converted_digits:                           EQU (#int_convert_to_string_output + 0)
int_converted_tens:                             EQU (#int_convert_to_string_output + 1)
int_converted_hundreds:                         EQU (#int_convert_to_string_output + 2)
int_converted_thousands:                        EQU (#int_convert_to_string_output + 3)

; ==============================================================================
; INT_CONVERT_TO_STRING
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; Converts an integer within the range 0-9999 to its ASCII equivalent.
; This subroutine places the resulting individual digits into the four result
; memory offsets starting from ______ and working backwards in powers of ten.
; For example, if the number passed to the function was '1724':
; - array[0]: 0x4
; - array[1]: 0x2
; - array[2]: 0x7
; - array[3]: 0x1
;
; ARGUMENTS:
; Registers:
; * ACCD: The number to convert.
;
; MEMORY MODIFIED:
; * int_convert_to_string_output: Storage for the converted string.
;
; ==============================================================================
int_convert_to_string:                          SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.original_number:                               EQU #temp_variables
.powers_of_ten_pointer:                         EQU #(temp_variables + 2)
.iterator                                       EQU #(temp_variables + 4)
.remainder                                      EQU #(temp_variables + 6)
.counter                                        EQU #(temp_variables + 7)

; ==============================================================================
    PSHX
    STD     .original_number
    LDX     #table_powers_of_ten
    STX     .powers_of_ten_pointer

    LDAB    #4
    STAB    .iterator

    LDD     .original_number

.convert_digit_loop:
; This is the outer-loop responsible for each digit.
    CLR     .counter

.test_power_of_ten_loop:
; Load the current power-of-ten, and subtract it from the value in ACCD.
    LDX     .powers_of_ten_pointer
    SUBD    0,x
; If this subtraction sets the carry bit, advance the loop to the next lowest
; power of ten.
    BCS     .next_power_of_ten

; If the number is still more than this power-of-ten, increment the counter,
; and perform the subtraction again.
    INC     .counter
    BRA     .test_power_of_ten_loop

.next_power_of_ten:
; Add the previously subtracted power-of-ten back to the number, since it's
; now negative.
    LDX     .powers_of_ten_pointer
    ADDD    0,x

; Increment the power-of-ten pointer.
    INX
    INX
    STX     .powers_of_ten_pointer

    STD     .remainder

    LDAA    .counter
    LDAB    .iterator

; Store the result digit.
    LDX     #.iterator
    ABX
    STAA    0,x

    LDD     .remainder
    DEC     .iterator
    BNE     .convert_digit_loop

    PULX
    RTS

table_powers_of_ten:
    DC.W 1000
    DC.W 100
    DC.W 10
    DC.W 1
