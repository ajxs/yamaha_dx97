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
; tape/output.asm
; ==============================================================================
; DESCRIPTION:
; Contains functionality used to output patches over the cassete interface.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TAPE_OUTPUT_PATCH
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; Outputs a single patch from the temporary tape output buffer via the synth's
; cassette interface.
;
; MEMORY MODIFIED:
; * tape_byte_counter
;
; ==============================================================================
tape_output_patch:                              SUBROUTINE
    LDX     #patch_buffer_tape_temp
    LDAB    #67
    STAB    <tape_byte_counter
    JSR     tape_output_pilot_tone
    LDAB    #28

    DELAY_SHORT
    NOP

.output_byte_loop:
    LDAA    0,x
    JSR     tape_output_byte

; @TODO: What is this?
    LDAB    #27
    DELAY_SINGLE
    INX
    DEC     tape_byte_counter
    BNE     .output_byte_loop

    RTS


; ==============================================================================
; TAPE_OUTPUT_PILOT_TONE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Outputs the pilot tone played before sending a patch.
;
; Memory:
; * tape_patch_output_counter: If this is the first patch being sent over the
;    tape interface, an extra long pilot tone is output.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
tape_output_pilot_tone:                         SUBROUTINE
    PSHA
    PSHB
    PSHX

; If this is the first patch being output in the bulk patch dump, output
; a long pilot tone, otherwise output a short pilot tone between patches.
    TST     tape_patch_output_counter
    BNE     .output_short_pilot_tone

    LDX     #12000
    BRA     .output_pilot_tone_loop

.output_short_pilot_tone:
    LDX     #600

.output_pilot_tone_loop:
; This setting of ACCB applies to the output subroutine in the loop below.
    LDAB    #14
    DELAY_SHORT
    NOP
; @TODO: What is this?
    DES
    JSR     tape_output_bit_one
    INS

    DEX
    BNE     .output_pilot_tone_loop

    PULX
    PULB
    PULA

    RTS


; ==============================================================================
; TAPE_OUTPUT_BIT_ONE
; ==============================================================================
; DESCRIPTION:
; Outputs a '1' bit via the synth's tape output interface.
; The initial pulse width is not hardcoded, since it belongs to the bit that
; was previously being output, and needs to match its length.
;
; ARGUMENTS:
; Registers:
; * ACCB: The width of the initial 'pulse'.
;
; ==============================================================================
tape_output_bit_one:
; The setting of ACCA sets the stating polarity of both the tape
; output, and remote ports 'high'. The 'tape_output_pulse' routine will
; use a XOR operation with the 'tape_output' port bit, keeping the remote
; port high, and inverting the output signal.
; @TODO: Why set the remote bit?
    LDAA    #%1100000
    JSR     tape_output_pulse

    JSR     tape_output_pulse_length_16
    JSR     tape_output_pulse_length_16
    JSR     tape_output_pulse_length_16

    RTS


; ==============================================================================
; TAPE_OUTPUT_BIT_ZERO
; ==============================================================================
; DESCRIPTION:
; Outputs a '0' bit via the synth's tape output interface.
; The initial pulse width is not hardcoded, since it belongs to the bit that
; was previously being output, and needs to match its length.
;
; ARGUMENTS:
; Registers:
; * ACCB: The width of the initial 'pulse'.
;
; ==============================================================================
tape_output_bit_zero:
; The setting of ACCA here sets the stating polarity of both the tape
; output, and remote ports 'high'. The 'tape_output_pulse' routine will
; use a XOR operation with the 'tape_output' port bit, keeping the remote
; port high, and inverting the output signal.
; @TODO: Why set the remote bit?
    LDAA    #%1100000
    JSR     tape_output_pulse
    LDAB    #33
    DELAY_SINGLE
    NOP
    JSR     tape_output_pulse

    RTS


; ==============================================================================
; TAPE_OUTPUT_PULSE
; ==============================================================================
; DESCRIPTION:
; Ouptuts a sinusoidal 'pulse' of a fixed width of 16 'cycles' to the
; synth's tape output port. This subroutine is used when outputting a '1' bit.
;
; ARGUMENTS:
; Registers:
; * ACCA: The initial polarity of the tape output port, stored in bit 6.
;         This polarity will be inverted after ACCB iterations, and sent to
;         the 'Tape Output' port.
;
; ==============================================================================
tape_output_pulse_length_16:
    LDAB    #16
; Fall-through below.

; ==============================================================================
; TAPE_OUTPUT_PULSE
; ==============================================================================
; DESCRIPTION:
; Ouptuts a sinusoidal 'pulse' of a variable width to the synth's tape output
; port. This subroutine will output either a high, or a low pulse, depending
; on the input polarity.
; Two invocations of this subroutine will create a full sinusoidal period.
;
; ARGUMENTS:
; Registers:
; * ACCA: The initial polarity of the tape output port, stored in bit 6.
;         This polarity will be inverted after ACCB iterations, and sent to
;         the 'Tape Output' port.
; * ACCB: The number of 'cycles' to keep the initial tape output polarity for.
;         This is used to control the 'width' of each output pulse.
;
; ==============================================================================
tape_output_pulse:                              SUBROUTINE
; Abort if the 'No' button is pressed.
    TIMD   #KEY_SWITCH_LINE_0_BUTTON_NO, key_switch_scan_driver_input
    BNE     .abort

    DECB
    BNE     tape_output_pulse

    DELAY_SHORT

