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
; Contains definitions related to the synth's UI.
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
