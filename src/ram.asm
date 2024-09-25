; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; ram.asm
; ==============================================================================
; DESCRIPTION:
; This file contains all of the variable definitions that are stored in the
; device's internal, and external RAM.
; Variables declared in 'internal' RAM will be initialised on system reset.
; Variables in external RAM are persistent across reboots.
; ==============================================================================

    .PROCESSOR HD6303

; These buffer sizes have been made much smaller than those in the original
; DX9 firmware (682, and 800, respectively).
; The sizes in this ROM are larger than in the DX7 (180, and 380).
MIDI_BUFFER_TX_SIZE:                            EQU 400
MIDI_BUFFER_RX_SIZE:                            EQU 600

PATCH_SIZE_PACKED_DX9:                          EQU 64
PATCH_SIZE_PACKED_DX7:                          EQU 128

PATCH_SIZE_UNPACKED_DX9:                        EQU 69
PATCH_SIZE_UNPACKED_DX7:                        EQU 155

PATCH_BUFFER_COUNT:                             EQU 10
PATCH_BUFFER_SIZE_BYTES:                        EQU PATCH_BUFFER_COUNT * PATCH_SIZE_PACKED_DX7

KEYBOARD_SCALE_CURVE_LENGTH                     EQU 43

    SEG.U ram_internal
    ORG $80

internal_ram_start:                             EQU *
memcpy_ptr_src:                                 DS 2
memcpy_ptr_dest:                                DS 2

key_switch_scan_input:                          DS 4
pedal_status_current:                           DS 1
pedal_status_previous:                          DS 1
sustain_status:                                 DS 1

; This variable address is shared by the test 'read button input' function.
patch_activate_operator_number:                 DS 1
patch_activate_operator_offset:                 DS 1

; These variables are used in places where the memcpy pointers are already
; used, such as tape patch serialisation routines.
copy_ptr_src:                                   DS 2
copy_ptr_dest:                                  DS 2
copy_counter:                                   DS 1

; When this flag is set the next keypress event will be used to set the
; synth's key transpose.
key_transpose_set_mode_active:                  DS 1

keyboard_last_scanned_values:                   DS 12

keyboard_scan_current_key:                      DS 1
keyboard_scan_current_octave:                   DS 1

; This variable stores the number of the last incoming note received via MIDI.
; It also stores the last scanned key, and pending key event.
; If this value is 0xFF, it indicates there is no key event pending.
; If bit 7 of this byte is set, it indicates that this note event is a
; 'Key Down' event originating from the keyboard, otherwise it is a 'Key Up'.
note_number:                                    DS 1
note_velocity:                                  DS 1

; This variable stores the previous played note.
; This is used when the synth is in monophonic mode, and the portamento mode is
; set to 'Fingered'. If two notes are currently active, and the new note is
; released, this will be the note that the portamento will transition towards.
note_number_previous:                           DS 1

