; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; tape/tape.asm
; ==============================================================================
; DESCRIPTION:
; Contains functionality related to the synth's cassette interface.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TAPE_CALCULATE_PATCH_CHECKSUM
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Calculates the checksum for an individual patch before it is output over the
; synth's cassette interface.
;
; MEMORY MODIFIED:
; * copy_counter
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCD: The calculated checksum for the patch
;
; ==============================================================================
tape_calculate_patch_checksum:                  SUBROUTINE
    LDX     #patch_buffer_incoming
    LDAB    #65
    STAB    <copy_counter
    CLRA
    CLRB

.calculate_checksum_loop:
    ADDB    0,x
; If the result of the previous addition to ACCB overflowed, add the carry bit
; to ACCA to expand the value into ACCD.
    ADCA    #0
    INX
    DEC     copy_counter
    BNE     .calculate_checksum_loop

    RTS


; ==============================================================================
; TAPE_REMOTE_TOGGLE_OUTPUT_POLARITY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Toggles the polarity of the tape 'remote' output port.
;
; ==============================================================================
tape_remote_toggle_output_polarity:             SUBROUTINE
    LDAA    tape_remote_output_polarity
    EORA    #1
    STAA    tape_remote_output_polarity
; Falls-through below to output signal.

; ==============================================================================
; TAPE_REMOTE_OUTPUT_SIGNAL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDACF
; DESCRIPTION:
; Sets the tape 'remote' output port's polarity to either high, or low, based
; upon the remote port polarity global variable.
;
; ARGUMENTS:
; Memory:
; * tape_remote_output_polarity: The tape polarity to set.
;
; ==============================================================================
tape_remote_output_signal:                      SUBROUTINE
    LDAA    tape_remote_output_polarity
    BEQ     tape_remote_output_low_signal

    BRA     tape_remote_output_high_signal


; ==============================================================================
; TAPE_REMOTE_OUTPUT_HIGH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDAD6
; DESCRIPTION:
; Sets the tape 'remote' output port's polarity to 'HIGH'.
;
; ==============================================================================
tape_remote_output_high:                        SUBROUTINE
    LDAA    #1
    STAA    tape_remote_output_polarity
; falls-through below.

tape_remote_output_high_signal:
    OIMD    #PORT_1_TAPE_REMOTE, io_port_1_data
    RTS


; ==============================================================================
; TAPE_REMOTE_OUTPUT_LOW
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDADF
; DESCRIPTION:
; Sets the tape 'remote' output port's polarity to 'LOW'.
;
; ==============================================================================
tape_remote_output_low:                         SUBROUTINE
    CLRA
    STAA    tape_remote_output_polarity
; falls-through below.

tape_remote_output_low_signal:
    AIMD    #~PORT_1_TAPE_REMOTE, io_port_1_data
    RTS


; ==============================================================================
; TAPE_UI_JUMPOFF
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Initiates the tape-related function specified by the last keypress.
; This subroutine is initiated by pressing the 'Yes' front-panel switch to
; confirm a prompt raised by pressing the tape-related keys in function mode.
; Note: This function masks all interrupts.
;
; ==============================================================================
tape_ui_jumpoff:                                SUBROUTINE
    SEI
    JSR     midi_reset

; Disable LED output.
    LDAA    #$FF
    STAA    <led_1
    STAA    <led_2

; Set the tape remote port output to low, to avoid triggering any tape
; actions prematurely.
    JSR     tape_remote_output_low

; Call the appropriate tape-function based on the last keypress.
    LDAB    ui_btn_numeric_last_pressed
    JSR     jumpoff

; The numbers here correspond to the function mode numeric button codes.
; i.e: 27 corresponds to the code for function mode button 7 (+1).
    DC.B tape_output_all_jump - *
    DC.B 27
    DC.B tape_input_all_jump - *
    DC.B 28
    DC.B tape_input_single_jump - *
    DC.B 29
    DC.B tape_exit_jump - *
    DC.B 0

; ==============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main tape UI jumpoff.
; ==============================================================================
tape_output_all_jump:
    JMP     tape_output_all

; ==============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main tape UI jumpoff.
; ==============================================================================
tape_input_all_jump:
    JMP     tape_input_all

; ==============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main tape UI jumpoff.
; ==============================================================================
tape_input_single_jump:
    JMP     tape_input_single

; ==============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main tape UI jumpoff.
; ==============================================================================
tape_exit_jump:
    JMP     tape_exit


; ==============================================================================
; TAPE_INPUT_RESET
; ==============================================================================
; DESCRIPTION:
; This utility routine pulls the remote output high, clears space in the LCD,
; and clears the 'Tape function aborted' flag. This was adapted from the
; common code called prior to all of the cassette interface input functions in
; the original DX9 ROM.
;
; ==============================================================================
tape_input_reset:                               SUBROUTINE
; Clear the last 6 spaces in the LCD buffer.
    LDX     #(lcd_buffer_next + 26)
    LDAA    #'
    LDAB    #6

.clear_lcd_loop:
    STAA    0,x
    INX
    DECB
    BNE     .clear_lcd_loop

    JSR     lcd_update
    JSR     tape_remote_output_high

    CLR     tape_function_aborted_flag

    RTS


; ==============================================================================
; TAPE_PRINT_ERROR_AND_WAIT_FOR_RETRY
; ==============================================================================
; DESCRIPTION:
; This routine is called when any of the cassette interface routines
; encounter an error state. It prints an error message string to the LCD, and
; then polls the user for input to proceed.
; This has been adapted from the wait loop that appears at 0xEBD1 in the
; DX9 ROM, among other places.
;
; ==============================================================================
tape_print_error_and_wait_for_retry:            SUBROUTINE
    LDX     #lcd_buffer_next_line_2
    STX     <memcpy_ptr_dest

    LDX     #str_error
    JSR     lcd_strcpy
    JSR     lcd_update

    JSR     tape_remote_output_low
; Falls-through below.

tape_wait_for_input_and_retry:                  SUBROUTINE
    JSR     input_read_front_panel
    TSTB
    BEQ     tape_wait_for_input_and_retry

    RTS


; ==============================================================================
; TAPE_EXIT
; ==============================================================================
; DESCRIPTION:
; Exits the tape function user-interface.
; This re-enables interrupts and sets the tape output low.
;
; ==============================================================================
tape_exit:                                      SUBROUTINE
    JSR     tape_remote_output_low
    CLI
    RTS


; ==============================================================================
; TAPE_WAIT_FOR_START_INPUT
; ==============================================================================
; DESCRIPTION:
; All of the cassette interface UI functions have a common interface.
; This function processes this user input. It checks for either the 'Remote',
; button being pressed, which toggles the remote port polarity, the 'Yes'
; button being pressed which causes the function to proceed, or the 'No' button
; which will exit the tape UI function.
; ==============================================================================
tape_wait_for_start_input:                      SUBROUTINE
; Read front-panel input to determine the next action.
; If 'No' is pressed, the tape UI actions are aborted.
; If 'Yes' is pressed, the operation proceeds.
; If the 'Remote' button is pressed, toggle the remote output polarity,
; and loop back to wait for further input.
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_10
    BNE     .is_no_button_pressed

    JSR     tape_remote_toggle_output_polarity
    BRA     tape_wait_for_start_input

.is_no_button_pressed:
    CMPB    #INPUT_BUTTON_NO
    BNE     .is_yes_button_pressed

    JMP     tape_exit

.is_yes_button_pressed:
    CMPB    #INPUT_BUTTON_YES
    BNE     tape_wait_for_start_input

    RTS
