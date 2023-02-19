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
; DESCRIPTION:
; This file contains the subroutines related to the synth's front-panel switch
; diagnostic testing.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_SWITCH
; ==============================================================================
; DESCRIPTION:
; @TODO
; ==============================================================================
test_switch:                                    SUBROUTINE
    LDAA    <test_stage_sub
    BEQ     loc_F916

; Delay?
    CMPA    #$FF
    BEQ     loc_F904

    JMP     loc_F9C7

loc_F904:
    LDX     #str_sw
    JSR     test_lcd_set_write_pointer_to_position_7
    LDX     #str_push
    JSR     test_lcd_set_write_pointer_to_line_2
    CLR     test_stage_sub_2
    CLR     test_stage_sub

loc_F916:
    LDAA    <test_stage_sub_2
    CMPA    #26
    BNE     loc_F91F

    JMP     loc_F9A3

; If 26 or above, return.

loc_F91F:
    BCC     .exit

; Clear LCD space.
; Print next switch to test...
    LDAA    #32
    LDX     #lcd_buffer_next_end

.clear_lcd_space_loop:
    DEX
    STAA    0,x
    CPX     #(lcd_buffer_next + $15)
    BNE     .clear_lcd_space_loop

    STX     <memcpy_ptr_dest
    LDAA    <test_stage_sub_2
    CMPA    #20

; If ACCA >= 20.
    BCC     loc_F945

; 0 - 19...
; Print numbers?
    LDAB    #'#
    JSR     lcd_store_character_and_increment_ptr
    CLRB
    INCA
    JSR     lcd_print_number_two_digits

loc_F940:
    JSR     lcd_update
    BRA     loc_F954

; 20 - 25
; Print button names.

loc_F945:
    SUBA    #20
    LDX     #table_str_pointer_test_switches_stage
    TAB
    ASLB
    ABX
    LDX     0,x
    JSR     lcd_strcpy
    BRA     loc_F940

loc_F954:
    LDAA    <test_stage_sub_2
    CMPA    #24

; If ACCA >= 24.
    BCC     loc_F98D

    JSR     input_read_front_panel
    JSR     jumpoff

    DC.B .exit - *
    DC.B 3
    DC.B test_switch_btn_store - *
    DC.B 4
    DC.B .exit - *
    DC.B 5
    DC.B test_switch_btn_main - *
    DC.B 8
    DC.B test_switch_store_btn_numeric - *
    DC.B 0

.exit:
    RTS

; ==============================================================================
; @TODO
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
test_switch_btn_store:                          SUBROUTINE
    LDAB    #20
    BRA     loc_F974


; ==============================================================================
; @TODO
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
test_switch_btn_main:                           SUBROUTINE
    ADDB    #16
    BRA     loc_F974


; ==============================================================================
; @TODO
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
test_switch_store_btn_numeric:                  SUBROUTINE
    SUBB    #8

loc_F974:
    CMPB    <test_stage_sub_2
    BNE     test_switches_error_F9B5

loc_F978:
    TBA
    INCA
    JSR     test_print_number_to_led
    LDX     #str_push ; "push"
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    INC     test_stage_sub_2
    JSR     pedals_update

_test_switches_exit:
    RTS

; 24 = Test whether sustain pedal is active.
; 25 = Test portamento pedal.

; ==============================================================================
; @TODO
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
loc_F98D:
    JSR     pedals_update
    CMPB    #1

; The carry being set indicates that a 0 result has been returned,
; indicating no pedal. So return and loop to wait.
    BCS     _test_switches_exit
    BHI     loc_F99B

    TIMD   #PEDAL_INPUT_SUSTAIN, pedal_status_current
    BEQ     _test_switches_exit

; Add 23 to ACCB, since the portamento pedal, and sustain pedal tests are
; test stages 24, and 25.

loc_F99B:
    ADDB    #23
    CMPB    <test_stage_sub_2
    BNE     test_switches_error_F9B5

    BRA     loc_F978

loc_F9A3:
    LDAA    #$FE
    STAA    <test_stage_sub_2
    JSR     lcd_clear_line_2
    LDX     #str_ok ; "OK!"
    JSR     lcd_strcpy
    JSR     lcd_update
    BRA     _test_switches_exit

test_switches_error_F9B5:
    TBA
    INCA
    JSR     test_print_number_to_led
    LDX     #str_test_err ; "ERR!"
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    LDAA    #$FE
    STAA    <test_stage_sub

loc_F9C7:
    LDX     #128

.delay_loop:
    JSR     delay
    DEX
    BNE     .delay_loop

    DEC     test_stage_sub
    BRA     _test_switches_exit

table_str_pointer_test_switches_stage:
    DC.W str_fragment_store
    DC.W str_function
    DC.W str_edit
    DC.W str_fragment_memory
    DC.W str_sustain
    DC.W str_portamento
