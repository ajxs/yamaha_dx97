; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; midi.asm
; ==============================================================================
; DESCRIPTION:
; This file contains all definitions, and subroutines related to the synth's
; MIDI functionality.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; MIDI_RX_CONTROL_CODE
; ==============================================================================
; DESCRIPTION:
; Handles incoming MIDI data when the pending MIDI event is a 'Control Code'
; event.
; If the incoming data is the first of the two required bytes, this function
; will store the incoming MIDI data, and jump back to process any further
; incoming MIDI data.
; If both bytes making up the message have been received, the synth will jump
; to the appropriate CC function handler based upon the event's control
; change code.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; ==============================================================================
midi_rx_control_code:                           SUBROUTINE
; Test whether the first data byte has already been processed.
; If not, the message is incomplete.
    TST     <midi_rx_data_count
    BEQ     .midi_rx_cc_incomplete

    CLR     <midi_rx_data_count

; Load the necessary data, and jump to the subroutine to add a new voice with
; the specified note.
    LDAB    midi_rx_first_data_byte

    JSR     jumpoff
; MIDI CC function jumpoff table.
    DC.B midi_rx_cc_1_mod_wheel - *
    DC.B 2
    DC.B midi_rx_cc_2_breath_controller - *
    DC.B 3
    DC.B midi_rx_cc_unsupported- *
    DC.B 5
    DC.B midi_rx_cc_5_portamento_time - *
    DC.B 6
    DC.B midi_rx_cc_6_data_entry - *
    DC.B 7
; Unlike the DX7, MIDI Volume is not supported on the DX9.
; As best I can tell the DAC's volume port is not wired into the CPU's IO
; ports, or address bus.
    DC.B midi_rx_cc_unsupported - *
    DC.B 64
    DC.B midi_rx_cc_64_sustain - *
    DC.B 65
    DC.B midi_rx_cc_65_portamento - *
    DC.B 66
    DC.B midi_rx_cc_unsupported - *
    DC.B 96
    DC.B midi_rx_cc_96_97_data_increment_decrement - *
    DC.B 98
    DC.B midi_rx_cc_unsupported - *
    DC.B 123
    DC.B midi_rx_cc_123_all_notes_off - *
    DC.B 124
    DC.B midi_rx_cc_unsupported - *
    DC.B 126
    DC.B midi_rx_cc_126_mode_mono - *
    DC.B 127
    DC.B midi_rx_cc_127_mode_poly - *
    DC.B 128

.midi_rx_cc_incomplete
    STORE_FIRST_BYTE_AND_PROCESS_NEXT_INCOMING_DATA


; ==============================================================================
; MIDI_RX_CC_UNSUPPORTED
; ==============================================================================
; DESCRIPTION:
; Handles receiving an unsupported control code message.
; Simply returns.
;
; ==============================================================================
midi_rx_cc_unsupported:                         SUBROUTINE
    RTS


; ==============================================================================
; MIDI_RX_CC_1_MOD_WHEEL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC4F3
; DESCRIPTION:
; Handles a MIDI CC event where the event number is '1'.
; This being a mod wheel event.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; ==============================================================================
midi_rx_cc_1_mod_wheel:                         SUBROUTINE
    ASLA
    STAA    analog_input_mod_wheel
    RTS


; ==============================================================================
; MIDI_RX_CC_2_BREATH_CONTROLLER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC52C
; DESCRIPTION:
; Handles a MIDI CC event where the event number is '2'.
; This being a breath controller event.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; ==============================================================================
midi_rx_cc_2_breath_controller:                 SUBROUTINE
    ASLA
    STAA    analog_input_breath_controller
    RTS


; ==============================================================================
; MIDI_RX_CC_5_PORTAMENTO_TIME
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC531
; DESCRIPTION:
; Handles a MIDI CC event where the event number is '5'.
; This being an update to the synth's portamento time.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; ==============================================================================
midi_rx_cc_5_portamento_time:                   SUBROUTINE
    LDAB    #200
    MUL
    STAA    portamento_time
    JSR     portamento_calculate_rate

; If the last button pressed was button 5 in 'Function Mode', this being
; the front-panel button to update the portamento time, print the
; main menu.
; This is presumably to update the value printed on the screen, if it is
; currently visible.
    LDAA    ui_btn_numeric_last_pressed
    CMPA    #BUTTON_FUNCTION_5
    BNE     .exit

    JMP     ui_print

.exit:
    RTS


; ==============================================================================
; MIDI_RX_CC_6_DATA_ENTRY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC545
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Handles a MIDI Control Code event of type '6'.
; This is intended to be a 'Data Entry' event.
; The TX7 Service manual suggests that this CC event is intended to update the
; currently selected "voice or function parameter", however the code appears
; to only actually work in function mode, and only work when the last pressed
; button was 'Button 1' in 'Function Mode', i.e. The master tune setting.
; This strange behaviour is shared by the v1.8 DX7 ROM.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
midi_rx_cc_6_data_entry:                        SUBROUTINE
    LDAB    ui_btn_numeric_last_pressed
    CMPB    #BUTTON_FUNCTION_1
    BNE     .exit

    TAB
    CLRA
    LSLD
    STD     master_tune

