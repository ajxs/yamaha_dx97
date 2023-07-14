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
; tape/input/single.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Reads a single patch over the synth's cassette interface into the
; synth's edit buffer.
; First the user needs to select which patch number to read using the
; front-panel numeric switches. Then the cassette interface 'reads' each
; incoming patch until the selected one is read.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TAPE_INPUT_SINGLE
; ==============================================================================
tape_input_single:                              SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.tape_input_selected_patch:                     EQU #temp_variables

; ==============================================================================
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_dest
    LDX     #str_from_tape_to_buf
    JSR     lcd_strcpy
    JSR     lcd_update

.wait_for_input_loop:
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_NO
    BEQ     .no_button_pressed

    BRA     .is_yes_button_pressed

.no_button_pressed:
    JMP     .exit_abort

.is_yes_button_pressed:
    CMPB    #INPUT_BUTTON_YES
    BEQ     .yes_button_pressed

    BRA     .is_incoming_patch_index_valid

.yes_button_pressed:
    JMP     .load_incoming_patch_to_edit_buffer

.is_incoming_patch_index_valid:
; Test whether the selected patch index is valid
; If '8' is higher than the code of the button pressed, loop.
    SUBB    #8
    BCS     .wait_for_input_loop

    STAB    .tape_input_selected_patch

.begin_input_process:
; Print the index of the selected patch.
    LDX     #(lcd_buffer_next + 22)
    STX     <memcpy_ptr_dest
    TBA
    INCA
    JSR     lcd_print_number_three_digits

    LDX     #str_ready
    JSR     lcd_strcpy
    JSR     lcd_update

.wait_for_input_loop_2:
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_10
    BEQ     .button_10_pressed

    BRA     .is_no_button_pressed

.button_10_pressed:
    JMP     .toggle_remote_polarity

.is_no_button_pressed:
    CMPB    #INPUT_BUTTON_NO
    BEQ     .no_button_pressed_abort

    BRA     .is_yes_button_pressed_2

.no_button_pressed_abort:
    JMP     .exit_abort

.is_yes_button_pressed_2:
    CMPB    #INPUT_BUTTON_YES
    BNE     .wait_for_input_loop_2

; @TODO: Understand why the LCD is cleared with 0x14.
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

.input_patch_loop:
    JSR     tape_input_patch
    TST     tape_error_flag
    BNE     .exit_abort

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
    LDAA    patch_tape_counter
    INCA
    JSR     lcd_print_number_three_digits
    JSR     lcd_update

; Test whether the current patch is the 'selected' patch.
    LDAA    .tape_input_selected_patch
    CMPA    patch_tape_counter
    BEQ     .finished_reading_selected_patch

; Test whether the selected patch has been missed, if so an error has occurred.
    LDAA    patch_tape_counter
    CMPA    .tape_input_selected_patch
    BCS     .input_patch_loop

    BRA     .print_error

.finished_reading_selected_patch:
    JSR     tape_remote_output_low

.load_incoming_patch_to_edit_buffer:
; Convert the patch from the serialised DX9 format to the DX7 format.
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

.exit_abort:
    JSR     tape_remote_output_low
    CLI
    RTS

.toggle_remote_polarity:
    JSR     tape_remote_toggle_output_polarity
    JMP     .wait_for_input_loop_2

.print_error:
    LDX     #lcd_buffer_next_line_2
    STX     <memcpy_ptr_dest
    LDX     #str_error
    JSR     lcd_strcpy
    JSR     lcd_update
    JSR     tape_remote_output_low

.wait_for_input_and_retry:
    JSR     input_read_front_panel
    TSTB
    BEQ     .wait_for_input_and_retry

    LDX     #lcd_buffer_next_line_2
    STX     <memcpy_ptr_dest
    LDX     #str_single
    JSR     lcd_strcpy

    LDAB    .tape_input_selected_patch
    JMP     .begin_input_process
