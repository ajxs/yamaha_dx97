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
; midi/sysex/voice_param.asm
; ==============================================================================
; DESCRIPTION:
; Contains functionality for handling incoming SysEx voice parameter messages.
; ==============================================================================

    .PROCESSOR HD6303

; =============================================================================
; MIDI_SYSEX_RX_PARAM_VOICE_PROCESS
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; Processes incoming SysEx voice parameter data.
; This subroutine is responsible for parsing, and storing the incoming data.
;
; =============================================================================
midi_sysex_rx_param_voice_process:              SUBROUTINE
; Test whether the SysEx parameter number is above 127.
; If the parameter number is above 127, the two least-significant bits in
; this message will be set.
; This 'Parameter Group' value must be '0' since this is a voice parameter
; message.
    LDAB    <midi_sysex_format_param_grp
    BNE     .param_above_127

; Exit in the case that 'Patch Compare Mode' is active.
    TST     patch_compare_mode_active
    BNE     .exit

    LDAB    <midi_sysex_byte_count_msb_param_number
    CMPB    #84

; Branch if the voice parameter number is '84', or above.
; DX7 parameters numbers 84 - 124 correspond to the two extra operators
; that are not present in the DX9.
    BCC     .exit

; This table acts as a translation between the DX7 voice parameter offsets,
; and those of the DX9.
; Load this translation table, and use the voice parameter number LSB as an
; index to load the offset of the corresponding parameter in voice memory.
; If the loaded offset is 0xFF, it is not valid, so exit.
    LDX     #table_sysex_voice_param_translation
    ABX
    LDAB    0,x
    BMI     .exit

; Get the offset to the selected voice parameter.
    LDX     #patch_buffer_edit
    ABX
    LDAA    <midi_sysex_byte_count_lsb_param_data
    BRA     .compare_parameter_to_current

.param_above_127:
; If this value is not '0', and not '1', it indicates that the parameter
; number must be over '255', which is invalid.
; If so, exit.
    CMPB    #1
    BNE     .exit

; Is the parameter number byte '27'?
; If so, the parameter is '155' since bit 7 is set in the parameter group
; byte.
    LDAB    <midi_sysex_byte_count_msb_param_number
    CMPB    #27
    BEQ     .param_155

; Is the parameter number above '155'?
; If so, this is invalid, exit.
    BCC     .exit

; Quite likely there is a missing branch here that exited in the case
; that 'Patch Compare Mode' is active.
    TST     patch_compare_mode_active

; This table acts as a translation between the DX7 voice parameter offsets,
; and those of the DX9.
; Load this translation table, and use the voice parameter number LSB as an
; index to load the offset of the corresponding parameter in voice memory.
; If the loaded offset is 0xFF, it is not valid, so exit.
    LDX     #table_sysex_voice_param_translation_above_127
    ABX
    LDAB    0,x
    BMI     .exit

; Get the offset to the selected voice parameter.
    LDX     #patch_buffer_edit
    ABX
    LDAA    <midi_sysex_byte_count_lsb_param_data

; Handle the case that the incoming SysEx parameter is the algorithm, or
; key transpose setting.
    JSR     midi_sysex_rx_param_set_alg_key_transpose

; If the carry bit is set at this point, it indicates an invalid value
; for the key tranpose, or algorithm settings.
    BCS     .exit

.compare_parameter_to_current:
; Test whether the incoming data is identical to the existing voice data.
; If not, write the data to the pointer in IX. Otherwise exit.
    CMPA    0,x
    BEQ     .exit

    STAA    0,x

; Trigger a patch reload with the newly stored voice data.
    LDAA    #EVENT_RELOAD_PATCH

; Set the patch edit buffer as having been modified.
    STAA    patch_current_modified_flag
    STAA    main_patch_event_flag
    BRA     .update_ui_and_exit

.param_155:
; Parameter '155' is the operator 'On/Off' status.
; Rotate this value left 4 times on account of having only 4 operators.
    LDAA    <midi_sysex_byte_count_lsb_param_data
    ROLA
    ROLA
    ROLA
    ROLA
    LDX     #operator_enabled_status

; Loop 4 times, rotating the current operator status bit into the carry bit
; each iteration.
; Clear the current operator's status in the current patch.
; If the carry bit is set, set the current operator's On/Off status
; accordingly by incrementing the byte, and then increment the pointer to
; the current patch's operator status.
.set_operator_status_loop:
    CLR     0,x
    ROLA
    BCC     .increment_loop
    INC     0,x

