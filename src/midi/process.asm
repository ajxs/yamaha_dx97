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
; midi/process.asm
; ==============================================================================
; DESCRIPTION:
; Contains functionality for processing incoming MIDI events.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; MIDI_PROCESS_INCOMING_DATA
; ==============================================================================
; DESCRIPTION:
; Processes the incoming MIDI messages stored in the MIDI RX buffer.
; This subroutine is called by the synthesizer's main loop.
; All of the synth's incoming MIDI functionality is initiated in this function.
;
; MEMORY MODIFIED:
; * midi_buffer_rx_ptr_read
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
midi_process_incoming_data:                     SUBROUTINE
; Test whether there is a current MIDI error code set.
; If not, proceed to processing the incoming data, otherwise print the
; associated error message, and exit.
    TST     <midi_error_code
    BEQ     .is_queue_empty

    JMP     midi_print_error_message

.is_queue_empty:
; Test whether the MIDI RX ring buffer read, and write pointers are equal,
; indicating that the MIDI RX buffer is empty.
; If not, proceed to processing the incoming MIDI data.
    LDX     <midi_buffer_ptr_rx_read
    CPX     <midi_buffer_ptr_rx_write
    BNE     .process_incoming_data

    CLR     <midi_rx_processing_pending

; In the event that the MIDI RX buffer is empty:
; Test whether the synth is currently receiving SysEx data.
; If this is the case reset the periodic interrupt, and exit.
; This functionality was copied from the DX9 firmware.
    LDAA    <midi_sysex_rx_active_flag
    BNE     .reset_and_exit

    RTS

.process_incoming_data:
    LDAA    #1
    STAA    <midi_rx_processing_pending

; Read the next incoming data byte.
; IX still contains the MIDI RX buffer read pointer.
    LDAA    0,x

; Increment the MIDI RX buffer read pointer, and test if it has overflowed.
; If so, reset it to the start of the buffer.
    INX
    CPX     #midi_buffer_rx_end
    BNE     .store_updated_rx_pointer

    LDX     #midi_buffer_rx

.store_updated_rx_pointer:
    STX     <midi_buffer_ptr_rx_read

; Test the incoming MIDI message to determine whether it's a data, or
; status byte. Bit 7 being set indicates that this is a status byte.
    TSTA
    BPL     midi_process_data_message

    BRA     midi_process_status_message

.reset_and_exit:
    CLR     midi_sysex_rx_active_flag
    JMP     midi_reset_timers


; ==============================================================================
; MIDI_PROCESS_STATUS_MESSAGE
; ==============================================================================
; DESCRIPTION:
; Handles any incoming MIDI status message.
; Typically this will just store the current message type, and return.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received status code.
;
; MEMORY MODIFIED:
; * midi_last_command_received
; * midi_rx_data_count
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_process_status_message:                    SUBROUTINE
; If the status code is 0xF7 or above, test if active sensing, otherwise ignore.
; Like in the original DX9 firmware, the SysEx end message is ignored.
    CMPA    #MIDI_STATUS_SYSEX_END
    BCS     .store_message_type

; The original DX9 firmware handled active sensing differently.
; Refer to the documentation on the 'midi_rx_active_sensing' function.
; This is handled here on account of active sensing not requiring any data.
    CMPA    #MIDI_STATUS_ACTIVE_SENSING
    BEQ     midi_rx_active_sensing

; Any other status code above 0xF7 is ignored.
; In this case, there's no need to store the 'last MIDI command', as no further
; processing is necessary, and these commands don't have any associated data.
    BRA     .exit

.store_message_type:
    STAA    <midi_last_command_received
    CLR     <midi_rx_data_count

; Return back to process any further incoming data in the buffer.
.exit:
    JMP     midi_process_incoming_data


; ==============================================================================
; MIDI_PROCESS_DATA_MESSAGE
; ==============================================================================
; DESCRIPTION:
; Processes an incoming MIDI data byte.
; This subroutine will handle storing the incoming data bytes associated with
; a command message. Once all of the required data has been received, this
; subroutine will jump to the relevant routine.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; MEMORY MODIFIED:
; * midi_rx_data_count
;
; REGISTERS MODIFIED:
; * ACCB
;
; ==============================================================================
midi_process_data_message:                      SUBROUTINE
; Check whether the status is under 0xF0. If so, branch.
    LDAB    <midi_last_command_received
    CMPB    #MIDI_STATUS_SYSEX_START
    BCS     .test_midi_channel

; If the status code is higher than 0xF0, ignore.
; Proceed to process the next incoming message in the buffer.
    BHI     midi_process_incoming_data

    JMP     midi_sysex_rx

