; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; midi/sysex/rx.asm
; ==============================================================================
; DESCRIPTION:
; Contains definitions, and functionality for handling incoming SysEx data.
; ==============================================================================

    .PROCESSOR HD6303

; =============================================================================
; MIDI_SYSEX_RX
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC5B8
; DESCRIPTION:
; Handles incoming MIDI SysEx data.
; This subroutine is the entry-point to the SysEx state machine routines.
; Initially the number of bytes already received will be used to determine
; which state to jump to.
;
; ARGUMENTS:
; Registers:
; * ACCA: The incoming MIDI SysEx data to parse.
;
; =============================================================================
midi_sysex_rx:                                  SUBROUTINE
    LDAB    <midi_rx_data_count
    JSR     jumpoff

    DC.B midi_sysex_rx_validate_manufacturer_id - *
    DC.B 1
    DC.B midi_sysex_rx_substatus - *
    DC.B 2
    DC.B midi_sysex_rx_format_param_grp - *
    DC.B 3
    DC.B midi_sysex_rx_byte_count_msb_param - *
    DC.B 4
    DC.B midi_sysex_rx_process_received_data - *
    DC.B 5
    DC.B midi_sysex_rx_bulk_data_store_jump - *
    DC.B 160
    DC.B midi_rx_sysex_bulk_data_finalise_jump - *
    DC.B 161
    DC.B .exit - *
    DC.B 0

.exit:
    LDAA    #MIDI_STATUS_SYSEX_END
    STAA    <midi_last_command_received
    JMP     midi_process_incoming_data


; =============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main SysEx jumpoff.
; =============================================================================
midi_sysex_rx_bulk_data_store_jump:             SUBROUTINE
    JMP     midi_sysex_rx_bulk_data_store


; =============================================================================
; Thunk function used to perform a jump to a function that isn't within 255
; bytes of the main SysEx jumpoff.
; =============================================================================
midi_rx_sysex_bulk_data_finalise_jump:          SUBROUTINE
    JMP     midi_rx_sysex_bulk_data_finalise


; =============================================================================
; MIDI_SYSEX_RX_VALIDATE_MANUFACTURER_ID
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC5DA
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; When receiving a SysEx message, this subroutine validates the SysEx
; manufacturer ID to determine whether it matches Yamaha's ID.
;
; ARGUMENTS:
; Registers:
; * ACCA: The received MIDI data, in this case the MIDI SysEx
;         manufacturer ID.
;
; =============================================================================
midi_sysex_rx_validate_manufacturer_id:         SUBROUTINE
; Test if the SysEx message's manufacturer code matches Yamaha's code.
; If not, abort.
    STAA    <midi_rx_first_data_byte
    CMPA    #MIDI_MANUFACTURER_ID_YAMAHA
    BNE     .manufacturer_id_invalid

    CLRA
    STAA    <midi_sysex_receive_data_active

; Increment the MIDI received data count.
    INC     midi_rx_data_count
    BRA     .exit

.manufacturer_id_invalid:
    LDAA    #MIDI_STATUS_SYSEX_END
    STAA    <midi_last_command_received

.exit:
    JMP     midi_process_incoming_data


; =============================================================================
; MIDI_SYSEX_RX_SUBSTATUS
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC5F5
; DESCRIPTION:
; Stores the incoming SysEx 'sub-status', and jumps to the appropriate
; handling function based upon its content.
;
; ARGUMENTS:
; Registers:
; * ACCA: The incoming SysEx data.
;
; =============================================================================
midi_sysex_rx_substatus:                        SUBROUTINE
    STAA    <midi_sysex_substatus

; Jump-off based on the substatus, which occupies bit 4-7.
; If this is '0', it will be below 0x10, on account of the MIDI channel.
; If it is '1', it will be below 0x20.
; Anything else is invalid.
    TAB
    JSR     jumpoff

    DC.B midi_sysex_rx_substatus_data - *
    DC.B $10
    DC.B midi_sysex_rx_substatus_param - *
    DC.B $20
    DC.B midi_sysex_substatus_invalid - *
    DC.B 0


