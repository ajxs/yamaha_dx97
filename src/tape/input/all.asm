; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; tape/input/all.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Reads all 20 patches from the cassette interface.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TAPE_INPUT_ALL
; ==============================================================================
tape_input_all:                                 SUBROUTINE
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_dest
    LDX     #str_from_tape_to_mem
    JSR     lcd_strcpy
    JSR     lcd_update

.wait_for_input_loop:
; Read the front panel button input.
    JSR     input_read_front_panel

; Test for button 10 = 'Remote'.
    CMPB    #INPUT_BUTTON_10
    BNE     .test_for_no_button_press

    JMP     .toggle_remote_polarity

.test_for_no_button_press:
; Test for the 'NO' button being pressed, which will cancel the process.
    CMPB    #INPUT_BUTTON_NO
    BNE     .test_for_yes_button_press

    JMP     .exit

.test_for_yes_button_press:
; Test for the 'YES' button being pressed.
; If not, loop back waiting for user input.
    CMPB    #INPUT_BUTTON_YES
    BNE     .wait_for_input_loop

; Test if memory is protected. If so, exit.
    LDAA    memory_protect
    TSTA
    BNE     .exit_memory_protected

    JSR     tape_input_reset

    CLRA
    STAA    tape_patch_index

.receive_patch_loop:
; Print the incoming patch number.
    LDX     #(lcd_buffer_next + 29)
    STX     <memcpy_ptr_dest
    INCA
    JSR     lcd_print_number_three_digits
    JSR     lcd_update

; Read the patch over the cassette interface.
; If an error occurred, exit.
    JSR     tape_input_patch
    TST     tape_error_flag
    BNE     .exit_input_error

    LDAA    tape_patch_index
    CMPA    patch_tape_counter
    BNE     .print_error

; Calculate the checksum of the received patch, compare against the received checksum.
    JSR     tape_calculate_patch_checksum
    SUBD    patch_tape_checksum
    BNE     .print_error

; Set up the source, and destination pointers for patch conversion.
    LDX     #patch_buffer_incoming
    STX     <memcpy_ptr_src

; Ensure the incoming patch index is below, or equal to the number of patches.
; An effect of this is that the patches that 'overflow' the reduced number of
; patches stored will just be stored in the 'incoming' buffer.
    LDAB    tape_patch_index
    CMPB    #PATCH_BUFFER_COUNT
    BCS     .store_destination_pointer

    LDAB    #PATCH_BUFFER_COUNT

.store_destination_pointer:
    JSR     patch_get_ptr
    STX     <memcpy_ptr_dest

; Convert the patch from the serialised DX9 format to the DX7 format.
    JSR     patch_convert_from_dx9_format

    LDAA    tape_patch_index
    INCA
    STAA    tape_patch_index
    CMPA    #20
    BNE     .receive_patch_loop

    JSR     tape_remote_output_low
    CLI
    JSR     ui_button_function_play

    LDAB    #0
    JSR     patch_load_store_edit_buffer_to_compare
    JMP     ui_print_update_led_and_menu

.toggle_remote_polarity:
    JSR     tape_remote_toggle_output_polarity
    JMP     .wait_for_input_loop

.exit_memory_protected:
    CLI

; Trigger the front-panel button press for 'Memory Protect', and exit.
    LDAB    #INPUT_BUTTON_20
    INS
    INS
    INS
    INS
    JMP     main_input_handler_dispatch

.exit_input_error:
    JSR     tape_remote_output_low
    LDAA    tape_patch_index
    BEQ     .exit

    LDAA    #20
    STAA    patch_index_current

    LDAA    #EVENT_HALT_VOICES_RELOAD_PATCH
    STAA    main_patch_event_flag

    CLI

; Set the synth's UI to 'Play' mode, and trigger the front-panel button press
; for the last received patch index.
    LDAB    #INPUT_BUTTON_PLAY
    JSR     main_input_handler_dispatch

; Adding '7' to this number converts it to a numeric button index.
; This will trigger a button-press for that patch selection.
; If this is above the maximum supported patch index, nothing should happen.
    LDAB    tape_patch_index
    ADDB    #7
    INS
    INS
    INS
    INS
    JMP     main_input_handler_dispatch

.exit:
    JSR     tape_remote_output_low
    CLI
    RTS

.print_error:
    JSR     tape_print_error_and_wait_for_retry

    JMP     tape_input_all