.test_midi_channel:
; Mask the MIDI channel nibble, and validate whether it matches the synth's
; selected MIDI receive channel.
; Exit if this message is not intended for this device.
    ANDB    #%1111
    CMPB    midi_channel_rx
    BNE     .exit

; Load the last status byte received, shift it right 4 bits, and mask the three
; least-significant bits. This will create a usable index from the MIDI status
; byte.
    LDAB    <midi_last_command_received
    LSRB
    LSRB
    LSRB
    LSRB
    ANDB    #%111

; Use the masked status byte as an index into this table of MIDI function
; pointers, then jump to the relevant function.
    LDX     #table_midi_function_pointers
    ASLB
    ABX
    LDX     0,x
    JMP     0,x

.exit
    RTS


; ==============================================================================
; MIDI function pointers.
; This table is referenced by the subroutine that handles incoming MIDI data
; messages.
; The last received status byte is masked, and used as an index into this
; table. The appropriate function is then jumped to.
; ==============================================================================
table_midi_function_pointers:
    DC.W                                        midi_rx_note_off
    DC.W                                        midi_rx_note_on
    DC.W                                        midi_rx_aftertouch
    DC.W                                        midi_rx_control_code
    DC.W                                        midi_rx_program_change
    DC.W                                        midi_rx_aftertouch
    DC.W                                        midi_rx_pitch_bend


; ==============================================================================
; MIDI_RX_ACTIVE_SENSING
; ==============================================================================
; @NEW_FUNCTIONALITY
; @NEEDS_TESTING
; DESCRIPTION:
; Handles an incoming MIDI active sensing message.
; The original DX9 firmware handled active sensing very differently.
; In the original, a SysEx start header together with the manufacturer code
; indicated a SysEx 'pulse'. Later ratifications of the MIDI standard
; implemented the current standard, which was subsequently introduced in a new
; ROM revision.
; From Yamaha Service News E-325:
; """
; Since DX-7 had been developed and released to the field before the MIDI
; Standard was established, on some occasions, earlier models may develop
; operational problems due to the MIDI code discord between instruments.
; Therefore, in order to improve the performanceof DX-7, some specifications
; have been modified as well as a change in the System ROM Version.
; """
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; MEMORY MODIFIED:
; * midi_active_sensing_rx_counter_enabled
; * midi_active_sensing_rx_counter
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_rx_active_sensing:                         SUBROUTINE
    LDAA    #1
    STAA    <midi_active_sensing_rx_counter_enabled
    CLR     <midi_active_sensing_rx_counter

    RTS


; ==============================================================================
; MIDI_RX_NOTE_OFF
; ==============================================================================
; DESCRIPTION:
; Handles incoming MIDI data when the pending MIDI event is a 'Note Off' event.
; If the incoming data is the first of the two required bytes, this function
; will store the incoming MIDI data, and return.
; If both bytes have been received, the internal 'Note Number' event dispatch
; register will be set with the incoming MIDI data, which will trigger a
; 'Voice Remove' event with the requested note.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; MEMORY MODIFIED:
; * note_velocity
;
; REGISTERS MODIFIED:
; * ACCB
;
; ==============================================================================
midi_rx_note_off:                               SUBROUTINE
; Test whether the first data byte has already been processed.
; If not, the message is incomplete.
    TST     <midi_rx_data_count
    BEQ     .midi_rx_note_off_incomplete

; This label is also referenced in the case that an incoming 'Note On' message
; has a velocity of zero. If so, it is treated as a 'Note Off' event.
midi_rx_note_off_process:
    CLR     <midi_rx_data_count
    STAA    <note_velocity

; Load the necessary data, and jump to the subroutine to remove the voice with
; the specified note.
    LDAB    <midi_rx_first_data_byte
    JMP     voice_remove

.midi_rx_note_off_incomplete:
    STORE_FIRST_BYTE_AND_PROCESS_NEXT_INCOMING_DATA


; ==============================================================================
; MIDI_RX_NOTE_ON
; ==============================================================================
; DESCRIPTION:
; Handles incoming MIDI data when the pending MIDI event is a 'Note On' event.
; If the incoming data is the first of the two required bytes, this function
; will store the incoming MIDI data, and return.
; If both bytes have been received, the internal 'Note Number' event dispatch
; register will be set with the incoming MIDI data, which will trigger a
; 'Voice Add' event with the requested note.
; If the velocity of the incoming MIDI event is zero, then the MIDI event will
; be handled by the synth as a 'Note Off' event.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; MEMORY MODIFIED:
; * note_velocity
;
; REGISTERS MODIFIED:
; * ACCB
;
; ==============================================================================
midi_rx_note_on:                                SUBROUTINE
; Test whether the first data byte has already been processed.
; If not, the message is incomplete.
    TST     <midi_rx_data_count
    BEQ     .midi_rx_note_on_incomplete

