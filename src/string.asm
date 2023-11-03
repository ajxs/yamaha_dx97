; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; string.asm
; ==============================================================================
; DESCRIPTION:
; This file contains string definitions used in the firmware ROM.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; String Table.
; This is the synth's main string table.
; Note: Some strings are not null-terminated, and are instead terminated with
; another integer. The string copy function will consider any ASCII character
; below 0x20 (space) to be the equivalent of a null-terminating character.
; This character value will effectively be returned by the string copy function.
; This value is actually used by the menu printing function to determine what
; function to use to print the parameter value associated with the parameter
; name string. This functionality was taken from the original DX9 ROM.
; ==============================================================================
str_algorithm_select:                   DC.B STR_FRAGMENT_OFFSET_ALG
                                        DC "ORITHM "
                                        DC.B STR_FRAGMENT_OFFSET_SELECT, 0

str_are_you_sure:                       DC "ARE YOU SURE ?", 0
str_battery_warning:                    DC "CHANGE BATTERY !", 0

str_battery_voltage:                    DC "BATTERY VOLT="
                                        DC.B PRINT_PARAM_FUNCTION_BATTERY_VOLTAGE

str_breath_range:                       DC.B STR_FRAGMENT_OFFSET_BREATH
                                        DC.B STR_FRAGMENT_OFFSET_RANGE
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_breath_pitch:                       DC.B STR_FRAGMENT_OFFSET_BREATH
                                        DC.B STR_FRAGMENT_OFFSET_PITCH
                                        DC.B PRINT_PARAM_FUNCTION_BOOLEAN

str_breath_amp:                         DC.B STR_FRAGMENT_OFFSET_BREATH
                                        DC.B STR_FRAGMENT_OFFSET_AMP
                                        DC.B PRINT_PARAM_FUNCTION_BOOLEAN

str_breath_eg_b:                        DC.B STR_FRAGMENT_OFFSET_BREATH
                                        DC.B STR_FRAGMENT_OFFSET_EG_B
                                        DC.B PRINT_PARAM_FUNCTION_BOOLEAN

str_edit_recall:                        DC "EDIT RECALL ?", 0
str_eg_copy:                            DC "EG COPY", 0

str_eg_rate:                            DC.B STR_FRAGMENT_OFFSET_EG
                                        DC.B $20 ; Space
                                        DC.B STR_FRAGMENT_OFFSET_RATE
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_eg_level:                           DC.B STR_FRAGMENT_OFFSET_EG
                                        DC.B $20 ; Space
                                        DC.B STR_FRAGMENT_OFFSET_LEVEL
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_err:                                DC "ERR", 0
str_error:                              DC "ERROR!", 0

str_feedback:                           DC "FEEDBACK"
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_freq_coarse:                        DC "F COARSE"
                                        DC.B PRINT_PARAM_FUNCTION_OSC_FREQ

str_freq_fine:                          DC "F FINE"
                                        DC.B PRINT_PARAM_FUNCTION_OSC_FREQ

str_from_mem_to_tape:                   DC "from MEM to TAPEall       "
                                        DC.B STR_FRAGMENT_OFFSET_READY

str_from_tape_to_mem:                   DC "from TAPE to MEMall       "
                                        DC.B STR_FRAGMENT_OFFSET_READY

str_from_tape_to_buf:                   DC "from TAPE to BUFsingle  ? (1-20)", 0

str_function_control:                   DC "FUNCTION CONTROL", 0

str_glissando:                          DC "GLISSANDO"
                                        DC.B PRINT_PARAM_FUNCTION_BOOLEAN

str_int:                                DC "INT", 0

str_lfo_name_triangle:                  DC "TRIANGLE", 0
str_lfo_name_saw_down:                  DC "SAW DWN", 0
str_lfo_name_saw_up:                    DC "SAW UP", 0
str_lfo_name_square:                    DC "SQUARE", 0
str_lfo_name_sine:                      DC "SINE", 0
str_lfo_name_sample_hold:               DC "S/HOLD", 0

str_lfo_speed:                          DC.B STR_FRAGMENT_OFFSET_LFO
                                        DC "SPEED"
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_lfo_wave:                           DC.B STR_FRAGMENT_OFFSET_LFO
                                        DC "WAVE"
                                        DC.B PRINT_PARAM_FUNCTION_LFO_WAVE

str_lfo_delay:                          DC.B STR_FRAGMENT_OFFSET_LFO
                                        DC "DELAY"
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_lfo_pm_depth:                       DC.B STR_FRAGMENT_OFFSET_LFO
                                        DC "PM"
                                        DC.B STR_FRAGMENT_OFFSET_DEPTH
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_lfo_am_depth:                       DC.B STR_FRAGMENT_OFFSET_LFO
                                        DC "AM"
                                        DC.B STR_FRAGMENT_OFFSET_DEPTH
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_lvl_scaling:                        DC.B "LVL "
                                        DC.B STR_FRAGMENT_OFFSET_SCALING, 0

