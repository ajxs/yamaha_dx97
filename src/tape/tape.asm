; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; tape/tape.asm
; ==============================================================================
; DESCRIPTION:
; Contains functionality related to the synth's cassette interface.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TAPE_CALCULATE_PATCH_CHECKSUM
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; Calculates the checksum for an individual patch before it is output over the
; synth's cassette interface.
;
; MEMORY MODIFIED:
; * copy_counter
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCD: The calculated checksum for the patch
;
; ==============================================================================
tape_calculate_patch_checksum:                  SUBROUTINE
    LDX     #patch_buffer_incoming
    LDAB    #65
    STAB    <copy_counter
    CLRA
    CLRB

.calculate_checksum_loop:
    ADDB    0,x
; If the result of the previous addition to ACCB overflowed, add the carry bit
; to ACCA to expand the value into ACCD.
    ADCA    #0
    INX
    DEC     copy_counter
    BNE     .calculate_checksum_loop

    RTS


; ==============================================================================
; TAPE_REMOTE_TOGGLE_OUTPUT_POLARITY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Toggles the polarity of the tape 'remote' output port.
;
; ==============================================================================
tape_remote_toggle_output_polarity:             SUBROUTINE
    LDAA    tape_remote_output_polarity
    EORA    #1
    STAA    tape_remote_output_polarity
; Falls-through below to output signal.

; ==============================================================================
; TAPE_REMOTE_OUTPUT_SIGNAL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Sets the tape 'remote' output port's polarity to either high, or low, based
; upon the remote port polarity global variable.
;
; ARGUMENTS:
; Memory:
; * tape_remote_output_polarity: The tape polarity to set.
;
; ==============================================================================
tape_remote_output_signal:                      SUBROUTINE
    LDAA    tape_remote_output_polarity
    BEQ     tape_remote_output_low_signal

    BRA     tape_remote_output_high_signal


; ==============================================================================
; TAPE_REMOTE_OUTPUT_HIGH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Sets the tape 'remote' output port's polarity to 'HIGH'.
;
; ==============================================================================
tape_remote_output_high:                        SUBROUTINE
    LDAA    #1
    STAA    tape_remote_output_polarity
; falls-through below.

tape_remote_output_high_signal:
    OIMD    #PORT_1_TAPE_REMOTE, io_port_1_data
    RTS


; ==============================================================================
; TAPE_REMOTE_OUTPUT_LOW
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Sets the tape 'remote' output port's polarity to 'LOW'.
;
; ==============================================================================
tape_remote_output_low:                         SUBROUTINE
    CLRA
    STAA    tape_remote_output_polarity
; falls-through below.

tape_remote_output_low_signal:
    AIMD    #~PORT_1_TAPE_REMOTE, io_port_1_data
    RTS


; ==============================================================================
; TAPE_UI_JUMPOFF
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Initiates the tape-related function specified by the last keypress.
; This subroutine is initiated by pressing the 'Yes' front-panel switch to
; confirm a prompt raised by pressing the tape-related keys in function mode.
; Note: This functions masks all interrupts.
;
; ==============================================================================
tape_ui_jumpoff:                                SUBROUTINE
    SEI
    JSR     midi_reset

; Disable LED output.
    LDAA    #$FF
    STAA    <led_1
    STAA    <led_2

; Set the tape remote port output to low, to avoid triggering any tape
; actions prematurely.
    JSR     tape_remote_output_low

; Call the appropriate tape-function based on the last keypress.
    LDAB    ui_btn_numeric_last_pressed
    JSR     jumpoff

; The numbers here correspond to the function mode numeric button codes.
; i.e: 27 corresponds to the code for function mode button 7 (+1).
    DC.B tape_output_all_jump - *
    DC.B 27
    DC.B tape_input_all_jump - *
    DC.B 28
    DC.B tape_input_single_jump - *
    DC.B 29
    DC.B tape_exit_jump - *
    DC.B 0

; ==============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main tape UI jumpoff.
; ==============================================================================
tape_output_all_jump:
    JMP     tape_output_all

; ==============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main tape UI jumpoff.
; ==============================================================================
tape_input_all_jump:
    JMP     tape_input_all

; ==============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main tape UI jumpoff.
; ==============================================================================
tape_input_single_jump:
    JMP     tape_input_single

; ==============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main tape UI jumpoff.
; ==============================================================================
tape_exit_jump:
    JMP     tape_exit


str_from_mem_to_tape:                   DC "from MEM to TAPEall       ready?", 0
str_verify_tape:                        DC "VERIFY      TAPE          ready?", 0
str_error:                              DC "ERROR!", 0
str_from_tape_to_mem:                   DC "from TAPE to MEMall       ready?", 0
str_from_tape_to_buf:                   DC "from TAPE to BUFsingle  ? (1-20)", 0
str_ready:                              DC " ready?", 0
str_err:                                DC "ERR", 0
str_single:                             DC "single", 0
str_function_control_verify:            DC "FUNCTION CONTROLVERIFY COMPLETED", 0