; =============================================================================
; MIDI_SYSEX_RX_SUBSTATUS_DATA
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC601
; DESCRIPTION:
; Handles the case where the SysEx substatus indicates that the incoming
; SysEx data is a data message.
;
; ARGUMENTS:
; Registers:
; * ACCB: The incoming SysEx substatus byte.
;
; =============================================================================
midi_sysex_rx_substatus_data:                   SUBROUTINE
    LDAA    #1
    STAA    <midi_sysex_receive_data_active
; Falls-through below.

; =============================================================================
; MIDI_SYSEX_RX_SUBSTATUS_PARAM
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC605
; DESCRIPTION:
; Handles the case where the SysEx substatus indicates that the incoming
; SysEx data is a parameter change message.
;
; ARGUMENTS:
; Registers:
; * ACCB: The incoming SysEx substatus byte.
;
; =============================================================================
midi_sysex_rx_substatus_param:                  SUBROUTINE
; Mask, and validate the MIDI channel.
; If this SYSEX message is not intended for this device, end the
; receipt of this SYSEX message.
    ANDB    #%1111
    CMPB    midi_channel_rx
    BNE     midi_sysex_substatus_invalid

    INC     midi_rx_data_count
    BRA     .exit

midi_sysex_substatus_invalid:
    LDAA    #MIDI_STATUS_SYSEX_END
    STAA    <midi_last_command_received

.exit:
    JMP     midi_process_incoming_data


; =============================================================================
; MIDI_SYSEX_RX_FORMAT_PARAM_GRP_STORE
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC618
; DESCRIPTION:
; Stores the incoming SysEx format/parameter group byte.
;
; ARGUMENTS:
; Registers:
; * ACCA: The incoming SysEx format/parameter group byte.
;
; =============================================================================
midi_sysex_rx_format_param_grp:                 SUBROUTINE
    STAA    <midi_sysex_format_param_grp
    INCREMENT_BYTE_COUNT_AND_RETURN


; =============================================================================
; MIDI_SYSEX_RX_BYTE_COUNT_MSB_PARAM_STORE
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC620
; DESCRIPTION:
; Stores the incoming SysEx data byte count if this is a data message, or
; parameter number if this is a parameter change message.
;
; ARGUMENTS:
; Registers:
; * ACCA: The incoming byte count/parameter number byte.
;
; =============================================================================
midi_sysex_rx_byte_count_msb_param:             SUBROUTINE
    STAA    <midi_sysex_byte_count_msb_param_number
    INCREMENT_BYTE_COUNT_AND_RETURN


; =============================================================================
; MIDI_SYSEX_RX_PROCESS_RECEIVED_DATA
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC628
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Stores the last incoming SysEx header data, and begins processing the data.
; In the case that this is the start of a bulk data dump, this subroutine
; will set the appropriate internal registers, in the case that the incoming
; SysEx data is a parameter change this will process the message in its
; entirety.
;
; ARGUMENTS:
; Registers:
; * ACCA: The incoming SysEx 'Byte Count LSB', or 'Parameter Data' byte.
;
; =============================================================================
midi_sysex_rx_process_received_data:            SUBROUTINE
    STAA    <midi_sysex_byte_count_lsb_param_data
    LDAB    <midi_sysex_substatus

; Check if the sub-status matches the code for a parameter change.
; If the status is less, it indicates we're receiving data.
; If so, branch.
    CMPB    #MIDI_SYSEX_SUBSTATUS_PARAM_CHANGE
    BCS     midi_sysex_rx_process_data_msg

; Handle 'Parameter Change' SysEx message.
    LDAB    <midi_sysex_format_param_grp