str_master_tune:                        DC "MASTER "
                                        DC.B STR_FRAGMENT_OFFSET_TUNE
                                        DC.B $20 ; Space
                                        DC "ADJ", 0

str_mem_protect:                        DC "MEM. PROTECT"
                                        DC.B PRINT_PARAM_FUNCTION_BOOLEAN

str_memory_select:                      DC.B STR_FRAGMENT_OFFSET_MEMORY
                                        DC.B STR_FRAGMENT_OFFSET_SELECT, 0
str_memory_store:                       DC.B STR_FRAGMENT_OFFSET_MEMORY
                                        DC.B STR_FRAGMENT_OFFSET_STORE, 0

str_memory_protect:                     DC.B STR_FRAGMENT_OFFSET_MEMORY
                                        DC "PROTECT", 0

str_midi_ch:                            DC "MIDI CH"
                                        DC.B PRINT_PARAM_FUNCTION_MIDI_CHANNEL

str_midi_error_buffer_full:             DC "MIDI BUFFER FULL", 0
str_midi_error_data:                    DC "MIDI DATA ERROR", 0
str_midi_received:                      DC " MIDI RECEIVED", 0
str_midi_checksum_error:                DC "MIDI CSUM ERROR", 0
str_midi_transmit:                      DC " MIDI TRANSMIT ?", 0
str_middle_c:                           DC "MIDDLE C"
                                        DC.B PRINT_PARAM_FUNCTION_KEY_TRANSPOSE

str_mod_sens_a:                         DC "A MOD SENS."
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_mod_sens_p:                         DC "P MOD SENS."
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_mode_poly:                          DC "POLY"
                                        DC.B STR_FRAGMENT_OFFSET_MODE,0

str_mode_mono:                          DC "MONO"
                                        DC.B STR_FRAGMENT_OFFSET_MODE
                                        DC.B PRINT_PARAM_FUNCTION_MONO_POLY

str_note_names:                         DC "C C#D D#E F F#G G#A A#B "
str_off:                                DC "OFF", 0
str_ok:                                 DC "OK!", 0
str_on:                                 DC " ON", 0
str_op_copy:                            DC "from OP  to OP?", 0

str_osc_detune:                         DC "OSC DE"
                                        DC.B STR_FRAGMENT_OFFSET_TUNE
                                        DC.B PRINT_PARAM_FUNCTION_OSC_DETUNE

str_osc_key_sync:                       DC "OSC KEY SYNC"
                                        DC.B PRINT_PARAM_FUNCTION_BOOLEAN

str_osc_mode:                           DC "OSC MODE"
                                        DC.B PRINT_PARAM_FUNCTION_OSC_MODE

str_osc_mode_ratio:                     DC "RATIO", 0
str_osc_mode_fixed:                     DC "FIXED", 0

str_output_level:                       DC "OUTPUT "
                                        DC.B STR_FRAGMENT_OFFSET_LEVEL
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_p_bend_range:                       DC "P BEND "
                                        DC.B STR_FRAGMENT_OFFSET_RANGE
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_porta_full_time:                    DC "FULL TIME "
                                        DC.B STR_FRAGMENT_OFFSET_PORTA, 0
str_porta_fingered:                     DC "FINGERED "
                                        DC.B STR_FRAGMENT_OFFSET_PORTA, 0

str_porta_retain:                       DC.B STR_FRAGMENT_OFFSET_SUS_KEY
                                        DC "RETAIN", 0
str_porta_follow:                       DC.B STR_FRAGMENT_OFFSET_SUS_KEY
                                        DC "FOLLOW", 0

str_porta_time:                         DC.B STR_FRAGMENT_OFFSET_PORTA
                                        DC.B $20 ; Space
                                        DC "TIME"
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_rate_scaling:                       DC.B STR_FRAGMENT_OFFSET_RATE
                                        DC.B STR_FRAGMENT_OFFSET_SCALING
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_sys_info:                           DC "SYS INFO "
                                        DC.B PRINT_PARAM_FUNCTION_AVAIL_UNAVAIL

str_sys_info_unavail:                   DC "UNAVAIL", 0

str_tape_save:                          DC "SAVE TO TAPE ?", 0
str_tape_verify:                        DC "VERIFY TAPE ?", 0
str_tape_load:                          DC "LOAD FROM TAPE ?", 0
str_tape_single:                        DC "LOAD SINGLE ?", 0
str_tape_remote:                        DC "TAPE REMOTE", 0

