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
; @CHANGED_FOR_6_OP
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

    JSR     tape_wait_for_start_input

; Initialise the verification process.
    JSR     tape_input_reset

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

    TST     tape_function_aborted_flag
    BEQ     .check_incoming_patch_index

    JMP     tape_exit

.check_incoming_patch_index:
    LDAA    tape_patch_index
    CMPA    patch_tape_counter
    BNE     .print_error_message

    JSR     tape_calculate_patch_checksum
    SUBD    patch_tape_checksum
    BNE     .print_error_message

    JSR     tape_verify_patch
; This flag being set indicates an error condition returned from the
; previous function call. If a received byte was found to be non-equal when
; compared against the current patch, the zero CPU flag will not be set.
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

; Loop for 8 * 0x10000, then exit the tape routines
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

.print_error_message:
    JSR     tape_print_error_and_wait_for_retry

    JMP     tape_verify


; ==============================================================================
; TAPE_VERIFY_PATCH
; ==============================================================================
; @CHANGED_FOR_6_OP
; @PRIVATE
; DESCRIPTION:
; Verifies an individual incoming patch by comparing it against its associated
; index in the patch buffer.
; @NOTE: This will convert the original patch to the DX9 format,
; storing it in a temporary buffer overlaid with the SysEx transmit buffer.
;
; ARGUMENTS:
; Memory:
; * tape_patch_index: The patch index being verified.
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
; Convert the original patch, prior to being output, to the DX9 format,
; and then compare this against what was received. This is done instead of
; converting the result read from tape because the conversion process can be
; destructive in some cases.
; Get the offset of the original unconverted patch.
; Construct this by multiplying the incoming patch number by the patch size,
; then adding the patch buffer offset.
    LDAB    tape_patch_index
    JSR     patch_get_ptr
    STX     <memcpy_ptr_src

    LDX     #patch_buffer_tape_conversion
    STX     <memcpy_ptr_dest

    JSR     patch_convert_to_dx9_format

; Compare the converted original patch, and the contents of the incoming
; patch buffer.
    LDX     #patch_buffer_tape_conversion
    STX     <copy_ptr_src

    LDX     #patch_buffer_incoming
    STX     <copy_ptr_dest

; Setup counter. This is 32 WORDS, since it is comparing against the DX9 format.
    LDAB    #32
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

    DEC     <copy_counter
    BNE     .compare_word_loop

.exit:
    RTS


