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
; MIDI_SYSEX_TX_PARAM_CHANGE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; Sends a parameter change event via MIDI SysEx.
; This subroutine will determine the proper parameter change message format to
; send based upon the parameter address in the IX register.
;
; ARGUMENTS:
; Registers:
; * IX:   The address of the selected parameter to send via SysEx.
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

    CPX     #patch_edit_key_transpose
    BNE     .send_sysex_header

    JMP     midi_sysex_tx_key_transpose_send

.send_sysex_header:
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

; Use this offset to load the value from this table.
    LDX     #table_sysex_parameter_map
    ABX
    CLRA
    LDAB    0,x

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
    JSR     midi_sysex_tx_param_change_algorithm_check
    ANDA    #$7F
    JSR     midi_tx

.exit:
    RTS


table_sysex_parameter_map:
    DC.B 0, 1, 2, 3, 4, 5, 6        ; 0
    DC.B 7, $A, $D, $E, $10, $12    ; 7
    DC.B $13, $14, $15, $16, $17    ; 13
    DC.B $18, $19, $1A, $1B, $1C    ; 18
    DC.B $1F, $22, $23, $25, $27    ; 23
    DC.B $28, $29, $2A, $2B, $2C    ; 28
    DC.B $2D, $2E, $2F, $30, $31    ; 33
    DC.B $34, $37, $38, $3A, $3C    ; 38
    DC.B $3D, $3E, $3F, $40, $41    ; 43
    DC.B $42, $43, $44, $45, $46    ; 48
    DC.B $49, $4C, $4D, $4F, $51    ; 53
    DC.B $52, $53, $86, $87, $88    ; 58
    DC.B $89, $8A, $8B, $8C, $8E    ; 63
    DC.B $8F, $90                   ; 68


; ==============================================================================
; MIDI_SYSEX_TX_PARAM_CHANGE_ALGORITHM_CHECK
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; If the currently selected parameter being transmitted via SysEx is the
; current patch's algorithm, this subroutine converts it to the equivalent
; algorithm number used by the DX7.
;
; ARGUMENTS:
; Registers:
; * IX:   A pointer to the currently 'selected' parameter being transmitted
;         within patch memory.
; * ACCA: The value of the currently 'selected' parameter being trasmitted.
;
; RETURNS:
; * ACCA: The converted algorithm value, if updated.
;
; ==============================================================================
midi_sysex_tx_param_change_algorithm_check:     SUBROUTINE
    CPX     #patch_edit_algorithm
    BNE     .exit
    LDX     #table_algorithm_conversion
    TAB
    ABX
    LDAA    0,x

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_PARAM_CHANGE_OPERATOR_ENABLE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @REMADE_FOR_6_OP
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

midi_sysex_tx_key_transpose_send:
    LDAA    #MIDI_STATUS_SYSEX_START
    JSR     midi_tx
    LDAA    #MIDI_MANUFACTURER_ID_YAMAHA
    JSR     midi_tx
    LDAA    #MIDI_SYSEX_SUBSTATUS_PARAM_CHANGE
    JSR     midi_tx
    LDAA    #1
    JSR     midi_tx
    LDAA    #MIDI_SYSEX_SUBSTATUS_PARAM_CHANGE
    JSR     midi_tx
    LDAA    patch_edit_key_transpose
    ADDA    #12
    ANDA    #%1111111
    JSR     midi_tx

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_SINGLE_VOICE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Transmits a single voice bulk data dump over SysEx.
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

    STAA    <midi_sysex_patch_number
    JSR     midi_sysex_tx_bulk_data_serialise_to_index
    JSR     midi_sysex_rx_bulk_data_single_deserialise
    JSR     midi_sysex_tx_bulk_data_single_voice_send

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_TAPE_INCOMING_SINGLE_PATCH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; @TODO
;
; ==============================================================================
midi_sysex_tx_tape_incoming_single_patch:   SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

    CLR     midi_sysex_patch_number
    LDX     #patch_buffer_incoming
    STX     <memcpy_ptr_src
    JSR     midi_sysex_tx_bulk_data_serialise_bulk_to_src_pointer
    LDAA    #$30 ; '0'
    STAA    midi_buffer_sysex_tx_bulk + 123
    JSR     midi_sysex_rx_bulk_data_single_deserialise
    JSR     midi_sysex_tx_bulk_data_single_voice_send

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_RECALLED_PATCH
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; @TODO
;
; ==============================================================================
midi_sysex_tx_recalled_patch:                   SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

; @TODO When is the patch number 0xFF?...
    LDAA    patch_index_current
    BMI     .clear_patch_number

; @TODO: When is the patch index 20?...
    CMPA    #20
    BEQ     .clear_patch_number

    STAA    <midi_sysex_patch_number
    BRA     loc_F1B9

