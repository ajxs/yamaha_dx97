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
; tape/input.asm
; ==============================================================================
; DESCRIPTION:
; Contains functionality used to input patches over the cassete interface.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TAPE_INPUT_PATCH
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; @TODO
;
; ==============================================================================
tape_input_patch:                               SUBROUTINE
    LDX     #patch_buffer_incoming
    LDAB    #67
    STAB    <tape_byte_counter
    JSR     tape_input_pilot_tone

.input_byte_loop:
    JSR     tape_input_byte
    STAA    0,x
    INX
    DEC     tape_byte_counter
    BNE     .input_byte_loop

    RTS


; ==============================================================================
; TAPE_INPUT_PILOT_TONE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; @TODO
;
; ==============================================================================
tape_input_pilot_tone:                          SUBROUTINE
    PSHA
    PSHB
    PSHX

    LDAA    <io_port_1_data
    ANDA    #PORT_1_TAPE_INPUT
    STAA    <tape_input_polarity_previous

loc_DA48:
    CLR     tape_input_pilot_tone_counter_QQQ

loc_DA4B:
    CLRB
    JSR     tape_input_read_pulse
    CMPB    #12
    BCC     loc_DA48

    CMPB    #4
    BCS     loc_DA48

    INC     tape_input_pilot_tone_counter_QQQ
    BNE     loc_DA4B

    PULX
    PULB
    PULA

    RTS


; ==============================================================================
; TAPE_INPUT_READ_PULSE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; @TODO
;
; ARGUMENTS:
; Registers:
; * ACCB: The number of 'pulses' previously read.
;
; RETURNS:
; * ACCB: The length of the pulse read so far.
;
; ==============================================================================
tape_input_read_pulse:                          SUBROUTINE
; If this line goes high, indicating the 'No' button was pressed, abort.
    TIMD   #KEY_SWITCH_LINE_0_BUTTON_NO, key_switch_scan_driver_input
    BNE     .read_aborted

    INCB

; Read the tape input line on port 1.
    LDAA    <io_port_1_data
    NOP

; Mask the newly read tape input line, and XOR with the previous input to
; test whether the polarity has changed since the last read.
    ANDA    #PORT_1_TAPE_INPUT
    EORA    <tape_input_polarity_previous
    BPL     tape_input_read_pulse

; Use XOR to reset the value to what it was before the previous operation.
    EORA    <tape_input_polarity_previous
    STAA    <tape_input_polarity_previous

    RTS

.read_aborted:
; Set the tape error flag.
    LDAA    #1
    STAA    <tape_error_flag

; Add '8' to the stack to exit the tape read functionality.
    TSX
    LDAB    #8
    ABX
    TXS

    RTS


; ==============================================================================
; TAPE_INPUT_BYTE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; @TODO
;
; ==============================================================================
tape_input_byte:                                SUBROUTINE
    PSHB
    PSHX
    DES

loc_DA80:
    LDAA    <io_port_1_data
    NOP
    ANDA    #PORT_1_TAPE_INPUT
    STAA    <tape_input_polarity_previous
    CLRB
    JSR     tape_input_read_pulse
    CMPB    #13
    BCS     loc_DA80

    LDAA    #29
    STAA    <tape_input_delay_length
    JSR     tape_input_delay
    LDX     #8

loc_DA97:
    JSR     tape_input_read_pulse
    LDAA    #21
    STAA    <tape_input_delay_length
    CLRB
    JSR     tape_input_delay
    JSR     tape_input_read_pulse
    CMPB    #23

; Transfer the CPU condition codes into ACCA.
; XOR with the tape output.
; @TODO: Double check this.
    TPA
    EORA    #1
    TAP

    LDAA    <tape_input_read_byte
    RORA
    STAA    <tape_input_read_byte
    JSR     tape_input_delay_29_cycles_QQQ
    DEX
    BNE     loc_DA97

    LDAA    <tape_input_read_byte
    INS
    PULX
    PULB

    RTS


; ==============================================================================
; ==============================================================================
; ==============================================================================
tape_input_delay_29_cycles_QQQ:                 SUBROUTINE
    LDAA    #29
    STAA    <tape_input_delay_length
