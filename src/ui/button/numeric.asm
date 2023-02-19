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
; ui/button/numeric.asm
; ==============================================================================
; DESCRIPTION:
; Contains code related to the handling of user input when the numeric
; front-panel buttons are pressed.
; Attempts to decompose this file into separate files containing the 'edit',
; and 'function' mode specific functionality have been unsuccessful.
; The relative addresses in the jump-table all need to be below 256 bytes,
; which makes reordering the function definitions precarious.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI_BUTTON_NUMERIC
; ==============================================================================
; DESCRIPTION:
; Main user-interface handler subroutine for a front-panel button press.
; The buttons have already been assigned the appropriate codes by the main
; input handler subroutines. This subroutine calls the specific functionality
; associated with each button.
; The main purpose of these subroutines is to populate the current edit
; parameter pointer, and its associated maximum value. This parameter variable
; will be manipulated by front-panel controls, such as increment/decrement,
; and the slider.
;
; ARGUMENTS:
; Registers:
; * ACCA: UI Input Mode
; * ACCB: Front-panel numeric switch number code.
;          0-19: Edit Mode Buttons.
;         20-39: Function Mode Buttons.
;
; ==============================================================================
ui_button_numeric:                              SUBROUTINE
    JSR     ui_button_check_test_mode_combination
    TBA
    JSR     jumpoff

    DC.B ui_button_edit_1_to_4_operator_enable - *
    DC.B 4
    DC.B ui_button_edit_5 - *
    DC.B 5
    DC.B ui_button_edit_6_7_8 - *
    DC.B 8
    DC.B ui_button_edit_9_pmd_amd - *
    DC.B 9
    DC.B ui_button_edit_10 - *
    DC.B 10
    DC.B ui_button_edit_11_operator_select - *
    DC.B 11
    DC.B ui_button_edit_12_13 - *
    DC.B 13
    DC.B ui_button_edit_14 - *
    DC.B 14
    DC.B ui_button_edit_15_16_jump - *
    DC.B 16
    DC.B ui_button_edit_12_13 - *
    DC.B 19
    DC.B ui_button_edit_20_jump - *
    DC.B 20
    DC.B ui_button_function_set_active_parameter_jump - *
    DC.B 25
    DC.B ui_button_function_6_jump - *
    DC.B 26
    DC.B ui_button_function_7_jump - *
    DC.B 27
    DC.B ui_button_function_set_active_parameter_jump - *
    DC.B 38
    DC.B ui_button_function_19_jump - *
    DC.B 39
    DC.B ui_button_function_20_jump - *
    DC.B 40
    DC.B ui_button_function_set_active_parameter_jump - *
    DC.B 0


; ==============================================================================
; UI_BUTTON_EDIT_1_TO_4_OPERATOR_ENABLE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Toggles the operator enable status of the synth's operators.
;
; ARGUMENTS:
; Registers:
; * ACCB: The triggering front-panel numeric button number.
;
; MEMORY MODIFIED:
; * operator_enabled_status
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_button_edit_1_to_4_operator_enable:          SUBROUTINE
; Use the triggering button number as an offset into the operator enabled
; status array, and load the associated status.
    LDX     #operator_enabled_status
    ABX
    LDAA    0,x

; Increment and mask the operator's status to toggle the value, then store it.
    INCA
    ANDA    #1
    STAA    0,x
    BNE     .load_selected_operator_status

; Test if the operator being enabled/disabled is the same as the operator copy
; source.
; @TODO: Revisit and confirm.
    CMPB    operator_selected_src
    BNE     .exit

; If the operator was disabled, load the 'Button 11' value into ACCB, and then
; retrigger processing the numeric button input. This will select the next
; operator. This is done to ensure that a disabled operator is not 'selected'.
    LDAB    #BUTTON_EDIT_11
    JSR     ui_button_numeric
    BRA     .exit

.load_selected_operator_status:
    LDX     #operator_enabled_status
    LDAB    operator_selected_src
    ANDB    #3
    ABX

