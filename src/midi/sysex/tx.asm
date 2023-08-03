; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; midi/sysex/tx.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions, and code related to the handling of sending
; SysEx data.
; ==============================================================================

    .PROCESSOR HD6303


; ==============================================================================
; Sends the specified SysEx header.
;
; ARGUMENTS:
; * 1: The header buffer to send.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
    .MACRO SYSEX_SEND_HEADER
        CLRB

.send_header_loop$:
        LDX     #{1}
        ABX
        LDAA    0,x
        JSR     midi_tx
        INCB
        CMPB    #6
        BCS     .send_header_loop$
    .ENDM


; ==============================================================================
; Sends the parameter change SysEx header.
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
    .MACRO SYSEX_SEND_HEADER_PARAM_CHANGE
        LDAA    #MIDI_STATUS_SYSEX_START
        JSR     midi_tx
        LDAA    #MIDI_MANUFACTURER_ID_YAMAHA
        JSR     midi_tx
        LDAA    #MIDI_SYSEX_SUBSTATUS_PARAM_CHANGE
        JSR     midi_tx
    .ENDM


; ==============================================================================
; Sends a specified buffer via SysEx.
;
; ARGUMENTS:
; * 1: The buffer to be sent.
; * 2: The number of bytes in the buffer.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
    .MACRO SYSEX_SEND_BUFFER
        LDX     #{1}
.send_midi_data_loop$:
        LDAA    0,x
        PSHX
        TAB

        ADDB    <midi_sysex_tx_checksum
        STAB    <midi_sysex_tx_checksum

        ANDA    #$7F
        JSR     midi_tx
        PULX
        INX
        CPX     #({1} + {2})

        BNE     .send_midi_data_loop$
    .ENDM


; ==============================================================================
; MIDI_SYSEX_TX_PARAM_CHANGE
; ==============================================================================
; @CHANGED_FOR_6_OP
; @NEEDS_TESTING
; DESCRIPTION:
; Sends a SysEx parameter change event.
; This subroutine will determine the proper parameter change message format to
; send based upon the parameter address in the IX register.
;
; ARGUMENTS:
; Registers:
; * IX:   The address of the selected parameter to send via SysEx.
;
; Memory:
; * ui_active_param_address: The address of the currently selected parameter.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
midi_sysex_tx_param_change:                     SUBROUTINE
; If SysEx transmission is not enabled, exit.
    TST     sys_info_avail
    BEQ     .exit

; If the currently selected parameter is not editable, exit.
    CPX     #null_edit_parameter
    BEQ     .exit

; Test if the currently selected edit parameter is a function parameter.
; If so it will be above the 'master tune' parameter in memory.
    CPX     #mono_poly
    BCC     midi_sysex_tx_param_change_function

; If the synth is in compare mode, exit.
; This check is performed here so the synth can still send 'function parameter'
; changes when in compare mode, but not 'edit parameter' changes.
    TST     patch_compare_mode_active
    BNE     .exit

    SYSEX_SEND_HEADER_PARAM_CHANGE

; Get the relative offset of the currently selected edit parameter.
    LDD     ui_active_param_address
    SUBD    #patch_buffer_edit

; Test if the parameter number is over 128.
; If so, increment A to set the MSB of the parameter number.
; ACCA will be '0' otherwise, since the parameter offsets are all under '256'.
    SUBB    #128

    BCS     .parameter_under_128

    INCA
    BRA     .send_sysex_data

.parameter_under_128:
; Re-add the '128' that was previously subtracted.
    ADDB    #128

.send_sysex_data:
; Send the parameter group.
    JSR     midi_tx

; Send the parameter number.
    TBA
    JSR     midi_tx

    BRA     midi_sysex_tx_send_active_parameter_value

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_PARAM_CHANGE_FUNCTION
; ==============================================================================
; DESCRIPTION:
; Sends a SysEx function parameter change event.
;
; ARGUMENTS:
; Registers:
; * IX:   The address of the selected parameter to send via SysEx.
;
; Memory:
; * ui_active_param_address: The address of the currently selected parameter.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
midi_sysex_tx_param_change_function:            SUBROUTINE
; Test whether the currently selected edit parameter pointer points to
; something higher in memory than the function parameters. In this case, exit.
    CPX     #sys_info_avail
    BCC     .exit

; Get the function parameter offset by loading the address of the parameter
; from the pointer, then subtracting the 'mono_poly' address.
    LDD     ui_active_param_address
    SUBD    #mono_poly

; If the parameter offset is equal to '6', or higher, this represents a
; controller parameter. These are not stored linearly in memory, and require
; different logic.
    CMPB    #6
    BCC     midi_sysex_tx_param_change_modulation

    SYSEX_SEND_HEADER_PARAM_CHANGE

; Send the parameter group.
    LDAA    #8
    JSR     midi_tx

