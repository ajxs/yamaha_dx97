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
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Tests the synth's internal RAM to diagnose any errors.
;
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
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Sets the test sub stage to '1', and prints the diagnostic test title.
;
; ==============================================================================
test_ram_init:                                  SUBROUTINE
    LDX     #(str_error_ram + 6)
    JSR     test_lcd_set_write_pointer_to_position_7
    LDX     #str_push_1_button
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update

; This variable is used to store the test result.
    CLR     test_stage_sub_2

    LDAB    #1
    STAB    <test_stage_sub

    RTS


; ==============================================================================
; TEST_RAM_STAGE_1_WAIT_FOR_BUTTON
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Waits for the user to press the '1' button to initiate the test.
;
; ==============================================================================
test_ram_stage_1_wait_for_button:               SUBROUTINE
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_1
    BNE     .exit

    LDAB    #2
    STAB    <test_stage_sub

.exit:
    RTS


RAM_TEST_END_ADDRESS:                           EQU $1800

; ==============================================================================
; TEST_RAM_STAGE_2
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; This stage performs the actual RAM tests.
; It tests writing the preset bit patterns 0xAA, and 0x55 to the first 2Kb of
; external RAM. It then backs up the higher 2Kb of RAM, and performs the same
; tests there, before restoring it.
; Refer to: https://stackoverflow.com/a/43924054/5931673
; Unlike the original RAM tests, which preserve the voice buffers, this
; has been changed to perform the tests across the full range of memory.
; This has been done because the stack now occupies the highest addresses in
; RAM, like in the DX7. The tests need to include this region to back up the
; stack to avoid clobbering it, and causing a crash.
; ==============================================================================
test_ram_stage_2:                               SUBROUTINE
    JSR     lcd_clear_line_2
    LDX     #str_under_test
    JSR     lcd_strcpy
    JSR     lcd_update

; Clear the first 2Kb of RAM.
    LDX     #external_ram_start
    CLRA
    CLRB
.clear_ram_loop:
    STD     0,x
    INX
    INX
    CPX     #$1000
    BNE     .clear_ram_loop

; Write 0x55 to the first 2Kb of RAM.
    LDX     #external_ram_start
    LDAA    #$55
.write_test_1_loop:
    CMPB    0,x
    BNE     .test_error_low_address

    STAA    0,x
    CMPA    0,x
    BNE     .test_error_low_address

    INX
    CPX     #$1000
    BNE     .write_test_1_loop

; Write 0xAA to the first 2Kb of RAM.
    LDX     #external_ram_start
    LDAA    #$AA
.write_test_2_loop:
    STAA    0,x
    CMPA    0,x
    BNE     .test_error_low_address

    INX
    CPX     #$1000
    BNE     .write_test_2_loop

    BRA     .backup_high_ram

.test_error_low_address:
    LDAA    #1
    STAA    <test_stage_sub_2

.backup_high_ram:
; The following section copies all RAM from 0x1000-0x1800 to 0x800-0x1000.
    LDX     #$1000

.copy_ram_loop_1:
    LDD     0,x
    XGDX
    SUBD    #$800
    XGDX
    STD     0,x
    XGDX
    ADDD    #$802
    XGDX
    CPX     #RAM_TEST_END_ADDRESS
    BNE     .copy_ram_loop_1

; This section clears all RAM from 0x1000 to 0x1800.
    LDX     #$1000
    CLRA
    CLRB
.clear_high_ram_loop:
    STD     0,x
    INX
    INX
    CPX     #RAM_TEST_END_ADDRESS
    BNE     .clear_high_ram_loop

; The following section writes 0x55 to the first byte in each word.
    LDX     #$1000
    LDAA    #$55
.write_test_3_loop:
    CMPB    0,x
    BNE     .test_error_high_address

    STAA    0,x
    CMPA    0,x
    BNE     .test_error_high_address

    INX
    CPX     #RAM_TEST_END_ADDRESS
    BNE     .write_test_3_loop

; The following section writes 0xAA to the first byte in each word.
    LDX     #$1000
    LDAA    #$AA
.write_test_4_loop:
    STAA    0,x
    CMPA    0,x
    BNE     .test_error_high_address

    INX
    CPX     #RAM_TEST_END_ADDRESS
    BNE     .write_test_4_loop

    BRA     .restore_high_ram

.test_error_high_address:
    LDAA    #2
    ORAA    <test_stage_sub_2

.restore_high_ram:
; The following section restores all the backed-up RAM from 0x800-0x1000 back
; to 0x1000-0x1800.
    LDX     #$800

.copy_ram_loop_2:
    LDD     0,x
    XGDX
    ADDD    #$800
    XGDX
    STD     0,x
    XGDX
    SUBD    #$7FE
    XGDX
    CPX     #$1000
    BNE     .copy_ram_loop_2

    LDAB    #3
    STAB    <test_stage_sub

    RTS


; ==============================================================================
; TEST_RAM_STAGE_3
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the results of the diagnostic test.
; A result of '1' indicates an error in the low 2Kb, a result of '2' indicates
; an error in the higher 2Kb.
;
; ==============================================================================
test_ram_stage_3:                               SUBROUTINE
    JSR     lcd_clear_line_2

; If this value is '0', the test results are okay.
    LDAA    <test_stage_sub_2
    ANDA    #%11
    BEQ     .print_result_ok

    LDX     #str_error_ram
    JSR     lcd_strcpy

    LDAA    <test_stage_sub_2
    ANDA    #1
    BEQ     .is_error_in_high_address

    JSR     lcd_print_number_single_digit

.is_error_in_high_address:
    LDAA    <test_stage_sub_2
    ANDA    #%10
    BEQ     .update_lcd_and_exit

    JSR     lcd_print_number_single_digit

.update_lcd_and_exit:
    JSR     lcd_update
    CLRB
    STAB    <test_stage_sub

    RTS

.print_result_ok:
    LDX     #str_ok
    JSR     lcd_strcpy
    BRA     .update_lcd_and_exit