; The XOR instruction here inverts the tape polarity in ACCA?
    EORA    #PORT_1_TAPE_OUTPUT
    STAA    <io_port_1_data

    RTS

.abort:
    LDAA    #1
    STAA    <tape_error_flag

; Add 11 bytes to the stack pointer to return higher up in the call chain.
    TSX
    LDAB    #11
    ABX
    TXS

    RTS


; ==============================================================================
; TAPE_OUTPUT_BYTE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Outputs an individual byte over the synth's cassette interface.
; @WARN: Some of the timing values used here might seem completely arbitrary,
; however exercise caution in changing any of the tape functionality. Yamaha
; likely spent considerable time, and effort debugging their tape interface.
; Modify these precise values at your own peril.
;
; ARGUMENTS:
; Registers:
; * ACCA: The byte to output.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
tape_output_byte:                               SUBROUTINE
    PSHA
    PSHB
    PSHX

; This register is used as a counter to output each bit of the byte.
    LDX     #8
    PSHA

; Send the leading zero marking the start of the data frame.
    JSR     tape_output_bit_zero
    PULA
    DELAY_SHORT
    DELAY_SHORT

.output_bit_loop:
    DELAY_SHORT

; Rotate the bit to the right, moving the LSB into the carry bit.
; If the carry bit is now set, the bit to be output is a '1'.
    RORA
    PSHA
    BCS     .output_bit_one

    LDAB    #31
    JSR     tape_output_bit_zero
    BRA     .decrement_bit_loop_counter

.output_bit_one:
    LDAB    #13
    JSR     tape_output_bit_one
; @TODO: This branch statement can likely be removed.
    BRA     *+2

.decrement_bit_loop_counter:
    PULA
    DEX
    BNE     .output_bit_loop

; Send the tail '1's that make up the data frame end marker.
    LDAB    #$D
    DELAY_SINGLE
    NOP
    DES
    JSR     tape_output_bit_one

    LDAB    #$E
    DELAY_SINGLE
    NOP
    JSR     tape_output_bit_one
    INS

    PULX
    PULB
    PULA

    RTS


; ==============================================================================
; TAPE_EXIT
; ==============================================================================
; DESCRIPTION:
; Exits the tape UI functions.
; This re-enables interrupts and sets the tape output low.
;
; ==============================================================================
tape_exit:                                      SUBROUTINE
    JSR     tape_remote_output_low
    CLI
    RTS


; ==============================================================================
; TAPE_OUTPUT_ALL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Outputs all the synth's internal patch memory over the synth's cassette
; interface.
;
; Memory:
; * ui_btn_function_7_sub_function: Determines whether this function will
;    begin verification of the tape data, or will begin patch output.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
tape_output_all:                                SUBROUTINE
; Test whether the button 7 sub-function is to output, or verify.
    TST     ui_btn_function_7_sub_function
    BEQ     .tape_output_sub_function_selected

    JMP     tape_verify

.tape_output_sub_function_selected:
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_dest
    LDX     #str_from_mem_to_tape
    JSR     lcd_strcpy
    JSR     lcd_update

.wait_for_user_input:
; Read front-panel input to determine the next action.
; If 'No' is pressed, the tape UI actions are aborted.
; If 'Remote' is pressed, the output port polarity is flipped.
; If 'Yes' is pressed, the operation proceeeds.
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_10
    BEQ     .remote_button_pressed

    CMPB    #INPUT_BUTTON_NO
    BEQ     tape_exit

    CMPB    #INPUT_BUTTON_YES
    BNE     .wait_for_user_input

    BRA     .clear_cd_output_number

.remote_button_pressed:
    JSR     tape_remote_toggle_output_polarity
    BRA     .wait_for_user_input

.clear_cd_output_number:
; Clear a space at the end of the LCD buffer for the number of the patch
; being output.
    LDX     #(lcd_buffer_next + 26)
    LDAA    #'
    LDAB    #6

.clear_lcd_output_number_loop:
    STAA    0,x
    INX
    DECB
    BNE     .clear_lcd_output_number_loop

    JSR     lcd_update
    JSR     tape_remote_output_high
    CLR     tape_error_flag

; The following section loops for 4 * 0xFFFF cycles.
; IX is decremented so it wraps around to 0xFFFF, then loops until it reaches
; zero, then ACCB is decremented.
    LDAB    #4
    LDX     #0

.wait_for_abort_loop:
; If the 'No' button is pressed, abort.
    TIMD   #KEY_SWITCH_LINE_0_BUTTON_NO, key_switch_scan_driver_input
    BNE     tape_exit

    DEX
    BNE     .wait_for_abort_loop

    DECB
    BNE     .wait_for_abort_loop

; The following loop outputs each of the individual patches.
; This variable is used as the main loop counter.
    CLRA
    STAA    tape_patch_output_counter

.patch_output_loop:
; Print the number of the current patch being output.
    LDX     #(lcd_buffer_next + 29)
    STX     <memcpy_ptr_dest
    INCA
    JSR     lcd_print_number_three_digits
    JSR     lcd_update

    LDAA    tape_patch_output_counter
    JSR     patch_copy_to_tape_buffer
    JSR     tape_calculate_patch_checksum
    STD     tape_patch_checksum
    JSR     tape_output_patch

; If any error occurred, exit.
    TST     tape_error_flag
    BNE     tape_exit

    LDAA    tape_patch_output_counter
    INCA
    STAA    tape_patch_output_counter
    CMPA    #20
    BNE     .patch_output_loop

; If the output process is finished, proceed to verification.
    JSR     tape_remote_output_low
    BRA     tape_verify

