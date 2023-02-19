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
; ui/print.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the synth's main UI menu printing subroutines.
; This is where the user-interface is printed, including the current UI mode,
; and the current parameter.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI_PRINT
; ==============================================================================
; DESCRIPTION:
; Main entry point to the synth's menu functionality.
; This subroutine will print the user-interface containing the currently
; active mode, the parameter currently being edited, and its value.
;
; ==============================================================================
ui_print:                                       SUBROUTINE
; Clear LCD 'next' buffer prior to printing menu.
    JSR     lcd_clear

; Jump to the correct menu function based upon the current UI mode, and
; memory protection flags.
    LDAB    ui_mode_memory_protect_state

; If ACCB > 10, clear.
    CMPB    #11
    BCS     .jumpoff

    CLRB

.jumpoff:
    JSR     jumpoff_indexed

; ==============================================================================
; UI Printing Functions.
; ==============================================================================
    DC.B ui_print_function_mode - *
    DC.B ui_print_edit_mode - *
    DC.B ui_print_memory_select_mode - *
    DC.B .exit - *

; ==============================================================================
; UI Printing Functions: Memory Protect Disabled.
; ==============================================================================
    DC.B .exit - *
    DC.B ui_print_eg_copy_mode - *
    DC.B ui_print_memory_store_mode - *
    DC.B .exit - *

; ==============================================================================
; UI Printing Functions: Memory Protect Enabled.
; ==============================================================================
    DC.B .exit - *
    DC.B ui_print_eg_copy_mode - *
    DC.B ui_print_memory_protected - *

.exit:
    RTS


; ==============================================================================
; UI_PRINT_MEMORY_STORE_MODE
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
ui_print_memory_store_mode:
    LDX     #str_memory_store
    BRA     ui_print_copy_string_and_update


; ==============================================================================
; UI_PRINT_MEMORY_PROTECTED
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
ui_print_memory_protected:
    LDX     #str_memory_protect
; Falls-through below.

; ==============================================================================
; UI_PRINT_COPY_STRING_AND_UPDATE
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
ui_print_copy_string_and_update:
    JSR     lcd_strcpy
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_EG_COPY_MODE
; ==============================================================================
; DESCRIPTION:
; Prints the 'EG COPY' menu dialog when the synth is in EG Copy mode.
;
; ==============================================================================
ui_print_eg_copy_mode:                          SUBROUTINE
    LDX     #str_eg_copy
    JSR     lcd_strcpy
    LDX     #(lcd_buffer_next + 16)
    STX     <memcpy_ptr_dest
    LDX     #str_op_copy
    JSR     lcd_strcpy

; Store the position for the source EG number on the LCD in the copy ptr.
    LDX     #(lcd_buffer_next + 23)
    STX     <memcpy_ptr_dest

; Print the selected operator number.
    LDAA    operator_selected_src
    ANDA    #%11
    INCA    ; Increment, since the number is zero-based.
    JSR     lcd_print_number_single_digit

; Load the destination operator.
; Check whether this is uninitialised (0xFF).
; If so, exit without printing.
    LDAA    operator_selected_dest
    BMI     .exit

; Store the position for the dest EG number on the LCD in the copy ptr.
    LDX     #(lcd_buffer_next + 30)
    STX     <memcpy_ptr_dest

; Increment, since the number is zero-based.
    INCA
    JSR     lcd_print_number_single_digit

; @TODO: Why is this reset?
    LDAA    #$FF
    STAA    operator_selected_dest

.exit:
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_EDIT_MODE
; ==============================================================================
; DESCRIPTION:
; Prints the 'Edit Mode' user-interface.
; This contains the information about the current algorithm, the operator
; enabled status, and the EG edit interface.
;
; ==============================================================================
ui_print_edit_mode:                             SUBROUTINE
    LDX     #str_fragment_alg
    JSR     lcd_strcpy

; Print the current patch's algorithm.
    LDAA    patch_edit_algorithm
    ANDA    #7
    INCA
    CLRB
    JSR     lcd_print_number_two_digits
    LDX     #(lcd_buffer_next + 7)
    STX     <memcpy_ptr_dest

