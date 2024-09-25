; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; lcd.asm
; ==============================================================================
; DESCRIPTION:
; This file contains all definitions, and subroutines used to interact with the
; synth's main LCD display.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; LCD Constants.
; These are constants related to the HD44780 LCD controller.
; ==============================================================================
LCD_CLEAR:                                      EQU 1
LCD_RETURN_HOME:                                EQU 1 << 1

LCD_ENTRY_MODE_SET:                             EQU 1 << 2
LCD_ENTRY_MODE_INCREMENT:                       EQU 1 << 1

LCD_DISPLAY_CONTROL:                            EQU 1 << 3
LCD_DISPLAY_ON:                                 EQU 1 << 2
LCD_DISPLAY_CURSOR:                             EQU 1 << 1
LCD_DISPLAY_BLINK:                              EQU 1

LCD_FUNCTION_SET:                               EQU 1 << 5
LCD_FUNCTION_DATA_LENGTH:                       EQU 1 << 4
LCD_FUNCTION_LINES:                             EQU 1 << 3

LCD_SET_POSITION:                               EQU 1 << 7


; ==============================================================================
; LCD_WAIT_FOR_READY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDDFB
; DESCRIPTION:
; Polls the LCD controller until it returns a status indicating that it is
; ready to accept new data.
;
; ==============================================================================
lcd_wait_for_ready:                             SUBROUTINE
    TST     lcd_ctrl
    BMI     lcd_wait_for_ready
    RTS


; ==============================================================================
; LCD_UPDATE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDE01
; DESCRIPTION:
; Updates the LCD screen with the contents of the LCD 'Next Contents' buffer.
; This compares the next contents against the current contents to determine
; whether any copy needs to take place. If so, the current content buffer will
; be updated also.
;
; MEMORY MODIFIED:
; * memcpy_ptr_src
; * memcpy_ptr_dest
; * lcd_buffer_current
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
lcd_update:                                     SUBROUTINE
; Load the address of the LCD's 'next', and 'current' contents buffers into
; the copy source, and destination pointers.
; Each character being copied is compared against the current LCD contents to
; determine whether it needs to be copied. Identical characters are skipped.
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_src
    LDX     #lcd_buffer_current
    STX     <memcpy_ptr_dest

; Load instruction to set LCD cursor position into B.
; This is incremented with each character copy operation, so that the position
; the command sets the cursor to stays correct.
    LDAB    #LCD_SET_POSITION

.lcd_update_copy_loop:
; Load ACCA from address pointer.
    LDX     <memcpy_ptr_src
    LDAA    0,x
; Increment the source pointer.
    INX
    STX     <memcpy_ptr_src

; If the next char to be printed matches the one in the same position
; in the LCD's current contents, it can be skipped.
    LDX     <memcpy_ptr_dest
    CMPA    0,x
    BEQ     .lcd_update_copy_loop_advance

; Write the instruction to update the LCD cursor position.
    JSR     lcd_wait_for_ready
    STAB    <lcd_ctrl

; Write the character data.
    JSR     lcd_wait_for_ready
    STAA    <lcd_data

; Store the character in the current LCD contents buffer.
    STAA    0,x

.lcd_update_copy_loop_advance:
; Increment the copy destination pointer.
    INX
    STX     <memcpy_ptr_dest

; Increment cursor position in ACCB, exit if we're at the end of the 2nd line.
    INCB
    CMPB    #(LCD_SET_POSITION + 0x40 + 16)
    BEQ     .lcd_update_exit

; Check whether the end of the first line has been reached.
; If so, set the current position to the start of the second line.
; Otherwise continue copying the first line contents.
    CMPB    #(LCD_SET_POSITION + 16)
    BNE     .lcd_update_copy_loop

; This instruction sets the LCD cursor to start of the second line.
    LDAB    #(LCD_SET_POSITION + 0x40)
    BRA     .lcd_update_copy_loop

.lcd_update_exit:
    RTS


; ==============================================================================
; LCD_CLEAR_LINE_2
; ==============================================================================
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Clears the second line of the LCD (next) buffer.
;
; MEMORY MODIFIED:
; * memcpy_ptr_dest: A pointer to the second line of the LCD next contents
; buffer is stored in the copy destination pointer.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * IX: A pointer to the start of the second LCD line.
;
; ==============================================================================
lcd_clear_line_2:                               SUBROUTINE
    LDAB    #16
    BRA     lcd_clear_chars

; ==============================================================================
; LCD_CLEAR
; ==============================================================================
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Clears the LCD (next) buffer.
;
; MEMORY MODIFIED:
; * memcpy_ptr_dest: A pointer to the start of the LCD next contents buffer is
;    stored in the copy dest pointer.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * IX: A pointer to the start of the LCD buffer.
;
; ==============================================================================
lcd_clear:                                      SUBROUTINE
    LDAB    #32