; Shift the 'Parameter Group' field right twice to mask it, then jump.
    LSRB
    LSRB
    JSR     jumpoff

    DC.B midi_sysex_rx_param_voice - *
    DC.B 1
    DC.B midi_sysex_rx_param_end - *
    DC.B 2
    DC.B midi_sysex_rx_param_function - *
    DC.B 3
    DC.B midi_sysex_rx_param_end - *
    DC.B 0


; =============================================================================
; MIDI_SYSEX_RX_PARAM_VOICE
; =============================================================================
; DESCRIPTION:
; Handles processing an incoming SysEX voice parameter change message.
;
; =============================================================================
midi_sysex_rx_param_voice:                      SUBROUTINE
    TST     sys_info_avail
    BEQ     midi_sysex_rx_param_end

    JSR     midi_sysex_rx_param_voice_process
    BRA     midi_sysex_rx_param_end


; =============================================================================
; MIDI_SYSEX_RX_PARAM_FUNCTION
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC63F
; DESCRIPTION:
; Handles processing an incoming SysEX function parameter change message.
;
; =============================================================================
midi_sysex_rx_param_function:                   SUBROUTINE
; If the SysEx parameter number is less than '64', branch.
    LDD     <midi_sysex_byte_count_msb_param_number
    CMPA    #64
    BCS     .function_param_below_64

; If receiving SysEx messages is not enabled, exit.
    TST     sys_info_avail
    BEQ     midi_sysex_rx_param_end

    JSR     midi_sysex_rx_param_function_64_to_76
    BRA     midi_sysex_rx_param_end

.function_param_below_64:
; If the SysEx function parameter number is below '64' it corresponds to
; a front-panel button press.
    LDAB    <midi_sysex_byte_count_lsb_param_data
    JSR     midi_sysex_rx_param_function_button
; Falls-through below.

; =============================================================================
; MIDI_SYSEX_RX_PARAM_END
; =============================================================================
; DESCRIPTION:
; Finishes receiving MIDI data from a SysEx message.
;
; =============================================================================
midi_sysex_rx_param_end:                        SUBROUTINE
    LDAA    #MIDI_STATUS_SYSEX_END
    STAA    <midi_last_command_received
    RTS


; =============================================================================
; MIDI_SYSEX_RX_PROCESS_DATA_MSG
; =============================================================================
; DESCRIPTION:
; Handles an initiating an incoming SysEx message when it is a bulk data
; type message.
;
; =============================================================================
midi_sysex_rx_process_data_msg:                 SUBROUTINE
; Test whether the synth will accept SysEx data. If not, exit.
    TST     sys_info_avail
    BEQ     midi_sysex_rx_force_message_end

; Jumpoff based on the format of the incoming data.
    LDAB    <midi_sysex_format_param_grp
    JSR     jumpoff

    DC.B midi_sysex_rx_bulk_data_single_voice - *
    DC.B 1
    DC.B midi_sysex_rx_force_message_end - *
    DC.B 9
    DC.B midi_sysex_rx_bulk_data_32_voices - *
    DC.B $A
    DC.B midi_sysex_rx_force_message_end - *
    DC.B 0


; =============================================================================
; MIDI_SYSEX_RX_BULK_DATA_SINGLE_VOICE
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC675
; DESCRIPTION:
; This subroutine handles initiating the receiving of a single voice bulk
; data dump. It validates the byte count, and sets the internal SysEx
; format flags.
;
; =============================================================================
midi_sysex_rx_bulk_data_single_voice:           SUBROUTINE
; Test whether the byte count MSB is equal to '1'.
; If not, this is not a valid byte count for a single voice.
    LDAA    <midi_sysex_byte_count_msb_param_number
    CMPA    #1
    BNE     midi_sysex_rx_force_message_end

