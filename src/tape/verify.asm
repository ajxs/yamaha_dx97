; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; tape/verify.asm
; ==============================================================================
; DESCRIPTION:
; Contains functionality related to verifying data sent, and received over the
; synth's cassette interface.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TAPE_VERIFY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Reads all 10 patches from the cassette interface, verifying each one as it is
; input. An error message will be printed in the case that verification fails.
;
; ==============================================================================
tape_verify:                                    SUBROUTINE
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_dest
    LDX     #str_verify_tape
    JSR     lcd_strcpy
    JSR     lcd_update

; Loop while waiting for user input.
; If the 'REMOTE' front-panel button is pressed, toggle the remote port
; polarity to start/stop tape playback.
; If the 'YES' key is pressed, start the verification process.
; If the 'NO' key is pressed, cancel the process.
.wait_for_user_input:
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_10
    BEQ     .remote_button_pressed

    BRA     .was_no_button_pressed

.remote_button_pressed:
    JMP     .toggle_remote_output_polarity

.was_no_button_pressed:
    CMPB    #INPUT_BUTTON_NO
    BNE     .was_yes_button_pressed
    JMP     .cancel_and_exit

.was_yes_button_pressed:
    CMPB    #INPUT_BUTTON_YES
    BNE     .wait_for_user_input

; Initialise the verification process.
; Clear a space in the LCD buffer with 0x14 (@TODO: Verify?)
; Pull the tape remote output high, clear any tape error flags, and clear
; the verify patch index.
    LDX     #(lcd_buffer_next + 26)
    LDAA    #$14
    LDAB    #6

.clear_lcd_loop:
    STAA    0,x
    INX
    DECB
    BNE     .clear_lcd_loop

    JSR     lcd_update
    JSR     tape_remote_output_high
    CLR     tape_error_flag
    CLRA
    STAA    tape_patch_index

; Verify an individual patch.
; Start by printing the patch number.
.verify_patch_loop:
    LDX     #(lcd_buffer_next + 29)
    STX     <memcpy_ptr_dest
    INCA
    JSR     lcd_print_number_three_digits
    JSR     lcd_update
    JSR     tape_input_patch

    TST     tape_error_flag
    BNE     .cancel_and_exit

    LDAA    tape_patch_index
    CMPA    patch_tape_counter
    BNE     .print_error_message

    JSR     tape_calculate_patch_checksum
    SUBD    patch_tape_checksum
    BNE     .print_error_message

; This flag being set indicates an error condition returned from the
; previous function call. If a received byte was found to be non-equal when
; compared against the current patch, the zero CPU flag will not be set.
    JSR     tape_verify_patch
    BNE     .print_error_message

    LDAA    tape_patch_index
    INCA
    STAA    tape_patch_index
    CMPA    #PATCH_BUFFER_COUNT
    BNE     .verify_patch_loop

; Print the 'Ok' string to line 2.
    LDX     #lcd_buffer_next_line_2
    STX     <memcpy_ptr_dest
    LDX     #str_ok
    JSR     lcd_strcpy
    JSR     lcd_update

; Loop for 8 * 0xFFFF, then exit the tape routines
    JSR     tape_remote_output_low
    LDAB    #8
    LDX     #0

.delay_loop:
    DEX
    BNE     .delay_loop

    DECB
    BNE     .delay_loop

; Print the verification complete message.
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_dest

    LDX     #str_function_control
    JSR     lcd_strcpy

    LDX     #lcd_buffer_next_line_2
    STX     <memcpy_ptr_dest

    LDX     #str_verify_complete
    JSR     lcd_strcpy

    JSR     lcd_update

; Exit to the main menu.
    CLI
    INS
    INS
    INS
    INS
    JMP     led_print_patch_number

.cancel_and_exit:
    JSR     tape_remote_output_low
    CLI
    RTS

.toggle_remote_output_polarity:
    JSR     tape_remote_toggle_output_polarity
    JMP     .wait_for_user_input

.print_error_message:
    LDX     #lcd_buffer_next_line_2
    STX     <memcpy_ptr_dest

    LDX     #str_error
    JSR     lcd_strcpy
    JSR     lcd_update
    JSR     tape_remote_output_low

; Loop while waiting for user input.
; Any button press will exit, and proceed to the verification routine.
.wait_for_input_loop:
    JSR     input_read_front_panel
    TSTB
    BEQ     .wait_for_input_loop

    JMP     tape_verify


; ==============================================================================
; TAPE_VERIFY_PATCH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Verifies an individual incoming patch by comparing it against its associated
; index in the patch buffer.
; @NOTE: This will automatically convert the incoming patch to the DX7 format,
; storing it in a temporary buffer overlaid with the SysEx transmit buffer.
;
; ARGUMENTS:
; Memory:
; * patch_tape_counter: The patch index being verified.
;
; MEMORY MODIFIED:
; * copy_counter
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * The CPU flags indicate the result of the verification process.
;   The zero flag will indicate whether any byte being verified differed.
;
; ==============================================================================
tape_verify_patch:                              SUBROUTINE
; Convert the patch from the serialised DX9 format to the DX7 format.
    LDX     #patch_buffer_incoming
    STX     <copy_ptr_src
    LDX     #patch_buffer_tape_conversion
    STX     <memcpy_ptr_dest
    JSR     patch_convert_from_dx9_format

; Set the converted patch as a source for the verification operation.
    LDX     #patch_buffer_tape_conversion
    STX     <copy_ptr_src

; Setup destination pointer.
; Construct this by multiplying the incoming patch number by the patch size,
; then adding the patch buffer offset.
    LDAA    patch_tape_counter
    LDAB    #PATCH_SIZE_PACKED_DX7
    MUL
    ADDD    #patch_buffer
    STD     <copy_ptr_dest

; Setup counter. This is 64 WORDS, since it is comparing against the DX7 format.
    LDAB    #64
    STAB    <copy_counter

.compare_word_loop:
; Load the source word.
    LDX     <copy_ptr_src
    LDD     0,x
    INX
    INX
    STX     <copy_ptr_src

; Subtract the word at the destination from the source.
; If this is different, exit.
; The CPU flags after return will indicate the result of this comparison.
    LDX     <copy_ptr_dest
    SUBD    0,x
    BNE     .exit

    INX
    INX
    STX     <copy_ptr_dest
    DEC     copy_counter

    BNE     .compare_word_loop

.exit:
    RTS