; Test if the operator status has changed.
    LDAA    0,x
    BNE     .exit

; Refer to comment above regarding selecting a new operator.
    LDAB    #BUTTON_EDIT_11
    JSR     ui_button_numeric

.exit:
    LDAA    #EVENT_RELOAD_PATCH
    STAA    main_patch_event_flag
    JSR     midi_sysex_tx_param_change_operator_enable

    RTS


; ==============================================================================
; UI_BUTTON_EDIT_11_OPERATOR_SELECT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Handles the front-panel numeric button 11 being pressed when the synth is
; in 'Edit Mode'.
; @NOTE: The way this subroutine exits has been changed from the original.
;
; ARGUMENTS:
; Registers:
; * ACCB: The triggering front-panel numeric button number.
;
; MEMORY MODIFIED:
; * operator_selected_src
; * ui_btn_numeric_last_pressed
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_button_edit_11_operator_select:              SUBROUTINE
    LDAB    operator_selected_src

; Loop over the operators until either an enabled operator is found, or the
; loop counter in ACCA reaches zero.
; If no operators are enabled, the end effect is that the selected operator
; will remain the same.
    LDAA    #4
.find_next_selected_operator_loop:
; Increment and mask the selected operator, then use this as an index into the
; operator enabled status array.
    LDX     #operator_enabled_status
    INCB
    ANDB    #%11
    ABX

; Test whether the current operator is enabled. If so, this becomes the newly
; selected operator.
    TST     0,x
    BNE     .store_selected_operator
; Decrement the loop counter.
    DECA
    BNE     .find_next_selected_operator_loop

.store_selected_operator:
    STAB    operator_selected_src

; Test if the previous button event was Edit mode button 20.
    LDAB    ui_btn_numeric_last_pressed
    CMPB    #BUTTON_EDIT_20_KEY_TRANSPOSE
    BNE     .process_previous_button_event

    RTS

.process_previous_button_event:
    CLR     ui_btn_numeric_last_pressed
    JMP     ui_button_numeric


; ==============================================================================
; UI_BUTTON_EDIT_20_JUMP
; Thunk subroutine to provide a reachable offset for the jump table.
; ==============================================================================
ui_button_edit_20_jump:                         SUBROUTINE
    JMP     ui_button_edit_20_key_transpose

; ==============================================================================
; UI_BUTTON_EDIT_15_16_JUMP
; ==============================================================================
ui_button_edit_15_16_jump:                      SUBROUTINE
    JMP     ui_button_edit_15_16_eg_stage

; ==============================================================================
; UI_BUTTON_EDIT_12_13_JUMP
; ==============================================================================
ui_button_edit_12_13:                           SUBROUTINE
    JMP     ui_store_last_button_and_load_max_value

; ==============================================================================
; UI_BUTTON_FUNCTION_20_JUMP
; ==============================================================================
ui_button_function_20_jump:                     SUBROUTINE
    JMP ui_button_function_20

; ==============================================================================
; UI_BUTTON_FUNCTION_SET_ACTIVE_PARAMETER_JUMP
; ==============================================================================
ui_button_function_set_active_parameter_jump:   SUBROUTINE
    JMP ui_button_function_set_active_parameter

; ==============================================================================
; UI_BUTTON_FUNCTION_7_JUMP
; ==============================================================================
ui_button_function_7_jump:                      SUBROUTINE
    JMP ui_button_function_7

; ==============================================================================
; UI_BUTTON_FUNCTION_19_JUMP
; ==============================================================================
ui_button_function_19_jump:                     SUBROUTINE
    JMP ui_button_function_19

; ==============================================================================
; UI_BUTTON_FUNCTION_6_JUMP
; ==============================================================================
ui_button_function_6_jump:                      SUBROUTINE
    JMP ui_button_function_6

