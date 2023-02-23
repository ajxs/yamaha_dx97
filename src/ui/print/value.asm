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
; ui/print/value.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the various functions used to print the value of the
; currently selected edit parameter.
; Refer to the functionality in 'ui/print/print.asm' for how these are called.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI_PRINT_PARAM_VALUE_EQUALS_AND_LOAD_VALUE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints an 'equals' to the LCD buffer, and then laods the currently active
; edit parameter.
;
; ARGUMENTS:
; Memory:
; * ui_active_param_address: The address of the selected edit parameter.
;
; REGISTERS MODIFIED:
; * ACCA, IX
;
; RETURNS:
; * ACCA: The value of the selected edit parameter.
;
; ==============================================================================
ui_print_param_value_equals_and_load_value:     SUBROUTINE
    LDAA    #'=
; Fall-through below.

; ==============================================================================
; UI_PRINT_PARAM_VALUE_SEPARATOR_CHARACTER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the specified separator charactor to the LCD buffer, and then loads
; the selected edit parameter.
;
; ARGUMENTS:
; Registers:
; * ACCA: The separator character to print.
;
; Memory:
; * ui_active_param_address: The address of the selected edit parameter.
;
; REGISTERS MODIFIED:
; * ACCA, IX
;
; RETURNS:
; * ACCA: The value of the selected edit parameter.
;
; ==============================================================================
ui_print_param_value_separator_character:       SUBROUTINE
    LDX     #(lcd_buffer_next + 28)

ui_print_character:
    STAA    0,x
    INX
    STX     <memcpy_ptr_dest

ui_load_active_param_value:
    LDX     ui_active_param_address
    LDAA    0,x

    RTS


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_NUMERIC
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints a numeric parameter to the LCD.
; This subroutine is used when the currently active edit parameter is numeric.
;
; ==============================================================================
ui_print_parameter_value_numeric:               SUBROUTINE
    JSR     ui_print_param_value_equals_and_load_value
    JSR     lcd_print_number_three_digits
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_ON_OFF
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints a boolean 'On/Off' parameter to the LCD.
; This subroutine is used when the currently active edit parameter is
; toggled on, and off.
;
; ==============================================================================
ui_print_parameter_value_on_off:                SUBROUTINE
    LDAA    #':
    JSR     ui_print_param_value_separator_character
    LDX     #str_on
    TSTA
    BNE     .print_on_off_string

    LDX     #str_off

.print_on_off_string:
    JSR     lcd_strcpy
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_OSC_FREQ
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the oscillator frequency to the LCD.
; @TODO.
;
; ==============================================================================
ui_print_parameter_value_osc_freq:              SUBROUTINE
    LDAA    #'=
    LDX     #(lcd_buffer_next + 24)
    JSR     ui_print_character
    LDAA    operator_selected_src
    BITA    #1
    BEQ     loc_E639

    INX
    XGDX
    ANDB    #$FE
    XGDX
    DEX
    BRA     loc_E63D

loc_E639:
    XGDX
    ANDB    #$FE
    XGDX

loc_E63D:
    LDAA    0,x
    BEQ     loc_E67E

    LDAB    1,x
    ADDB    #100
    MUL
    CLR     lcd_print_number_print_zero_flag
    CLR     lcd_print_number_divisor

loc_E64C:
    SUBD    #1000
    BCS     loc_E656

    INC     lcd_print_number_print_zero_flag
    BRA     loc_E64C

loc_E656:
    ADDD    #1000

loc_E659:
    SUBD    #100
    BCS     loc_E663

    INC     lcd_print_number_divisor
    BRA     loc_E659

loc_E663:
    ADDD    #100
    PSHB
    LDAA    <lcd_print_number_print_zero_flag
    LDAB    #10
    MUL
    ADDB    <lcd_print_number_divisor
    TBA
    JSR     lcd_print_number_three_digits
    LDAB    #'.
    JSR     lcd_store_character_and_increment_ptr
    PULA
    JSR     lcd_print_number_two_digits
    JMP     lcd_update

loc_E67E:
    CLRA
    JSR     lcd_print_number_three_digits
    LDAB    #'.
    JSR     lcd_store_character_and_increment_ptr
    LDAA    1,x
    LSRA
    ADDA    #50
    JSR     lcd_print_number_two_digits
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_OSC_DETUNE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the value of the 'Oscillator Detune' parameter.
;
; ==============================================================================
ui_print_parameter_value_osc_detune:            SUBROUTINE
    JSR     ui_print_param_value_equals_and_load_value
    SUBA    #7
    BHI     .detune_value_positive

    BMI     .detune_value_negative

; If the value is zero, print the value without the leading '+', or '-'.
    JSR     lcd_print_number_three_digits
    BRA     .update_lcd_and_exit

.detune_value_positive:
    LDAB    #'+
    JSR     lcd_store_character_and_increment_ptr
    BRA     .print_detune_value

.detune_value_negative:
    LDAB    #'-
    JSR     lcd_store_character_and_increment_ptr
    NEGA

.print_detune_value:
    CLRB
    JSR     lcd_print_number_two_digits

