; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; test/kbd.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the keyboard diagnostic test routine.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_KBD
; ==============================================================================
; DESCRIPTION:
; Diagnostic routine that tests whether each individual key on the keyboard is
; functioning correctly.
;
; MEMORY MODIFIED:
; * test_stage_sub
; * test_stage_sub_2
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
test_kbd:                                       SUBROUTINE
    LDAA    <test_stage_sub
    BEQ     .is_test_finished

    CMPA    #$FF
    BEQ     .initialise_test

    JMP     .delay_and_exit

.initialise_test:
    JSR     patch_init_edit_buffer
    JSR     patch_activate
    CLR     test_stage_sub_2
    LDX     #str_kbd
    JSR     test_lcd_set_write_pointer_to_position_7
    JSR     lcd_update
    CLR     test_stage_sub

.is_test_finished:
    LDAA    <test_stage_sub_2
    CMPA    #61
    BEQ     .test_finished

    BCS     .scan_for_key_down

    CMPA    #$FE
    BEQ     .scan_for_key_up

    BRA     .exit

.scan_for_key_down:
    JSR     keyboard_scan
    LDAB    <note_number

; Is this a key up event?
    BPL     .key_up

; Was no key pressed?
    CMPB    #$FF
    BEQ     .exit

; Mask the note number, and add a new voice.
    ANDB    #$7F
    JSR     voice_add

; Subtract 36 from the note number, and compare against the expected note.
    LDAB    <note_number
    ANDB    #$7F
    SUBB    #36
    CMPB    <test_stage_sub_2
    BNE     .print_error_message

; Print the note number to the LEDs.
    TBA
    INCA
    JSR     test_print_number_to_led
    JSR     lcd_clear_line_2
    JSR     lcd_update
    INC     test_stage_sub_2

.exit:
    RTS

.key_up:
    JSR     voice_remove
    BRA     .exit

.test_finished:
    LDAA    #$FE
    STAA    <test_stage_sub_2

    LDX     #str_ok
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    BRA     .exit

.scan_for_key_up:
    JSR     keyboard_scan
    LDAB    <note_number
    BMI     .exit

; Remove the newly added voice from the key-press.
    JSR     voice_remove
    BRA     .exit

.print_error_message:
    TBA
    INCA
    JSR     test_print_number_to_led
    LDX     #str_test_err
    JSR     test_lcd_set_write_pointer_to_line_2
    LDX     <memcpy_ptr_dest
    INX
    STX     <memcpy_ptr_dest

    LDAB    <test_stage_sub_2
    JSR     test_kbd_print_note_name
    JSR     lcd_update

    LDAA    #$FE
    STAA    <test_stage_sub

.delay_and_exit:
    LDX     #$80

.delay_loop:
    JSR     delay
    DEX
    BNE     .delay_loop

    DEC     test_stage_sub
    BRA     .exit


; ==============================================================================
; TEST_KBD_PRINT_NOTE_NAME
; ==============================================================================
; DESCRIPTION:
; Prints the note name, and octave to the LCD screen.
;
; ARGUMENTS:
; Registers:
; * ACCB: The note number to be printed.
;
; ==============================================================================
test_kbd_print_note_name:                       SUBROUTINE
    LDX     <memcpy_ptr_dest

; Load ASCII '0'.
    LDAA    #48

.get_octave_number_loop:
; Subtract 12 from the note name with each iteration, incrementing ACCA.
; When the carry bit is set, the octave will have been found.
    INCA
    SUBB    #12
    BCC     .get_octave_number_loop

; Write the ASCII octave number to the LCD buffer.
    STAA    2,x

; Add '12' back to ACCB to compensate for the final subtraction.
    ADDB    #12

; Use the remaining number in ACCB as an index into the note name string.
    LDX     #str_note_names
    ASLB
    ABX
    LDD     0,x
    LDX     <memcpy_ptr_dest
    STD     0,x
    INX
    INX
    INX
    STX     <memcpy_ptr_dest

    RTS