; Print the enabled status of each individual operator.
; The 'Print Single Number' routine will print a '1', or '0' to indicate
; the status of each operator. Incrementing the LCD write pointer with
; each iteration.
    LDX     #operator_enabled_status

.print_operator_enabled_loop:
    LDAA    0,x
    ANDA    #1
    JSR     lcd_print_number_single_digit
    INX
    CPX     #(operator_enabled_status + 4)
    BNE     .print_operator_enabled_loop

    LDAB    ui_btn_numeric_last_pressed
    CMPB    #BUTTON_EDIT_10_MOD_SENS
    BNE     .is_last_button_12
    TST     ui_btn_edit_10_sub_function
    BEQ     .print_selected_operator

.is_last_button_12:
    CMPB    #BUTTON_EDIT_12_OSC_FREQ_COARSE
    BCS     ui_print_parameter
    CMPB    #BUTTON_EDIT_14_DETUNE_SYNC
    BNE     .is_last_button_20
    TST     ui_btn_edit_14_sub_function
    BNE     ui_print_parameter

.is_last_button_20:
    CMPB    #BUTTON_EDIT_20_KEY_TRANSPOSE
    BCC     ui_print_parameter


.print_selected_operator:
; Print the selected operator to the LCD.
; Prints 'OP' by directly copying these two bytes to the LCD buffer in IX,
; then prints the operator number by adding an ASCII '1' to the value of
; the currently selected operator.
; This differs from the original, which directly loads the string "OP".
; dasm does not permit this, so loading the equivalent integer is used.
    LDX     #$4F50
    STX     lcd_buffer_next + 13

    LDAA    operator_selected_src
    ANDA    #%11
    ADDA    #'1
    STAA    lcd_buffer_next + 15

    CMPB    #BUTTON_EDIT_15_EG_RATE
    BCS     ui_print_parameter
    CMPB    #BUTTON_EDIT_17_KBD_SCALE_RATE
    BCC     ui_print_parameter

; Print the currently selected EG stage.
    LDAA    ui_currently_selected_eg_stage
    ANDA    #%11
    ADDA    #'1
    STAA    lcd_buffer_next + 26

; Call the main menu print subroutine.
; This will print the currently selected parameter and its value.
    BRA     ui_print_parameter


; ==============================================================================
; UI_PRINT_FUNCTION_MODE
; ==============================================================================
; DESCRIPTION:
; Prints the main user-interface when the synth is in 'Function Mode'.
; This subroutine will print the function mode header, the parameter currently
; being edited, and its value.
; This subroutine is also responsible for printing the 'patch init', and
; 'test mode entry' prompts.
;
; ==============================================================================
ui_print_function_mode:                         SUBROUTINE
    LDAB    ui_btn_numeric_last_pressed

; If the 'TEST MODE ENTRY' prompt is active, print this message and exit.
    CMPB    #BUTTON_TEST_ENTRY_COMBO
    BNE     .print_header
    LDX     #str_test_mode_entry
    JSR     lcd_strcpy
    JMP     lcd_update

.print_header:
    LDX     #str_function_control
    JSR     lcd_strcpy

; If the initialise patch prompt is active, print this message and exit.
; Otherwise proceed to the main menu print subroutine.
    TST     ui_btn_function_19_patch_init_prompt
    BEQ     ui_print_parameter

; If this code has been reached, the patch initialisation UI menu is active.
; This prints the 'Are you sure' prompt.
    LDX     #lcd_buffer_next_line_2
    STX     <memcpy_ptr_dest
    LDX     #str_are_you_sure
    JSR     lcd_strcpy
    JMP     lcd_update


; ==============================================================================
; MENU_MEMORY_SELECT
; ==============================================================================
; DESCRIPTION:
; Prints the main user-interface when the synth is in 'Memory Select Mode'.
;
; ==============================================================================
ui_print_memory_select_mode:                    SUBROUTINE
    LDX     #str_memory_select
    JSR     lcd_strcpy
; Falls-through to print menu.

