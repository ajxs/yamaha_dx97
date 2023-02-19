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
; patch/initialise.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions and code used for initialising the patch
; edit buffer.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_INITIALISE
; ==============================================================================
; DESCRIPTION:
; Initialises the patch edit buffer.
; If the currently loaded patch has been modified, it will copy the current
; patch edit buffer into the patch compare buffer.
;
; ==============================================================================
patch_initialise:                               SUBROUTINE
    CLR     patch_compare_mode_active

; Setting the sign bit of the current patch index will cause the
; 'patch_load' to reload the init patch buffer.
    LDAB    #$80
    JSR     patch_set_new_index_and_copy_edit_to_compare
    JSR     midi_sysex_tx_bulk_data_send_init_voice
; Falls-through below.

; ==============================================================================
; PATCH_INIT_EDIT_BUFFER
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; Initialises the patch edit buffer.
; This is called directly from several places to initialise the edit buffer
; without sending any SysEx event.
;
; ==============================================================================
patch_init_edit_buffer:
; Reset the operator 'On/Off' status.
    RESET_OPERATOR_STATUS

; Deserialise from the init patch buffer to the patch edit buffer.
    LDX     #patch_buffer_init_voice_dx9
    JMP     patch_deserialise_to_edit_from_ptr_and_reload


; ==============================================================================
; Initialised Patch Buffer.
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; ==============================================================================
patch_buffer_init_voice_dx9:
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B 0
    DC.B 0
    DC.B 0
    DC.B 0
    DC.B 1
    DC.B 0
    DC.B 7
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B 0
    DC.B 0
    DC.B 0
    DC.B 0
    DC.B 1
    DC.B 0
    DC.B 7
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B 0
    DC.B 0
    DC.B 0
    DC.B 0
    DC.B 1
    DC.B 0
    DC.B 7
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B 0
    DC.B 0
    DC.B 0
    DC.B $63
    DC.B 1
    DC.B 0
    DC.B 7
    DC.B 0
    DC.B 8
    DC.B $23
    DC.B 0
    DC.B 0
    DC.B 0
    DC.B $18
    DC.B 12
