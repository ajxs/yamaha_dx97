; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; test/test.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions and code used for the loading, and UI of the
; internal diagnostic routines.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_ENTRY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xF738
; DESCRIPTION:
; This is the main entry point to the synth's diagnostic self-test routines.
; Once this is entered, the synth will be put in a loop, cycling through the
; diagnostic routines.
;
; ==============================================================================
test_entry:                                     SUBROUTINE
    JSR     test_entry_reset_system

.test_stage_loop:
    JSR     test_entry_get_input

; Load the current test stage, and clamp this value at '12'.
; This value is then used as an index into the table of diagnostic
; function pointers.
    LDX     #table_test_function_ptrs
    LDAB    <test_stage_current
    CMPB    #12
    BCS     .jump_to_test_function

    CLRB

.jump_to_test_function:
    ASLB
    ABX
    LDX     0,x

; Jump to the test function, and then loop back to get user input again.
    JSR     0,x
    BRA     .test_stage_loop


; ==============================================================================
; Test Function Pointer Table.
; ==============================================================================
table_test_function_ptrs:
    DC.W test_volume
    DC.W test_lcd
    DC.W test_switch
    DC.W test_kbd
    DC.W test_adc
    DC.W test_tape
    DC.W test_tape_remote
    DC.W test_ram
    DC.W test_rom
    DC.W test_eg_op
    DC.W test_auto_scaling
    DC.W test_exit


; ==============================================================================
; TEST_EXIT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Exits the test routines and returns to the synth's normal functionality.
; This re-enables interrupts.
;
; ==============================================================================
test_exit:                                      SUBROUTINE
; @TODO: I'm not sure what the stack trace looks like at this point.
; Presumably this is to break out of the UI subroutines that triggered the test
; routines.
    INS
    INS

; Re-enable the output-compare interrupt, and clear condition flags.
    LDAA    #TIMER_CTRL_EOCI
    STAA    <timer_ctrl_status

    CLRA
    TAP

    RTS


; ==============================================================================
; TEST_ENTRY_RESET_SYSTEM
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xF768
; DESCRIPTION:
; Resets system variables when entering the synth's self-test diagnostic mode.
; The EGS voice data will also be reset.
; This subroutine resets the test stage to '0'.
;
; ==============================================================================
test_entry_reset_system:                        SUBROUTINE
    JSR     voice_reset_egs
    LDAA    #$FF
    TAP

; Disable the output-compare interrupt, and clear condition flags.
    CLRA
    STAA    <timer_ctrl_status

; Set portamento speed to instantaneous.
    LDAA    #$FF
    STAA    <portamento_rate_scaled

    JSR     voice_reset_pitch_eg_current_frequency

; Clear EGS pitch-mod.
    CLRA
    STAA    egs_pitch_mod_high
    STAA    egs_pitch_mod_low
    STAA    mono_poly

; Enable all operators.
    RESET_OPERATOR_STATUS

; Reset the button input.
    LDAA    #3
    STAA    <test_button_input

; Reset the current test stage to '0'.
    CLRB
    JMP     test_entry_store_updated_stage


; ==============================================================================
; TEST_ENTRY_GET_INPUT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Handles user input for the test mode user-interface.
; This allows the user to increment, and decrement the current 'test stage'.
;
; ==============================================================================
test_entry_get_input:                           SUBROUTINE
    JSR     test_entry_get_user_input_read_buttons
    JSR     jumpoff

    DC.B .exit - *
    DC.B 1
    DC.B test_entry_get_input_increment_stage - *
    DC.B 2
    DC.B test_entry_get_input_decrement_stage - *
    DC.B 3
    DC.B .exit - *
    DC.B 0

.exit:
    RTS


; ==============================================================================
; TEST_ENTRY_GET_INPUT_INCREMENT_STAGE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xF7A4
; DESCRIPTION:
; Increment the current test stage.
; This is triggered by user input during the test entry main loop.
;
; MEMORY MODIFIED:
; * test_stage_current: The current test stage being changed.
;
; ==============================================================================
test_entry_get_input_increment_stage:           SUBROUTINE
    LDAB    <test_stage_current
    INCB
    CMPB    #12
    BCS     test_entry_store_updated_stage

    LDAB    #11
