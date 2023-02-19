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
; test/ram.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the diagnostic testing routines for the synth's RAM.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_RAM
; ==============================================================================
; DESCRIPTION:
; @TODO
; ==============================================================================
test_ram:                                       SUBROUTINE
    LDAB    <test_stage_sub
    JSR     jumpoff

    DC.B .exit - *
    DC.B 1
    DC.B test_ram_stage_1_wait_for_button - *
    DC.B 2
    DC.B test_ram_stage_2 - *
    DC.B 3
    DC.B test_ram_stage_3 - *
    DC.B 4
    DC.B test_ram_init - *
    DC.B 0

.exit:
    RTS


; ==============================================================================
; TEST_RAM_INIT
; ==============================================================================
; DESCRIPTION:
; @TODO
; Sets the test sub stage to '1'.
;
; ==============================================================================
test_ram_init:                                  SUBROUTINE
    LDX     #(str_error_ram + 6)
    JSR     test_lcd_set_write_pointer_to_position_7
    LDX     #str_push_1_button
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    CLR     test_stage_sub_2

    LDAB    #1
    STAB    <test_stage_sub

    RTS


; ==============================================================================
; @TODO
; ==============================================================================
; DESCRIPTION:
; @TODO
; Is this waiting for a button press?
; ==============================================================================
test_ram_stage_1_wait_for_button:               SUBROUTINE
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_1
    BNE     .exit

    LDAB    #2
    STAB    <test_stage_sub

.exit:
    RTS


; ==============================================================================
; @TODO
; ==============================================================================
; DESCRIPTION:
; @TODO
; ==============================================================================
test_ram_stage_2:                               SUBROUTINE
    JSR     lcd_clear_line_2
    LDX     #str_under_test
    JSR     lcd_strcpy
    JSR     lcd_update

; Clear all RAM?
; RAM start.
    LDX     #external_ram_start
    CLRA
    CLRB

loc_FC68:
    STD     0,x
    INX
    INX
    CPX     #$1000
    BNE     loc_FC68

    LDX     #$800
    LDAA    #$55 ; 'U'

loc_FC76:
    CMPB    0,x
    BNE     loc_FC99

    STAA    0,x
    CMPA    0,x
    BNE     loc_FC99

    INX
    CPX     #$1000
    BNE     loc_FC76

    LDX     #$800
    LDAA    #$AA

loc_FC8B:
    STAA    0,x
    CMPA    0,x
    BNE     loc_FC99

    INX
    CPX     #$1000
    BNE     loc_FC8B

    BRA     loc_FC9D

loc_FC99:
    LDAA    #1
    STAA    <test_stage_sub_2

loc_FC9D:
    LDX     #$1000

loc_FCA0:
    LDD     0,x
    XGDX
    SUBD    #2048
    XGDX
    STD     0,x
    XGDX
    ADDD    #2050
    XGDX
    CPX     #$17A0
    BNE     loc_FCA0

    LDX     #$1000
    CLRA
    CLRB

loc_DC.B8:
    STD     0,x
    INX
    INX
    CPX     #$17A0
    BNE     loc_DC.B8

    LDX     #$1000
    LDAA    #$55 ; 'U'

loc_DC6:
    CMPB    0,x
    BNE     loc_FCE9

    STAA    0,x
    CMPA    0,x
    BNE     loc_FCE9

    INX
    CPX     #$17A0
    BNE     loc_DC6

    LDX     #$1000
    LDAA    #$AA

loc_FCDB:
    STAA    0,x
    CMPA    0,x
    BNE     loc_FCE9

    INX
    CPX     #$17A0
    BNE     loc_FCDB

    BRA     loc_FCED

loc_FCE9:
    LDAA    #2
    ORAA    <test_stage_sub_2

loc_FCED:
    LDX     #$800

loc_FCF0:
    LDD     0,x
    XGDX
    ADDD    #$800
    XGDX
    STD     0,x
    XGDX
    SUBD    #$7FE
    XGDX
    CPX     #$1000
    BNE     loc_FCF0

    LDAB    #3
    STAB    <test_stage_sub

    RTS


; ==============================================================================
; @TODO
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
test_ram_stage_3:                               SUBROUTINE
    JSR     lcd_clear_line_2
    LDAA    <test_stage_sub_2
    ANDA    #3
    BEQ     loc_FD30

    LDX     #str_error_ram ; "ERROR RAM"
    JSR     lcd_strcpy
    LDAA    <test_stage_sub_2
    ANDA    #1
    BEQ     loc_FD20

    JSR     lcd_print_number_single_digit

loc_FD20:
    LDAA    <test_stage_sub_2
    ANDA    #2
    BEQ     loc_FD29

    JSR     lcd_print_number_single_digit

loc_FD29:
    JSR     lcd_update
    CLRB
    STAB    <test_stage_sub

    RTS

loc_FD30:
    LDX     #str_ok ; "OK!"
    JSR     lcd_strcpy
    BRA     loc_FD29