; Test whether the byte count LSB is equal to '27'.
; Together with the MSB this will add up to '155'.
; The formula for the total is actually: LSB | (MSB << 7).
; If not, this is not a valid byte count for a single voice.
    LDAA    <midi_sysex_byte_count_lsb_param_data
    CMPA    #27
    BNE     midi_sysex_rx_force_message_end

    CLR     midi_sysex_format_type
    BRA     midi_sysex_rx_bulk_data_setup


; =============================================================================
; MIDI_SYSEX_RX_BULK_DATA_32_VOICES
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC686
; DESCRIPTION:
; This subroutine handles initiating the receiving of a 32 voice bulk
; data dump. It validates the byte count, and sets the internal SysEx
; format flags.
;
; =============================================================================
midi_sysex_rx_bulk_data_32_voices:              SUBROUTINE
; Since the bulk data dump will overwrite the internal patch memory, first
; test whether memory protection is enabled.
; If so, exit.
    TST     memory_protect
    BNE     midi_sysex_rx_force_message_end

; Test whether the byte count MSB is above '32'.
; If '32', together with the LSB this will add up to '4096'.
; The formula for the total is actually: LSB | (MSB << 7).
; If not, this is not a valid byte count for a bulk voice dump.
    LDAA    <midi_sysex_byte_count_msb_param_number
    DECA
    CMPA    #32
    BCC     midi_sysex_rx_force_message_end

    TST     midi_sysex_byte_count_lsb_param_data
    BNE     midi_sysex_rx_force_message_end

; This variable is used during storage of the incoming data.
    LDAA    #MIDI_SYSEX_FORMAT_BULK
    STAA    <midi_sysex_format_type

; Reset the incoming SysEx patch number index.
    CLR     midi_sysex_rx_bulk_patch_index
; Falls-through below.

; =============================================================================
; MIDI_SYSEX_RX_BULK_DATA_SETUP
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Initialises the system in preparation of receiving a bulk data dump.
;
; =============================================================================
midi_sysex_rx_bulk_data_setup:
    JSR     lcd_clear_line_2
    JSR     lcd_update
    CLR     midi_sysex_rx_checksum
    INCREMENT_BYTE_COUNT_AND_RETURN


; =============================================================================
; MIDI_SYSEX_RX_FORCE_MESSAGE_END
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; This subroutine is used to end receiving a particular SysEx transmission.
;
; MEMORY MODIFIED:
; * midi_last_command_received
;
; REGISTERS MODIFIED:
; * ACCA
;
; =============================================================================
midi_sysex_rx_force_message_end:
    LDAA    #MIDI_STATUS_SYSEX_END
    STAA    <midi_last_command_received
    JMP     midi_process_incoming_data


; =============================================================================
; MIDI_SYSEX_RX_BULK_DATA_STORE
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC6B4
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Stores incoming SysEx data for a bulk voice dump.
; Based upon whether this is a single voice, or a 32 voice bulk data dump,
; this subroutine will store the data accordingly.
; In the case of a single voice, if all bytes have been received, it will set
; the SysEx state machine to a state where validation will occur.
; In the case of a 32 voice bulk data dump, after successfully receiving the
; data for an individual voice, this routine will call the subroutine for
; deserialising the received patch data.
;
; ARGUMENTS:
; Registers:
; * ACCA: The incoming SysEx bulk voice data byte.
;
; =============================================================================
midi_sysex_rx_bulk_data_store:                  SUBROUTINE
; Timer interrupts are disabled, and the SysEx receive flag is set here because
; up until this point there are numerous ways in which the incoming SysEx
; message can fail validation, and the process be aborted.
    CLR     <timer_ctrl_status
    LDAB    #1
    STAB    <midi_sysex_rx_active_flag

; Load the received SysEx data count, and use this value as an index into
; the incoming SysEx bulk data temporary buffer.
; Subtract 5 to take into account the size of the SysEx header, which is
; not stored.
    LDAB    <midi_rx_data_count
    SUBB    #5
    LDX     #midi_buffer_sysex_rx
    ABX