; ==============================================================================
; UI_BUTTON_EDIT_5
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Handles the numeric button 5 being pressed when the synth is in 'Edit Mode'.
;
; ARGUMENTS:
; Registers:
; * ACCB: The triggering front-panel numeric button number.
;
; MEMORY MODIFIED:
; * ui_btn_edit_5_sub_function
;
; REGISTERS MODIFIED:
; * ACCB
;
; ==============================================================================
ui_button_edit_5:                               SUBROUTINE
; If this button has been pressed twice in succession, cycle the sub-function.
    CMPB    ui_btn_numeric_last_pressed
    BNE     .store_sub_function

    TOGGLE_BUTTON_SUB_FUNCTION ui_btn_edit_5_sub_function

.store_sub_function:
    STAB    ui_btn_numeric_last_pressed
    TST     ui_btn_edit_5_sub_function
    BNE     .load_max_value

    DECB

.load_max_value:
    BRA     ui_button_edit_max_value_load_base


; ==============================================================================
; UI_BUTTON_EDIT_9_PMD_AMD
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Handles the numeric button 9 being pressed when the synth is in 'Edit Mode'.
; This cycles through the sub-functions associated with pitch, and amplitude
; modulation depth.
;
; ==============================================================================
ui_button_edit_9_pmd_amd:                       SUBROUTINE
; If this button has been pressed twice in succession, cycle the sub-function.
    CMPB    ui_btn_numeric_last_pressed
    BNE     .set_edit_parameter_address

; @TODO: Verify why this check is performed.
; Ordinarily this scenario should be unreachable.
    LDAA    ui_mode_memory_protect_state
    CMPA    #UI_MODE_MEMORY_SELECT
    BEQ     .set_edit_parameter_address

    TST     ui_flag_disable_edit_btn_9_mode_select
    BNE     .set_edit_parameter_address

    TOGGLE_BUTTON_SUB_FUNCTION ui_btn_edit_9_sub_function

.set_edit_parameter_address:
    CLR     ui_flag_disable_edit_btn_9_mode_select
    STAB    ui_btn_numeric_last_pressed
    TST     ui_btn_edit_9_sub_function
    BEQ     ui_button_edit_max_value_load_base

    LDX     #max_value_lfo_pitch_mod_depth
    BRA     ui_button_edit_get_active_parameter_address


; ==============================================================================
; UI_BUTTON_EDIT_6_7_8
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Handles the numeric buttons 6,7,8 being pressed when in 'Edit Mode'.
;
; ==============================================================================
ui_button_edit_6_7_8:                           SUBROUTINE
    STAB    ui_btn_numeric_last_pressed
; Falls-through below.

; ==============================================================================
; UI_BUTTON_EDIT_MAX_VALUE_LOAD_BASE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Loads the base offset of the currently selected 'edit parameter' based upon
; the last front-panel button press.
;
; ARGUMENTS:
; Registers:
; * ACCB: The triggering front-panel numeric button number.
;
; REGISTERS MODIFIED:
; * ACCB, IX
;
; ==============================================================================
ui_button_edit_max_value_load_base:                SUBROUTINE
    ASLB
    LDX     #table_edit_param_max_values_button_offset

; This has been changed from the original DX9 ROM functionality to avoid using
; a potentially unnecessary label just to add the offset value to IX.
    ABX
    BRA     ui_button_edit_get_active_parameter_address


; ==============================================================================
; UI_BUTTON_EDIT_10
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Handles the numeric buttons 10 being pressed when in 'Edit Mode'.
;
; ==============================================================================
ui_button_edit_10:                              SUBROUTINE
; If this button has been pressed twice in succession, cycle the sub-function.
    CMPB    ui_btn_numeric_last_pressed
    BNE     .store_sub_function

    TOGGLE_BUTTON_SUB_FUNCTION ui_btn_edit_10_sub_function

.store_sub_function:
    STAB    ui_btn_numeric_last_pressed
    TST     ui_btn_edit_10_sub_function
    BEQ     ui_button_edit_max_value_load_base

    LDX     #max_value_lfo_pitch_mod_sens
    BRA     ui_button_edit_get_active_parameter_address


