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
; test/lcd.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the synth's LED/LCD diagnostic test.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_LCD
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Performs a diagnostic routine for the synth's LED, and LCD interface.
; This test will toggle the LED, and LCD display between being entirely filled,
; and being entirely cleared.
;
; ==============================================================================
test_lcd:                                       SUBROUTINE
    TST     test_stage_sub
    BEQ     .test_initialised

; Initialise the test.
    JSR     lcd_clear
    JSR     lcd_update
    CLR     test_stage_sub
    BRA     .exit

.test_initialised:
    LDAA    <test_stage_sub_2
    INCA
    TAB
; Toggle this flag.
    EORA    <test_stage_sub_2
    BITA    #$80
    BEQ     .store_sub_stage_and_delay

    STAB    <test_stage_sub_2
    BPL     .display_off

    JSR     test_lcd_led_all_on
    JSR     test_lcd_fill

.update_and_exit:
    JSR     lcd_update

.exit:
    RTS

.display_off:
    JSR     test_lcd_led_all_off
    JSR     lcd_clear
    BRA     .update_and_exit

.store_sub_stage_and_delay:
    STAB    <test_stage_sub_2

    LDX     #1000
.delay_loop:
    DEX
    BNE     .delay_loop

    BRA     .exit


; ==============================================================================
; TEST_LCD_FILL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Fills the LCD display.
;
; ==============================================================================
test_lcd_fill:                                  SUBROUTINE
    LDAA    #$FF
    LDAB    #32
    JMP     lcd_fill_chars


; ==============================================================================
; TEST_LCD_LED_ALL_OFF
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Turns all of the LED segments off.
;
; ==============================================================================
test_lcd_led_all_off:                           SUBROUTINE
    LDAA    #$FF

test_lcd_led_store:
    STAA    <led_1
    STAA    <led_2

    RTS


; ==============================================================================
; TEST_LCD_ALL_ON
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Turns all of the LED segments on.
;
; ==============================================================================
test_lcd_led_all_on:                            SUBROUTINE
    CLRA
    BRA     test_lcd_led_store