; Falls-through below.

; ==============================================================================
; TEST_ENTRY_STORE_UPDATED_STAGE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Stores the newly updated test stage, and initialises variables used by the
; test stages.
; It also prints the test stage number.
;
; ARGUMENTS:
; Registers:
; * ACCB: The updated test stage to store.
;
; MEMORY MODIFIED:
; * pedal_status_current
; * sustain_status
; * pedal_status_previous
; * test_stage_current
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
test_entry_store_updated_stage:                 SUBROUTINE
    STAB    <test_stage_current

    JSR     voice_reset

; Reset peripherals, and sustain status.
    CLRB
    STAB    <pedal_status_current
    STAB    <sustain_status
    STAB    <pedal_status_previous

; Reset test sub-stage.
    LDAB    #$FF
    STAB    <test_stage_sub

; Print the main test stage number to the LCD screen.
; This prints 'TEST 0x'. The individual test subroutines print the test
; names starting from position 7 onwards in the LCD buffer.
    JSR     test_lcd_led_all_off
    JSR     lcd_clear
    LDX     #str_test
    JSR     lcd_strcpy

; Print the current test number to the LCD.
    LDAA    <test_stage_current
    INCA
    CLRB
    JSR     lcd_print_number_two_digits
    JMP     lcd_update


; ==============================================================================
; TEST_ENTRY_GET_INPUT_DECREMENT_STAGE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xF7D7
; @PRIVATE
; DESCRIPTION:
; Decrements the current test stage.
; This is triggered by user input during the test entry main loop.
;
; ==============================================================================
test_entry_get_input_decrement_stage:           SUBROUTINE
    LDAB    <test_stage_current
    DECB
    BPL     .store_stage

    CLRB

.store_stage:
    BRA     test_entry_store_updated_stage


; ==============================================================================
; TEST_ENTRY_GET_USER_INPUT_READ_BUTTONS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Reads the front-panel button input to determine whether the 'YES', or 'NO'
; buttons are currently being pressed.
;
; MEMORY MODIFIED:
; * test_button_input
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; RETURNS:
; * ACCB: The result of reading the front-panel button input.
;    '0' if no input, '1' if 'YES', '2' if 'NO'.
;
; ==============================================================================
test_entry_get_user_input_read_buttons:         SUBROUTINE
    LDAB    <io_port_1_data
    ANDB    #%11110000
    STAB    <io_port_1_data
    DELAY_SINGLE

    LDAB    <key_switch_scan_driver_input
    ANDB    #(KEY_SWITCH_LINE_0_BUTTON_YES | KEY_SWITCH_LINE_0_BUTTON_NO)

; Load the current button input value into ACCA, and store the updated input
; into ACCB.
    LDAA    <test_button_input
    STAB    <test_button_input

; Invert the previous value, then AND this with the current updated value.
; This will set the bit of any input line that has changed.
    COMA
    ANDA    <test_button_input

; This value will be shifted right to set the carry bit in the case that a
; particular input line is set. The value '2' is loaded here since we're only
; interested in the YES/NO buttons, which are lines 0/1.
    LDAB    #2

; If the carry bit is set after rotating right once, it means the 'YES' button
; is being pressed, so return '1'.
    ASRA
    BCS     .decrement_result

; If the carry bit is set after rotating right twice, it means the 'NO' button
; is being pressed, so return '2'.
    ASRA
    BCS     .exit

; If this point has been reached, it means no buttons are being pressed.
; Decrement ACCB twice to return 0.
    DECB

.decrement_result:
    DECB

.exit:
    RTS


; ==============================================================================
; TEST_PRINT_NUMBER_TO_LED
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Prints a number to the synth's LEDs. This routine is used by the keyboard,
; ADC, and switch test subroutines.
; @TODO: A number over 100 passed to this subroutine will print a pattern.
;
; ARGUMENTS:
; Registers:
; * ACCA: The number to print to the LEDs.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
test_print_number_to_led:                       SUBROUTINE
    CMPA    #100
    BCC     .number_over_100

    CLRB