; ==============================================================================
; UI_BUTTON_EDIT_14
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Handles the numeric buttons 14 being pressed when in 'Edit Mode'.
;
; ==============================================================================
ui_button_edit_14:                              SUBROUTINE
; If this button has been pressed twice in succession, cycle the sub-function.
    CMPB    ui_btn_numeric_last_pressed
    BNE     .store_sub_function

    TOGGLE_BUTTON_SUB_FUNCTION ui_btn_edit_14_sub_function

.store_sub_function:
    STAB    ui_btn_numeric_last_pressed
    TST     ui_btn_edit_14_sub_function
    BEQ     ui_load_max_value_from_button

    LDX     #max_value_oscillator_sync
    BRA     ui_button_edit_get_active_parameter_address


; ==============================================================================
; UI_BUTTON_EDIT_20_KEY_TRANSPOSE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Sets the 'Key Transpose Set' mode as being active, causing the next keypress
; to set the transpose root.
;
; ARGUMENTS:
; Registers:
; * ACCB: The numerical code of the last-pressed button.

; MEMORY MODIFIED:
; * ui_btn_numeric_last_pressed
; * key_tranpose_set_mode_active
; * ui_active_param_address
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_button_edit_20_key_transpose:                SUBROUTINE
    STAB    ui_btn_numeric_last_pressed

; @TODO: What is this flag?
    TST     ui_flag_blocks_key_transpose
    BNE     .clear_edit_parameter

    TST     patch_compare_mode_active
    BNE     .clear_edit_parameter

; Set the 'Key Transpose' mode as active.
    LDAB    #1
    STAB    <key_tranpose_set_mode_active

.clear_edit_parameter:
; Store the address of the 'null' edit parameter in the active edit parameter
; address pointer.
    LDX     #null_edit_parameter
    STX     ui_active_param_address

; Validate the current key transpose value.
    LDX     #patch_edit_key_transpose
    LDAA    #24
    JMP     ui_check_edit_parameter_against_max_value


; ==============================================================================
; UI_BUTTON_EDIT_15_16_EG_STAGE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Selects either the EG rate, or level as the active edit parameter.
; Multiple successive presses selects the active EG stage.
;
; ARGUMENTS:
; Registers:
; * ACCB: The numerical code of the last-pressed button.
;
; MEMORY MODIFIED:
; * ui_currently_selected_eg_stage
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_button_edit_15_16_eg_stage:                  SUBROUTINE
; If the last pressed button was identical to the previous, then increment
; the currently selected EG stage.
    CMPB    ui_btn_numeric_last_pressed
    BNE     ui_store_last_button_and_load_max_value

    LDAA    ui_currently_selected_eg_stage
    INCA
    ANDA    #%11
    STAA    ui_currently_selected_eg_stage
; Fall-through below.

; ==============================================================================
; UI_STORE_LAST_BUTTON_AND_LOAD_MAX_VALUE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Stores the latest button press as the 'last' pressed numeric button, and then
; loads the maximum value for this button's associated 'edit parameter'.
;
; ARGUMENTS:
; Registers:
; * ACCB: The numerical code of the last-pressed button.
;
; ==============================================================================
ui_store_last_button_and_load_max_value:        SUBROUTINE
    STAB    ui_btn_numeric_last_pressed
; Fall-through below.

; ==============================================================================
; UI_LOAD_MAX_VALUE_FROM_BUTTON
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Loads the max value of the currently selected edit parameter based upon the
; associated numeric button code.
;
; ARGUMENTS:
; Registers:
; * ACCB: The numerical code of the last-pressed button.
;
; ==============================================================================
ui_load_max_value_from_button:                  SUBROUTINE
    ASLB
    LDX     #table_max_param_values_edit_button_offset
    ABX
; Fall-through below.

