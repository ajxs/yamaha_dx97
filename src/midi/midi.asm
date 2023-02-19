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
; midi.asm
; ==============================================================================
; DESCRIPTION:
; This file contains all definitions, and subroutines related to the synth's
; MIDI functionality.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; MIDI Status Codes.
; ==============================================================================
MIDI_STATUS_NOTE_OFF:                           EQU $80
MIDI_STATUS_NOTE_ON:                            EQU $90
MIDI_STATUS_MODE_CHANGE:                        EQU $B0
MIDI_STATUS_PROGRAM_CHANGE:                     EQU $C0
MIDI_STATUS_PITCH_BEND:                         EQU $E0
MIDI_STATUS_SYSEX_START:                        EQU $F0
MIDI_STATUS_SYSEX_END:                          EQU $F7
MIDI_STATUS_ACTIVE_SENSING:                     EQU $FE

; ==============================================================================
; MIDI SysEx Constants.
; ==============================================================================
MIDI_SYSEX_FORMAT_BULK:                         EQU 9
MIDI_SYSEX_SUBSTATUS_PARAM_CHANGE:              EQU $10
MIDI_MANUFACTURER_ID_YAMAHA:                    EQU $43

; ==============================================================================
; MIDI CC Constants
; ==============================================================================
MIDI_CC_DATA_ENTRY                              EQU 6

; ==============================================================================
; Macro for incrementing the received byte count, and returning to process
; further incoming MIDI data.
; ==============================================================================
    .MAC INCREMENT_BYTE_COUNT_AND_RETURN
        INC     midi_rx_data_count
        JMP     midi_process_incoming_data
    .ENDM

; ==============================================================================
; MIDI_INIT
; ==============================================================================
; DESCRIPTION:
; Initialises the synth's MIDI interface.
; This sets up the SCI to enable interrupts, and initialises the synth's
; MIDI ring buffers.
;
; MEMORY MODIFIED:
; * midi_last_command_received
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_init:                                      SUBROUTINE
; Set the data format, and clock source for the serial interface.
    LDAA    #(RATE_MODE_CTRL_CC0 | RATE_MODE_CTRL_CC1)
    STAA    <rate_mode_ctrl

    LDAA    #(SCI_CTRL_TE | SCI_CTRL_RE | SCI_CTRL_RIE | SCI_CTRL_TDRE)
    STAA    <sci_ctrl_status

    LDAA    <sci_ctrl_status
    LDAA    <sci_rx

; Set the last received MIDI status to that of a 'SysEx End' message.
; This will cause a no-operation in the main executive loop's MIDI
; processing function.
    LDAA    #MIDI_STATUS_SYSEX_END
    STAA    <midi_last_command_received

; Reset the synth's MIDI buffers.
    JMP     midi_reset_buffers


; ==============================================================================
; MIDI_RESET
; ==============================================================================
; DESCRIPTION:
; Halts all active voices, and resets the synth's MIDI interface.
; This routine is called in the case of an SCI error.
;
; MEMORY MODIFIED:
; * midi_last_command_received
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_reset:                                     SUBROUTINE
; Reset the voices on the EGS.
    JSR     voice_reset_egs
    JSR     voice_reset_frequency_data

    CLR     active_voice_count

; Set the last received MIDI status to that of a 'SysEx End' message.
; This will cause a no-operation in the main executive loop's MIDI
; processing function.
    LDAA    #MIDI_STATUS_SYSEX_END
    STAA    <midi_last_command_received

; Reset the synth's MIDI receive buffer.
    JMP     midi_reset_read_buffer


; ==============================================================================
; MIDI_RESET_BUFFERS
; ==============================================================================
; DESCRIPTION:
; Resets the MIDI TX, and RX ring buffers.
;
; MEMORY MODIFIED:
; * midi_buffer_ptr_tx_read
; * midi_buffer_ptr_tx_write
; * midi_buffer_ptr_rx_read
; * midi_buffer_ptr_rx_write
;
; REGISTERS MODIFIED:
; * IX
;
; ==============================================================================
midi_reset_buffers:                             SUBROUTINE
; Initialise the synth's MIDI transmit ring buffer.
; This is done by pointing both the read, and write buffer pointers to the
; start of the TX data buffer.
    LDX     #midi_buffer_tx
    STX     <midi_buffer_ptr_tx_read
    STX     <midi_buffer_ptr_tx_write

