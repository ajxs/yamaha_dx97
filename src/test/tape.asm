; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; test/ram.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the diagnostic routines for the cassette interface.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_TAPE
; ==============================================================================
; DESCRIPTION:
; This test strobes the output line for an arbitrary period, then reads an
; input signal of an arbitrary frequency, testing whether the input signal's
; frequency was correctly read.
; This was potentially intended to correspond to some external test equipment.
; There is nothing contained in the synth's manual, or service manual about
; this test.
;
; ==============================================================================
test_tape:                                      SUBROUTINE
; Check whether the test stage is complete.
    TST     test_stage_sub
    BEQ     .exit

; The test stage was initialised at 0xFF.
; This tests whether this test function has been initialised.
    BPL     .test_initialised

; Write test stage name to the LCD.
    LDX     #str_cassette
    JSR     test_lcd_set_write_pointer_to_position_7

    LDX     #str_push_1_button
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update

; Mark the test as having been initialised.
    CLR     <test_stage_sub_2
    LDAA    #1
    STAA    <test_stage_sub
    BRA     .exit

.test_initialised:
; Wait for the '1' button to be pressed to begin the actual test.
    LDAA    <test_stage_sub
    CMPA    #1
    BNE     .begin_test

    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_1
    BNE     .exit

    LDAA    #2
    STAA    <test_stage_sub
    BRA     .exit

.begin_test:
    JSR     lcd_clear_line_2

; Clear ACCB so that this loop iterates 256 times.
    CLRB
.strobe_output_loop:
; Toggle the tape output line high/low.
    EIMD    #PORT_1_TAPE_OUTPUT, io_port_1_data
    BSR     test_tape_delay

; @TODO: Why is the input read?
; This does initialise the 'previous polarity', but this isn't needed?
    LDAA    <io_port_1_data
    ANDA    #PORT_1_TAPE_INPUT
    STAA    <tape_input_polarity_previous

    DECB
    BNE     .strobe_output_loop

; The following loop counts the number of pulses read over the tape input line.
    LDAB    #$80
.count_input_pulses_loop:
; Toggle the tape output line high/low.
    EIMD    #PORT_1_TAPE_OUTPUT, io_port_1_data
    BSR     test_tape_read_input

    DECB
    BNE     .count_input_pulses_loop

    LDAA    <test_stage_sub_2

; Is the number of pulses detected less than 126?
; If so, this constitutes an error.
    CMPA    #126
    BCS     .print_error_string

; Is the number of pulses detected more than 130?
; If so, this constitutes an error.
    CMPA    #130
    BCC     .print_error_string

    LDX     #str_ok

.print_result_string:
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update

; Mark the test as complete.
    CLR     test_stage_sub

.exit:
    RTS

.print_error_string:
    LDX     #str_test_err
    BRA     .print_result_string


; ==============================================================================
; TEST_TAPE_DELAY
; ==============================================================================
; DESCRIPTION:
; An arbitrary delay used when strobing the tape interface output line.
;
; ==============================================================================
test_tape_delay:                                SUBROUTINE
    LDX     #90
    NOP
    NOP

.delay_loop:
    DEX
    BNE     .delay_loop

    RTS


; ==============================================================================
; TEST_TAPE_READ_INPUT
; ==============================================================================
; @TAKEN_FROM_DX9_ROM:0xFBB1
; DESCRIPTION:
; Reads the tape input over an arbitrary period of 12 cycles, incrementing the
; test sub stage variable to count the number of 'pulses' that occur within
; the period.
;
; ==============================================================================
test_tape_read_input:                           SUBROUTINE
    LDX     #12

.read_input_loop:
    LDAA    <io_port_1_data
    ANDA    #PORT_1_TAPE_INPUT

; Test whether the polarity has changed.
    EORA    <tape_input_polarity_previous
    BPL     .input_loop_delay

    EORA    <tape_input_polarity_previous
    STAA    <tape_input_polarity_previous
    INC     test_stage_sub_2
    BRA     .advance_loop

.input_loop_delay:
    DELAY_SINGLE
    DELAY_SHORT
    DELAY_SHORT

.advance_loop:
    DEX
    BNE     .read_input_loop

    DELAY_SINGLE
    NOP

    RTS


; ==============================================================================
; TEST_TAPE_REMOTE
; ==============================================================================
; DESCRIPTION:
; This test stage essentially just drives the 'remote' output line high.
;
; ==============================================================================
test_tape_remote:                               SUBROUTINE
; Check whether the test has been initialised.
    TST     test_stage_sub
    BEQ     .test_initialised

; Pull the remote line low.
    AIMD    #~PORT_1_TAPE_REMOTE, io_port_1_data

; Print the test stage string.
    LDX     #str_remote
    JSR     test_lcd_set_write_pointer_to_position_7

    LDX     #str_push_1_button
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update

    CLR     test_stage_sub_2

; Mark the test as complete.
    CLR     test_stage_sub
    BRA     .exit

.test_initialised:
    TST     test_stage_sub_2
    BNE     .exit

; Wait for the '1' button to be pressed.
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_1
    BNE     .exit

; Pull the remote line high.
    OIMD    #PORT_1_TAPE_REMOTE, io_port_1_data
    JSR     lcd_clear_line_2

    LDX     #str_test_on
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update

; Mark the test as complete.
    LDAA    #$FF
    STAA    <test_stage_sub_2

.exit:
    RTS
