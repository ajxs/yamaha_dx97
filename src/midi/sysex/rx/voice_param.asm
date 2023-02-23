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
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Processes incoming SysEx voice parameter data.
; This subroutine is responsible for storing the incoming data.
; This has been significantly reworked from the original DX9 ROM code, as no
; translation of parameter offsets is necessary.
;
; =============================================================================
midi_sysex_rx_param_voice_process:              SUBROUTINE
; The full parameter offset is contained in both the param number byte,
; and the two least-significant bits of the parameter group byte.
; These need to be combined.
    LDAA    <midi_sysex_format_param_grp
    LDAB    <midi_sysex_byte_count_msb_param_number

; If this value is zero, no combination of these values is necessary.
    CMPA    #0
    BEQ     .set_parameter

; If this value is not one, it indicates a value over 255, which is invalid.
    CMPA    #1
    BNE     .exit

; Set this bit to combine the values.
    ORAB    1 << 7

.set_parameter:
    LDAA    <midi_sysex_byte_count_lsb_param_data

    LDX     #patch_buffer_edit
    ABX

; Test whether the incoming data is identical to the existing voice data.
; If not, write the data to the pointer in IX. Otherwise exit.
    CMPA    0,x
    BEQ     .exit

    STAA    0,x

.exit:
    JMP     ui_print_update_led_and_menu
