; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; test/adc.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the ADC test subroutine.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_ADC
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Tests the synth's analog input peripherals.
; This subroutine reads the analog input from the last touched peripheral, such
; as the mod wheel, pitch bend wheel, and data entry slider, and prints the
; last read value to the LED.
;
; ==============================================================================
test_adc:                                       SUBROUTINE
    TST     test_stage_sub
    BEQ     .continue_test

    LDX     #str_ad
    JSR     test_lcd_set_write_pointer_to_position_7
    JSR     lcd_update
    CLR     test_stage_sub
    BRA     .exit

.continue_test:
    LDAB    analog_input_source_next
    JSR     adc_set_source
    JSR     adc_update_input_source
    BCS     .decrement_input_source

    JSR     lcd_clear_line_2

; Get pointer to string.
; This is the next analog input source multiplied by 17, which is the length
; of each string, including the null-terminating byte.
    LDX     #str_pitch_bender
    LDAB    analog_input_source_next
    LDAA    #17
    MUL
    ABX
    JSR     test_lcd_set_write_pointer_to_line_2

    LDX     #analog_input_pitch_bend
    LDAB    analog_input_source_next
    ABX
    LDAA    0,x
    LDAB    #$64
    MUL
    JSR     test_print_number_to_led
    JSR     lcd_update

.decrement_input_source:
    LDAB    analog_input_source_next
    DECB
    BPL     .store_input_source

    LDAB    #ADC_SOURCE_SLIDER

.store_input_source:
    STAB    analog_input_source_next

.exit:
    RTS