.increment_loop:
    INX
    CPX     #(operator_enabled_status + 4)
    BNE     .set_operator_status_loop

.update_ui_and_exit:
    JSR     ui_print_update_led_and_menu

.exit:
    RTS

; @NEEDS_TO_BE_REMADE_FOR_6_OP
table_sysex_voice_param_translation:
    DC.B 0, 1, 2, 3, 4, 5, 6; 0
    DC.B 7, $FF, $FF, 8, $FF; 7
    DC.B $FF, 9, $A, $FF, $B; 12
    DC.B $FF, $C, $D, $E, $F; 17
    DC.B $10, $11, $12, $13, $14; 22
    DC.B $15, $16, $FF, $FF, $17; 27
    DC.B $FF, $FF, $18, $19, $FF; 32
    DC.B $1A, $FF, $1B, $1C, $1D; 37
    DC.B $1E, $1F, $20, $21, $22; 42
    DC.B $23, $24, $25, $FF, $FF; 47
    DC.B $26, $FF, $FF, $27, $28; 52
    DC.B $FF, $29, $FF, $2A, $2B; 57
    DC.B $2C, $2D, $2E, $2F, $30; 62
    DC.B $31, $32, $33, $34, $FF; 67
    DC.B $FF, $35, $FF, $FF, $36; 72
    DC.B $37, $FF, $38, $FF, $39; 77
    DC.B $3A, $3B; 82

table_sysex_voice_param_translation_above_127:
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $3C
    DC.B $3D
    DC.B $3E
    DC.B $3F
    DC.B $40
    DC.B $41
    DC.B $42
    DC.B $FF
    DC.B $43
    DC.B $44
    DC.B $45
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF
    DC.B $FF

; =============================================================================
; MIDI_SYSEX_RX_PARAM_SET_ALG_KEY_TRANPOSE
; =============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; If the incoming SysEx parameter being set is the patch's algorithm, or
; key transpose, this subroutine will handle that.
; In any other case the subroutine will not do anything, and leave changing
; the value to the caller.
;
; ARGUMENTS:
; Registers:
; * IX:   A pointer to the DX9 voice parameter being edited.
; * ACCA: The incoming voice parameter data from the SysEx message.
;
; RETURNS:
; * ACCA: The result voice parameter data.
; * CC:C: The carry bit is set to indicate an error condition in the case that
;   the key transpose, or algorithm value is not valid.
;
; =============================================================================
midi_sysex_rx_param_set_alg_key_transpose:      SUBROUTINE
; Test whether the voice parameter being set is the algorithm.
    CPX     #patch_edit_algorithm
    BNE     .param_is_key_transpose

; If the voice parameter currently being set is the algorithm, load the
; algorithm conversion table and iterate over it testing whether the
; incoming voice parameter data matches each particular algorithm.
    PSHX
    LDX     #table_algorithm_conversion
    CLRB

; Compare each of the DX7 algorithm numbers in the table against the
; incoming parameter value.
; If it matches, transfer the index number (which is the DX9 algorithm)
; to ACCA to return.
.set_algorithm_loop:
    CMPA    0,x

; If the correct DX9 algorithm corresponding to the incoming DX7 algorithm
; number has been found, transfer this value to ACCB, and restore the
; parameter pointer in the original IX value.
    BEQ     .set_algorithm_loop_found
    INCB
    INX
    CPX     #(table_algorithm_conversion + 8)
    BNE     .set_algorithm_loop

    PULX
    BRA     .exit_invalid

.set_algorithm_loop_found:
    TBA
    PULX
    BRA     .exit

.param_is_key_transpose:
    CPX     #patch_edit_key_transpose
    BNE     .exit
    SUBA    #12

; Exit with the carry flag set in error if the 'Key Tranpose' value is
; less than '12'.
    BCS     .exit_invalid

; Exit with the carry flag set in error if the 'Key Tranpose' value is
; above '24'.
; Otherwise clear the carry flag, and exit.
    CMPA    #24
    BLS     .exit

.exit_invalid:
; If the incoming parameter value is invalid, set the carry flag and exit.
    SEC
    RTS

.exit:
    CLC
    RTS
