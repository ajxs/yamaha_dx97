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
; ui/input/slider.asm
; ==============================================================================
; DESCRIPTION:
; Contains the functionality related to user input when the triggering input
; source is the front-panel slider.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; UI_SLIDER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; This subroutine handles editing parameters via the front-panel slider.
; It is called by the main slider input handler subroutine. It works by
; loading the maximum value of the currently edited parameter, scaling it
; according to the analog slider input, and then storing it.
;
; MEMORY MODIFIED:
; * ui_slider_value_previous
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
ui_slider:                                      SUBROUTINE
    TST     patch_compare_mode_active
    BEQ     .test_if_slider_updated

; This tests if the currently selected edit parameter is an 'Edit Mode'
; parameter, as opposed to a 'Function Mode' one. Since the function mode
; parameter addresses are higher than the null value address.
; The purpose of this check is so that function parameters can be edited while
; the synth is in 'Compare Mode', but not edit parameters.
    LDX     ui_active_param_address
    CPX     #null_edit_parameter
    BCS     .exit

.test_if_slider_updated:
; Check whether the slider input has actually changed since the last input,
; by comparing the new value against a previous recorded value.
; If this has changed, store the new input.
; This is necessary since the previous value used in the ADC processing
; routine is overwritten, and cannot be used for this purpose.
    LDAB    analog_input_slider
    CMPB    ui_slider_value_previous
    BEQ     .exit

    STAB    ui_slider_value_previous

; Load the maximum value of the parameter currently being edited.
    LDAA    ui_active_param_max_value
    INCA

; Decrement in the case of overflow.
    BNE     .scale_parameter
    DECA

.scale_parameter:
; Scale the param by incrementing the maximum value, and then multiplying it
; by the analog value obtained from the slider input.
; The result will be stored in ACCD. The MSB will hold a scaled version of
; the maximum, which will become the new parameter value.
    MUL
    LDX     ui_active_param_address

    CPX     #master_tune
    BEQ     .parameter_is_master_tune

; This branch, and the exit label were not in the original DX9 firmware.
; This was added to provide cleaner subroutine local labels.
    JMP     ui_update_numeric_parameter

.parameter_is_master_tune:
; If the currently selected edit parameter is the master tune setting set this
; manually, as the scaled value is expanded to two bytes.
    TAB
    CLRA
    LSLD
    STD     master_tune

.exit:
    RTS