; ==============================================================================
; UI_BUTTON_EDIT_GET_ACTIVE_PARAMETER_ADDRESS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; Loads, and parses the entry in the edit parameter offset, and maximum value
; table, then stores the active parameter address, and maximum value.
; Based upon the offset value, this subroutine determines whether the
; parameter being edited is an operator EG value, and operator value, or a
; patch value.
; @TODO: Fix the operator pointer code when the patch edit buffer is remade.
;
; ARGUMENTS:
; Registers:
; * IX:   A pointer to the edit parameter offset, and maximum value.
;
; MEMORY MODIFIED:
; * ui_active_param_address
; * ui_active_param_max_value
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_button_edit_get_active_parameter_address:    SUBROUTINE
    LDD     0,x
    STAB    ui_active_param_max_value
    TAB

; Is the param offset relative to the patch buffer, or the selected operator?
; If it is below '69', it's a patch parameter.
; If not, get the offset % 64.
    CMPB    #69
    BCS     .get_patch_buffer_offset

    ANDB    #%111111

.get_patch_buffer_offset:
    LDX     #patch_buffer_edit
    ABX

; If bit 7 of the offset is set, this parameter is either relative to an
; operator, or relative to an operator's envelope stage.
    TSTA
    BPL     .store_edit_param_address

; If bit 6 is set, this indicates the parameter is an envelope stage.
    BITA    #%1000000
    BEQ     .get_pointer_to_operator

    LDAB    ui_currently_selected_eg_stage
    ABX

; Get a pointer to the currently selected operator, and add it to the current
; parameter pointer.
.get_pointer_to_operator:
    LDAA    operator_selected_src
    COMA
    ANDA    #%11
    LDAB    #$F
    MUL
    ABX

.store_edit_param_address:
    STX     ui_active_param_address
    BRA     ui_load_active_param_ptr_and_max_value


; ==============================================================================
; UI_BUTTON_FUNCTION_6
; ==============================================================================
; DESCRIPTION:
; Handles a press to button '6' when the synth is in function mode.
; This routine cycles through the sub-functions associated with this button.
;
; ARGUMENTS:
; Registers:
; * ACCB: The triggering front-panel numeric button number.
;
; MEMORY MODIFIED:
; * ui_btn_function_6_sub_function
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_button_function_6:                           SUBROUTINE
; If this button has been pressed twice in succession, cycle the sub-function.
    CMPB    ui_btn_numeric_last_pressed
    BNE     .set_active_edit_parameter

; If the sub function is '1', test whether 'Sys Info' is available before
; incrementing the sub-function.
    LDAA    ui_btn_function_6_sub_function
    CMPA    #1
    BEQ     .is_sys_info_avail

    INCA

; After incrementing, compared the value against '3'.
; If the carry-bit is set, indicating it is equal or above, reset to '0'.
    CMPA    #3
    BCS     .store_sub_function

    CLRA
    BRA     .store_sub_function

.is_sys_info_avail:
; Test whether 'SYS INFO AVAIL' has been enabled.
; If this is not enabled, do not increment the sub-function to '2'.
; This is because MIDI transmission is not permitted if SysEx is disabled.
    TST     sys_info_avail
    BNE     .sys_info_available

; If SysEx transmission is disabled, toggle the value back to '0'.
    CLRA
    BRA     .store_sub_function

.sys_info_available:
; Increment the sub-function if SysEx transmission is enabled.
    INCA

.store_sub_function:
    STAA    ui_btn_function_6_sub_function
    TBA

.set_active_edit_parameter:
    TST     ui_btn_function_6_sub_function
    BEQ     ui_button_function_set_active_parameter

    ADDA    #16
    BRA     ui_button_function_set_active_parameter


; ==============================================================================
; UI_BUTTON_FUNCTION_7
; ==============================================================================
; DESCRIPTION:
; Handles a press to button '7' when the synth is in function mode.
;
; ==============================================================================
ui_button_function_7:                           SUBROUTINE
; If this button has been pressed twice in succession, cycle the sub-function.
    CMPB    ui_btn_numeric_last_pressed
    BNE     ui_button_function_set_active_parameter

    TOGGLE_BUTTON_SUB_FUNCTION ui_btn_function_7_sub_function

    BRA     ui_button_function_set_active_parameter