; Fall-through below.

; ==============================================================================
; LCD_CLEAR_CHARS
; ==============================================================================
lcd_clear_chars:                                SUBROUTINE
    LDAA    #'
; Fall-through below.

; ==============================================================================
; LCD_FILL_CHARS
; ==============================================================================
lcd_fill_chars:                                 SUBROUTINE
    LDX     #lcd_buffer_next_end

.fill_chars_loop:
    DEX
    STAA    0,x
    DECB
    BNE     .fill_chars_loop

    STX     <memcpy_ptr_dest
    RTS


; ==============================================================================
; LCD_INIT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDAE7
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Initialises the synth's LCD screen, and the LCD 'current contents' buffer.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
lcd_init:                                       SUBROUTINE
; The HD44780 datasheet instructs the user to wait for more than 15 ms after
; VCC rises to 4.5V before sending the first command.
    DELAY_LONG

; Call the function set command to initialise the controller settings.
    LDAA    #(LCD_FUNCTION_SET | LCD_FUNCTION_DATA_LENGTH | LCD_FUNCTION_LINES)
    STAA    lcd_ctrl
    DELAY_LONG

; Keep sending the initialisation command.
    STAA    lcd_ctrl
    DELAY_LONG

; Keep sending the initialisation command.
    STAA    lcd_ctrl
    JSR     lcd_wait_for_ready

; Now the full function set can be sent.
; In this case, it happens to be identical.
    STAA    lcd_ctrl
    JSR     lcd_wait_for_ready

; Turn the display on.
    LDAA    #(LCD_DISPLAY_CONTROL | LCD_DISPLAY_ON)
    STAA    lcd_ctrl
    JSR     lcd_wait_for_ready

; Clear the LCD.
    LDAA    #LCD_CLEAR
    STAA    lcd_ctrl
    JSR     lcd_wait_for_ready

; Set the LCD direction to 'increment'.
    LDAA    #(LCD_ENTRY_MODE_SET | LCD_ENTRY_MODE_INCREMENT)
    STAA    lcd_ctrl
    JSR     lcd_wait_for_ready

; Clear the synth's LCD 'current contents' buffer by filling each position
; in the buffer with an ASCII space.
; This buffer is used to store the current contents of the LCD screen.
    LDAA    #'
    LDX     #lcd_buffer_current

.clear_current_lcd_contents_loop:
    STAA    0,x
    INX
    CPX     #lcd_buffer_current_end
    BNE     .clear_current_lcd_contents_loop

    RTS


; ==============================================================================
; LCD_STRCPY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDDD8
; DESCRIPTION:
; Prints either a null-terminated string, or string sequence to a destination
; string buffer.
; The DX9 firmware supports the idea of a 'String Sequence', consisting of a
; series of offsets from an arbitrary location stored with the string. If
; these are encountered, a new string will be recursively loaded from this
; relative position, and printed until a terminating null character is found.
; This supports combining a series of strings into a sequence.
;
; ARGUMENTS:
; Registers:
; * IX:   A pointer to the string to print.
;
; MEMORY MODIFIED:
; * memcpy_ptr_dest: The destination string buffer pointer.
;
; REGISTERS MODIFIED:
; * ACCB, IX
;
; RETURNS:
; * IX:   A pointer to the last character written.
; * ACCB: The terminating character. This is actually used by the menu print
;         function. The parameter name strings are terminated with an integer
;         indexing the function used to print the associated parameter value.
;
; ==============================================================================
lcd_strcpy:                                     SUBROUTINE
    LDAB    0,x

; Is the character under the cursor equal or higher than 0x80?
; If so, this is a relative offset into the string table.
    BMI     .print_offset_string

; Test whether the character under the cursor is above ASCII space (0x20).
; If so, copy. Otherwise exit.
    CMPB    #32
    BCC     .copy_character

    RTS

.copy_character:
    JSR     lcd_store_character_and_increment_ptr
    INX
    BRA     lcd_strcpy

.print_offset_string:
; If the byte under the cursor is above 0x80 it represents an offset from this
; fixed point in the string table. This is a pointer to another string.
; The function is called recursively with this pointer.
; Once the recursive call returns, the pointer is incremented, and execution
; returns to the start of the function.
; This allows multiple strings to be called together in a predefined sequence.
    PSHX
    LDX     #string_fragment_offset_start
    ABX
    JSR     lcd_strcpy
    PULX
    INX
    BRA     lcd_strcpy


