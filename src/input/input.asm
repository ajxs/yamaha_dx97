; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; input.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the functionality associated with processing the synth's
; hardware input.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; Raw input button codes.
; These are the codes returned from scanning the front panel input.
; ==============================================================================
INPUT_BUTTON_YES:                               EQU 1
INPUT_BUTTON_NO:                                EQU 2
INPUT_BUTTON_STORE:                             EQU 3
INPUT_BUTTON_FUNCTION:                          EQU 4
INPUT_BUTTON_EDIT:                              EQU 5
INPUT_BUTTON_PLAY:                              EQU 7
INPUT_BUTTON_1:                                 EQU 8
INPUT_BUTTON_10:                                EQU 17
INPUT_BUTTON_20:                                EQU 27

; ==============================================================================
; MAIN_INPUT_HANDLER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC3A3
; DESCRIPTION:
; This is the entry point for the synth's input handling.
; This is where the synth's analog front-panel input is read, and acted upon.
; The subroutine is called from the main loop, and the source of the last
; input event is used as an index into a switch table, which initiates the
; synth's main UI functionality.
;
; @TODO: Figure out how it's handled when nothing is pressed?
; Potentially this just defaults to the slider.
;
; ==============================================================================
main_input_handler:
    CLR     main_patch_event_flag
    JSR     input_read_front_panel
; Falls-through below.

; ==============================================================================
; MAIN_INPUT_HANDLER_PROCESS_BUTTON
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC3A9
; DESCRIPTION:
; Processes an individual front-panel button press.
; This subroutine is called from various places to arbitrarily process an
; individual front panel button press.
;
; ARGUMENTS:
; Registers:
; * ACCB: The front-panel button code.
;
; MEMORY MODIFIED:
; * key_transpose_set_mode_active
; * ui_flag_blocks_key_transpose
;
; ==============================================================================
main_input_handler_process_button:              SUBROUTINE
; Is the last analog event code below 3? If so, branch.
; This indicates it's either a slider, or Yes/No button event.
    CMPB    #INPUT_BUTTON_STORE
    BCS     main_input_handler_dispatch

; If any key other than the data input slider, or 'Yes/No' are pressed
; clear the key transpose mode flag.
    CLR     key_transpose_set_mode_active
    CLR     ui_flag_blocks_key_transpose
; Falls-through below.

; ==============================================================================
; MAIN_INPUT_HANDLER_DISPATCH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; This is the main jumpoff where the different front-panel button
; functionality is initiated, based upon the UI input mode.
;
; ARGUMENTS:
; Registers:
; * ACCB: The front-panel button code.
;
; ==============================================================================
main_input_handler_dispatch:
    LDAA    ui_mode_memory_protect_state
    JSR     jumpoff

    DC.B input_slider - *
    DC.B 1
    DC.B input_button_yes_no - *
    DC.B 3
    DC.B input_button_main - *
    DC.B 8
    DC.B input_button_numeric - *
    DC.B 0


; ==============================================================================
; INPUT_SLIDER
; ==============================================================================
; @PRIVATE
; DESCRIPTION:
; The main input handler for the front-panel 'Data Entry' slider.
;
; ARGUMENTS:
; Registers:
; * ACCA: The UI Input Mode.
; * ACCB: The triggering front-panel input code.
;
; ==============================================================================
input_slider:                                   SUBROUTINE
; Exit if the synth is in 'Play' mode.
    CMPA    #UI_MODE_PLAY
    BEQ     .exit

; Check if the current UI state is in 'Store' mode. If so, exit.
    ANDA    #%1100
    BNE     .exit

    JSR     ui_slider
    TST     main_patch_event_flag
    BNE     input_update_led_and_menu

.exit:
    RTS