; Store the incoming data, and increment the received byte count.
    STAA    0,x
    INC     <midi_rx_data_count

; Add the incoming data to the checksum byte, and store.
    ADDA    <midi_sysex_rx_checksum
    STAA    <midi_sysex_rx_checksum

; Test whether we're storing the bulk data for a single patch, or multiple.
    TST     <midi_sysex_format_type
    BNE     .receiving_multiple_patches

; Return to process further incoming data.
    JMP     midi_process_incoming_data

.receiving_multiple_patches:
; Test whether '133' bytes have been received (128 + 5 for the header).
; If a full patch has not been received, return and process the next data.
    LDAA    <midi_rx_data_count
    CMPA    #133
    BEQ     .process_completed_patch

    JMP     midi_process_incoming_data

.process_completed_patch:
; Deserialise the newly received patch into the synth's patch memory.
    JSR     midi_sysex_rx_bulk_data_deserialise

; Increment the received patch index.
    LDAA    <midi_sysex_rx_bulk_patch_index
    INCA
    STAA    <midi_sysex_rx_bulk_patch_index

; The MSB of the SysEx bulk data byte count will contain the number of
; patches contained in the bulk data dump.
; This value is used to check whether all of the patches have been received.
    CMPA    <midi_sysex_byte_count_msb_param_number
    BEQ     .finish_receiving_bulk_data

; If the bulk voice transfer isn't finished, reset the received SysEx byte
; count to '5', which is the size of the SysEx header.
; This sets up the state machine to anticipate the next incoming patch.
    LDAB    #5
    STAB    <midi_rx_data_count
    JMP     midi_process_incoming_data

.finish_receiving_bulk_data:
; Set the received data count to '160' to trigger the validation of the
; received data using the SysEx checksum.
    LDAB    #160
    STAB    <midi_rx_data_count
    JMP     midi_process_incoming_data


; =============================================================================
; MIDI_SYSEX_RX_BULK_DATA_FINALISE
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC708
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Finalises the received SysEx bulk patch data.
; This subroutine validates the bulk data checksum, and initiates the
; deserialisation of the bulk patch data into the synth's memory.
;
; ARGUMENTS:
; Registers:
; * ACCA: The incoming SysEx checksum byte.
;
; =============================================================================
midi_rx_sysex_bulk_data_finalise:               SUBROUTINE
    CLR     midi_sysex_rx_active_flag

; Add the incoming final checksum byte to the checksum, and test whether it
; is equal to zero. If not, a MIDI transmission error has occurred.
    ADDA    <midi_sysex_rx_checksum
    ANDA    #%1111111
    BNE     .checksum_error

    TST     <midi_sysex_format_type
    BNE     .finalise_all_patches

; Copy the received patch to the 'incoming' buffer, and load it.
    JSR     midi_sysex_rx_bulk_data_serialise_incoming

    LDAB    #PATCH_INCOMING_BUFFER_INDEX
    JSR     patch_set_new_index_and_copy_edit_to_compare
    JSR     patch_load_clear_compare_mode_state

; Reset operator 'On/Off' status.
    RESET_OPERATOR_STATUS

    JSR     led_print_patch_number
    JSR     lcd_clear
    LDX     #str_midi_received
    JSR     lcd_strcpy

; Print the received patch name.
; This copies each character of the patch name to the LCD 'next' buffer.
    LDX     #(lcd_buffer_next + 20)
    STX     <memcpy_ptr_dest
    JSR     patch_print_current_name

    BRA     .exit

.finalise_all_patches:
; Since each patch is 128 bytes in size, and the SysEx data has a 7 bit length,
; the data length's MSB indicates the number of patches in the dump.
; Decrement the MSB count to convert the total number of patches in the
; bulk patch dump to a usable patch index.
; If this is more than the highest patch buffer index, clamp.
    LDAB    <midi_sysex_byte_count_msb_param_number
    DECB
    CMPB    #(PATCH_BUFFER_COUNT - 1)
    BLS     .set_index

    LDAB    #(PATCH_BUFFER_COUNT - 1)