; Fall-through below.

; ==============================================================================
; TAPE_INPUT_DELAY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Triggers a delay for an aribtrary specified period.
; This is used in the tape input subroutines.
;
; ARGUMENTS:
; Memory:
; * tape_input_delay_length: The amount of arbitrary 'cycles' to delay for.
;
; ==============================================================================
tape_input_delay:                               SUBROUTINE
    DELAY_SINGLE
    DELAY_SHORT

    NOP
    INCB
    CMPB    <tape_input_delay_length
    BCS     tape_input_delay

    RTS


; ==============================================================================
; TAPE_INPUT_ALL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
;
; ==============================================================================
tape_input_all:                                 SUBROUTINE
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_dest
    LDX     #str_from_tape_to_mem
    JSR     lcd_strcpy
    JSR     lcd_update

loc_EBE8:
    JSR     input_read_front_panel

; Wait for 'Remote' button 10.
    CMPB    #INPUT_BUTTON_10
    BNE     .test_for_no_button

    JMP     loc_EC60

.test_for_no_button:
    CMPB    #INPUT_BUTTON_NO
    BEQ     loc_EBF5

    BRA     loc_EBF8

loc_EBF5:
    JMP     loc_EC94

loc_EBF8:
    CMPB    #INPUT_BUTTON_YES
    BNE     loc_EBE8

    LDAA    memory_protect
    TSTA
    BNE     loc_EC66

    LDX     #(lcd_buffer_next+$1A)
    LDAA    #$14
    LDAB    #6

loc_EC09:
    STAA    0,x
    INX
    DECB
    BNE     loc_EC09

    JSR     lcd_update
    JSR     tape_remote_output_high
    CLR     tape_error_flag
    CLRA
    STAA    tape_patch_index

loc_EC1C:
    LDX     #(lcd_buffer_next+$1D)
    STX     <memcpy_ptr_dest
    INCA
    JSR     lcd_print_number_three_digits
    JSR     lcd_update
    JSR     tape_input_patch
    TST     tape_error_flag
    BNE     loc_EC70

    LDAA    tape_patch_index
    CMPA    tape_patch_output_counter
    BNE     loc_EC99

    JSR     tape_calculate_patch_checksum
    SUBD    tape_patch_checksum
    BNE     loc_EC99

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
    BNE     loc_EC1C

    JSR     tape_remote_output_low
    CLI
    JSR     ui_button_function_memory_select

    LDAB    #0
    JSR     patch_load_store_edit_buffer_to_compare
    JMP     ui_print_update_led_and_menu

loc_EC60:
    JSR     tape_remote_toggle_output_polarity
    JMP     loc_EBE8

loc_EC66:
    CLI
    LDAB    #$1B
    INS
    INS
    INS
    INS
    JMP     main_input_handler_dispatch

loc_EC70:
    JSR     tape_remote_output_low
    LDAA    tape_patch_index
    BEQ     loc_EC94

    LDAA    #20
    STAA    patch_index_current
    LDAA    #EVENT_HALT_VOICES_RELOAD_PATCH
    STAA    main_patch_event_flag
    CLI
    LDAB    #7
    JSR     main_input_handler_dispatch
    LDAB    tape_patch_index
    ADDB    #7
    INS
    INS
    INS
    INS
    JMP     main_input_handler_dispatch

loc_EC94:
    JSR     tape_remote_output_low
    CLI
    RTS

loc_EC99:
    LDX     #(lcd_buffer_next+$10)
    STX     <memcpy_ptr_dest
    LDX     #str_error
    JSR     lcd_strcpy
    JSR     lcd_update
    JSR     tape_remote_output_low

loc_ECAA:
    JSR     input_read_front_panel
    TSTB
    BEQ     loc_ECAA

    JMP     tape_input_all


; ==============================================================================
; TAPE_INPUT_SINGLE
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
tape_input_single:                              SUBROUTINE
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_dest
    LDX     #str_from_tape_to_buf
    JSR     lcd_strcpy
    JSR     lcd_update