.clear_patch_number:
    CLR     midi_sysex_patch_number

loc_F1B9:
    LDX     #patch_buffer_compare
    STX     <memcpy_ptr_src
    JSR     midi_sysex_tx_bulk_data_serialise_bulk_to_src_pointer

    LDAA    patch_index_current
    BMI     loc_F1CC

    CMPA    #20
    BEQ     loc_F1D1

    BRA     .add_ed_to_patch_name

loc_F1CC:
    LDAA    #$30 ; '0'
    STAA    midi_buffer_sysex_tx_bulk + 122

loc_F1D1:
    LDAA    #$30 ; '0'
    STAA    midi_buffer_sysex_tx_bulk + 123

.add_ed_to_patch_name:
    LDAA    #$45 ; 'E'
    LDAB    #$44 ; 'D'
    STD     midi_buffer_sysex_tx_bulk + 124
    JSR     midi_sysex_rx_bulk_data_single_deserialise
    JSR     midi_sysex_tx_bulk_data_single_voice_send

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_SEND_INIT_VOICE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; @TODO
;
; ==============================================================================
midi_sysex_tx_bulk_data_send_init_voice:        SUBROUTINE
    TST     sys_info_avail
    BEQ     .exit

    CLR     midi_sysex_patch_number

    LDX     #patch_buffer_init_voice
    STX     <memcpy_ptr_src

    JSR     midi_sysex_tx_bulk_data_serialise_bulk_to_src_pointer
    LDX     #(midi_buffer_sysex_tx_bulk + 122)
    STX     <memcpy_ptr_dest

    CLRA
    LDAB    #$FF
    JSR     lcd_print_number_two_digits
    JSR     midi_sysex_rx_bulk_data_single_deserialise
    JSR     midi_sysex_tx_bulk_data_single_voice_send

.exit:
    RTS


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_32_VOICES
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; @TODO
;
; ==============================================================================
midi_sysex_tx_bulk_data_32_voices:              SUBROUTINE
    JSR     voice_reset_egs
    JSR     voice_reset_frequency_data
    CLR     active_voice_count
    JSR     lcd_clear
    JSR     lcd_update
    JSR     midi_sysex_tx_bulk_data_32_voices_header
    CLR     midi_sysex_patch_number

loc_F21B:
    JSR     midi_sysex_tx_bulk_data_serialise_to_index
    JSR     midi_sysex_tx_bulk_data
    LDAB    <midi_sysex_patch_number
    INCB
    STAB    <midi_sysex_patch_number
    CMPB    #32
    BNE     loc_F21B

    JSR     midi_sysex_tx_send_checksum
    JSR     ui_print

    RTS


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_SINGLE_VOICE_SEND
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
;
; ==============================================================================
midi_sysex_tx_bulk_data_single_voice_send:      SUBROUTINE
    CLRB

.send_header_loop:
    LDX     #midi_sysex_header_bulk_data_single
    ABX
    LDAA    0,x
    JSR     midi_tx
    INCB
    CMPB    #6
    BCS     .send_header_loop

    CLR     midi_sysex_tx_checksum
    LDX     #midi_buffer_sysex_tx_single

.send_midi_data_loop:
    LDAA    0,x
    PSHX
    TAB

    ADDB    <midi_sysex_tx_checksum
    STAB    <midi_sysex_tx_checksum

    ANDA    #$7F
    JSR     midi_tx
    PULX
    INX
    CPX     #midi_buffer_sysex_tx_single_end

    BNE     .send_midi_data_loop

; Send operator-enable.
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
; MIDI_SYSEX_TX_BULK_DATA_32_VOICES_HEADER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Sends the SysEx header for a 32 voice bulk data dump.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
midi_sysex_tx_bulk_data_32_voices_header:       SUBROUTINE
    CLRB

.send_header_loop:
    LDX     #midi_sysex_header_bulk_data_32_voices
    ABX
    LDAA    0,x
    JSR     midi_tx
    INCB
    CMPB    #6
    BCS     .send_header_loop

    CLR     midi_sysex_tx_checksum

    RTS

midi_sysex_header_bulk_data_32_voices:
    DC.B MIDI_STATUS_SYSEX_START
    DC.B MIDI_MANUFACTURER_ID_YAMAHA
    DC.B 0
    DC.B MIDI_SYSEX_FORMAT_BULK
    DC.B $20
    DC.B 0


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; @TODO
;
; ==============================================================================
midi_sysex_tx_bulk_data:                        SUBROUTINE
    LDX     #midi_buffer_sysex_tx_bulk

