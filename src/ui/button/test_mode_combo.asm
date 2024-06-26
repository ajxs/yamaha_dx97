; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; ui/button/test_mode_combo.asm
; ==============================================================================
; DESCRIPTION:
; Contains the code for testing for the test mode button combination.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI_BUTTON_CHECK_TEST_MODE_COMBINATION
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE176
; DESCRIPTION:
; Tests whether the test mode button combination (Function + 10 + 20) are
; currently active.
;
; ARGUMENTS:
; Registers:
; * ACCA: UI Input Mode
; * ACCB: Front-panel numeric switch number code.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; MEMORY MODIFIED:
; * ui_test_mode_button_combo_state
;
; RETURNS:
; * ACCB: If the test mode button combination is active, the corresponding
;         test mode button state will be returned in ACCB.
;
; ==============================================================================
ui_button_check_test_mode_combination:          SUBROUTINE
    CMPB    #BUTTON_FUNCTION_10
    BEQ     .button_10_is_down

    CMPB    #BUTTON_FUNCTION_20
    BEQ     .button_20_is_down

.reset_test_mode_button_state:
; Reset the test button combination state.
    CLRA

.store_test_mode_button_state:
    STAA    <ui_test_mode_button_combo_state

.exit:
    RTS

.button_10_is_down:
    JSR     ui_button_check_test_mode_button_function
    TSTA
    BEQ     .reset_test_mode_button_state

    LDAA    #1
    BRA     .store_test_mode_button_state

.button_20_is_down:
; If the triggering button press was 'button 20', test whether button 10 was
; previously pressed, and the first stage of the 'test button combination'
; has been assigned.
    TST     ui_test_mode_button_combo_state
    BEQ     .exit

; Test whether the 'Store', and '10' buttons are currently being pressed.
    JSR     ui_button_check_test_mode_button_function
    TSTA
    BEQ     .reset_test_mode_button_state

    JSR     ui_button_check_test_mode_button_10
    TSTA
    BEQ     .reset_test_mode_button_state

; Set the UI Button State to display the Test Mode entry prompt.
    CLR     ui_test_mode_button_combo_state
    LDAB    #BUTTON_TEST_ENTRY_COMBO
    BRA     .exit


; ==============================================================================
; UI_BUTTON_CHECK_TEST_MODE_BUTTON_FUNCTION
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE1A4
; @PRIVATE
; DESCRIPTION:
; Tests whether the 'Function' button is currently being pressed, as part of
; testing the test mode button combination.
;
; REGISTERS MODIFIED:
; * ACCA
;
; RETURNS:
; * ACCA: The state of the 'Function' button.
;
; ==============================================================================
ui_button_check_test_mode_button_function:      SUBROUTINE
    LDAA    <io_port_1_data
    ANDA    #%11110000
    STAA    <io_port_1_data

    DELAY_SINGLE
    LDAA    <key_switch_scan_driver_input
    ANDA    #KEY_SWITCH_LINE_0_BUTTON_FUNCTION

    RTS


; ==============================================================================
; UI_BUTTON_CHECK_TEST_MODE_BUTTON_10
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE1B1
; @PRIVATE
; DESCRIPTION:
; Tests whether the '10' button is currently being pressed, as part of
; testing the test mode button combination.
;
; REGISTERS MODIFIED:
; * ACCA
;
; RETURNS:
; * ACCA: The state of the '10' button.
;
; ==============================================================================
ui_button_check_test_mode_button_10:            SUBROUTINE
    LDAA    <io_port_1_data
    ANDA    #%11110000
    ORAA    #KEY_SWITCH_SCAN_DRIVER_SOURCE_BUTTONS_2
    STAA    <io_port_1_data

    DELAY_SINGLE
    LDAA    <key_switch_scan_driver_input
    ANDA    #KEY_SWITCH_LINE_1_BUTTON_10

    RTS
