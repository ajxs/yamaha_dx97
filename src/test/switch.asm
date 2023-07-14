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
; test/switch.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; This file contains the subroutines related to the synth's front-panel switch
; diagnostic testing.
; ==============================================================================

    .PROCESSOR HD6303

test_switch:                                    SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.test_switch_delay_counter:                     EQU #test_stage_sub
.test_switch_expected_input:                    EQU #test_stage_sub_2

; ==============================================================================
    LDAA    <.test_switch_delay_counter
    BEQ     .test_initialised

; The test 'sub stage' will have been initialised as 0xFF.
    CMPA    #$FF
    BEQ     .initialise_test

    JMP     .delay

.initialise_test:
    LDX     #str_sw
    JSR     test_lcd_set_write_pointer_to_position_7

    LDX     #str_push
    JSR     test_lcd_set_write_pointer_to_line_2

    CLR     .test_switch_expected_input
    CLR     .test_switch_delay_counter

.test_initialised:
; If not yet 26, the test is incomplete. Proceed to the current test stage.
    LDAA    <.test_switch_expected_input
    CMPA    #26
    BNE     .test_incomplete

; If the test is complete, reset and exit.
    LDAA    #$FE
    STAA    <.test_switch_expected_input

    JSR     lcd_clear_line_2
    LDX     #str_ok
    JSR     lcd_strcpy
    JSR     lcd_update
    BRA     .exit

.test_incomplete:
; If the test stage is equal to, or above 26, exit.
    BCC     .exit

; Clear space in the LCD buffer to print the name of the next switch to test.
    LDAA    #'
    LDX     #lcd_buffer_next_end

.clear_lcd_space_loop:
    DEX
    STAA    0,x
    CPX     #(lcd_buffer_next + 21)
    BNE     .clear_lcd_space_loop

    STX     <memcpy_ptr_dest

    LDAA    <.test_switch_expected_input
    CMPA    #20
    BCC     .test_stage_buttons_main

; Sub-stage 0 - 19.
; Print the numeric switches 1-20.
    LDAB    #'#
    JSR     lcd_store_character_and_increment_ptr
    CLRB
    INCA
    JSR     lcd_print_number_two_digits
    BRA     .lcd_update

.test_stage_buttons_main:
; Sub-stage 20 - 25.
; Print the 'main' button names.
    SUBA    #20
    LDX     #table_str_pointer_test_switches_stage
    TAB
    ASLB
    ABX
    LDX     0,x
    JSR     lcd_strcpy

.lcd_update:
    JSR     lcd_update

.is_test_stage_pedals:
; Test whether the sub-stage is above 24.
; The sub-stages above 24 involve the pedals.
    LDAA    <.test_switch_expected_input
    CMPA    #24
    BCC     .test_pedals

; Read the front-panel switch state.
    JSR     input_read_front_panel
    JSR     jumpoff

    DC.B .exit - *
    DC.B 3
    DC.B .test_switch_btn_store - *
    DC.B 4
    DC.B .exit - *
    DC.B 5
    DC.B .test_switch_btn_main - *
    DC.B 8
    DC.B .test_switch_store_btn_numeric - *
    DC.B 0

.exit:
    RTS

.test_switch_btn_store:
    LDAB    #20
    BRA     .compare_against_expected_input

.test_switch_btn_main:
    ADDB    #16
    BRA     .compare_against_expected_input

.test_switch_store_btn_numeric:
    SUBB    #8

.compare_against_expected_input:
; Compare the front-panel input state against the expected switch.
    CMPB    <.test_switch_expected_input
    BNE     .test_error

.update_expected_input:
    TBA
    INCA
    JSR     test_print_number_to_led
    LDX     #str_push
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    INC     .test_switch_expected_input
    JSR     pedals_update

    BRA     .exit

.test_pedals:
; 24 = Test whether sustain pedal is active.
; 25 = Test portamento pedal.
    JSR     pedals_update
    CMPB    #1

; The carry being set indicates that a 0 result has been returned,
; indicating no pedal. So return and loop to wait.
    BCS     .exit

    BHI     .compare_pedal_against_expected_input

    TIMD   #PEDAL_INPUT_SUSTAIN, pedal_status_current
    BEQ     .exit

.compare_pedal_against_expected_input:
; Add 23 to the pedal state change recorded in ACCB, since the portamento pedal,
; and sustain pedal tests are test stages 24, and 25.
    ADDB    #23
    CMPB    <.test_switch_expected_input
    BNE     .test_error

    BRA     .update_expected_input

.test_error:
    TBA
    INCA
    JSR     test_print_number_to_led
    LDX     #str_test_err
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update

    LDAA    #$FE
    STAA    <.test_switch_delay_counter

.delay:
    LDX     #128

.delay_loop:
    JSR     delay
    DEX
    BNE     .delay_loop

    DEC     .test_switch_delay_counter
    BRA     .exit


table_str_pointer_test_switches_stage:
    DC.W str_fragment_store
    DC.W str_function
    DC.W str_edit
    DC.W str_fragment_memory
    DC.W str_sustain
    DC.W str_portamento
