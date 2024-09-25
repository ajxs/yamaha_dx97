; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; tape/input/single.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Reads a single patch over the synth's cassette interface into the
; synth's edit buffer.
; First the user needs to select which patch number to read using the
; front-panel numeric switches. Then the cassette interface 'reads' each
; incoming patch until the selected one is read.
; @NOTE: Even though the DX9/7 firmware can only receive the first 10 patches
; when receiving a bulk patch dump from the cassette interface, this function
; can receive any individual patch of the 20 patch dump.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TAPE_INPUT_SINGLE
; ==============================================================================
tape_input_single:                              SUBROUTINE
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_dest
    LDX     #str_from_tape_to_buf
    JSR     lcd_strcpy
    JSR     lcd_update

.wait_for_patch_index_selection_loop:
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_NO
    BNE     .is_valid_index_selection

    JMP     tape_exit

.is_valid_index_selection:
; Test whether the selected patch index is valid
; If the code of the button pressed is below '8', loop.
; This ensures that a numerical button was pressed.
    SUBB    #8
    BCS     .wait_for_patch_index_selection_loop

    STAB    tape_input_selected_patch_index

; Print the index of the selected patch.
    LDX     #(lcd_buffer_next + 22)
    STX     <memcpy_ptr_dest
    TBA
    INCA
    JSR     lcd_print_number_three_digits

    LDX     #str_fragment_ready
    JSR     lcd_strcpy
    JSR     lcd_update

    JSR     tape_wait_for_start_input

    JSR     tape_input_reset

.input_patch_loop:
    JSR     tape_input_patch
    TST     tape_function_aborted_flag
    BEQ     .test_checksum

    JMP     tape_exit

.test_checksum:
; Calculate the checksum of the received patch, and compare it against the
; received checksum.
    JSR     tape_calculate_patch_checksum
    SUBD    patch_tape_checksum

    BEQ     .checksum_valid

; Print the error message.
    LDX     #(lcd_buffer_next + 29)
    STX     <memcpy_ptr_dest

    LDX     #str_err
    JSR     lcd_strcpy
    JSR     lcd_update
    BRA     .input_patch_loop

.checksum_valid:
    LDX     #(lcd_buffer_next + 29)
    STX     <memcpy_ptr_dest

; Print the incoming patch number.
    LDAA    patch_tape_counter
    INCA
    JSR     lcd_print_number_three_digits
    JSR     lcd_update

; Test whether the incoming patch is the 'selected' patch.
    LDAA    tape_input_selected_patch_index
    CMPA    patch_tape_counter

; Test whether the selected patch has been missed, if so an error has occurred.
; This will exit the loop in the case that the patch is never found, once the
; 'patch_tape_counter' counter variable reaches a value over the maximum index.
    BCS     .print_error_message

; If not over the selected patch index, and not equal, jump back to receive
; the next patch.
    BNE     .input_patch_loop

; If this point is reached the selected patch has been received.
    JSR     tape_remote_output_low

; Convert the incoming patch from the serialised DX9 format to the DX7 format.
    LDX     #patch_buffer_incoming
    STX     <memcpy_ptr_src

    LDX     #patch_buffer_tape_conversion
    STX     <memcpy_ptr_dest

    JSR     patch_convert_from_dx9_format

; Deserialise the patch into the edit buffer.
    LDX     #patch_buffer_tape_conversion
    STX     <memcpy_ptr_src

    LDX     #patch_buffer_edit
    JSR     patch_deserialise

; Set the patch index to the maximum count, to indicate to the system that
; the loaded patch is not serialised to internal memory.
    LDAA    #PATCH_BUFFER_COUNT
    STAA    patch_index_current

    CLR     patch_current_modified_flag
    CLR     patch_compare_mode_active

; Trigger the 'Play' button press, and reload patch.
    LDAB    #INPUT_BUTTON_PLAY
    JSR     main_input_handler_process_button
    LDAA    #EVENT_HALT_VOICES_RELOAD_PATCH
    STAA    main_patch_event_flag
    CLI
    JMP     midi_sysex_tx_tape_incoming_single_patch

.print_error_message:
    JSR     tape_print_error_and_wait_for_retry

    JMP     tape_input_single
