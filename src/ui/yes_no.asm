; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; ui/input/yes_no.asm
; ==============================================================================
; DESCRIPTION:
; Contains the functionality related to user input when the 'Yes', or 'No'
; buttons are pressed.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI_YES_NO
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC3CF
; DESCRIPTION:
; Handles user input when the button pressed was 'Yes', or 'No'.
;
; ARGUMENTS:
; Registers:
; * ACCA: The UI Input Mode.
; * ACCB: The triggering button code. In this case, either YES(1), or NO(2).
;
; RETURNS:
; * CC:C: The CPU carry bit is set in the case that the subroutine was called
; after a function key press that prompts for a single 'Yes/No' answer. As
; opposed to an edit parameter that requires incrementing or decrementing.
; This is used by the calling function to determine whether it should
; fall-through to the increment/decrement routine.
;
; ==============================================================================
ui_yes_no:                                      SUBROUTINE
    TBA

; If the last pressed numeric button was not a 'Function Mode' button, this
; will be caught in the jumpoff's first entry and ignored.
    LDAB    ui_btn_numeric_last_pressed
    JSR     jumpoff

    DC.B ui_yes_no_exit_numeric_parameter - *
    DC.B 25
    DC.B ui_yes_no_fn_btn_6 - *
    DC.B 26
    DC.B ui_yes_no_fn_btn_7_8_9 - *
    DC.B 29
    DC.B ui_yes_no_exit_numeric_parameter - *
    DC.B 38
    DC.B ui_yes_no_fn_btn_19 - *
    DC.B 39
    DC.B ui_yes_no_exit_numeric_parameter - *
    DC.B 40
    DC.B ui_yes_no_test_entry - *
    DC.B 41
    DC.B ui_yes_no_exit_numeric_parameter - *
    DC.B 0

; ==============================================================================
; Exit, and clear the carry bit in the case that the parameter was numeric.
; ==============================================================================
ui_yes_no_exit_numeric_parameter:
    TAB
    CLC
    RTS


; ==============================================================================
; UI_YES_NO_FN_BTN_6
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE300
; DESCRIPTION:
; 'Yes/No' button handler when the synth is in function mode, and the previous
; front-panel button press was button '6'.
;
; ARGUMENTS:
; Registers:
; * ACCA: The triggering button code. In this case, either YES(1), or NO(2).
;
; ==============================================================================
ui_yes_no_fn_btn_6:                             SUBROUTINE
; Test if the sub-function is the MIDI channel, or the 'Sys Info' status.
; If so, it is a numeric parameter which can be incremented, or decremented by
; the appropriate handler.
    LDAB    #2
    CMPB    ui_btn_function_6_sub_function
    BNE     ui_yes_no_exit_numeric_parameter

; Otherwise it is the SysEx transmission prompt.
; Test whether the last button was 'Yes'. If so, begin the bulk dump.
    CMPA    #INPUT_BUTTON_YES
    BNE     .exit

    JSR     midi_sysex_tx_bulk_data_all_patches

.exit:
    SEC
    RTS


; ==============================================================================
; UI_YES_NO_FN_BTN_7_8_9
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE310
; DESCRIPTION:
; 'Yes/No' button handler when the synth is in function mode, and the previous
; front-panel button press was button '7', '8', or '9'.
;
; ARGUMENTS:
; Registers:
; * ACCA: The triggering button code. In this case, either YES(1), or NO(2).
;
; MEMORY MODIFIED:
; * ui_btn_function_7_sub_function
;
; ==============================================================================
ui_yes_no_fn_btn_7_8_9:                         SUBROUTINE
    CMPA    #INPUT_BUTTON_YES
    BNE     .cancel

    JSR     tape_ui_jumpoff
    BRA     .exit

.cancel:
; Test whether button 7 has been pressed multiple times in sequence.
; If the triggering button press was not 7, nothing will happen here.
    LDAB    #BUTTON_FUNCTION_7
    CMPB    ui_btn_numeric_last_pressed
    BNE     .exit

