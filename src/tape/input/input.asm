; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; tape/input.asm
; ==============================================================================
; DESCRIPTION:
; Contains functionality used to input patches over the cassete interface.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TAPE_INPUT_PATCH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Reads an individual patch over the synth's cassette interface.
; @NOTE: The patch format serialised/deserialised over the synth's cassette
; interface is the original DX9 format. Refer to the entry in the ROM's FAQ.
;
; ==============================================================================
tape_input_patch:                               SUBROUTINE
    LDX     #patch_buffer_incoming
    LDAB    #67
    STAB    tape_byte_counter
    JSR     tape_input_pilot_tone

.input_byte_loop:
    JSR     tape_input_byte
    STAA    0,x
    INX
    DEC     tape_byte_counter
    BNE     .input_byte_loop

    RTS


; ==============================================================================
; TAPE_INPUT_PILOT_TONE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Reads the cassette interface 'pilot tone', played before each patch in the
; cassette storage.
; @TODO: This function needs more documentation to explain how it works.
;
; ==============================================================================
tape_input_pilot_tone:                          SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.tape_input_pilot_tone_counter:                 EQU #temp_variables

; ==============================================================================
    PSHA
    PSHB
    PSHX

; Read the first tape input polarity value.
    LDAA    <io_port_1_data
    ANDA    #PORT_1_TAPE_INPUT
    STAA    <tape_input_polarity_previous

.reset_input_loop:
    CLR     .tape_input_pilot_tone_counter

.read_pilot_tone_period_loop:
    CLRB
    JSR     tape_input_read_pulse
; If the pulse was '12' or more in length, reset.
    CMPB    #12
    BCC     .reset_input_loop

; If the pulse less than '4' in length, reset.
    CMPB    #4
    BCS     .reset_input_loop

    INC     .tape_input_pilot_tone_counter
    BNE     .read_pilot_tone_period_loop

    PULX
    PULB
    PULA

    RTS


; ==============================================================================
; TAPE_INPUT_READ_PULSE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; This subroutine reads the length of a wave 'pulse' read from the cassette
; input interface.
; It polls the cassette input port, to test for the polarity changing,
; waiting until either the polarity changes, and the 'NO' button is pressed,
; which aborts the process.
;
; ARGUMENTS:
; Registers:
; * ACCB: The number of 'samples' previously read.
;
; RETURNS:
; * ACCB: The length of the pulse read so far.
;    Since the function calls itself to continue reading in the case of change
;    in polarity, this will become the new input.
;
; ==============================================================================
tape_input_read_pulse:                          SUBROUTINE
; If this line goes high, indicating the 'No' button was pressed, abort.
    TIMD   #KEY_SWITCH_LINE_0_BUTTON_NO, key_switch_scan_driver_input
    BNE     .read_aborted

    INCB

; Read the tape input line on port 1.
    LDAA    <io_port_1_data
    NOP

; Mask the newly read tape input line, and XOR with the previous input to
; test whether the polarity has changed since the last read.
    ANDA    #PORT_1_TAPE_INPUT
    EORA    <tape_input_polarity_previous
; If the polarity has not changed, loop back.
    BPL     tape_input_read_pulse

; Use XOR to reset the value to what it was before the previous operation.
    EORA    <tape_input_polarity_previous
    STAA    <tape_input_polarity_previous

    RTS

.read_aborted:
; Set the tape function aborted flag.
    LDAA    #1
    STAA    <tape_function_aborted_flag

; Add '8' to the stack to exit the tape read functionality.
    TSX
    LDAB    #8
    ABX
    TXS

    RTS


; ==============================================================================
; TAPE_INPUT_BYTE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Reads in a single byte from the synth's cassette interface.
;
; MEMORY MODIFIED:
; * tape_input_delay_length
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCA: The byte read from the cassette interface.
;
; ==============================================================================
tape_input_byte:                                SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.tape_input_byte_result:                        EQU #temp_variables

; ==============================================================================
    PSHB
    PSHX
    DES

; Wait for the previous wave pulse to finish before beginning reading a byte.
.finish_previous_pulse_loop:
    LDAA    <io_port_1_data
    NOP
    ANDA    #PORT_1_TAPE_INPUT
    STAA    <tape_input_polarity_previous
    CLRB
    JSR     tape_input_read_pulse
    CMPB    #13
    BCS     .finish_previous_pulse_loop

; The previous pulse length is stored in ACCB.
; This call delays the difference between the previous pulse length, which had
; to be '13', or higher, and '29'.
    LDAA    #29
    STAA    <tape_input_delay_length
    JSR     tape_input_delay

    LDX     #8
.read_bit_loop:
    JSR     tape_input_read_pulse

    LDAA    #21
    STAA    <tape_input_delay_length
    CLRB
    JSR     tape_input_delay

; ACCB is incremented here in the read pulse call.
    JSR     tape_input_read_pulse

; Compare against '23', and transfer the CPU condition codes into ACCA.
; This has the effect of setting the LSB if the pulse length was over '23'
    CMPB    #23
    TPA

; XOR the carry-bit contents with '1'. This has the effect of setting the carry
; bit to '1' if the pulse length was under '23'.
    EORA    #1
    TAP

; The carry bit will be rotated into the MSB of the result byte.
    LDAA    .tape_input_byte_result
    RORA
    STAA    .tape_input_byte_result

    JSR     tape_input_read_bit_delay

    DEX
    BNE     .read_bit_loop

    LDAA    .tape_input_byte_result
    INS
    PULX
    PULB

    RTS


; ==============================================================================
; TAPE_INPUT_READ_BIT_DELAY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Creates a short delay used between reading the pulses of individual bits
; when reading a byte.
;
; ==============================================================================
tape_input_read_bit_delay:                 SUBROUTINE
    LDAA    #29
    STAA    <tape_input_delay_length
; Fall-through below.

; ==============================================================================
; TAPE_INPUT_DELAY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Triggers a delay for an arbitrary specified period.
; This is used in the tape input subroutines.
;
; ARGUMENTS:
; Memory:
; * tape_input_delay_length: The amount of arbitrary 'cycles' to delay for.
;
; ==============================================================================
tape_input_delay:                               SUBROUTINE
    DELAY_SINGLE
    DELAY_SHORT

    NOP
    INCB
    CMPB    <tape_input_delay_length
    BCS     tape_input_delay

    RTS