.wait_for_input_loop:
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_NO
    BEQ     .no_button_pressed

    BRA     .is_yes_button_down

.no_button_pressed:
    JMP     loc_ED88

.is_yes_button_down:
    CMPB    #INPUT_BUTTON_YES
    BEQ     .yes_button_pressed

    BRA     .is_button_press_valid

.yes_button_pressed:
    JMP     loc_ED63

.is_button_press_valid:
; If '8' is higher than the code of the button pressed, loop.
    SUBB    #8
    BCS     .wait_for_input_loop

    STAB    tape_unknown_byte_15DC

loc_ECDD:
; @TODO: Does this print the number of the patch being input?
    LDX     #(lcd_buffer_next+$16)
    STX     <memcpy_ptr_dest
    TBA
    INCA
    JSR     lcd_print_number_three_digits

    LDX     #str_ready
    JSR     lcd_strcpy
    JSR     lcd_update

loc_ECF0:
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_10
    BEQ     loc_ECF9
    BRA     loc_ECFC

loc_ECF9:
    JMP     loc_ED8D

loc_ECFC:
    CMPB    #2
    BEQ     loc_ED02
    BRA     loc_ED05

loc_ED02:
    JMP     loc_ED88

loc_ED05:
    CMPB    #1
    BNE     loc_ECF0

    LDX     #(lcd_buffer_next+$1A)
    LDAA    #$14
    LDAB    #6

loc_ED10:
    STAA    0,x
    INX
    DECB
    BNE     loc_ED10

    JSR     lcd_update
    JSR     tape_remote_output_high
    CLR     tape_error_flag

loc_ED1F:
    JSR     tape_input_patch
    TST     tape_error_flag
    BNE     loc_ED88

    JSR     tape_calculate_patch_checksum
    SUBD    tape_patch_checksum
    BEQ     loc_ED3F

    LDX     #(lcd_buffer_next+$1D)
    STX     <memcpy_ptr_dest
    LDX     #str_err
    JSR     lcd_strcpy
    JSR     lcd_update
    BRA     loc_ED1F

loc_ED3F:
    LDX     #(lcd_buffer_next+$1D)
    STX     <memcpy_ptr_dest
    LDAA    tape_patch_output_counter
    INCA
    JSR     lcd_print_number_three_digits
    JSR     lcd_update
    LDAA    tape_unknown_byte_15DC
    CMPA    tape_patch_output_counter
    BEQ     loc_ED60

    LDAA    tape_patch_output_counter
    CMPA    tape_unknown_byte_15DC
    BCS     loc_ED1F

    BRA     loc_ED93

loc_ED60:
    JSR     tape_remote_output_low

loc_ED63:
    LDX     #patch_buffer_incoming
    STX     <memcpy_ptr_src
    LDX     #patch_buffer_edit
    JSR     patch_deserialise
    LDAA    #$14
    STAA    patch_index_current
    CLR     patch_current_modified_flag
    CLR     patch_compare_mode_active

; Trigger the 'Memory' button press?
    LDAB    #INPUT_BUTTON_MEMORY
    JSR     main_input_handler_process_button
    LDAA    #EVENT_HALT_VOICES_RELOAD_PATCH
    STAA    main_patch_event_flag
    CLI
    JSR     midi_sysex_tx_tape_incoming_single_patch

    RTS

loc_ED88:
    JSR     tape_remote_output_low
    CLI
    RTS

loc_ED8D:
    JSR     tape_remote_toggle_output_polarity
    JMP     loc_ECF0

loc_ED93:
    LDX     #(lcd_buffer_next+$10)
    STX     <memcpy_ptr_dest
    LDX     #str_error
    JSR     lcd_strcpy
    JSR     lcd_update
    JSR     tape_remote_output_low

loc_EDA4:
    JSR     input_read_front_panel
    TSTB
    BEQ     loc_EDA4
    LDX     #(lcd_buffer_next+$10)
    STX     <memcpy_ptr_dest
    LDX     #str_single
    JSR     lcd_strcpy
    LDAB    tape_unknown_byte_15DC
    JMP     loc_ECDD
