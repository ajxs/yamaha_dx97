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
    DC.B ui_print_play_mode - *
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
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
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
    INCA
    CLRB
    JSR     lcd_print_number_two_digits

; Print the enabled status of each individual operator.
; The 'Print Single Number' routine will print a '1', or '0' to indicate
; the status of each operator. Incrementing the LCD write pointer with
; each iteration.
; @Note: This is moved 1 space to the left, to match the position on the DX7.
    LDX     #lcd_buffer_next + 6
    STX     <memcpy_ptr_dest

    LDAA     patch_edit_operator_status

; Rotate left twice times, since we're testing 6 operators.
; This will place the six operator statuses at bits 7-2 in ACCA.
; With each iteration, this value will be rotated left.
; This will set the carry bit to the status of each operator.
    ASLA
    ASLA

    LDAB    #6
.print_operator_enabled_loop:
    ROLA

    PSHA
    PSHB

    LDAA    #0
    BCC     .print_operator_status

    LDAA    #1
.print_operator_status:
    JSR     lcd_print_number_single_digit

    PULB
    PULA
    DECB
    BNE     .print_operator_enabled_loop

    LDAB    ui_btn_numeric_last_pressed
    CMPB    #BUTTON_EDIT_10_MOD_SENS
    BNE     .was_last_button_below_12

    TST     ui_btn_edit_10_sub_function
    BEQ     .print_selected_operator

.was_last_button_below_12:
    CMPB    #BUTTON_EDIT_12_OSC_FREQ_COARSE
    BCS     ui_print_parameter

    CMPB    #BUTTON_EDIT_14_DETUNE_SYNC
    BNE     .was_last_button_in_function_mode

    TST     ui_btn_edit_14_sub_function
    BNE     ui_print_parameter

.was_last_button_in_function_mode:
; If the carry flag is clear, it means that the last button press registered
; was in function mode.
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
    LDX     #str_test_mode_prompt
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
; UI_PRINT_PLAY_MODE
; ==============================================================================
; DESCRIPTION:
; Prints the main user-interface when the synth is in 'Play Mode'.
;
; ==============================================================================
ui_print_play_mode:                             SUBROUTINE
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
    BNE     .is_button_above_11

    JMP     .non_printable_param_value

.is_button_above_11:
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
    BNE     .is_function_button_4

; Value 9 (13) = Button 14 (Detune/Osc Sync).
; Test the value of the Edit Button 14 sub-status.
; 0 = Detune, 1 = Oscillator Sync.
    TST     ui_btn_edit_14_sub_function
    BEQ     .test_if_param_is_printable

; Load the string table offset for 'Osc Key Sync'.
    LDAB    #37
    BRA     .print_parameter_name

.is_function_button_4:
    CMPB    #BUTTON_FUNCTION_4 - 4
    BNE     .is_function_button_6

; Value 19 (23) = Function Mode Button 4.
; Test the value of the Function Button 4 sub-status.
; 0 = Portamento Mode, 1 = Glissando Enabled.
    LDAA    ui_btn_function_4_sub_function
    BEQ     .test_if_param_is_printable

; Load the string table offset for 'Glissando'.
    LDAB    #45
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
    CMPB    #46
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
; @NOTE: The original ROM had the full test prompt string pointer here.
; This string is 32 characters long. If this was reached, it would overflow the
; LCD buffer, and clobber the adjacent memory. This was the bottom of the stack,
; so it was highly unlikely to cause any issues. In this ROM that isn't the
; case, so it has been changed to print only the second line of the test entry
; prompt.
    DC.W str_test_mode_prompt_line_2

; Sub-function parameter name strings.
    DC.W str_osc_key_sync
    DC.W str_lfo_pm_depth
    DC.W str_mod_sens_p
    DC.W str_voice_init
    DC.W str_battery_voltage
    DC.W str_tape_verify
    DC.W str_sys_info
    DC.W str_midi_transmit
    DC.W str_glissando

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
    DC.W ui_print_parameter_value_sys_info
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
