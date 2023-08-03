; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; peripherals.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions for accessing the synth's peripherals.
; ==============================================================================

    .PROCESSOR HD6303

key_switch_scan_driver_input                    EQU $20

adc_data                                        EQU $22
adc_source                                      EQU $24

ops_mode                                        EQU $26
ops_alg_feedback                                EQU $27

lcd_ctrl:                                       EQU $28
lcd_data:                                       EQU $29

led_1:                                          EQU $2B
led_2:                                          EQU $2C

EGS_KEY_EVENT_ON                                EQU 1
EGS_KEY_EVENT_OFF                               EQU 2

egs_voice_frequency:                            EQU $1800
egs_operator_frequency:                         EQU $1820
egs_operator_detune:                            EQU $1830
egs_operator_eg_rate:                           EQU $1840
egs_operator_eg_level:                          EQU $1860
egs_operator_level:                             EQU $1880
egs_operator_keyboard_scaling:                  EQU $18E0
egs_amp_mod:                                    EQU $18F0
egs_key_event:                                  EQU $18F1
egs_pitch_mod_high:                             EQU $18F2
egs_pitch_mod_low:                              EQU $18F3


PORT_1_ADC_EOC:                                 EQU 1 << 4
PORT_1_TAPE_REMOTE:                             EQU 1 << 5
PORT_1_TAPE_OUTPUT:                             EQU 1 << 6
PORT_1_TAPE_INPUT:                              EQU 1 << 7

KEY_SWITCH_SCAN_DRIVER_SOURCE_BUTTONS_2:        EQU 2
KEY_SWITCH_SCAN_DRIVER_SOURCE_PEDALS:           EQU 3
KEY_SWITCH_SCAN_DRIVER_SOURCE_KEYBOARD:         EQU 4

KEY_SWITCH_LINE_0_BUTTON_YES:                   EQU 1
KEY_SWITCH_LINE_0_BUTTON_NO:                    EQU 2
KEY_SWITCH_LINE_0_BUTTON_FUNCTION:              EQU 8

KEY_SWITCH_LINE_1_BUTTON_10:                    EQU 2
