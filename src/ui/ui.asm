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
; ui/ui.asm
; ==============================================================================
; DESCRIPTION:
; Contains definitions, and functionality related to the synth's UI.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI Modes.
; These codes are used to determine the input mode of the synth's UI.
; ==============================================================================
UI_MODE_FUNCTION:                               EQU 0
UI_MODE_EDIT:                                   EQU 1
UI_MODE_MEMORY_SELECT:                          EQU 2
UI_MODE_UNKNOWN:                                EQU 3

; ==============================================================================
; Button Codes
; ==============================================================================
BUTTON_EDIT_2:                                  EQU 1
BUTTON_EDIT_5_ALG_FEEDBACK:                     EQU 4
BUTTON_EDIT_6_LFO_WAVE:                         EQU 5
BUTTON_EDIT_9:                                  EQU 8
BUTTON_EDIT_10_MOD_SENS:                        EQU 9
BUTTON_EDIT_11:                                 EQU 10
BUTTON_EDIT_12_OSC_FREQ_COARSE:                 EQU 11
BUTTON_EDIT_14_DETUNE_SYNC:                     EQU 13
BUTTON_EDIT_15_EG_RATE:                         EQU 14
BUTTON_EDIT_17_KBD_SCALE_RATE:                  EQU 16
BUTTON_EDIT_20_KEY_TRANSPOSE:                   EQU 19
BUTTON_FUNCTION_1:                              EQU 20
BUTTON_FUNCTION_2:                              EQU 21
BUTTON_FUNCTION_4:                              EQU 23
BUTTON_FUNCTION_5:                              EQU 24
BUTTON_FUNCTION_6:                              EQU 25
BUTTON_FUNCTION_7:                              EQU 26
BUTTON_FUNCTION_10:                             EQU 29
BUTTON_FUNCTION_11:                             EQU 30
BUTTON_FUNCTION_19:                             EQU 38
BUTTON_FUNCTION_20:                             EQU 39
BUTTON_TEST_ENTRY_COMBO:                        EQU 40


; ==============================================================================
; UI_UPDATE_NUMERIC_PARAMETER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Handles updating a numeric edit parameter.
; This subroutine is called via the front-panel increment/decrement, and
; slider input handler routines.
;
; ARGUMENTS:
; Registers:
; * IX:   The active parameter address.
; * ACCA: The new parameter value.
;
; MEMORY MODIFIED:
; * main_patch_event_flag
; * patch_current_modified_flag
; * active_voice_count
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_update_numeric_parameter:                    SUBROUTINE
; Check if the value has been updated by the previous operation.
; If so, store the newly updated value.
    CMPA    0,x
    BEQ     .exit

    STAA    0,x

; Trigger the reloading of the patch data to the EGS chip.
    LDAA    #EVENT_RELOAD_PATCH
    STAA    main_patch_event_flag

; If the previous front-panel button press that initiated this action
; originated from a function parameter button, branch.
    LDAA    ui_btn_numeric_last_pressed
    CMPA    #BUTTON_EDIT_20_KEY_TRANSPOSE
    BCC     .function_parameter

; Set the patch edit buffer as having been modified.
    LDAA    #1
    STAA    patch_current_modified_flag
    BRA     .exit

.function_parameter:
; If the parameter being updated is the synth's polyphony mode, stop all
; voices, and reset the voice buffers.
    CMPA    #BUTTON_FUNCTION_2
    BEQ     .reset_voices

; If the MIDI channel is updated, reset all voices.
    CMPA    #BUTTON_FUNCTION_6
    BNE     .exit

    TST     ui_btn_function_6_sub_function
    BNE     .exit

.reset_voices:
    JSR     voice_reset

.exit:
    RTS