; ==============================================================================
; UI_BUTTON_FUNCTION_19
; ==============================================================================
; DESCRIPTION:
; Handles a press to button '19' when the synth is in function mode.
;
; ==============================================================================
ui_button_function_19:                          SUBROUTINE
; If this button has been pressed twice in succession, cycle the sub-function.
    CMPB    ui_btn_numeric_last_pressed
    BNE     ui_button_function_set_active_parameter

    CYCLE_3_BUTTON_SUB_FUNCTIONS ui_btn_function_19_sub_function

    TBA
    BRA     ui_button_function_set_active_parameter


; ==============================================================================
; UI_BUTTON_FUNCTION_20
; ==============================================================================
; DESCRIPTION:
; Handles a press to button '20' when the synth is in function mode.
;
; ARGUMENTS:
; Registers:
; * ACCB: The triggering front-panel numeric button number.
;
; MEMORY MODIFIED:
; * ui_btn_function_6_sub_function
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_button_function_20:                          SUBROUTINE
    LDAA    #BUTTON_FUNCTION_20
    LDAB    #BUTTON_FUNCTION_20
; Falls-through below.

; ==============================================================================
; UI_BTN_FN_MODE_SET_ACTIVE_PARAM
; ==============================================================================
; DESCRIPTION:
; This subroutine sets the currently selected 'Edit Parameter' and its
; associated maximum value when a numeric button is pressed while the synth is
; in 'Function Mode'.
;
; ARGUMENTS:
; Registers:
; * ACCA: The 'code' of the initial function mode button press which triggered
;         this changing of the current 'Edit Parameter'.
;         This will be used to look up the parameter pointer and maximum value
;         in the associated table.
;
; MEMORY MODIFIED:
; * ui_active_param_address
; * ui_active_param_max_value
;
; ==============================================================================
ui_button_function_set_active_parameter:        SUBROUTINE
; '20' is subtracted from this value on account of the function mode
; button codes beginning at '20'.
    SUBA    #20

; Test whether the last button press was '23' (Button 4/ Porta Mode).
; If the synth is in polyphonic mode, do not allow any editing of this
; parameter, as there is only one portamento mode available.
    CMPA    #(BUTTON_FUNCTION_4 - 20)
    BNE     .get_active_parameter_ptr

    TST     mono_poly
    BNE     .get_active_parameter_ptr

; Load the index for the 'Null' edit parameter.
; @TODO
    LDAA    #20

.get_active_parameter_ptr:
; Multiply the index by 3, since each entry in this table is 3 bytes long.
; It has the format:
; - 'Pointer to edit parameter' (2 bytes)
; - 'Maximum Value' (1 byte)
    STAB    ui_btn_numeric_last_pressed
    LDAB    #3
    MUL

    LDX     #table_max_parameter_values_function_mode
    ABX

; Store a pointer to the parameter currently being edited.
    LDD     0,x
    STD     ui_active_param_address

; Store the maximum value of the parameter currently being edited.
    LDAB    2,x
    STAB    ui_active_param_max_value
    CLR     ui_btn_function_19_patch_init_prompt
; Fall-through below.

; ==============================================================================
; UI_LOAD_ACTIVE_PARAM_PTR_AND_MAX_VALUE
; ==============================================================================
; DESCRIPTION:
; Loads the active edit parameter pointer, and max value.
; @TODO
;
; ==============================================================================
ui_load_active_param_ptr_and_max_value:         SUBROUTINE
    LDX     ui_active_param_address
    LDAA    ui_active_param_max_value
; Fall-through below.