; ==============================================================================
; UI_PRINT_PARAMETER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Prints the currently selected edit parameter, and its value to the LCD.
; This routine works by finding the correct offset into the string table for
; the active parameter, based upon the last numeric button pressed.
; The string table entry for the particular parameters are encoded with a
; reference to the correct UI subroutine to call to print the parameter value.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_print_parameter:                             SUBROUTINE
; Set the LCD memcpy pointer to the start of line 2.
    LDX     #lcd_buffer_next_line_2
    STX     <memcpy_ptr_dest

; Load the last numeric button pressed, and subtract '4' from this value.
; This arrangement is done because buttons 1-4 in 'Edit mode' don't trigger
; any UI changes.
    LDAB    ui_btn_numeric_last_pressed
    SUBB    #4

; If value 6 (10): Button 11 (Operator Select), update the LCD and exit.
    CMPB    #BUTTON_EDIT_11 - 4
    BEQ     .non_printable_param_value

; If the button value is above 6 (Button 11), branch.
    BCC     .is_edit_button_14

; If ACCB == 0, the triggering button is Edit Mode Button 5.
    TSTB
    BNE     .is_edit_button_9

; Value 0 (4) = Edit Mode Button 5.
; Test the value of the Edit Button 5 sub-status.
; 0 = Algorithm, 1 = Feedback.
    TST     ui_btn_edit_5_sub_function
    BEQ     .test_if_param_is_printable

.is_edit_button_9:
    CMPB    #BUTTON_EDIT_9 - 4
    BNE     .is_edit_button_10

; Value 4 (8) = Edit Mode Button 9.
; Test the value of the Edit Button 9 sub-status.
; 0 = LFO Amp Mod Depth, 1 = LFO Pitch Mod Depth.
    TST     ui_btn_edit_9_sub_function
    BEQ     .increment_and_print

; Load the string table offset for 'LFO Pitch Mod Depth'
    LDAB    #38
    BRA     .print_parameter_name

.is_edit_button_10:
    CMPB    #BUTTON_EDIT_10_MOD_SENS - 4
    BNE     .increment_and_print

; value 5 (9) = Edit Mode Button 10.
; Test the value of the Edit Button 10 sub-status.
; 0 = Amp Mod Sensitivity, 1 = Pitch Mod Sensitivity.
    TST     ui_btn_edit_10_sub_function
    BEQ     .increment_and_print

; Load the string table offset for 'Pitch Mod Sens'.
    LDAB    #39
    BRA     .print_parameter_name

; Increment the triggering button number to get the string pointer.

.increment_and_print:
    INCB
    BRA     .test_if_param_is_printable

.is_edit_button_14:
    CMPB    #BUTTON_EDIT_14_DETUNE_SYNC - 4
    BNE     .is_function_button_6

; Value 9 (13) = Button 14 (Detune/Osc Sync).
; Test the value of the Edit Button 14 sub-status.
; 0 = Detune, 1 = Oscillator Sync.
    TST     ui_btn_edit_14_sub_function
    BEQ     .test_if_param_is_printable

; Load the string table offset for 'Osc Key Sync'.
    LDAB    #37
    BRA     .print_parameter_name

.is_function_button_6:
    CMPB    #BUTTON_FUNCTION_6 - 4
    BNE     .is_function_button_7

; Value 21 (25) = Function Mode Button 6.
; Test the value of the Function Button 6 sub-status.
; 0 = MIDI Channel, 1 = Sys Info, 2 = MIDI Transmit.
    LDAA    ui_btn_function_6_sub_function
    BEQ     .test_if_param_is_printable

    CMPA    #1
    BNE     .print_midi_transmit

; Load the string table offset for 'Sys Info'.
    LDAB    #43
    BRA     .print_parameter_name

.print_midi_transmit:
; Load the string table offset for 'MIDI TRANSMIT ?'
    LDAB    #44
    BRA     .print_parameter_name

.is_function_button_7:
    CMPB    #BUTTON_FUNCTION_7 - 4
    BNE     .is_function_button_19

; Value 22 (26) = Function Mode Button 7.
; Test the value of the Function Button 7 sub-status.
; 0 = Save Tape, 1 = Verify Tape.
    TST     ui_btn_function_7_sub_function
    BEQ     .test_if_param_is_printable