.exit:
    RTS


; ==============================================================================
; MIDI_RX_CC_64_SUSTAIN
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC550
; DESCRIPTION:
; Handles a MIDI control code message with a type of '64'.
; This is the command to affect the sustain pedal.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
; Valid data is either 0 to disable the pedal, or 0x7F to enable it.
;
; MEMORY MODIFIED:
; * pedal_status_current
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_rx_cc_64_sustain:                          SUBROUTINE
; Test whether the incoming value is 0 (Off), or 0x7F (On).
; Any other value has no effect.
    TSTA
    BNE     .set_sustain_active

    AIMD    #~PEDAL_INPUT_SUSTAIN, pedal_status_current
    BRA     .exit

.set_sustain_active:
    CMPA    #$7F
    BNE     .exit

    OIMD    #PEDAL_INPUT_SUSTAIN, pedal_status_current

.exit:
    RTS


; ==============================================================================
; MIDI_RX_CC_65_PORTAMENTO
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC550
; DESCRIPTION:
; Handles a MIDI control code message with a type of '65'.
; This is the command to affect the portamento pedal.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
; Valid data is either 0 to disable the pedal, or 0x7F to enable it.
;
; MEMORY MODIFIED:
; * pedal_status_current
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_rx_cc_65_portamento:                       SUBROUTINE
; Test whether the incoming value is 0 (Off), or 0x7F (On).
; Any other value has no effect.
    TSTA
    BNE     .set_portamento_active

    AIMD    #~PEDAL_INPUT_PORTA, pedal_status_current
    BRA     .exit

.set_portamento_active:
    CMPA    #$7F
    BNE     .exit

    OIMD    #PEDAL_INPUT_PORTA, pedal_status_current

.exit:
    RTS


; ==============================================================================
; MIDI_RX_CC_96_97_DATA_INCREMENT_DECREMENT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC570
; DESCRIPTION:
; Handles a MIDI control code message with a type of '96', or '97.
; These are the MIDI commands to increment, or decrement the currently
; selected parameter.
;
; ARGUMENTS:
; Registers:
; * ACCB: The MIDI control code.
;         This is either '96' for 'Yes', or '97' for 'No'.
;
; ==============================================================================
midi_rx_cc_96_97_data_increment_decrement:      SUBROUTINE
    CMPA    #127
    BNE     .exit

    LDAA    ui_btn_numeric_last_pressed
    CMPA    #BUTTON_FUNCTION_1
    BEQ     .exit

; 'Function Mode' button 6 has no function, so do not perform any action.
    CMPA    #BUTTON_FUNCTION_6
    BEQ     .exit

; 'Function Mode' button 10 controls the tape remote polarity.
; Do not perform any action in this case.
    CMPA    #BUTTON_FUNCTION_10
    BEQ     .exit

; 'Function Mode' button 20 controls the synth memory protection.
; Do not perform any action in this case.
    CMPA    #BUTTON_FUNCTION_20
    BEQ     .exit

; Subtract '95' from ACCB so that the value passed to the
; increment/decrement subroutine is '1' for 'Yes', '2' for 'No'.
    SUBB    #95
    JSR     ui_increment_decrement_parameter
    JSR     ui_print_update_led_and_menu

.exit:
    RTS


; ==============================================================================
; MIDI_RX_CC_123_ALL_NOTES_OFF
; ==============================================================================
; DESCRIPTION:
; Deactivates all active notes, and resets all voice parameters.
;
; ==============================================================================
midi_rx_cc_123_all_notes_off:                   SUBROUTINE
    JMP     voice_reset


; ==============================================================================
; MIDI_RX_CC_126_MODE_MONO
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC590
; DESCRIPTION:
; Handles a MIDI control code message with a type of '126'.
; This is the command to set the synth to monophonic mode.
;
; MEMORY MODIFIED:
; * mono_poly
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_rx_cc_126_mode_mono:                       SUBROUTINE
    TST     mono_poly
    BNE     .exit

    LDAA    #1
    STAA    mono_poly

midi_rx_polyphony_reset_voices:
; If the synth's polyphony settings have changed, reset all of the voice data.
    JSR     voice_reset

; If the last button pressed was the 'Function Mode' button to control
; the synth's polyphony, print the synth's menu.
    LDAA    ui_btn_numeric_last_pressed
    CMPA    #BUTTON_FUNCTION_2
    BNE     .exit

    JSR     ui_print

.exit:
    RTS


; ==============================================================================
; MIDI_RX_CC_127_MODE_POLY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC5AE
; DESCRIPTION:
; Handles a MIDI Control Code message with a type of '127'.
; This sets the synth to polyphonic mode.
;
; MEMORY MODIFIED:
; * mono_poly
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_rx_cc_127_mode_poly:                       SUBROUTINE
; If the synth is already polyphonic, exit.
    TST     mono_poly
    BEQ     .exit

    CLR     mono_poly
    BRA     midi_rx_polyphony_reset_voices

.exit:
    RTS
