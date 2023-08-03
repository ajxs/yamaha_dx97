; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; test/rom.asm
; ==============================================================================
; DESCRIPTION:
; Tests the ROM by calculating a checksum of the entire ROM memory in 64 byte
; 'blocks'. After summing all blocks, the final checksum byte is tested for
; correctness.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_ROM
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; The entry subroutine to the ROM diagnostic tests.
;
; ==============================================================================
test_rom:                                       SUBROUTINE
; The test 'sub-stage' variable is reset to '0xFF' when the stage is
; incremented.
; This will cause the test stage to be initialised when this subroutine
; is initially called.
; After the 64 'blocks' of the ROM binary have been tested, a sub-stage
; number equal to, or above 64 will be a no-op.
    LDAB    <test_stage_sub
    JSR     jumpoff

    DC.B test_rom_get_block_checksum - *
    DC.B $40
    DC.B .exit - *
    DC.B $FF
    DC.B test_rom_init - *
    DC.B 0

.exit:
    RTS


; ==============================================================================
; TEST_ROM_INIT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; This subroutine initialises the test stage variables used in the ROM test
; stage.
;
; ==============================================================================
test_rom_init:                                  SUBROUTINE
; 'TEST #' is already written to the LCD.
    LDX     #str_rom
    JSR     test_lcd_set_write_pointer_to_position_7
    JSR     lcd_update

; Reset test stage variables.
    CLR     test_stage_sub_2
    CLR     test_stage_sub

    RTS


; ==============================================================================
; TEST_ROM_GET_BLOCK_CHECKSUM
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Calculates the checksum for a 256 byte 'block' of the ROM binary.
; This checksum is calculated by summing the individual bytes in the block,
; storing the sum in a single byte, and ignoring the resulting overflow.
; After every byte in the binary has been summed, the expected result is that
; the final sum of all blocks is '0'.
; This function is called 64 times in total to sum all of the binary.
; In order to implement this test, a byte should be stored at an
; arbitrary location with the final value that will round the ROM's checksum
; off to zero. This value could be placed anywhere. In the original ROM it
; is placed at 0xC000.
;
; ==============================================================================
test_rom_get_block_checksum:                    SUBROUTINE
    LDD     #$C000 ; Start of ROM memory.

; Add the current test sub-stage to ACCA.
; Since the address is in ACCA+ACCB, this will effectively increment the
; block pointer by 256.
; The block pointer is then transferred to IX.
    ADDA    <test_stage_sub
    XGDX

; ACCB is used as an iterator for a loop from 0-256.
; In the loop it is decremented prior to comparing against zero, so it will
; run 256 times in total.
; ACCA is used to store the checksum for the current 'block'.
    CLRB
    LDAA    <test_stage_sub_2

.get_block_checksum_loop:
; Add the contents of the memory to the checksum.
    ADDA    0,x
    INX
    DECB
    BNE     .get_block_checksum_loop

    STAA    <test_stage_sub_2

; Test whether IX has overflowed to 0.
; This indicates that the entire ROM memory has been summed.
    CPX     #0
    BNE     .increment_block

; Compare the whole binary's 'checksum' against '0'.
    CMPA    #0
    BNE     .checksum_error

    LDX     #str_ok

.print_message:
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update

.increment_block:
    INC     test_stage_sub

    RTS

.checksum_error:
    LDX     #str_test_err
    BRA     .print_message
