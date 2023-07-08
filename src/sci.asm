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
; sci.asm
; ==============================================================================
; DESCRIPTION:
; This file contains all definitions, and subroutines related to the synth's
; Serial Communications Interface.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; MIDI Error codes.
; @TAKEN_FROM_DX9_FIRMWARE
; These constants are used to track the status of the MIDI buffers. If an error
; condition occurs, these constants will be written to the appropriate memory
; location. They are referenced in printing error messages.
; This functionality is identical in the DX7 firmware.
; ==============================================================================
MIDI_ERROR_BUFFER_FULL                          EQU 1
MIDI_ERROR_OVERRUN                              EQU 2

; ==============================================================================
; HANDLER_SCI
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Top-level handler for all hardware Serial Communication Interface events.
; This subroutine handles the buffering of all incoming, and outgoing MIDI
; messages.
;
; ==============================================================================
handler_sci:                                    SUBROUTINE
    LDAA    <sci_ctrl_status

; If Status[RDRF] is set, it means there is data in the receive
; register. If so, branch.
    ASLA
    BCS     .receive_incoming_data

    ASLA

; Branch if Status[ORFE] is set.
    BCS     .midi_overrun_framing_error

; Checks if Status[TDRE] is clear.
; If so the serial interface is ready to transmit new data.
    BMI     .is_tx_buffer_empty

    BRA     .handler_sci_exit

.receive_incoming_data:
; Load the incoming data, store it into the RX buffer.
    LDAA    <sci_rx
    LDX     <midi_buffer_ptr_rx_write
    STAA    0,x

; Increment the write pointer, and test whether the end of the buffer has been
; reached.
    INX
    CPX     #midi_buffer_rx_end
    BNE     .is_rx_buffer_full

; Reset the RX data ring buffer if it has reached the end.
    LDX     #midi_buffer_rx

.is_rx_buffer_full:
; If the RX write pointer wraps around to the read pointer this indicates
; a MIDI buffer overflow.
    CPX     <midi_buffer_ptr_rx_read
    BEQ     .midi_buffer_full

    STX     <midi_buffer_ptr_rx_write
    BRA     .handler_sci_exit

.midi_buffer_full:
    LDAA    #MIDI_ERROR_BUFFER_FULL
    STAA    <midi_error_code
    JSR     midi_reset
    BRA     .handler_sci_exit

.is_tx_buffer_empty:
    LDX     <midi_buffer_ptr_tx_read
    CPX     <midi_buffer_ptr_tx_write

; If the read, and write pointer are equal, it indicates the buffer is empty.
    BEQ     .tx_buffer_empty

; Load the next MIDI byte to be sent.
; Test whether this is a MIDI status byte by checking bit 7.
    LDAA    0,x
    BPL     .tx_byte

; If the next byte to be sent is a status command, it is stored in a
; variable to ensure that the same status byte is not sent multiple times.
; If the status byte is a MIDI SysEx start command, this check is ignored.
    CMPA    #MIDI_STATUS_SYSEX_START
    BEQ     .store_last_sent_command

    CMPA    <midi_last_command_sent
    BEQ     .increment_tx_ptr

.store_last_sent_command:
    STAA    <midi_last_command_sent

.tx_byte:
    STAA    <sci_tx

.increment_tx_ptr:
    INX

; Check whether the read pointer has reached the end of the MIDI TX buffer,
; if so, the read pointer is reset to the start.
    CPX     #midi_buffer_rx
    BNE     .store_tx_ptr_read

    LDX     #midi_buffer_tx

.store_tx_ptr_read:
    STX     <midi_buffer_ptr_tx_read
    BRA     .handler_sci_exit

.tx_buffer_empty:
    LDAA    #(SCI_CTRL_TE | SCI_CTRL_RE | SCI_CTRL_RIE)
    STAA    <sci_ctrl_status
    BRA     .handler_sci_exit

.midi_overrun_framing_error:
    LDAA    #MIDI_ERROR_OVERRUN
    STAA    <midi_error_code
    JSR     midi_reset
    LDAA    <sci_rx

.handler_sci_exit:
    RTI