; Load the string table offset for 'VERIFY TAPE ?'.
    LDAB    #42
    BRA     .print_parameter_name

.is_function_button_19:
    CMPB    #BUTTON_FUNCTION_19 - 4
    BNE     .test_if_param_is_printable

; Value 34 (38) = Function mode button 19.
; Test the value of the Function Button 19 sub-status.
; 0 = Edit Recall, 1 = Voice Init, 2 = Battery Voltage.
    LDAA    ui_btn_function_19_sub_function
    BEQ     .test_if_param_is_printable
    DECA
    BNE     .print_battery_voltage

; Load the string table offset for 'VOICE INIT ?'.
    LDAB    #40
    BRA     .print_parameter_name

.print_battery_voltage:
; Load the string table offset for the 'BATTERY VOLT=' string.
    LDAB    #41
    BRA     .print_parameter_name

.test_if_param_is_printable:
; If the string offset number is over 44, the param is not printable.
; In this case, clear ACCB.
    CMPB    #45
    BCS     .print_parameter_name
    CLRB

.print_parameter_name:
; Print the parameter name to line 2 of the LCD screen.
    ASLB
    LDX     #table_menu_parameter_names
    ABX
    LDX     0,x

; The terminating character of the parameter name string will be returned in
; ACCB. This value will determine what function will be used to print the
; associated parameter value. Refer to the documentation below, or in the
; string table for more information.
    JSR     lcd_strcpy

; After the parameter name has been printed, print the parameter value.
; If ACCB less than 12, branch, otherwise clear the index.
; This index will be used as an offset into a table of printing routines.
; These routines are used to correctly print the parameter.
    CMPB    #12
    BCS     .print_parameter_value

.non_printable_param_value:
    CLRB

.print_parameter_value:
; This is where the parameter value is printed.
; The following table contains pointers to the various functions used to
; print the parameter values.
; Most parameters (value over 12) do not require any specialised printing
; routine, so in this case the LCD will just be updated.
    LDX     #table_menu_print_parameter_functions
    ASLB
    ABX
    LDX     0,x
    JMP     0,x

; ==============================================================================
; Parameter name string pointer table.
; ==============================================================================
table_menu_parameter_names:
; Edit mode parameter name strings.
    DC.W str_algorithm_select
    DC.W str_feedback
    DC.W str_lfo_wave
    DC.W str_lfo_speed
    DC.W str_lfo_delay
    DC.W str_lfo_am_depth
    DC.W str_mod_sens_a
    DC.W str_freq_coarse
    DC.W str_freq_fine
    DC.W str_osc_detune
    DC.W str_eg_rate
    DC.W str_eg_level
    DC.W str_rate_scaling
    DC.W str_lvl_scaling
    DC.W str_output_level
    DC.W str_middle_c

; Function mode parameter name strings.
    DC.W str_master_tune
    DC.W print_parameter_mono_poly_offset
    DC.W str_p_bend_range
    DC.W print_parameter_porta_mode_offset
    DC.W str_porta_time
    DC.W str_midi_ch
    DC.W str_tape_save
    DC.W str_tape_load
    DC.W str_tape_single
    DC.W str_tape_remote
    DC.W str_wheel_range
    DC.W str_wheel_pitch
    DC.W str_wheel_amp
    DC.W str_wheel_eg_b
    DC.W str_breath_range
    DC.W str_breath_pitch
    DC.W str_breath_amp
    DC.W str_breath_eg_b
    DC.W str_edit_recall
    DC.W str_mem_protect
    DC.W str_test_mode_entry
    DC.W str_osc_key_sync
    DC.W str_lfo_pm_depth
    DC.W str_mod_sens_p
    DC.W str_voice_init
    DC.W str_battery_voltage
    DC.W str_tape_verify
    DC.W str_sys_info
    DC.W str_midi_transmit

; ==============================================================================
; Parameter value print function pointers.
; ==============================================================================
table_menu_print_parameter_functions:
    DC.W lcd_update
    DC.W ui_print_parameter_value_numeric
    DC.W ui_print_parameter_value_on_off
    DC.W ui_print_parameter_value_osc_freq
    DC.W ui_print_parameter_value_osc_detune
    DC.W ui_print_parameter_value_key_transpose
    DC.W ui_print_parameter_value_battery_voltage
    DC.W ui_print_parameter_value_mono_poly
    DC.W ui_print_parameter_value_portamento_mode
    DC.W ui_print_parameter_value_lfo
    DC.W ui_print_parameter_value_avail_unavail
    DC.W ui_print_parameter_value_midi_channel

