; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
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
    LDX     #patch_buffer_init_voice
    JMP     patch_deserialise_to_edit_from_ptr_and_reload


; ==============================================================================
; Initialise Patch Buffer.
; This buffer contains the data to initialise the patch 'Edit Buffer'.
; @CHANGED_FOR_6_OP
; ==============================================================================
patch_buffer_init_voice:
; Operator 6.
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
    DC.B 0
    DC.B $38
    DC.B 0
    DC.B 0
    DC.B 2
    DC.B 0
; Operator 5.
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
    DC.B 0
    DC.B $38
    DC.B 0
    DC.B 0
    DC.B 2
    DC.B 0
; Operator 4.
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
    DC.B 0
    DC.B $38
    DC.B 0
    DC.B 0
    DC.B 2
    DC.B 0
; Operator 3.
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
    DC.B 0
    DC.B $38
    DC.B 0
    DC.B 0
    DC.B 2
    DC.B 0
; Operator 2.
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
    DC.B 0
    DC.B $38
    DC.B 0
    DC.B 0
    DC.B 2
    DC.B 0
; Operator 1.
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
    DC.B 0
    DC.B $38
    DC.B 0
    DC.B $63
    DC.B 2
    DC.B 0
; Pitch EG Rate.
    DC.B $63
    DC.B $63
    DC.B $63
    DC.B $63
; Pitch EG Level.
    DC.B $32
    DC.B $32
    DC.B $32
    DC.B $32
; Algorithm.
    DC.B 0
; Oscillator Key Sync/Feedback.
    DC.B 8
; LFO Speed.
    DC.B $23
; LFO Delay.
    DC.B 0
; LFO Pitch Mod Depth.
    DC.B 0
; LFO Amp Mod Depth.
    DC.B 0
; LFO Wave / LFO Key Sync.
    DC.B $31
; Key Transpose.
    DC.B $18
    DC "INIT VOICE"
