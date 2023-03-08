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
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; @NEEDS_TESTING
; DESCRIPTION:
; Sends a parameter change event via MIDI SysEx.
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
    CPX     #master_tune
    BCC     .send_function_parameter

    TST     patch_compare_mode_active
    BNE     .exit

; Send the parameter change sysex header.
    LDAA    #MIDI_STATUS_SYSEX_START
    JSR     midi_tx
    LDAA    #MIDI_MANUFACTURER_ID_YAMAHA
    JSR     midi_tx
    LDAA    #MIDI_SYSEX_SUBSTATUS_PARAM_CHANGE
    JSR     midi_tx

; Get the relative offset of the currently selected edit parameter.
    LDD     ui_active_param_address
    SUBD    #patch_buffer_edit

; Test if the parameter number is over 128.
; If so, increment A to set the MSB of the parameter number.
    SUBB    #128

    BCS     .parameter_under_128

    INCA
    BRA     .send_parameter_value

.parameter_under_128:
    ADDB    #128
    BRA     .send_parameter_value

.send_function_parameter:
; Test whether the currently selected edit parameter pointer points to
; something higher in memory than the MIDI RX channel. If so, it represents
; an invalid value. In this case, exit.
; @Note: This is a different point in memory than the original DX9 ROM, due to
; parameters being reordered.
    CPX     #sys_info_avail
    BCC     .exit

    LDAA    #MIDI_STATUS_SYSEX_START
    JSR     midi_tx
    LDAA    #MIDI_MANUFACTURER_ID_YAMAHA
    JSR     midi_tx
    LDAA    #MIDI_SYSEX_SUBSTATUS_PARAM_CHANGE
    JSR     midi_tx

; Get the function parameter number by loading the address of the parameter
; from the pointer, then subtracting the 'master_tune' address.
    LDD     ui_active_param_address
    SUBD    #master_tune

; @TODO: Why does this not match DX7?
    LDAA    #12
    ADDB    #65

.send_parameter_value:
    JSR     midi_tx
    TBA
    ANDA    #$7F
    JSR     midi_tx
    LDX     ui_active_param_address
    LDAA    0,x
    ANDA    #$7F
    JSR     midi_tx

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

; Send the SysEx parameter number associated with the operator enable status.
; In this case '155'.
    LDAA    #MIDI_STATUS_SYSEX_START
    JSR     midi_tx
    LDAA    #MIDI_MANUFACTURER_ID_YAMAHA
    JSR     midi_tx
    LDAA    #MIDI_SYSEX_SUBSTATUS_PARAM_CHANGE
    JSR     midi_tx
    LDAA    #1
    JSR     midi_tx
    LDAA    #27
    JSR     midi_tx
    LDAA    patch_edit_operator_status
    JSR     midi_tx

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

    LDAA    #MIDI_STATUS_SYSEX_START
    JSR     midi_tx
    LDAA    #MIDI_MANUFACTURER_ID_YAMAHA
    JSR     midi_tx
    LDAA    #MIDI_SYSEX_SUBSTATUS_PARAM_CHANGE
    JSR     midi_tx
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
; MIDI_SYSEX_TX_BULK_DATA_SINGLE_VOICE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Transmits a single voice bulk data dump over SysEx.
;
; ARGUMENTS:
; Memory:
; * patch_index_current: The 0-indexed number of the patch to send.
;
; REGISTERS MODIFIED:
; * ACCA
;
; ==============================================================================
midi_sysex_tx_bulk_data_single_voice:           SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

    LDAA    patch_index_current
    BMI     .exit

    JSR     patch_get_ptr_to_current
    STX     memcpy_ptr_src
    LDX     #midi_buffer_sysex_tx
    JSR     patch_deserialise

    JSR     midi_sysex_tx_bulk_data_single_voice_send

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

    JSR     midi_sysex_tx_bulk_data_single_voice_send

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

    JSR     midi_sysex_tx_bulk_data_single_voice_send

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_32_VOICES
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; @TODO
;
; ==============================================================================
midi_sysex_tx_bulk_data_32_voices:              SUBROUTINE
    JSR     voice_reset
    JSR     lcd_clear
    JSR     lcd_update

    SYSEX_SEND_HEADER midi_sysex_header_bulk_data_32_voices

    CLR     midi_sysex_tx_checksum

    CLR     midi_sysex_patch_number

.send_patch_loop:
; Store the pointer to the source patch in the patch buffer.
    LDAB    <midi_sysex_patch_number
    JSR     patch_get_ptr
    STX     <memcpy_ptr_src

; Load the destination buffer adress, and number of bytes to copy.
    LDX     #midi_buffer_sysex_tx
    LDAB    PATCH_SIZE_PACKED_DX7

; Copy to the temporary SysEx buffer, then send.
    JSR     memcpy_store_dest_and_copy_accb_bytes

    SYSEX_SEND_BUFFER midi_buffer_sysex_tx, PATCH_SIZE_PACKED_DX7

; Increment the patch number.
    LDAB    <midi_sysex_patch_number
    INCB
    STAB    <midi_sysex_patch_number
    CMPB    #32
    BNE     .send_patch_loop

; Send the checksum.
    LDAA    <midi_sysex_tx_checksum
    NEGA
    ANDA    #$7F
    JSR     midi_tx

    JMP     ui_print


midi_sysex_header_bulk_data_32_voices:
    DC.B MIDI_STATUS_SYSEX_START
    DC.B MIDI_MANUFACTURER_ID_YAMAHA
    DC.B 0
    DC.B MIDI_SYSEX_FORMAT_BULK
; @TODO: Fix byte count.
    DC.B $20
    DC.B 0


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_SINGLE_VOICE_SEND
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; @TODO
;
; ==============================================================================
midi_sysex_tx_bulk_data_single_voice_send:      SUBROUTINE
    SYSEX_SEND_HEADER midi_sysex_header_bulk_data_single

    CLR     midi_sysex_tx_checksum

    SYSEX_SEND_BUFFER midi_buffer_sysex_tx, PATCH_SIZE_UNPACKED_DX7

; Send checksum.
    NEGB
    ANDB    #$7F
    TBA
    JSR     midi_tx

    RTS


midi_sysex_header_bulk_data_single:
    DC.B MIDI_STATUS_SYSEX_START
    DC.B MIDI_MANUFACTURER_ID_YAMAHA
    DC.B 0
    DC.B 0
    DC.B 1
    DC.B $1B


; ==============================================================================
; MIDI_SYSEX_TX_PROGRAM_CHANGE_CURRENT_PATCH
; ==============================================================================
; DESCRIPTION:
; If SysEx is enabled, this subroutine sends a MIDI 'Program Change' event
; with the currently selected patch index.
;
; ==============================================================================
midi_sysex_tx_program_change_current_patch:     SUBROUTINE
    TST     sys_info_avail
    BNE     .exit

    LDAA    #MIDI_STATUS_PROGRAM_CHANGE
    JSR     midi_tx
    LDAA    patch_index_current
    ANDA    #$7F
    JSR     midi_tx

.exit:
    RTS