midi_reset_read_buffer:
; Initialise the synth's MIDI receive ring buffer.
    LDX     #midi_buffer_rx
    STX     <midi_buffer_ptr_rx_read
    STX     <midi_buffer_ptr_rx_write

    RTS


; ==============================================================================
; MIDI_RESET_TIMERS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Resets the CPU's internal timers.
; This is called after finishing recieving SysEx data.
; This is taken directly from the DX9 firmware. It possibly could be replaced
; with a macro, as it is only called twice.
;
; ==============================================================================
midi_reset_timers:                              SUBROUTINE
    LDX     #0
    STX     <free_running_counter

; Reading this register clears the Timer Overflow Flag (TOF).
    LDAA    <timer_ctrl_status
    LDX     #2500
    STX     <output_compare

; Enable output compare (OCF) interrupt.
    LDAA    #TIMER_CTRL_EOCI1
    STAA    <timer_ctrl_status

    RTS


; ==============================================================================
; MIDI_PRINT_ERROR_MESSAGE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; If an error condition is encountered during the processing of incoming, or
; outgoing MIDI data, the 'midi_error_code' variable will be set.
; This subroutine will print the appropriate message to the LCD, according to
; this error code.
;
; Memory:
; * midi_error_code: The error code to print.
;
; MEMORY MODIFIED:
; * midi_error_code
;
; REGISTERS MODIFIED:
; * ACCA, IX
;
; ==============================================================================
midi_print_error_message:                       SUBROUTINE
    JSR     lcd_clear_line_2
    LDAA    #MIDI_ERROR_BUFFER_FULL
    CMPA    <midi_error_code
    BNE     .print_error_message_data

    LDX     #str_midi_error_buffer_full
    BRA     .print_error_message_print_and_exit

.print_error_message_data:
    LDX     #str_midi_error_data

.print_error_message_print_and_exit:
    JSR     lcd_strcpy
    JSR     lcd_update
    CLR     midi_error_code

    RTS


; ==============================================================================
; MIDI_TX
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Pushes a MIDI message byte to the MIDI TX ring buffer.
; This message will be sent in the next SIO interrupt handler event.
;
; ARGUMENTS:
; Registers:
; * ACCA: The MIDI message byte to enqueue.
;
; REGISTERS MODIFIED:
; * ACCA, IX
;
; ==============================================================================
midi_tx:                                        SUBROUTINE
    LDX     <midi_buffer_ptr_tx_write
    STAA    0,x

; Check whether the MIDI TX write buffer has reached the last address within
; the MIDI TX buffer.
    CPX     #midi_buffer_tx_end - 1
; If the ring buffer hasn't reached the last address, branch.
    BNE     .increment_buffer_ptr

; If the pointer pointed to the last address in the TX buffer, load the last
; address BEFORE the TX buffer, prior to the pointer being incremented and
; stored.
    LDX     #midi_buffer_tx - 1

.increment_buffer_ptr:
    INX
    CPX     <midi_buffer_ptr_tx_read
    BEQ     midi_tx

    STX     <midi_buffer_ptr_tx_write

; Enable TX, RX, TX interrupts, and RX interrupts.
    LDAA    #(SCI_CTRL_TE | SCI_CTRL_RE | SCI_CTRL_TIE | SCI_CTRL_RIE)
    STAA    <sci_ctrl_status

    RTS


; ==============================================================================
; MIDI_TX_ACTIVE_SENSING
; ==============================================================================
; DESCRIPTION:
; Sends an 'Active Sensing' event via the MIDI interface.
;
; ==============================================================================
midi_tx_active_sensing:                         SUBROUTINE
    LDAA    #MIDI_STATUS_ACTIVE_SENSING
    JSR     midi_tx

    RTS
