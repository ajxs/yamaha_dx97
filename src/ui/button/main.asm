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
; ui/button/main.asm
; ==============================================================================
; DESCRIPTION:
; Contains the subroutines that handle buttonpresses to tye synth's 'main'
; front-panel buttons. These being 'Store', 'Function', 'Edit', 'Memory'.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI_BUTTON_MAIN
; ==============================================================================
; DESCRIPTION:
; Main UI subroutine for the 'main', non-numeric, front-panel buttons.
; This subroutine creates an index into a jump table based upon the current
; UI input mode, and then jumps to the relevant function for button that
; was pressed, based upon the input mode.
;
; ARGUMENTS:
; Registers:
; * ACCA: UI Input Mode.
; * ACCB: 'Main' front-panel buttons indexed from 0.
;          - 0: "STORE"
;          - 1: ???
;          - 2: "FUNCTION"
;          - 3: "EDIT"
;          - 4: "MEMORY "
;
; ==============================================================================
ui_button_main:                                 SUBROUTINE
; Mask these bits to ignore the memory protect flags.
    ANDA    #%11
    BEQ     .clamp_index

    CMPA    #UI_MODE_UNKNOWN
    BEQ     .clamp_index

.get_index_loop:
; Create an index into the UI main button function table based upon the
; current UI mode.
; This works by adding 5 to the button index per mode index.
    ADDB    #5
    DECA
    BNE     .get_index_loop

.clamp_index:
; Clamp the index at 14.
    CMPB    #15
    BCS     .jumpoff

    CLRB

.jumpoff:
    JSR     jumpoff_indexed

; ==============================================================================
; UI Input Main Button Handlers.
; ==============================================================================
    DC.B .exit - *
    DC.B .exit - *
    DC.B .exit - *
    DC.B ui_button_function_edit - *
    DC.B ui_button_function_memory_select - *

; ==============================================================================
; UI Input Main Button Handlers: Memory Protect Disabled.
; ==============================================================================
    DC.B ui_button_edit_store - *
    DC.B ui_memory_protect_state_clear - *
    DC.B ui_button_edit_function - *
    DC.B ui_patch_compare_toggle - *
    DC.B ui_button_edit_memory_select - *

; ==============================================================================
; UI Input Main Button Handlers: Memory Protect Enabled.
; ==============================================================================
    DC.B ui_memory_protect_state_set - *
    DC.B ui_memory_protect_state_clear - *
    DC.B ui_mode_fn - *
    DC.B ui_mode_edit - *
    DC.B .exit - *

.exit:
    RTS

; ==============================================================================
; UI_BUTTON_EDIT_FUNCTION
; ==============================================================================
; DESCRIPTION:
; Handles an 'Edit' keypress while the synth's UI is in 'Function' mode.
; @TODO
;
; ==============================================================================
ui_button_edit_function:                        SUBROUTINE
    JSR     ui_button_edit_save_previous
; Falls-through below.

; ==============================================================================
; UI_MODE_FN
; ==============================================================================
; DESCRIPTION:
; Sets the synt's UI mode to 'Function'
;
; ==============================================================================
ui_mode_fn:                                     SUBROUTINE
    CLR     ui_mode_memory_protect_state
    LDAB    ui_btn_numeric_previous_fn_mode
    JMP     ui_button_numeric


; ==============================================================================
; UI_BUTTON_FUNCTION_EDIT
; ==============================================================================
; DESCRIPTION:
; Handles a 'Function' keypress while the synth's UI is in 'Edit' mode.
;
; ==============================================================================
ui_button_function_edit:                        SUBROUTINE
    JSR     ui_button_function_save_previous
; Falls-through below.

; ==============================================================================
; UI_MODE_EDIT
; ==============================================================================
; DESCRIPTION:
; Sets the synth's UI into 'Edit' mode.
;
; ==============================================================================
ui_mode_edit:                                   SUBROUTINE
    LDAA    #UI_MODE_EDIT
    STAA    ui_mode_memory_protect_state

; @TODO: Verify why these two UI flags are necessary.
    STAA    ui_flag_blocks_key_transpose
    STAA    ui_flag_disable_edit_btn_9_mode_select
    LDAB    ui_btn_numeric_previous_edit_mode
    JMP     ui_button_numeric


; ==============================================================================
; UI_BUTTON_FUNCTION_MEMORY_SELECT
; ==============================================================================
; DESCRIPTION:
; Handles a 'Memory Select' keypress while the UI is in 'Function' mode.
;
; ==============================================================================
ui_button_function_memory_select:               SUBROUTINE
    JSR     ui_button_function_save_previous
    JMP     ui_button_memory_select


; ==============================================================================
; UI_MODE_EDIT_BTN_STORE
; ==============================================================================
; DESCRIPTION:
; Handles the 'STORE' button being pressed while the synth's UI is in
; 'Edit Mode'. If the synth is not currently in 'Patch Compare' mode, this will
; place the synth in 'Store' mode.
;
; ==============================================================================
ui_button_edit_store:                           SUBROUTINE
    TST     patch_compare_mode_active
    BEQ     ui_memory_protect_state_set

    RTS