; Note that this string is not null-terminated.
; The test UI routine will copy both lines to the LCD buffer.
str_test_mode_prompt:                   DC "V0.9.8 04-Nov-23"
str_test_mode_prompt_line_2:            DC " Test Entry ?", 0

str_verify_complete:                    DC "VERIFY COMPLETED", 0
str_verify_tape:                        DC "VERIFY      TAPE          "
                                        DC.B STR_FRAGMENT_OFFSET_READY

str_voice_init:                         DC "VOICE INIT ?", 0

str_welcome_message:                    DC "* YAMAHA DX9/7 *https://ajxs.me ", 0

str_wheel_range:                        DC.B STR_FRAGMENT_OFFSET_WHEEL
                                        DC.B STR_FRAGMENT_OFFSET_RANGE
                                        DC.B PRINT_PARAM_FUNCTION_NUMERIC

str_wheel_pitch:                        DC.B STR_FRAGMENT_OFFSET_WHEEL
                                        DC.B STR_FRAGMENT_OFFSET_PITCH
                                        DC.B PRINT_PARAM_FUNCTION_BOOLEAN

str_wheel_amp:                          DC.B STR_FRAGMENT_OFFSET_WHEEL
                                        DC.B STR_FRAGMENT_OFFSET_AMP
                                        DC.B PRINT_PARAM_FUNCTION_BOOLEAN

str_wheel_eg_b:                         DC.B STR_FRAGMENT_OFFSET_WHEEL
                                        DC.B STR_FRAGMENT_OFFSET_EG_B
                                        DC.B PRINT_PARAM_FUNCTION_BOOLEAN

str_test:                               DC "TEST", 0

; ==============================================================================
; String Fragment Table.
; The DX9 firmware uses an novel method for saving space in the string table.
; It stores commonly printed 'fragments' of strings, which can be reused in
; regular strings.
; If the LCD string copy function encounters a byte with a value above 0x80, it
; treats this byte as an offset from the start of the 'string fragment table',
; and will then use this offset to load, and copy the specified 'fragment'.
; The 'start' offset below is 128 bytes offset from the start of the table so
; that the string copy code does not require any pointer arithmetic.
; The string copy function will add the offset to this pointer to find the
; specified fragment.
; This functionality is used in the DX100, and TX81Z, most likely others.
; It is not used in the DX7.
; ==============================================================================
string_fragment_offset_start:           EQU (#str_fragment_table_start - 0x80)

str_fragment_table_start:
str_fragment_alg:                       DC "ALG", 0
str_fragment_amp:                       DC "AMP", 0
str_fragment_breath:                    DC "BREATH ", 0
str_fragment_depth:                     DC " DEPTH", 0
str_fragment_eg:                        DC "EG ", 0
str_fragment_eg_b:                      DC "EG B.", 0
str_fragment_level:                     DC "LEVEL", 0
str_fragment_lfo:                       DC "LFO ", 0
str_fragment_memory:                    DC "MEMORY ", 0
str_fragment_mode:                      DC " MODE", 0
str_fragment_pitch:                     DC "PITCH ", 0
str_fragment_porta:                     DC "PORTA", 0
str_fragment_range:                     DC "RANGE", 0
str_fragment_rate:                      DC "RATE ", 0
str_fragment_scaling:                   DC "SCALING", 0
str_fragment_select:                    DC "SELECT", 0
str_fragment_store:                     DC "STORE", 0
str_fragment_tune:                      DC "TUNE", 0
str_fragment_wheel:                     DC "WHEEL ", 0
str_fragment_sus_key:                   DC "SUS-KEY P ", 0
str_fragment_ready:                     DC "ready?", 0

STR_FRAGMENT_OFFSET_ALG                 EQU (str_fragment_alg - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_AMP                 EQU (str_fragment_amp - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_BREATH              EQU (str_fragment_breath - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_DEPTH               EQU (str_fragment_depth - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_EG                  EQU (str_fragment_eg - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_EG_B                EQU (str_fragment_eg_b - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_LEVEL               EQU (str_fragment_level - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_LFO                 EQU (str_fragment_lfo - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_MEMORY              EQU (str_fragment_memory - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_MODE                EQU (str_fragment_mode - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_PITCH               EQU (str_fragment_pitch - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_PORTA               EQU (str_fragment_porta - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_RANGE               EQU (str_fragment_range - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_RATE                EQU (str_fragment_rate - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_SCALING             EQU (str_fragment_scaling - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_SELECT              EQU (str_fragment_select - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_STORE               EQU (str_fragment_store - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_TUNE                EQU (str_fragment_tune - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_WHEEL               EQU (str_fragment_wheel - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_SUS_KEY             EQU (str_fragment_sus_key - #string_fragment_offset_start)
STR_FRAGMENT_OFFSET_READY               EQU (str_fragment_ready - #string_fragment_offset_start)
