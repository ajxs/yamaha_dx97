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
; midi/tx.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions, and code related to the sending of outgoing
; MIDI events from the synth.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; MIDI_TX_NOTE_ON
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Sends a 'Note On' MIDI event.
; Note: The DX9 transmits a fixed velocity on account of not having a velocity
; sensitive keyboard.
;
; ARGUMENTS:
; Registers:
; * ACCB: The MIDI note number to send with the 'Note On' event.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
midi_tx_note_on:                                SUBROUTINE
    LDAA    #MIDI_STATUS_NOTE_ON
    JSR     midi_tx
    TBA
    JSR     midi_tx

; Send output MIDI velocity.
    LDAA    <note_velocity
    JSR     midi_tx

    RTS


; ==============================================================================
; MIDI_TX_NOTE_OFF
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Sends a 'Note Off' MIDI event.
; The DX9 creates a 'Note Off' MIDI event by sending a 'Note On' event with
; zero velocity.
;
; ARGUMENTS:
; Registers:
; * ACCB: The MIDI note number to send with the 'Note Off' event.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
midi_tx_note_off:                               SUBROUTINE
    LDAA    #MIDI_STATUS_NOTE_ON
    JSR     midi_tx
    TBA
    JSR     midi_tx
    CLRA
    JSR     midi_tx

    RTS


; ==============================================================================
; MIDI_TX_ANALOG_INPUT_EVENT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Transmits an analog input event, such as a portamento, or sustain pedal
; status change, as a MIDI 'Mode Change' MIDI event.
; This subroutine sends the argument in ACCB, then ACCA shifted once to the
; right. This is done since the value must be 7-bits to be a MIDI data message.
;
; ARGUMENTS:
; Registers:
; * ACCA: The 'value' of the mode change event.
; * ACCB: Type 'type' of the 'Mode Change' event.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
midi_tx_analog_input_event:                     SUBROUTINE
    PSHA
    LDAA    #MIDI_STATUS_MODE_CHANGE
    JSR     midi_tx
    TBA
    JSR     midi_tx
    PULA
    LSRA
    JSR     midi_tx

    RTS


; ==============================================================================
; MIDI_TX_PEDAL_STATUS_SUSTAIN
; ==============================================================================
; DESCRIPTION:
; Sends a MIDI 'Mode Change' event corresponding to the sustain pedal status.
; Sends either a 0, or 0xFF value, depending on whether the pedal status is
; off, or on.
;
; ==============================================================================
midi_tx_pedal_status_sustain:                   SUBROUTINE
    LDAB    #64
    CLRA
    TIMD   #PEDAL_INPUT_SUSTAIN, pedal_status_current
; Falls-through below.

; ==============================================================================
; MIDI_TX_ANALOG_INPUT_SUSTAIN_PORTA
; ==============================================================================
; DESCRIPTION:
; Sends a MIDI message corresponding to portamento, and sustain analog inputs.
;
; ARGUMENTS:
; Registers:
; * CC:C: Whether the analog input event was 'On', or 'Off'.
;
; ==============================================================================
midi_tx_analog_input_sustain_porta:             SUBROUTINE
    BEQ     .send_input_event
    COMA

.send_input_event:
    JSR     midi_tx_analog_input_event
    RTS


; ==============================================================================
; MIDI_TX_PEDAL_STATUS_PORTAMENTO
; ==============================================================================
; DESCRIPTION:
; Sends a MIDI 'Mode Change' event corresponding to the portamento pedal
; status. Sends either a 0, or 0xFF value, depending on whether the pedal
; status is off, or on.
;
; ==============================================================================
midi_tx_pedal_status_portamento:                SUBROUTINE
    LDAB    #65
    CLRA
    TIMD   #PEDAL_INPUT_PORTA, pedal_status_current
    BRA     midi_tx_analog_input_sustain_porta


; ==============================================================================
; MIDI_TX_CC_INCREMENT_DECREMENT
; ==============================================================================
; DESCRIPTION:
; Sends a MIDI control change event corresponding to the triggering of the
; yes/no front-panel buttons.
;
; ARGUMENTS:
; Registers:
; * ACCB: The triggering front-panel button. In this case, either YES(1),
;         or NO(2).
;
; ==============================================================================
midi_tx_cc_increment_decrement:                 SUBROUTINE
    PSHB
    ADDB    #95
    LDAA    #$FF
    JSR     midi_tx_analog_input_event
    PULB

    RTS


; ==============================================================================
; MIDI_TX_PITCH_BEND
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Sends a MIDI event corresponding to an update from the front-panel
; pitch-bend wheel.
; This will send a 14-bit value over the selected MIDI channel, sent as
; three bytes, the status byte, and two data bytes.
; Refer to this resource for more information on the structure of a
; MIDI pitch-bend event:
; https://sites.uci.edu/camp2014/2014/04/30/managing-midi-pitchbend-messages/
;
; (from the above site) "If we bit-shift 95 to the left by 7 bits we
; get 12,160, and if we then combine that with the LSB value 120 by a
; bitwise OR or by addition, we get 12,280."
;
; ARGUMENTS:
; Registers:
; * ACCA: The pitch-bend value received from the hardware input scanner.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
midi_tx_pitch_bend:                             SUBROUTINE
    TAB
    LDAA    #MIDI_STATUS_PITCH_BEND
    JSR     midi_tx
    TBA

; If this value is positive, indicating that the value is a downward bend,
; clear the MSB of the two-byte MIDI data message.
    BPL     .pitch_bend_downwards

    ANDA    #%1111111
    BRA     .send_pitch_bend_event

.pitch_bend_downwards:
    CLRA

.send_pitch_bend_event:
    JSR     midi_tx
    TBA
    LSRA
    JSR     midi_tx

    RTS