; ==============================================================================
; INPUT_BUTTON_YES_NO
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC3CF
; @CHANGED_FOR_6_OP
; @PRIVATE
; DESCRIPTION:
; The main input handler for when the front-panel 'Yes', or 'No' buttons are
; pressed.
;
; ARGUMENTS:
; Registers:
; * ACCA: The UI Input Mode.
; * ACCB: The triggering button code. In this case, either YES(1), or NO(2).
;
; ==============================================================================
input_button_yes_no:                            SUBROUTINE
; Exit if the synth is in 'Play' mode.
    CMPA    #UI_MODE_PLAY
    BEQ     .exit

; Check if the current UI state is in 'Store' mode. If so, exit.
    ANDA    #%1100
    BNE     .exit

; The following subroutine call sets the carry-bit to indicate that the
; corresponding UI menu item is a 'Yes/No' prompt, as opposed to representing a
; numeric value that can be incremented, or decremented.
; This will cause a jump to update the LED, print the menu, and exit.
; Otherwise it will continue to process incrementing, or decrementing the
; currently selected parameter.
    JSR     ui_yes_no
    BCS     input_update_led_and_menu

; This section was moved from the UI increment/decrement functionality in
; the original DX9 ROM, since it isn't used anywhere else.
    LDX     ui_active_param_address
    CPX     #master_tune
    BEQ     .update_ui_and_exit

; Send a MIDI CC signal indicating the increment/decrement.
    JSR     midi_tx_cc_increment_decrement

    JSR     ui_increment_decrement_parameter

.update_ui_and_exit:
    BRA     input_update_led_and_menu

.exit:
    RTS


; ==============================================================================
; INPUT_BUTTON_MAIN
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC3DD
; @PRIVATE
; DESCRIPTION:
; Handles a 'main' front-panel button being pressed.
; These buttons are the main non-numeric, non data-entry buttons.
;
; ARGUMENTS:
; Registers:
; * ACCA: UI Input Mode.
; * ACCB: The analog input code passed from the main input handler routine.
;         This represents the source of the last front-panel input.
;         This will be converted to a relative value representing the last
;         'main' button pressed, and used as an input to a switch table.
;         These values are:
;          - 0: "STORE"
;          - 1: ???
;          - 2: "FUNCTION"
;          - 3: "EDIT"
;          - 4: "PLAY "
;
; ==============================================================================
input_button_main:                              SUBROUTINE
    SUBB    #3

; 3 is subtracted from the input source code on account of the 'main'
; front-panel buttons starting at index 3.
    JSR     ui_button_main
    BRA     input_update_led_and_menu


; ==============================================================================
; INPUT_BUTTON_NUMERIC
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC3E4
; @PRIVATE
; DESCRIPTION:
; Main input handler function for when the triggering front-panel button press
; is one of the numeric buttons (1-20).
;
; ARGUMENTS:
; Registers:
; * ACCA: UI Input Mode
; * ACCB: Front-panel switch number.
;
; ==============================================================================
input_button_numeric:                           SUBROUTINE
; Subtract 8, since the numeric buttons start at 8.
    SUBB    #8
    CMPA    #10

; If ACCA >= 10, clear.
    BCS     .jumpoff
    CLRA

.jumpoff:
    JSR     jumpoff_indexed_from_acca

; ==============================================================================
; Numeric Button Handler Functions.
; ==============================================================================
    DC.B input_button_numeric_function_mode - *
    DC.B input_button_numeric_edit_mode - *
    DC.B input_button_numeric_play_mode - *
    DC.B input_update_led_and_menu - *

; ==============================================================================
; Numeric Button Handler Functions: Memory Protect Disabled.
; ==============================================================================
    DC.B input_update_led_and_menu - *
    DC.B input_button_numeric_eg_copy_mode - *
    DC.B input_button_numeric_store_mode - *
    DC.B input_update_led_and_menu - *

; ==============================================================================
; Numeric Button Handler Functions: Memory Protect Enabled.
; ==============================================================================
    DC.B input_update_led_and_menu - *
    DC.B input_button_numeric_eg_copy_mode - *