; ==============================================================================
; Printing the polyphony mode, and portamento mode don't print the parameter
; name, only the value. These offsets are hardcoded in the ROM so that instead
; of loading a parameter name to print, followed by the offset of the function
; to print the parameter, effectively only the offset is loaded.
; This hack is taken from the original DX9 ROM.
; ==============================================================================
print_parameter_mono_poly_offset:      DC.B PRINT_PARAM_FUNCTION_MONO_POLY
print_parameter_porta_mode_offset:     DC.B PRINT_PARAM_FUNCTION_PORTAMENTO_MODE

; ==============================================================================
; These indexes are used as the null-terminating character of the parameter
; name strings.
; The string copy function will return these in ACCB, which is read by the
; menu printing function to determine what function to use to print the
; associated parameter value.
; ==============================================================================
PRINT_PARAM_FUNCTION_NUMERIC:                   EQU 1
PRINT_PARAM_FUNCTION_BOOLEAN:                   EQU 2
PRINT_PARAM_FUNCTION_OSC_FREQ:                  EQU 3
PRINT_PARAM_FUNCTION_OSC_DETUNE:                EQU 4
PRINT_PARAM_FUNCTION_KEY_TRANSPOSE:             EQU 5
PRINT_PARAM_FUNCTION_BATTERY_VOLTAGE:           EQU 6
PRINT_PARAM_FUNCTION_MONO_POLY:                 EQU 7
PRINT_PARAM_FUNCTION_PORTAMENTO_MODE:           EQU 8
PRINT_PARAM_FUNCTION_LFO_WAVE:                  EQU 9
PRINT_PARAM_FUNCTION_AVAIL_UNAVAIL:             EQU 10
PRINT_PARAM_FUNCTION_MIDI_CHANNEL:              EQU 11


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
; @TODO
;
; ==============================================================================
ui_print_parameter_value_osc_detune:            SUBROUTINE
    JSR     ui_print_param_value_equals_and_load_value
    SUBA    #7
    BHI     loc_E6A0

    BMI     loc_E6A7

    JSR     lcd_print_number_three_digits
    BRA     loc_E6B1

loc_E6A0:
    LDAB    #'+
    JSR     lcd_store_character_and_increment_ptr
    BRA     loc_E6AD

loc_E6A7:
    LDAB    #'-
    JSR     lcd_store_character_and_increment_ptr
    NEGA

loc_E6AD:
    CLRB
    JSR     lcd_print_number_two_digits

loc_E6B1:
    JMP     lcd_update


; ==============================================================================
; UI_PRINT_PARAMETER_VALUE_KEY_TRANSPOSE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; @TODO
;
; ==============================================================================
ui_print_parameter_value_key_transpose:         SUBROUTINE
    JSR     ui_print_param_value_equals_and_load_value
    LDAB    patch_edit_key_transpose

; get octave?
    LDAA    #49

loc_E6BC:
    INCA
    SUBB    #12
    BCC     loc_E6BC

    STAA    lcd_buffer_next+$1F
    ADDB    #$C
    ASLB
    LDX     #str_note_names
    ABX
    LDD     0,x
    STD     lcd_buffer_next+$1D
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
; @PRIVATE
; DESCRIPTION:
; Prints the synth's currently selected portamento mode to the LCD screen.
;
; REGISTERS MODIFIED:
; * IX
;
; ==============================================================================
ui_print_parameter_value_portamento_mode:       SUBROUTINE
    TST     mono_poly
    BNE     .synth_is_mono

    LDX     #str_porta_full_time
    BRA     ui_lcd_copy_and_update

.synth_is_mono:
    JSR     ui_load_active_param_value
    LDX     #str_porta_fingered
    TSTA
    BNE     ui_lcd_copy_and_update

    LDX     #str_porta_full_time
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