; ==============================================================================
; LCD_STORE_CHARACTER_AND_INCREMENT_POINTER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDDF1
; DESCRIPTION:
; Copies an individual character to the address stored in the memcpy
; destination pointer, then increments and stores the pointer. This routine is
; used by the string copy functions.
;
; ARGUMENTS:
; Registers:
; * ACCB: The character to store in the string buffer.
;
; Memory:
; * memcpy_ptr_dest: The destination string buffer pointer.
;
; REGISTERS MODIFIED:
; * IX
;
; RETURNS:
; * IX:   A pointer to the newly updated copy destination.
;
; ==============================================================================
lcd_store_character_and_increment_ptr:          SUBROUTINE
    PSHX
    LDX     <memcpy_ptr_dest
    STAB    0,x
    INX
    STX     <memcpy_ptr_dest
    PULX

    RTS


; ==============================================================================
; LCD_PRINT_NUMBER_THREE_DIGITS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDDA9
; DESCRIPTION:
; Prints a number with three digits to a string buffer.
; This subroutine will print the most-significant digit, and automatically
; fall through to print the remaining digits.
;
; ARGUMENTS:
; Registers:
; * ACCA: The number to be printed.
;
; Memory:
; * memcpy_ptr_dest: The destination string buffer pointer, pointing to where
;  the resulting number will be printed to.
;
; ==============================================================================
lcd_print_number_three_digits:                  SUBROUTINE
    CLR     lcd_print_number_print_zero_flag
    LDAB    #100
    BSR     lcd_print_number_get_digit
; Falls-through below.

; ==============================================================================
; LCD_PRINT_NUMBER_TWO_DIGITS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDDB0
; DESCRIPTION:
; Prints a number with two digits to a string buffer.
; This subroutine will print the most-significant digit, and automatically
; fall through to print the remaining digits.
;
; ARGUMENTS:
; Registers:
; * ACCA: The number to be printed.
;
; Memory:
; * memcpy_ptr_dest: The destination string buffer pointer, pointing to where
;  the resulting number will be printed to.
;
; ==============================================================================
lcd_print_number_two_digits:                    SUBROUTINE
    STAB    <lcd_print_number_print_zero_flag
    LDAB    #10
    BSR     lcd_print_number_get_digit
; Falls-through below.

; ==============================================================================
; LCD_PRINT_NUMBER_SINGLE_DIGIT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDDB6
; DESCRIPTION:
; Prints a single digit number to a string buffer.
;
; ARGUMENTS:
; Registers:
; * ACCA: The number to be printed.
;
; Memory:
; * memcpy_ptr_dest: The destination string buffer pointer, pointing to where
;     the resulting number will be printed to.
;
; ==============================================================================
lcd_print_number_single_digit:                  SUBROUTINE
    ADDA    #'0
    TAB
    BRA     lcd_print_number


; ==============================================================================
; LCD_PRINT_NUMBER_GET_DIGIT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDDBB
; DESCRIPTION:
; This subroutine converts one digit of a number to its ASCII equivalent.
; This is used as part of the 'lcd_print_number' routines.
; The 'divisor' argument passed in ACCB is used to determine which digit of a
; multiple digit number is returned.
;
; ARGUMENTS:
; Registers:
; * ACCA: The number to get the digit(s) of.
; * ACCB: The divisor for the operation.
;         This is used to find the ASCII digit by determining how
;         many of the divisor fit into the required number.
;         e.g: For getting the first digit of a three digit number, the
;         divisor should be '100'.
;
; MEMORY MODIFIED:
; * lcd_print_number_print_zero_flag: Used to determine whether a '0' should
; be printed in the case that the result is zero, or an ASCII space.
; * lcd_print_number_divisor: Used to store the divisor.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCA: The remainder after getting the current digit.
;         e.g: If the digit was the second digit of '123', the remainder
;         returned from the function will be '3'.
; * ACCB: The ASCII digit result, with 0x20 subtracted.
;         This is used to indicate whether a digit above zero was found.
;         This is used to determine whether a zero should be printed if the
;         function is called as part of printing a multiple digit number.
;         This will be saved, and passed to the next invocation.
;
; ==============================================================================
lcd_print_number_get_digit:                     SUBROUTINE
    STAB    <lcd_print_number_divisor

; Begin with an ASCII zero as the result byte.
    LDAB    #'0

; Is the number in ACCA less than the divisor?
; This tests whether the remaining number is divisible by the divisor.
.is_number_divisable:
    CMPA    <lcd_print_number_divisor
    BCS     .is_number_zero

; If the number is more than the divisor, increment the result, and subtract
; the divisor.
    INCB
    SUBA    <lcd_print_number_divisor
    BRA     .is_number_divisable

.is_number_zero:
; Test whether the resulting digit is equal to ASCII zero.
    CMPB    #'0
    BNE     lcd_print_number

; If the result is an ASCII zero, test whether the zero should be printed,
; or whether it should print an ASCII space.
    TST     lcd_print_number_print_zero_flag
    BNE     lcd_print_number

    LDAB    #'

lcd_print_number:
    JSR     lcd_store_character_and_increment_ptr
    SUBB    #'
    RTS