; ==============================================================================
; UI_CHECK_EDIT_PARAMETER_AGAINST_MAX_VALUE
; ==============================================================================
; DESCRIPTION:
; Validates the currently selected 'edit parameter' against its maximum
; allowed value. If it has exceeded the maximum value, reset it to '0'.
;
; ==============================================================================
ui_check_edit_parameter_against_max_value:      SUBROUTINE
; Compare the current parameter value against the maximum.
; If it has exceeded the maximum, and thus set the carry bit, reset it to 0.
    CMPA    0,x
    BCC     .send_parameter_change

    CLR     0,x

.send_parameter_change:
; Send the newly active parameter via SysEx.
; This is performed to allow remote control of a separate DX9.
    JMP     midi_sysex_tx_param_change

; This hack was adapted from the original DX9 ROM.
; I can't recall the original use of this offset.
table_edit_param_max_values_button_offset:      EQU (#table_max_param_values_edit_mode - 6)

; Since the edit mode front-panel buttons only start editing parameters at
; button 5, and the two-byte entries in the table below are indexed by button
; number, this pointer subtracts 8 to start from button 5.
table_max_param_values_edit_button_offset:      EQU (#table_max_param_values_edit_mode - 8)

; ==============================================================================
; Edit mode parameter offset, and max value table.
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; This table contains an array of entries used to get a pointer to the
; currently selected 'Edit Mode' parameter, and its associated max value.
; The first byte of each entry is the offset, as well as a set of flags.
; These flags determine whether the offset applies to the operator EG,
; operator, or the patch as a whole. The offset will be used accordingly to set
; up a pointer relative to the start of the patch edit buffer.
; The second byte is the maximum value for this parameter.
; ==============================================================================
table_max_param_values_edit_mode:
    DC.B $3C ; Algorithm
    DC.B 7
    DC.B $3D ; Feedback
    DC.B 7
    DC.B $43 ; LFO wave.
    DC.B 5
    DC.B $3F ; LFO speed.
    DC.B 99
    DC.B $40 ; LFO Delay.
    DC.B 99
    DC.B $42 ; Amp mod?
    DC.B 99
    DC.B $8A ; Pitch mod?
    DC.B 3
    DC.B $8C
    DC.B 31
    DC.B $8D
    DC.B 99
    DC.B $8E
    DC.B 14
    DC.B $C0
    DC.B 99
    DC.B $C4
    DC.B 99
    DC.B $89
    DC.B 7
    DC.B $88
    DC.B 99
    DC.B $8B
    DC.B 99
max_value_oscillator_sync:
    DC.B 62
    DC.B 1
max_value_lfo_pitch_mod_depth:
    DC.B 65
    DC.B 99
max_value_lfo_pitch_mod_sens:
    DC.B $44
    DC.B 7

; ==============================================================================
; Function mode parameter pointer, and max value table.
; This table contains an array of pointers to the 'Function Mode' parameters,
; and their maximum allowed values.
; This table is used by the UI button functions.
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; ==============================================================================
table_max_parameter_values_function_mode:
    DC.W master_tune
    DC.B 127
    DC.W mono_poly
    DC.B 1
    DC.W pitch_bend_range
    DC.B 12
    DC.W portamento_mode
    DC.B 1
    DC.W portamento_time
    DC.B 99
    DC.W midi_channel_rx
    DC.B 15
    DC.W null_edit_parameter
    DC.B 1
    DC.W null_edit_parameter
    DC.B 1
    DC.W null_edit_parameter
    DC.B 1
    DC.W tape_remote_output_polarity
    DC.B 1
    DC.W mod_wheel_range
    DC.B 99
    DC.W mod_wheel_assign
    DC.B 1
    DC.W mod_wheel_amp
    DC.B 1
    DC.W mod_wheel_eg_bias
    DC.B 1
    DC.W breath_control_range
    DC.B 99
    DC.W breath_control_assign
    DC.B 1
    DC.W breath_control_amp
    DC.B 1
    DC.W breath_control_eg_bias
    DC.B 1
    DC.W null_edit_parameter
    DC.B 1
    DC.W memory_protect
    DC.B 1
    DC.W null_edit_parameter
    DC.B 1
    DC.W sys_info_avail
    DC.B 1