.count_tens_loop:
    SUBA    #10
    BCS     .test_tens_digit

    INCB
    BRA     .count_tens_loop

.test_tens_digit:
; Add '10' to the number to compensate for the final '10' subtracted.
    ADDA    #10

; Test if the number is above 10.
; If it is, proceed to looking up the tens digit.
    TSTB
    BNE     .lookup_digit_1

; If the ACCB is equal to 0, set ACCB to 0xFF to make the first digit blank.
    LDAB    #$FF
    BRA     .store_digit_1

.lookup_digit_1:
    LDX     #table_led_digit_map
    ABX
    LDAB    0,x

.store_digit_1:
    STAB    <led_1

    LDX     #table_led_digit_map
    TAB
    ABX
    LDAB    0,x
    STAB    <led_2

.exit:
    RTS

.number_over_100:
; Subtract 100 to get an index into the table.
; If the result is over 2, clear it.
    SUBA    #100
    CMPA    #2
    BCS     .lookup_table_entry

    CLRA

.lookup_table_entry:
    LDX     #table_led_patterns
    TAB
    ASLB
    ABX
    LDD     0,x
    STD     <led_1
    BRA     .exit


table_led_patterns:
    DC.W $FFFF
    DC.W $C0C0


; ==============================================================================
; TEST_LCD_SET_WRITE_POINTER_TO_POSITION_7
; ==============================================================================
; DESCRIPTION:
; Sets the LCD strcpy pointer to position 7 in the LCD buffer.
;
; ==============================================================================
test_lcd_set_write_pointer_to_position_7:       SUBROUTINE
    LDD     #(lcd_buffer_next + 7)
; Falls-through below.

test_lcd_store_write_pointer:
    STD     <memcpy_ptr_dest
    JMP     lcd_strcpy


; ==============================================================================
; TEST_LCD_SET_WRITE_POINTER_TO_LINE_2
; ==============================================================================
; DESCRIPTION:
; Sets the LCD strcpy pointer to the start of line 2 in the LCD buffer.
;
; ==============================================================================
test_lcd_set_write_pointer_to_line_2:           SUBROUTINE
    LDD     #lcd_buffer_next_line_2
    BRA     test_lcd_store_write_pointer


table_test_eg_op_string_offsets:
    DC.B str_envelope - *
    DC.B str_modulation - *
    DC.B str_test_feedback - *

; A/D Test strings.
; These strings are expected to be in a specific order.
str_ad:                         DC "A/D", 0
str_pitch_bender:               DC "PITCH BENDER    ", 0
str_modulation_wheel:           DC "MODULATION WHEEL", 0
str_breath_controller:          DC "BREATH CONTROLER", 0
str_data_entry:                 DC "DATA ENTRY", 0

str_auto_scal:                  DC "AUTO SCAL", 0
str_eg_op:                      DC "EG/OP", 0
str_push_1_button:              DC "push #1 button", 0
str_test_adj_vr5:               DC "ADJ VR5", 0

str_envelope:                   DC "envelope", 0
str_modulation:                 DC "modulation", 0
str_test_feedback:              DC "feedback", 0

str_edit:                       DC "EDIT", 0
str_function:                   DC "FUNCTION", 0
str_sustain:                    DC "SUSTAIN", 0
str_portamento:                 DC.B STR_FRAGMENT_OFFSET_PORTA
                                DC "MENTO", 0
str_push:                       DC "push", 0
str_sw:                         DC "SW", 0
str_test_err:                   DC "ERR!", 0
str_kbd:                        DC "KBD", 0
str_error_ram:                  DC "ERROR RAM", 0
str_under_test:                 DC "UNDER TEST", 0
str_cassette:                   DC "CASSETTE", 0
str_rom:                        DC "ROM", 0
str_remote:                     DC "REMOTE", 0
str_test_on:                    DC "ON", 0