; Send the parameter number.
; This is 0x40 plus the offset.
    ADDB    #64
    TBA
    JSR     midi_tx

    BRA     midi_sysex_tx_send_active_parameter_value

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_SEND_ACTIVE_PARAMETER_VALUE
; ==============================================================================
; DESCRIPTION:
; Sends the value of the currently selected function parameter via SysEx.
;
; ARGUMENTS:
; Memory:
; * ui_active_param_address: The address of the currently selected parameter.
;
; REGISTERS MODIFIED:
; * ACCA, IX
;
; ==============================================================================
midi_sysex_tx_send_active_parameter_value:      SUBROUTINE
    LDX     ui_active_param_address
    LDAA    0,x
    ANDA    #$7F
    JSR     midi_tx

    LDAA    #MIDI_STATUS_SYSEX_END
    JMP     midi_tx


; ==============================================================================
; MIDI_SYSEX_TX_PARAM_CHANGE_MODULATION
; ==============================================================================
; DESCRIPTION:
; This subroutine handles sending a function parameter change SysEx message
; related to the synth's modulation parameters.
; If an assignment parameter is changed, this involves converting the data to
; the bitmask format usde by the DX7.
;
; ARGUMENTS:
; Registers:
; * ACCB: The parameter offset.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
midi_sysex_tx_param_change_modulation:          SUBROUTINE
; If the parameter offset is equal to '10', or higher, it corresponds to
; the breath controller.
    CMPB    #10
    BCC     .breath_controller_param

    LDX     #mod_wheel_range

; If the parameter offset is between '6', and '10', it is an assignment flag
; parameter.
    CMPB    #6
    BEQ     .send_mod_wheel_range

    LDAB    #71
    BRA     .modulation_assignment_flag_parameter

.send_mod_wheel_range:
    LDAB    #70
    LDAA    0,x
    BRA     .send_parameter

.breath_controller_param:
    LDX     #breath_control_range

; If the parameter offset is abve '10', it is an assignment flag parameter.
    CMPB    #10
    BEQ     .send_breath_control_range

    LDAB    #75
    BRA     .modulation_assignment_flag_parameter

.send_breath_control_range:
    LDAB    #74
    LDAA    0,x
    BRA     .send_parameter

.modulation_assignment_flag_parameter:
; If the current edit parameter is a modulation source flag
; parameter (pitch/amp/eg bias), convert to the bitmask format used by the DX7.
; Test each of the sequential parameters, setting the appropriate bitmask for
; each if they're enabled.
    PSHB
    JSR     midi_sysex_tx_convert_mod_assignment_flags
    PULB

.send_parameter:
    PSHA

    SYSEX_SEND_HEADER_PARAM_CHANGE

; Send the parameter group.
    LDAA    #8
    JSR     midi_tx

; Send the parameter number.
    TBA
    JSR     midi_tx

; Send the parameter value.
    PULA
    ANDA    #$7F
    JSR     midi_tx

    LDAA    #MIDI_STATUS_SYSEX_END
    JMP     midi_tx

    RTS


; ==============================================================================
; MIDI_SYSEX_TX_CONVERT_MOD_ASSIGNMENT_FLAGS
; ==============================================================================
; @PRIVATE
; DESCRIPTION:
; The DX7, and DX9 ROMs store the modulation assignment flags differently.
; The DX9 stores the assignment flags (pitch/amp/eg bias) as sequantial bytes,
; whereas the DX7 stores them in a bitmask.
; This subroutine converts the data to the bitmask format usde by the DX7.
;
; ARGUMENTS:
; Registers:
; * IX:   The address of the currently selected modulation source's 'range'
; value. This will be either 'mod_wheel_range', or 'breath_control_range'.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
midi_sysex_tx_convert_mod_assignment_flags:     SUBROUTINE
    CLRA

    LDAB    1,x
    BEQ     .test_pitch_modulation

    ORAA    #1

.test_pitch_modulation:
    LDAB    2,x
    BEQ     .test_eg_bias

    ORAA    #2

.test_eg_bias:
    LDAB    3,x
    BEQ     .exit

    ORAA    #4

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_PARAM_CHANGE_OPERATOR_ENABLE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Combines the status of each of the synth's operators into a single value,
; and then sends it via SysEx.
;
; REGISTERS MODIFIED:
; * ACCA, IX
;
; ==============================================================================
midi_sysex_tx_param_change_operator_enable:     SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

    SYSEX_SEND_HEADER_PARAM_CHANGE