.set_index:
; Set the new patch index.
    JSR     patch_set_new_index_and_copy_edit_to_compare
    JSR     patch_load_clear_compare_mode_state

    RESET_OPERATOR_STATUS

    JSR     ui_print_update_led_and_menu
    JSR     lcd_clear_line_2
    LDX     #str_midi_received
    JSR     lcd_strcpy
    JSR     lcd_update
    BRA     .exit

.checksum_error:
    JSR     lcd_clear_line_2
    LDX     #str_midi_checksum_error
    JSR     lcd_strcpy
    JSR     lcd_update

.exit:
    LDAA    #MIDI_STATUS_SYSEX_END
    STAA    <midi_last_command_received
    JMP     midi_reenable_timer_interrupt


; =============================================================================
; MIDI_SYSEX_RX_PARAM_FUNCTION_64_TO_76
; =============================================================================
; DESCRIPTION:
; Handles a SysEx function parameter change message from '64' to '76'.
; These correspond to the synth's main function parameters.
;
; ARGUMENTS:
; Registers:
; * ACCA: The incoming SysEx parameter number.
; * ACCB: The incoming SysEx parameter value.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; =============================================================================
midi_sysex_rx_param_function_64_to_76:          SUBROUTINE
; If the parameter number is '76' or above, this is invalid.
; Unlike the DX7, this excludes the final two editable parameters
; (0x4C, and 0x4D). These are for aftertouch, which is not relevant to the DX9.
    CMPA    #76
    BCC     .exit

; If the parameter number is equal to '70', or higher, this represents a
; controller parameter. These are not stored linearly in memory, and require
; different logic.
    CMPA    #70
    BCC     .is_mod_wheel_param

; Load a pointer to the function data.
; Subtract '64', and use this value as an index to the specified function
; parameter in the synth's memory.
    LDX     #mono_poly
    SUBA    #64
    TAB
    ABX
    BRA     .store_incoming_value

.is_mod_wheel_param:
; If the parameter number is equal to '72' or above, it's not the mod wheel.
    CMPA    #72
    BCC     .is_breath_controller_param

; The parameter number is either '46' (Range), or '47' (Settings).
; The following code tests which setting number it is by testing whether the
; parameter number is odd.
    LDX     #mod_wheel_range

    BITA    #1
    BNE     .parse_modulation_properties

    BRA     .store_incoming_value

.is_breath_controller_param:
; If the parameter number is below '74', it's for the foot controller, so exit.
    CMPA    #74
    BCS     .exit

    LDX     #breath_control_range

    BITA    #1
    BNE     .parse_modulation_properties

    BRA     .store_incoming_value

.parse_modulation_properties:
; In the DX7 firmware, the controller settings are stored as a bitmask.
; This section translates between the bitmask format shared by the SysEx
; implementation, and the sequential variables used in the DX9 firmware.
    CLC
    LDAA    #1

; Clear the three settings variables initially.
    CLR     1,x
    CLR     2,x
    CLR     3,x

; Rotate the bitmask rightwards.
; If the first bit (Pitch modulation) is set, this will set the carry bit.
    RORB
    BCC     .test_amplitude_setting

    STAA    1,x

.test_amplitude_setting:
    RORB
    BCC     .test_eg_bias_setting

    STAA    2,x

.test_eg_bias_setting:
    RORB
    BCC     .update_ui_and_exit

    STAA    3,x

    BRA     .update_ui_and_exit

.store_incoming_value:
; Write the newly received SysEx data.
    LDAA    <midi_sysex_byte_count_lsb_param_data
    STAA    0,x

; Check whether the function parameter being edited is the polyphony.
; If so, reset the synth's voice data.
    CPX     #mono_poly
    BNE     .is_param_porta_time

    JSR     voice_reset
    BRA     .update_ui_and_exit