; If so, cycle the button's 'sub function'.
; This is achieved by incrementing, and then masking with '1', since this is
; effectively toggling between two-states.
    LDAA    ui_btn_function_7_sub_function
    INCA
    ANDA    #1
    STAA    ui_btn_function_7_sub_function

.exit:
    SEC
    RTS


; ==============================================================================
; UI_YES_NO_FN_BTN_19
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE32B
; DESCRIPTION:
; 'Yes/No' button handler when the synth is in function mode, and the previous
; front-panel button press was button '19'.
;
; ARGUMENTS:
; Registers:
; * ACCA: The triggering button code. In this case, either YES(1), or NO(2).
;
; MEMORY MODIFIED:
; * ui_btn_function_19_patch_init_prompt
;
; ==============================================================================
ui_yes_no_fn_btn_19:                            SUBROUTINE
; If the function mode button 19 sub-function is to print the battery mode,
; yes/no has no effect, so exit.
    LDAB    #2
    CMPB    ui_btn_function_19_sub_function
    BEQ     .exit

; Test whether the 'Patch Init' prompt is active.
    TST     ui_btn_function_19_patch_init_prompt
    BEQ     .set_prompt_flag

; Since some user action (Yes/No) has been taken, clear the prompt flag,
; then test whether the button pressed was 'Yes'. If not, exit.
    CLR     ui_btn_function_19_patch_init_prompt
    CMPA    #INPUT_BUTTON_YES
    BNE     .exit

; If the button pressed was yes, jump to this subroutine, then return to
; set the carry flag and exit.
    JSR     ui_patch_init_recall
    BRA     .exit

.set_prompt_flag:
; If the button pressed was not 'Yes', proceed to cycle the sub function.
    CMPA    #INPUT_BUTTON_YES
    BNE     .cycle_button_sub_function

; If the button was yes, enable the 'Patch Init' prompt.
    STAA    <ui_btn_function_19_patch_init_prompt
    BRA     .exit

.cycle_button_sub_function:
; Cycle the button's 'sub function'.
; This is achieved by incrementing, and then masking with '1', since this is
; effectively toggling between two-states.
    LDAA    ui_btn_function_19_sub_function
    INCA
    ANDA    #1
    STAA    ui_btn_function_19_sub_function

.exit:
    SEC
    RTS


; ==============================================================================
; UI_PATCH_INIT_RECALL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE1C0
; DESCRIPTION:
; Performs the Patch 'Initialise'/'Recall' user-interface functionality.
;
; ==============================================================================
ui_patch_init_recall:                           SUBROUTINE
    LDAA    ui_btn_function_19_sub_function
    BEQ     .edit_recall
    DECA
    BEQ     .patch_init

.exit:
    RTS

.edit_recall:
    JSR     patch_edit_recall
    BRA     .set_ui_to_edit_mode

.patch_init:
    JSR     patch_initialise
; Reset the selected operator.
    CLRA
    STAA    operator_selected_src

.set_ui_to_edit_mode:
; After initialising the patch, or recalling the compare buffer, set the
; synth's UI to 'Edit' mode.
    JSR     ui_button_function_edit
    BRA     .exit


; ==============================================================================
; UI_YES_NO_TEST_ENTRY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE356
; DESCRIPTION:
; 'Yes/No' button handler when the synth is presenting the 'Test Mode' entry
; prompt. The 'Yes' button will initiate the synth's diagnosic mode.
;
; ARGUMENTS:
; Registers:
; * ACCA: The triggering button code. In this case, either YES(1), or NO(2).
;
; ==============================================================================
ui_yes_no_test_entry:                           SUBROUTINE
    CMPA    #INPUT_BUTTON_YES
    BNE     ui_test_entry_reload_patch_and_exit

    JSR     test_entry

ui_test_entry_reload_patch_and_exit:
    CLR     ui_test_mode_button_combo_state
    JSR     ui_button_function_play
    LDAB    patch_index_current
    JSR     patch_load_store_edit_buffer_to_compare
    SEC

    RTS