.update_lcd_and_exit:
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_KEY_TRANSPOSE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the value of the 'Key Transpose' function parameter.
;
; ==============================================================================
ui_print_parameter_value_key_transpose:         SUBROUTINE
    JSR     ui_print_param_value_equals_and_load_value
    LDAB    patch_edit_key_transpose

    LDAA    #49

; Subtract 12 with each iteration, until the value goes below zero.
; This will determine the octave of the root key transpose note.
.get_octave_loop:
    INCA
    SUBB    #12
    BCC     .get_octave_loop

    STAA    lcd_buffer_next+$1F

; Add 12 back to take into account the subtraction of '12' that overflowed.
    ADDB    #12

; Use this value as an index into the note name array.
    ASLB
    LDX     #str_note_names
    ABX
    LDD     0,x
    STD     lcd_buffer_next + 29
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_BATTERY_VOLTAGE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the synth's battery voltage to the synth's LCD screen.
;
; ARGUMENTS:
; Memory:
; * analog_input_battery_voltage: The battery voltage, as read on reset.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
ui_print_parameter_value_battery_voltage:       SUBROUTINE
    LDAB    analog_input_battery_voltage
    LDAA    #5
    MUL

    ADDA    #'0
    STAA    lcd_buffer_next + 29

    LDAA    #'.
    STAA    lcd_buffer_next + 30

    LDAA    #10
    MUL
    ADDA    #'0
    STAA    lcd_buffer_next + 31
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_MONO_POLY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the synth's polyphony setting to the LCD screen.
;
; REGISTERS MODIFIED:
; * ACCA, IX
;
; ==============================================================================
ui_print_parameter_value_mono_poly:             SUBROUTINE
    JSR     ui_load_active_param_value
    LDX     #str_mode_mono
    TSTA
    BNE     ui_lcd_copy_and_update

    LDX     #str_mode_poly
; Falls-through below.

; ==============================================================================
; UI_LCD_COPY_AND_UPDATE
; ==============================================================================
; DESCRIPTION:
; Convenience subroutine to print the current parameter value string to the LCD.
;
; ARGUMENTS:
; Registers:
; * IX:   The string to print to the LCD.
;
; Memory:
; * memcpy_pointer_dest: The destination in memory to copy the string to.
;
; ==============================================================================
ui_lcd_copy_and_update:
    JSR     lcd_strcpy
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_PORTAMENTO_MODE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; @PRIVATE
; DESCRIPTION:
; Prints the synth's currently selected portamento mode to the LCD screen.
;
; REGISTERS MODIFIED:
; * IX
;
; ==============================================================================
ui_print_parameter_value_portamento_mode:       SUBROUTINE
    JSR     ui_load_active_param_value
    TST     mono_poly
    BNE     .synth_is_mono

    LDX     #str_porta_follow
    TSTA
    BNE     ui_lcd_copy_and_update

    LDX     #str_porta_retain
    BRA     ui_lcd_copy_and_update

.synth_is_mono:
    LDX     #str_porta_full_time
    TSTA
    BNE     ui_lcd_copy_and_update

    LDX     #str_porta_fingered
    BRA     ui_lcd_copy_and_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_LFO
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the synth's currently selected LFO wave to the LCD screen.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_print_parameter_value_lfo:                   SUBROUTINE
    LDAA    #':
    LDX     #(lcd_buffer_next + 24)
    JSR     ui_print_character
    CMPA    #6
    BCS     .print_lfo_wave_name

    CLRA

.print_lfo_wave_name:
    LDX     #table_str_lfo_names
    TAB
    ASLB
    ABX
    LDX     0,x
    BRA     ui_lcd_copy_and_update

table_str_lfo_names:
    DC.W str_lfo_name_triangle
    DC.W str_lfo_name_saw_down
    DC.W str_lfo_name_saw_up
    DC.W str_lfo_name_square
    DC.W str_lfo_name_sine
    DC.W str_lfo_name_sample_hold

; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_AVAIL_UNAVAIL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the value of the SysEx 'Sys Info Avail' setting.
;
; REGISTERS MODIFIED:
; * IX
;
; ==============================================================================
ui_print_parameter_value_avail_unavail:         SUBROUTINE
    JSR     ui_load_active_param_value
    LDX     #str_sys_info_unavail + 2
    TSTA
    BNE     ui_lcd_copy_and_update

    LDX     #str_sys_info_unavail
    BRA     ui_lcd_copy_and_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_MIDI_CHANNEL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the value of the currently selected MIDI channel.
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
ui_print_parameter_value_midi_channel:          SUBROUTINE
    JSR     ui_print_param_value_equals_and_load_value
    INCA
    JSR     lcd_print_number_three_digits
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_UPDATE_LED_AND_MENU
; ==============================================================================
; DESCRIPTION:
; Updates the LED patch number, and prints the UI to the LCD.
; This subroutine is used to update the synth's UI after various user actions.
;
; ==============================================================================
ui_print_update_led_and_menu:
    JSR     led_print_patch_number
    JMP     ui_print