; Send the SysEx parameter number associated with the operator enable status.
; In this case '155'.
    LDAA    #1
    JSR     midi_tx
    LDAA    #27
    JSR     midi_tx
    LDAA    patch_edit_operator_status
    JSR     midi_tx

    LDAA    #MIDI_STATUS_SYSEX_END
    JMP     midi_tx

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_KEY_TRANSPOSE
; ==============================================================================
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Transmits the synth's key transpose settings via SysEx.
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_sysex_tx_key_transpose:                    SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

    SYSEX_SEND_HEADER_PARAM_CHANGE

    LDAA    #1
    JSR     midi_tx
    LDAA    #16
    JSR     midi_tx
    LDAA    patch_edit_key_transpose
    ANDA    #%1111111
    JSR     midi_tx

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_SINGLE_PATCH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Transmits a single patch bulk data dump over SysEx.
;
; ARGUMENTS:
; Memory:
; * patch_index_current: The 0-indexed number of the patch to send.
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_sysex_tx_bulk_data_single_patch:           SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

    LDAA    patch_index_current
    BMI     .exit

    JSR     patch_get_ptr_to_current
    STX     memcpy_ptr_src
    LDX     #midi_buffer_sysex_tx
    JSR     patch_deserialise

    JMP     midi_sysex_tx_bulk_data_single_patch_send

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_TAPE_INCOMING_SINGLE_PATCH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
; This needs to be reimplemented from scratch.
;
; ==============================================================================
midi_sysex_tx_tape_incoming_single_patch:   SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_RECALLED_PATCH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Sends the contents of the patch compare buffer via SysEx.
;
; ==============================================================================
midi_sysex_tx_recalled_patch:                   SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

    LDX     #patch_buffer_compare
    STX     <memcpy_ptr_src
    LDX     #midi_buffer_sysex_tx
    JSR     patch_deserialise

    JMP     midi_sysex_tx_bulk_data_single_patch_send

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_SEND_INIT_VOICE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Sends the initialise voice buffer via SysEx.
;
; ==============================================================================
midi_sysex_tx_bulk_data_send_init_voice:        SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

    CLR     midi_sysex_patch_number

    LDX     #patch_buffer_init_voice
    STX     <memcpy_ptr_src
    LDX     #midi_buffer_sysex_tx
    JSR     patch_deserialise

    JMP     midi_sysex_tx_bulk_data_single_patch_send

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_ALL_PATCHES
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Sends a bulk patch dump of all the synth's patches.
; @NOTE: In order for a bulk patch dump to be properly recognised, it needs to
; have a full 32 patches included. In the original DX9 firmware this was
; accomplished by sending whatever was in the 'incoming' buffer multiple times
; to pad the dump.
; This firmware pads the dump with the initialised patch.
;
; ==============================================================================
midi_sysex_tx_bulk_data_all_patches:            SUBROUTINE
    JSR     voice_reset
    JSR     lcd_clear
    JSR     lcd_update

    SYSEX_SEND_HEADER midi_sysex_header_bulk_data_all_patches

    CLR     midi_sysex_tx_checksum

    CLR     midi_sysex_patch_number

.send_patch_loop:
; If the _current_ patch number is under the size of the internal patch count,
; then send the indexed patch.
; Otherwise send the initialised patch.
    LDAB    <midi_sysex_patch_number
    CMPB    #PATCH_BUFFER_COUNT
    BCS     .serialise_internal_patch

    LDX     #patch_buffer_init_voice
    BRA     .serialise_to_outgoing_buffer

.serialise_internal_patch:
    JSR     patch_get_ptr

.serialise_to_outgoing_buffer:
; Store the pointer to the source patch.
    STX     <memcpy_ptr_src

; Copy to the temporary SysEx buffer, then send.
    LDX     #midi_buffer_sysex_tx
    LDAB    #PATCH_SIZE_PACKED_DX7
    JSR     memcpy_store_dest_and_copy_accb_bytes

    SYSEX_SEND_BUFFER midi_buffer_sysex_tx, PATCH_SIZE_PACKED_DX7

; Increment the patch number.
    LDAB    <midi_sysex_patch_number
    INCB
    STAB    <midi_sysex_patch_number
    CMPB    #32
    BNE     .send_patch_loop

; Send the checksum, and SysEx end status.
    LDAA    <midi_sysex_tx_checksum
    NEGA
    ANDA    #$7F
    JSR     midi_tx

    LDAA    #MIDI_STATUS_SYSEX_END
    JSR     midi_tx

    JMP     ui_print


midi_sysex_header_bulk_data_all_patches:
    DC.B MIDI_STATUS_SYSEX_START
    DC.B MIDI_MANUFACTURER_ID_YAMAHA
    DC.B 0
    DC.B MIDI_SYSEX_FORMAT_BULK
    DC.B $20
    DC.B 0


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_SINGLE_PATCH_SEND
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Sends a single patch via SysEx.
;
; ==============================================================================
midi_sysex_tx_bulk_data_single_patch_send:      SUBROUTINE
    SYSEX_SEND_HEADER midi_sysex_header_bulk_data_single

    CLR     midi_sysex_tx_checksum

    SYSEX_SEND_BUFFER midi_buffer_sysex_tx, PATCH_SIZE_UNPACKED_DX7

; Send checksum.
    NEGB
    ANDB    #$7F
    TBA
    JSR     midi_tx

    LDAA    #MIDI_STATUS_SYSEX_END
    JMP     midi_tx


midi_sysex_header_bulk_data_single:
    DC.B MIDI_STATUS_SYSEX_START
    DC.B MIDI_MANUFACTURER_ID_YAMAHA
    DC.B 0
    DC.B 0
    DC.B 1
    DC.B $1B
