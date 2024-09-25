; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
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
; Prints an 'equals' to the LCD buffer, and then loads the currently active
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
; Falls-through below.

; ==============================================================================
; UI_PRINT_PARAM_VALUE_SEPARATOR_CHARACTER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the specified separator character to the LCD buffer, and then loads
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
; * IX:   The address of the selected edit parameter.
; * ACCA: The value of the selected edit parameter.
;
; ==============================================================================
ui_print_param_value_separator_character:       SUBROUTINE
    LDX     #(lcd_buffer_next + 28)

ui_print_separator_and_load_active_param:
    STAA    0,x
    INX
    STX     <memcpy_ptr_dest

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
; @CHANGED_FOR_6_OP
; @PRIVATE
; DESCRIPTION:
; Prints the synth's polyphony setting to the LCD screen.
;
; REGISTERS MODIFIED:
; * ACCA, IX
;
; ==============================================================================
ui_print_parameter_value_mono_poly:             SUBROUTINE
    LDAA    mono_poly
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
ui_lcd_copy_and_update:                         SUBROUTINE
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
    LDAA    portamento_mode

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
    JSR     ui_print_separator_and_load_active_param
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
; UI_PRINT_PARAMETER_VALUE_SYS_INFO
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; @PRIVATE
; DESCRIPTION:
; Prints the value of the SysEx 'Sys Info Avail' setting.
;
; REGISTERS MODIFIED:
; * IX
;
; ==============================================================================
ui_print_parameter_value_sys_info:              SUBROUTINE
    LDAA    sys_info_avail

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
ui_print_update_led_and_menu:                   SUBROUTINE
    JSR     led_print_patch_number
    JMP     ui_print


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_OSC_MODE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Prints the value of the currently selected operator's mode.
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
ui_print_parameter_value_osc_mode:              SUBROUTINE
    LDX     #(lcd_buffer_next + 24)
    LDAA    #':

    JSR     ui_print_separator_and_load_active_param

    LDX     #str_osc_mode_fixed
    TSTA
    BNE     ui_lcd_copy_and_update

    LDX     #str_osc_mode_ratio

    BRA     ui_lcd_copy_and_update