; ==============================================================================
; INPUT_BUTTON_NUMERIC_FUNCTION_MODE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC3F8
; @PRIVATE
; DESCRIPTION:
; Handles a front-panel numeric button press while the synth's user-interface
; is in 'Function Mode'.
; This function adds '20' to the button number, since the 'Function Mode'
; button codes start after the 'Edit Mode' button codes (0-19).
; This function then calls the main UI numeric button handler, which triggers
; the specific functionality associated with the assigned button code.
;
; ARGUMENTS:
; Registers:
; * ACCA: UI Input Mode
; * ACCB: Front-panel numeric switch number, starting at index 0.
;         '20' is added to this number to properly index the function mode
;         front-panel buttons.
;
; ==============================================================================
input_button_numeric_function_mode:             SUBROUTINE
    ADDB    #20
; Falls-through below.

; ==============================================================================
; INPUT_BUTTON_NUMERIC_EDIT_MODE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC3FA
; @PRIVATE
; DESCRIPTION:
; Handles a front-panel numeric button press while the synth's user-interface
; is in 'Edit Mode'.
; This function then calls the main UI numeric button handler, which triggers
; the specific functionality associated with the assigned button code.
;
; ARGUMENTS:
; Registers:
; * ACCA: UI Input Mode
; * ACCB: Front-panel numeric switch number, starting at index 0.
;
; ==============================================================================
input_button_numeric_edit_mode:                 SUBROUTINE
    JSR     ui_button_numeric
    BRA     input_update_led_and_menu


; ==============================================================================
; INPUT_BUTTON_NUMERIC_PLAY_MODE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC3FF
; @CHANGED_FOR_6_OP
; @PRIVATE
; DESCRIPTION:
; Handles a front-panel numeric button press while the synth's user-interface
; is in 'Play Mode'. Specifically this means 'Memory Select' mode while
; 'Memory Protect' is enabled.
; Initiates loading a patch from a front-panel numeric button press.
;
; ARGUMENTS:
; Registers:
; * ACCA: UI Input Mode
; * ACCB: Front-panel numeric switch number, starting at index 0.
;
; ==============================================================================
input_button_numeric_play_mode:                 SUBROUTINE
; If the numeric button is higher than the patch count, exit.
    CMPB    #PATCH_BUFFER_COUNT
    BCC     .exit

    JSR     patch_load
.exit:
    BRA     input_update_led_and_menu


; ==============================================================================
; INPUT_BUTTON_NUMERIC_EG_COPY_MODE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC404
; @PRIVATE
; DESCRIPTION:
; Handles a front-panel numeric button press while the synth's user-interface
; is in 'EG Copy Mode'. Specifically this means 'Edit' mode while the memory
; protect bits are set in the UI mode.
; Initiates copying an operator's EG settings from a front-panel numeric
; button press.
;
; ARGUMENTS:
; Registers:
; * ACCB: Front-panel numeric switch number, starting at index 0.
;
; ==============================================================================
input_button_numeric_eg_copy_mode:              SUBROUTINE
    JSR     patch_operator_eg_copy
    BRA     input_update_led_and_menu


; ==============================================================================
; INPUT_BUTTON_NUMERIC_STORE_MODE
; ==============================================================================
; @PRIVATE
; DESCRIPTION:
; Handles a front-panel numeric button press while the synth's user-interface
; is in 'Store Mode'. Specifically this means 'Memory Select' mode while
; 'Memory Protect' is disabled.
; Initiates saving a patch from a front-panel numeric button press. The number
; of the key pressed will be passed as the index to save the patch to.
;
; ARGUMENTS:
; Registers:
; * ACCB: Front-panel numeric switch number, starting at index 0.
;
; ==============================================================================
input_button_numeric_store_mode:                SUBROUTINE
    JSR     patch_save
; Falls-through below.

; ==============================================================================
; INPUT_UPDATE_LED_AND_MENU
; ==============================================================================
; @PRIVATE
; DESCRIPTION:
; This call serves as the exit point for many subroutines.
; It updates the LED, and prints the menu.
;
; ==============================================================================
input_update_led_and_menu:                      SUBROUTINE
    JMP     ui_print_update_led_and_menu