.send_midi_data_loop:
    LDAA    0,x
    PSHX
    TAB
    ADDB    <midi_sysex_tx_checksum
    STAB    <midi_sysex_tx_checksum
    ANDA    #$7F
    JSR     midi_tx
    PULX
    INX
    CPX     #midi_buffer_sysex_rx_bulk
    BNE     .send_midi_data_loop

    RTS


; ==============================================================================
; MIDI_SYSEX_TX_SEND_CHECKSUM
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Sends the MIDI outgoing SysEx checksum.
;
; ==============================================================================
midi_sysex_tx_send_checksum:                    SUBROUTINE
    LDAA    <midi_sysex_tx_checksum
    NEGA
    ANDA    #$7F
    JSR     midi_tx

    RTS


; ==============================================================================
; MIDI_SYSEX_TX_BULK_DATA_SERIALISE_TO_INDEX
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
;
; ==============================================================================
midi_sysex_tx_bulk_data_serialise_to_index:     SUBROUTINE
    LDAA    <midi_sysex_patch_number

; Value could be 0xFF?
; Clamp at 20?
    BPL     loc_F2A9

    JMP     .exit

loc_F2A9:
    CMPA    #20
    BLS     loc_F2AF

    LDAA    #20

loc_F2AF:
    LDAB    #64
    MUL
    ADDD    #patch_buffer
    STD     <memcpy_ptr_src

midi_sysex_tx_bulk_data_serialise_bulk_to_src_pointer:
    LDX     #midi_buffer_sysex_tx_bulk
    LDAB    #4

loc_F2BC:
    PSHB
    LDAB    #8
    JSR     memcpy_store_dest_and_copy_accb_bytes
    LDAA    #$F
    CLRB
    STD     0,x
    LDX     <memcpy_ptr_src
    LDAA    0,x
    LDAB    #4
    LDX     <memcpy_ptr_dest
    STD     2,x
    LDX     <memcpy_ptr_src
    LDAA    1,x
    ANDA    #7
    LDAB    5,x
    ASLB
    ASLB
    ASLB
    ABA
    LDX     <memcpy_ptr_dest
    STAA    4,x
    LDX     <memcpy_ptr_src
    LDAA    1,x
    LSRA
    LSRA
    LSRA
    ANDA    #3
    LDX     <memcpy_ptr_dest
    STAA    5,x
    LDX     <memcpy_ptr_src
    LDD     2,x
    ASLB
    LDX     <memcpy_ptr_dest
    STD     6,x
    LDX     <memcpy_ptr_src
    LDAA    4,x
    LDX     <memcpy_ptr_dest
    STAA    8,x
    LDX     <memcpy_ptr_src
    LDAB    #6
    ABX
    STX     <memcpy_ptr_src
    LDX     <memcpy_ptr_dest
    LDAB    #9
    ABX
    PULB
    DECB
    BNE     loc_F2BC
    LDAB    #2

loc_F311:
    PSHB
    LDAB    #$C
    CLRA

loc_F315:
    STAA    0,x
    INX
    DECB
    BNE     loc_F315
    LDAA    #$38 ; '8'
    STAA    0,x
    INX
    LDAB    #4
    CLRA

loc_F323:
    STAA    0,x
    INX
    DECB
    BNE     loc_F323
    PULB
    DECB
    BNE     loc_F311
    LDAB    #4
    LDAA    #$63 ; 'c'

loc_F331:
    STAA    0,x
    INX
    DECB
    BNE     loc_F331
    LDAB    #4
    LDAA    #$32 ; '2'

loc_F33B:
    STAA    0,x
    INX
    DECB
    BNE     loc_F33B
    STX     <memcpy_ptr_dest
    LDX     <memcpy_ptr_src
    LDAB    0,x
    INX
    STX     <memcpy_ptr_src
    LDX     #table_algorithm_conversion
    ABX
    LDAA    0,x
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    LDAB    #5
    JSR     memcpy_store_dest_and_copy_accb_bytes
    STX     <memcpy_ptr_dest
    LDX     <memcpy_ptr_src
    LDD     0,x
    ASLA
    ADDB    #$C
    LDX     <memcpy_ptr_dest
    STD     0,x
    INX
    INX
    STX     <memcpy_ptr_dest
    LDX     #aDx9 ; "DX9."
    JSR     lcd_strcpy
    LDAA    <midi_sysex_patch_number
    CMPB    #$14
    BEQ     loc_F37A
    INCA
    BRA     loc_F37B

loc_F37A:
    CLRA

loc_F37B:
    CLRB
    JSR     lcd_print_number_two_digits
    LDAB    #4
    LDAA    #$20 ; ' '
    LDX     <memcpy_ptr_dest

loc_F385:
    STAA    0,x
    INX
    DECB
    BNE     loc_F385

.exit:
    RTS

aDx9:           DC "DX9.", 0