; This is the base logarithmic frequency of the current note, before the
; current pitch EG level is added.
note_frequency:                                 DS 2
note_frequency_low:                             EQU (#note_frequency + 1)

note_frequency_previous:                        DS 2

; This variable stores the index of the _next_ voice to be added.
; This is persisted across 'voice_add' calls so that the next available voice
; can be found quicker.
voice_add_index:                                DS 1

tape_input_polarity_previous:                   DS 1
tape_input_delay_length:                        DS 1
; This flag is set when a particular tape function is aborted by the user.
tape_function_aborted_flag:                     DS 1

portamento_rate_scaled:                         DS 1

; The synth's current portamento direction.
; * 0: Down.
; * 1: Up.
portamento_direction:                           DS 1

pitch_bend_amount:                              DS 1
pitch_bend_frequency:                           DS 2

lfo_phase_increment:                            DS 2
lfo_delay_increment:                            DS 2
lfo_mod_depth_pitch:                            DS 1
lfo_mod_depth_amp:                              DS 1

lfo_delay_accumulator:                          DS 2
; The 'LFO delay fadein factor' variable is used to 'fade in' the LFO
; amplitude after the LFO delay has expired.
lfo_delay_fadein_factor:                        DS 2
lfo_phase_accumulator:                          DS 2
lfo_sample_and_hold_update_flag:                DS 1
lfo_amplitude:                                  DS 1

; This flag is 'toggled' On/Off with each interrupt.
; This flag is used to determine whether portamento, or pitch modulation
; should be updated in the OCF interrupt. The reason is likely to save CPU
; cycles used by these expensive operations.
pitch_eg_update_toggle:                         DS 1

lcd_print_number_print_zero_flag:               DS 1
lcd_print_number_divisor:                       DS 1
ui_btn_function_19_patch_init_prompt:           DS 1

; Used to track the state of the 'Test Mode' button combination internally.
ui_test_mode_button_combo_state:                DS 1

; The synth's current active voice count when in monophonic mode.
active_voice_count:                             DS 1

midi_buffer_ptr_tx_write:                       DS 2
midi_buffer_ptr_tx_read:                        DS 2
midi_buffer_ptr_rx_write:                       DS 2
midi_buffer_ptr_rx_read:                        DS 2

midi_last_command_received:                     DS 1
midi_last_command_sent:                         DS 1

midi_rx_first_data_byte:                        DS 1

midi_rx_data_count:                             DS 1

; This boolean parameter is used to test whether incoming MIDI processing is
; currently pending. If so, pitch modulation processing is ignored.
midi_rx_processing_pending:                     DS 1

midi_sysex_substatus:                           DS 1
midi_sysex_format_param_grp:                    DS 1

; The received SysEx byte count MSB, in the case that the incoming SysEx
; message is data, or the parameter number if it is a parameter change
; message.
midi_sysex_byte_count_msb_param_number:         DS 1

; The received SysEx byte count LSB, in the case that the incoming SysEx
; message is data, or the parameter data if it is a parameter change
; message.
midi_sysex_byte_count_lsb_param_data:           DS 1
midi_sysex_patch_number:                        DS 1
; When a SysEx bulk data transfer is being received, this variable indicates
; whether the format is a single patch, or a bulk patch transfer.
midi_sysex_format_type:                         DS 1
midi_sysex_tx_checksum:                         DS 1
midi_sysex_rx_checksum:                         DS 1

; The index of the current patch being received during a SysEx bulk data dump.
; This is set to '20' when receiving a single voice, which will store it in
; the tape buffer.
midi_sysex_rx_bulk_patch_index:                 DS 1
; Whether the synth is currently receiving SysEx data.
midi_sysex_rx_active_flag:                      DS 1

; This variable tracks the time between sending Active Sensing pulses if this
; feature has been enabled.
midi_active_sensing_tx_counter:                 DS 1
; When this flag is cleared, an active sensing message can be transmitted.
midi_active_sensing_tx_pending_flag:            DS 1
; Decides whether the active sensing counter is enabled.
midi_active_sensing_rx_counter_enabled:         DS 1
midi_active_sensing_rx_counter:                 DS 1

; Whether the synth is currently in the middle of receiving, and processing
; a SysEx message.
midi_sysex_receive_data_active:                 DS 1
midi_error_code:                                DS 1

; In the original DX9 firmware, variables used in the test subroutines share
; locations in memory with other variables. Presumably this is because they're
; unused during the diagnostic routines.
test_stage_current:                             EQU #midi_sysex_substatus
test_stage_sub:                                 EQU #midi_sysex_format_param_grp
test_stage_sub_2:                               EQU #midi_sysex_byte_count_msb_param_number
test_button_input:                              EQU #midi_sysex_byte_count_lsb_param_data

; The portamento pitch transition for only half of the synth's voices are
; processed with each iteration. This variable controls which half.
portamento_voice_toggle:                        DS 1

tape_byte_counter:                              DS 1
tape_input_selected_patch_index:                DS 1
updated_input_source:                           DS 1

; Temporary variables used in the various interrupt routines.
; Refer to the documentation of 'temp_variables'.
interrupt_temp_variables:                       DS 18

    SEG.U ram_external
    ORG $800

external_ram_start:                             EQU *

; Place the patch buffer at the start of external RAM.
; Because it is a fixed size that is unlikely to change, putting this buffer
; here at this fixed location stops the synth's patch memory being corrupted
; when the firmware is upgraded.
patch_buffer:                                   DS PATCH_BUFFER_SIZE_BYTES

; This is essentially a 'hidden' patch buffer, used to store a patch received
; via MIDI/cassette tape. This can be loaded programmatically in the same way
; as a normal patch in the patch buffer, but is not accessible via the UI.
patch_buffer_incoming:                          DS PATCH_SIZE_PACKED_DX7

; Patches input via the cassette interface shared the incoming patch buffer,
; but are only 64 bytes in size, followed by one byte for the counter, and two
; bytes for the checksum.
patch_tape_counter:                             EQU (#patch_buffer_incoming + 64)
patch_tape_checksum:                            EQU (#patch_buffer_incoming + 65)

patch_buffer_compare:                           DS PATCH_SIZE_PACKED_DX7

; ==============================================================================
; Patch Edit Buffer.
; This is where the currently loaded patch is unpacked, and stored in memory.
; ==============================================================================
patch_buffer_edit:                              DS PATCH_SIZE_UNPACKED_DX7

patch_edit_algorithm:                           EQU (#patch_buffer_edit + PATCH_ALGORITHM)
patch_edit_feedback:                            EQU (#patch_buffer_edit + PATCH_FEEDBACK)
patch_edit_oscillator_sync:                     EQU (#patch_buffer_edit + PATCH_OSC_SYNC)

patch_edit_lfo_speed:                           EQU (#patch_buffer_edit + PATCH_LFO_SPEED)
patch_edit_lfo_delay:                           EQU (#patch_buffer_edit + PATCH_LFO_DELAY)
patch_edit_lfo_pitch_mod_depth:                 EQU (#patch_buffer_edit + PATCH_LFO_PITCH_MOD_DEPTH)
patch_edit_lfo_amp_mod_depth:                   EQU (#patch_buffer_edit + PATCH_LFO_AMP_MOD_DEPTH)
patch_edit_lfo_sync:                            EQU (#patch_buffer_edit + PATCH_LFO_SYNC)
patch_edit_lfo_waveform:                        EQU (#patch_buffer_edit + PATCH_LFO_WAVEFORM)
patch_edit_lfo_pitch_mod_sens:                  EQU (#patch_buffer_edit + PATCH_LFO_PITCH_MOD_SENS)

patch_edit_pitch_eg:                            EQU (#patch_buffer_edit + PATCH_PITCH_EG_R1)

patch_edit_key_transpose:                       EQU (#patch_buffer_edit + PATCH_KEY_TRANSPOSE)

patch_edit_name:                                EQU (#patch_buffer_edit + PATCH_PATCH_NAME)

patch_edit_operator_status:                     DS 1

; This value is used as a 'null' edit parameter.
; When it is selected as the active 'Edit Parameter', any data input will have
; no effect. It is used by the UI subroutines when data input needs to be
; disabled.
null_edit_parameter:                            DS 1

; ==============================================================================
; Performance Parameters.
; ==============================================================================
; The DX9 ROM stored this variable in a byte.
; All use of this variable involved shifting it left twice to get its internal
; representation. This was likely done so that it can be treated like any other
; function parameter for the purposes of editing.
; This has been changed back to the original DX7 implementation.
master_tune:                                    DS 2

; The synth's global polyphony setting:
; * 0: Polyphonic.
; * 1: Monophonic.
mono_poly:                                      DS 1
pitch_bend_range:                               DS 1
; This is currently not implemented.
; This is placed here so that the incoming SysEx function parameter changes
; work correctly. This feature may be properly implemented at one point in the
; future.
pitch_bend_step:                                DS 1

; Portamento Mode:
; Monophonic Mode:
; * 0: Full-time.
; * 1: Fingered.
; Polyphonic Mode:
; * 0: Retain.
; * 1: Follow.
portamento_mode:                                DS 1

portamento_time:                                DS 1
mod_wheel_range:                                DS 1
mod_wheel_pitch:                                DS 1
mod_wheel_amp:                                  DS 1
mod_wheel_eg_bias:                              DS 1
breath_control_range:                           DS 1
breath_control_pitch:                           DS 1
breath_control_amp:                             DS 1
breath_control_eg_bias:                         DS 1

sys_info_avail:                                 DS 1
tape_remote_output_polarity:                    DS 1

; The synth's 'Memory Protect' state.
; When this variable is updated, the memory protection flag bits in the
; 'ui_state' variable are updated, which will prevent any UI operations
; modifying internal memory.
; This variable is referred to independently of the UI state when performing
; tape input operations.
memory_protect:                                 DS 1

midi_buffer_tx:                                 DS MIDI_BUFFER_TX_SIZE
midi_buffer_tx_end:                             EQU *

midi_buffer_rx:                                 DS MIDI_BUFFER_RX_SIZE
midi_buffer_rx_end:                             EQU *

; This is a temporary buffer location for conversion of patches read over the
; cassette interface from the DX9 format, to the DX7 format.
; This relies on the SysEx buffer being bigger than the size of a single patch.
patch_buffer_tape_conversion:                   EQU *

; @TODO: Is it possible to use one buffer for both sending, and receiving of
; SysEx data? Is it possible for both to be used simultaneously?
; @TODO: Is it possible to use the same space as the 'incoming' patch buffer?
midi_buffer_sysex_tx:                           DS PATCH_SIZE_UNPACKED_DX7
midi_buffer_sysex_rx:                           DS PATCH_SIZE_UNPACKED_DX7

midi_channel_rx:                                DS 1
midi_channel_tx:                                DS 1

tape_patch_index:                               DS 1

; The current Pitch EG step for each of the synth's voices.
pitch_eg_current_step:                          DS 16

; When a patch is loaded, the serialised pitch EG rate/level values are
; converted into the format used internally to process the pitch EG, and stored
; to these two buffers.
; The code depends on these two arrays being in this sequential order.
pitch_eg_parsed_rate:                           DS 4
pitch_eg_parsed_level:                          DS 4
; The final pitch EG frequency for the current patch.
; This doubles as the INITIAL pitch EG frequency.
pitch_eg_parsed_level_final:                    EQU (#pitch_eg_parsed_level + 3)

; @TODO: Document
patch_operator_velocity_sensitivity:            DS 12

; The operator keyboard scaling level curve data.
; When the keyboard scaling level for an operator is parsed from the patch data,
; this curve data is created with the amplitude scaling factor for the full
; keyboard range.
; The MSB of the note frequency word is used as an index into this curve data
; when looking up the scaling factor for a particular note.
; Length: 6 * 43.
operator_keyboard_scaling_level_curve_table:    DS (6 * KEYBOARD_SCALE_CURVE_LENGTH)

; This array contains the final volume value for each operator for a voice.
; This is the value that will be loaded to the EGS.
operator_volume:                                DS 6

; This variable stores the synth's current UI mode, and memory protect state.
; Refer to the 'ui_memory_protect_state_set' subroutine for how the memory
; protect state is set.
; Bit 0-1 store the current UI state:
; * 0: Function
; * 1: Edit
; * 2: Memory Select
; Bit 2-3 store the memory protect state:
; If memory protect is enabled, bit 3 is set.
; If memory protect is disabled bit 2 is set.
ui_mode_memory_protect_state:                   DS 1

ui_btn_numeric_last_pressed:                    DS 1
ui_btn_numeric_previous_fn_mode:                DS 1
ui_btn_numeric_previous_edit_mode:              DS 1

operator_selected_src:                          DS 1
operator_selected_dest:                         DS 1

ui_currently_selected_eg_stage:                 DS 1

; This variable is used as an event dispatch flag.
; Depending on the value set, it will either cause the patch data to be
; reloaded to the EGS/OPS, or the data reloaded and all active voices halted.
main_patch_event_flag:                          DS 1

; Edit mode button 5 sub-function:
; * 0: Algorithm
; * 1: Feedback
ui_btn_edit_5_sub_function:                     DS 1

; Edit mode button 9 sub-function:
; * 0: LFO Amp Mod Depth
; * 1: LFO Pitch ""
ui_btn_edit_9_sub_function:                     DS 1

; Edit mode button 10 sub-function:
; * 0: LFO Amp Mod Sens
; * 1: LFO Pitch ""
ui_btn_edit_10_sub_function:                    DS 1

; Edit mode button 14 sub-function:
; * 0: Detune
; * 1: Oscillator Sync
; * 2: Oscillator Mode
ui_btn_edit_14_sub_function:                    DS 1

; Function mode button 6 sub-function:
; * 0: MIDI Channel
; * 1: Sys Info
; * 2: MIDI Transmit
ui_btn_function_6_sub_function:                 DS 1

; Function mode button 7 sub-function:
; * 0: Save to tape
; * 1: Verify tape
ui_btn_function_7_sub_function:                 DS 1

; Function mode button 19 sub-function:
; * 0: Edit Recall
; * 1: Voice Init
; * 2: Battery Voltage
ui_btn_function_19_sub_function:                DS 1

; This flag appears to block the mode cycling of button 9 when the synth is
; in 'Edit Mode'.
; It is set when the synth is switched into 'Edit' mode, and is disabled by
; the next press of button 9. So effectively it stops the first press of
; button 9 from cycling the mode.
; The reason this is used is likely so that the user can see which mode is
; selected PRIOR to the mode being cycled.
ui_flag_disable_edit_btn_9_mode_select:         DS 1

; These two variables are used by the user interface to control the currently
; selected 'Edit Parameter', which will be edited by the data input controls.
; The address, and maximum value are loaded from lookup tables in the UI
; routines.
ui_active_param_address:                        DS 2
ui_active_param_max_value:                      DS 1

; This variable is used to store the previously recorded slider input.
; This is used in the slider parameter update routine.
ui_slider_value_previous:                       DS 1

; This flag appears to disable 'Key Tranpose' UI functionality.
; This is ostensibly used so that the user doesn't activate the 'Key Transpose'
; mode by accident.
ui_flag_blocks_key_transpose:                   DS 1

; This flag tracks whether the patch currently loaded into the patch
; edit buffer has been modified.
patch_current_modified_flag:                    DS 1
patch_compare_mode_active:                      DS 1

patch_index_current:                            DS 1
patch_index_compare:                            DS 1

lfo_waveform:                                   DS 1
lfo_pitch_mod_sensitivity:                      DS 1
lfo_sample_hold_accumulator:                    DS 1

led_contents:                                   DS 2
led_compare_mode_blink_counter:                 DS 1

analog_input_source_next:                       DS 1

; Note that there is no 'previous' battery voltage reading.
; Unlike the others, this analog input source is not scanned periodically.
analog_input_previous:                          DS 4
analog_input_previous_pitch_bend:               EQU (#analog_input_current + 0)
analog_input_previous_mod_wheel:                EQU (#analog_input_current + 1)
analog_input_previous_breath_controller:        EQU (#analog_input_current + 2)
analog_input_previous_slider:                   EQU (#analog_input_current + 3)

analog_input_current:                           DS 5
analog_input_pitch_bend:                        EQU (#analog_input_current + 0)
analog_input_mod_wheel:                         EQU (#analog_input_current + 1)
analog_input_breath_controller:                 EQU (#analog_input_current + 2)
analog_input_slider:                            EQU (#analog_input_current + 3)
analog_input_battery_voltage:                   EQU (#analog_input_current + 4)

; This buffer stores the LCD screen's _current_ contents.
; During writing the string buffer to the LCD, if the current char to be
; written matches the one in there, the character copy process is skipped.
lcd_buffer_current:                             DS 32
lcd_buffer_current_end:                         EQU *

; This buffer stores the LCD screen's _next_ contents.
; These are the contents that will be printed to the LCD screen the next time
; the LCD screen is updated.
lcd_buffer_next:                                DS 32
lcd_buffer_next_line_2:                         EQU (#lcd_buffer_next + 16)
lcd_buffer_next_end:                            EQU *

; These temporary variables are used in various routines throughout the
; firmware, and are given appropriate contextual names in the routines where
; they are used, and are referenced in the re-definitions by this address.
; Note: These variables cannot be used in subroutines called during interrupts,
; otherwise they could clobber their usage in ordinary routines.
; Note: Also ensure that these variables are not used in subroutines that call
; one another. If these are used in such situations, ensure that they do not
; clobber each other.
temp_variables:                                 DS 18

; Like in the original DX9 ROM the voice buffers occupy a fixed space adjacent
; to the EGS chip. This allows for optimisation of the portamento routine.
; The stack occupies all of the free space left between the end of the defined
; variables, and the start of these voice buffers.
; This likely accounts for the stack's highly arbitrary size in the DX9.
; I'm not sure what the ideal size for the stack is, however it can likely be
; much smaller than it is in both the original DX9 (222), and the DX7 (448).
stack_bottom:                                   EQU *

stack_top:                                      EQU $177F

    ORG $1780

; The voice status array is used to store the current note, and voice status
; for each of the synth's 16 voices.
; Each entry is a two byte structure with the format:
;  (Key_Number << 8) | Flags.
; The flags field has two bits:
;  * '0b10' : This voice is actively playing a note.
;  * '0b1'  : This voice is being sustained.

; The DX7, and DX9 ROMs differ here, in that the DX9 stores the log frequency
; instead of the MIDI note number.
; In the DX9 the most-significant 14 bits are the log frequency of the voice's
; current note, and the 2 least-significant bits are a mask indicating the
; voice's status.
voice_status:                                   DS 32
; The 'target' frequency for each voice.
; This is the target, final frequency for each voice's frequency transition
; during portamento between two notes.
voice_frequency_target:                         DS 32
; This buffer holds the current frequency of the synth's 16 voices.
; If portamento is currently active the individual voices will transition from
; this current frequency towards their target frequency.
; This frequency is set by the main 'Voice add' subroutines.
voice_frequency_current:                        DS 32

; The current Pitch EG frequency for each of the synth's voices.
; The default value for each of these 16 entries is 0x4000. Since the pitch
; EG range is +-4 octaves, and in the EGS frequency registers each octave is
; represented by a logarithmic value of 0x1000, this represents the middle of
; that 8 octave range.
; This default value corresponds to a value of '50' in a patch's Pitch EG
; level.
pitch_eg_current_frequency:                     DS 32