; Clear the processed data count. This is important for the synth dealing with
; 'Running Status' MIDI messages.
    CLR     <midi_rx_data_count

; Check if the incoming velocity value is zero.
; If so, process this as a 'Note Off' event.
    TSTA
    BEQ     midi_rx_note_off_process

; Translate the incoming MIDI velocity to its internal representation.
    TAB
    LSRB
    LSRB
    LDX     #table_midi_velocity
    ABX
    LDAA    0,x
    STAA    <note_velocity

; Load the necessary data, and jump to the subroutine to add a new voice with
; the specified note.
    LDAB    <midi_rx_first_data_byte
    JMP     voice_add

.midi_rx_note_on_incomplete:
    STORE_FIRST_BYTE_AND_PROCESS_NEXT_INCOMING_DATA


; ==============================================================================
; MIDI Velocity Table.
; This table is used to translate between the incoming MIDI velocity value
; (0..127) and the synth's internal note velocity value.
; ==============================================================================
table_midi_velocity:
    DC.B $6E
    DC.B $64
    DC.B $5A
    DC.B $55
    DC.B $50
    DC.B $4B
    DC.B $46
    DC.B $41
    DC.B $3A
    DC.B $36
    DC.B $32
    DC.B $2E
    DC.B $2A
    DC.B $26
    DC.B $22
    DC.B $1E
    DC.B $1C
    DC.B $1A
    DC.B $18
    DC.B $16
    DC.B $14
    DC.B $12
    DC.B $10
    DC.B $E
    DC.B $C
    DC.B $A
    DC.B 8
    DC.B 6
    DC.B 4
    DC.B 2
    DC.B 1
    DC.B 0


; ==============================================================================
; MIDI_RX_AFTERTOUCH
; ==============================================================================
; @NEW_FUNCTIONALITY
; DESCRIPTION:
; Aftertouch is currently not supported.
;
; ==============================================================================
midi_rx_aftertouch:                             SUBROUTINE
    RTS


; ==============================================================================
; MIDI_RX_PROGRAM_CHANGE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Handles incoming MIDI data when the pending MIDI event is a
; 'Program Change' event.
; This MIDI event will trigger changing the currently selected patch.
; This subroutine tests whether the synth is in 'Play/Memory Select' mode,
; and if so triggers a front-panel numeric button press event to select the
; new patch.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; MEMORY MODIFIED:
; * main_patch_event_flag
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
midi_rx_program_change:                         SUBROUTINE
; If the patch number is equal to the total patch amount, or above, set to the
; last patch index.
    CMPA    #PATCH_BUFFER_COUNT
    BCS     .is_synth_in_play_mode

    LDAA    #(PATCH_BUFFER_COUNT - 1)

.is_synth_in_play_mode:
; Test whether the synth is in 'Play/Memory Select' mode. If not, exit.
    LDAB    ui_mode_memory_protect_state
    CMPB    #UI_MODE_PLAY
    BNE     .exit

    CLR     main_patch_event_flag

; Transfer A to B, then add 8.
; 8 is the front-panel button offset for 'Button 1'.
; Adding 8 will offset B from the start of the buttons.
; The input handler button processor is then called.
    TAB
    ADDB    #INPUT_BUTTON_1
    JSR     main_input_handler_process_button

.exit:
    RTS


; ==============================================================================
; MIDI_RX_PITCH_BEND
; ==============================================================================
; DESCRIPTION:
; Handles incoming MIDI 'Pitch Bend' events.
; If the incoming data is the first of the two required bytes, this function
; will store the incoming MIDI data, and jump back to process any further
; incoming MIDI data.
; If both bytes have been received, the internal register for storing the
; analog pitch bend data will be updated with the MSB of the incoming data.
;
; A MIDI pitch bend event is transmitted as three bytes, the status byte,
; and two data bytes.
; Refer to this resource for more information on the structure of a
; MIDI pitch-bend event:
; https://sites.uci.edu/camp2014/2014/04/30/managing-midi-pitchbend-messages/
;
; Like many other synths, the DX7/9 only use the MSB of the pitch-bend data
; standard internally.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data.
;
; MEMORY MODIFIED:
; * analog_input_pitch_bend
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_rx_pitch_bend:                             SUBROUTINE
; Test whether the first data byte has already been processed.
; If not, the message is incomplete.
    TST     <midi_rx_data_count
    BEQ     .midi_rx_pitch_bend_incomplete

    CLR     <midi_rx_data_count

; Only take the MSB, discard the 1st data byte with the LSB.
    ASLA
    STAA    analog_input_pitch_bend

    RTS

.midi_rx_pitch_bend_incomplete:
    STORE_FIRST_BYTE_AND_PROCESS_NEXT_INCOMING_DATA