.is_param_porta_time:
; If the incoming function parameter is the portamento time, re-calculate
; the portamento increment.
    CPX     #portamento_time
    BNE     .update_ui_and_exit

    JSR     portamento_calculate_rate

.update_ui_and_exit:
    JMP     ui_print_update_led_and_menu

.exit:
    RTS


; =============================================================================
; MIDI_SYSEX_RX_PARAM_FUNCTION_BUTTON
; =============================================================================
; DESCRIPTION:
; SysEx parameter numbers below '42' correspond to DX7 button presses.
; The DX9 only acknowledges '0' to '28'.
; This subroutine initiates button presses from receiving SysEx function data.
; Refer to equivalent functionality in DX7 v1.8 firmware at 0xEEBB.
;
; ARGUMENTS:
; Registers:
; * ACCA: The incoming SysEx parameter number.
; * ACCB: The incoming SysEx parameter data.
;
; =============================================================================
midi_sysex_rx_param_function_button:            SUBROUTINE
; Test that the button is 28, or below.
    CMPA    #28
    BCC     .exit

; @TODO: I'm not sure what the significance of this is. This does not
; feature in the DX7 firmware.
    CMPA    #INPUT_BUTTON_FUNCTION
    BEQ     .is_button_4

; The button function parameters have two valid data states: '0', and '127'.
; '127' indicates a button being depressed.
; In this case, only acknowledge this value.
    CMPB    #127
    BNE     .exit

    BRA     .trigger_button_press

.is_button_4:
    TSTB
    BNE     .exit

.trigger_button_press:
; Trigger the button-press corresponding to this SysEx function parameter
; message by passing the parameter number to the main input handler.
    CLR     main_patch_event_flag
    TAB
    JMP     main_input_handler_process_button

.exit:
    RTS


; =============================================================================
; MIDI_SYSEX_RX_BULK_DATA_SERIALISE_INCOMING
; =============================================================================
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; This subroutine serialises patch data received via the SysEx 'single'
; patch method to the bulk 'packed' format, which will later be deserialised
; into the patch edit buffer.
; The reason this is used instead of just deserialising straight from the
; the SysEx buffer into the edit buffer is so that the regular patch loading
; methods can be used to store the previous patch to the compare buffer, and
; correctly set the patch indexes.
;
; =============================================================================
midi_sysex_rx_bulk_data_serialise_incoming:
    LDX     #midi_buffer_sysex_rx
    STX     <memcpy_ptr_src

    LDX     #patch_buffer_incoming
    STX     <memcpy_ptr_dest

    JMP     patch_serialise


; =============================================================================
; MIDI_SYSEX_RX_BULK_DATA_DESERIALISE
; =============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Deserialises a patch from the incoming SysEx buffer to its final destination
; in the synth's memory.
;
; ARGUMENTS:
; Memory:
; * midi_sysex_rx_bulk_patch_index: The patch index to deserialise the incoming
;    patch into.
;
; =============================================================================
midi_sysex_rx_bulk_data_deserialise:            SUBROUTINE
    LDX     #midi_buffer_sysex_rx
    STX     <memcpy_ptr_src

; Ensure patch index is less than, or equal to the size of the patch buffer.
; If the index is above the maximum, store it in the incoming patch buffer.
    LDAA    <midi_sysex_rx_bulk_patch_index
    CMPA    #PATCH_BUFFER_COUNT
    BLS     .get_patch_buffer_pointer

    LDAA    #PATCH_INCOMING_BUFFER_INDEX

.get_patch_buffer_pointer:
; Get index into patch buffer.
    LDAB    #PATCH_SIZE_PACKED_DX7
    MUL
    ADDD    #patch_buffer
    STD     <memcpy_ptr_dest

    LDAB    #PATCH_SIZE_PACKED_DX7
    JMP     memcpy

.exit:
    RTS