; ==============================================================================
; UI_MEMORY_PROTECT_STATE_SET
; ==============================================================================
; DESCRIPTION:
; This subroutine sets the memory protect bits in the UI state register.
; These bits are set based upon the current value of the memory protection.
; If memory protect is enabled, bit 3 is set.
; If memory protect is disabled bit 2 is set.
; Setting these bits puts the UI into 'Store' mode.
;
; MEMORY MODIFIED:
; * ui_mode_memory_protect_state
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
ui_memory_protect_state_set:                    SUBROUTINE
    LDAA    memory_protect
    ANDA    #1
    INCA
    ASLA
    ASLA
    ORAA    ui_mode_memory_protect_state
    STAA    ui_mode_memory_protect_state

    RTS


; ==============================================================================
; UI_MEMORY_PROTECT_STATE_CLEAR
; ==============================================================================
; DESCRIPTION:
; Clears the UI memory protect state.
;
; MEMORY MODIFIED:
; * ui_mode_memory_protect_state
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
ui_memory_protect_state_clear:                  SUBROUTINE
    LDAA    #%11
    ANDA    ui_mode_memory_protect_state
    STAA    ui_mode_memory_protect_state

    RTS


; ==============================================================================
; UI_PATCH_COMPARE_TOGGLE
; ==============================================================================
; DESCRIPTION:
; @TODO
; ==============================================================================
ui_patch_compare_toggle:                        SUBROUTINE
    LDAA    patch_current_modified_flag
    BEQ     .exit

    TST     patch_compare_mode_active
    BNE     .compare_mode_active

    LDAA    #1
    STAA    patch_compare_mode_active
    JMP     patch_copy_edit_to_compare_and_load_current

.compare_mode_active:
    CLR     patch_compare_mode_active
    JSR     patch_restore_edit_buffer_from_compare
    LDAA    #BUTTON_EDIT_20_KEY_TRANSPOSE
    CMPA    ui_btn_numeric_last_pressed
    BEQ     loc_DE9B

    LDX     ui_active_param_address
    BRA     loc_DE9E

loc_DE9B:
    LDX     #patch_edit_key_transpose

loc_DE9E:
    JMP     midi_sysex_tx_param_change

.exit:
    RTS


; ==============================================================================
; UI_BUTTON_EDIT_MEMORY_SELECT
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
ui_button_edit_memory_select:                   SUBROUTINE
    JSR     ui_button_edit_save_previous
; Falls-through below.

; ==============================================================================
; UI_BUTTON_MEMORY_SELECT
; ==============================================================================
; DESCRIPTION:
; @TODO
;
; ==============================================================================
ui_button_memory_select:                        SUBROUTINE
    LDAA    #UI_MODE_MEMORY_SELECT
    STAA    ui_mode_memory_protect_state
    RESET_OPERATOR_STATUS

; Load the previous 'Store Mode' numeric key, and then jump to the
; numeric button handler.
    LDAB    ui_btn_numeric_previous_store_mode
    JMP     ui_button_numeric


; ==============================================================================
; UI_BUTTON_EDIT_SAVE_PREVIOUS
; ==============================================================================
; DESCRIPTION:
; This routine saves the previous numeric button pressed while the synth's UI
; was in 'Edit' mode.
;
; MEMORY MODIFIED:
; * ui_btn_numeric_previous_store_mode
; * ui_btn_numeric_previous_edit_mode
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
ui_button_edit_save_previous:                   SUBROUTINE
    LDAA    ui_btn_numeric_last_pressed
    STAA    ui_btn_numeric_previous_edit_mode
    CMPA    #BUTTON_EDIT_6_LFO_WAVE
    BCS     .exit

    CMPA    #BUTTON_EDIT_10_MOD_SENS
    BCC     .exit

    STAA    ui_btn_numeric_previous_store_mode

.exit:
    CLR     key_transpose_set_mode_active
    RTS


; ==============================================================================
; UI_BUTTON_FUNCTION_SAVE_PREVIOUS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; This routine saves the previous numeric button pressed while the synth's UI
; was in 'Function' mode.
; @TODO: There are several behaviours not well understood here.
;
; MEMORY MODIFIED:
; * ui_btn_numeric_previous_store_mode
; * ui_btn_numeric_previous_fn_mode
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
ui_button_function_save_previous:               SUBROUTINE
; Don't save the button state as the test entry button combination.
; Decrement A to save this as function mode button 20 instead.
    LDAA    ui_btn_numeric_last_pressed
    CMPA    #BUTTON_TEST_ENTRY_COMBO
    BNE     .store_previous_function_mode_button

    DECA

.store_previous_function_mode_button:
    STAA    ui_btn_numeric_previous_fn_mode

    CMPA    #BUTTON_FUNCTION_6
    BCS     .store_previous_store_mode_button

    CMPA    #BUTTON_FUNCTION_11
    BCS     .clear_test_mode_button_input_state

    CMPA    #BUTTON_FUNCTION_19
    BCC     .clear_test_mode_button_input_state

; @TODO: Why does this occur?
.store_previous_store_mode_button:
    STAA    ui_btn_numeric_previous_store_mode

.clear_test_mode_button_input_state:
    CLR     test_mode_button_state
    RTS
