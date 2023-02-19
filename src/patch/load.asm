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
; patch/load.asm
; ==============================================================================
; DESCRIPTION:
; Contains definitions and functionality for loading serialised patches.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_LOAD
; ==============================================================================
; DESCRIPTION:
; @TODO
; Initiates deserialisation of a patch from the synth's internal memory into
; the synth's edit buffer.
;
; ARGUMENTS:
; Registers:
; * ACCB: The index of the patch to load into the synth's patch memory,
;         starting at index 0.
;
; ==============================================================================
patch_load:                                     SUBROUTINE
    CMPB    patch_index_current
    BNE     patch_load_store_edit_buffer_to_compare

; If the incoming patch number in ACCB is identical to the currently
; selected patch index, test whether the currently loaded patch has been
; modified. If not, exit.
    TST     patch_current_modified_flag
    BNE     patch_load_store_edit_buffer_to_compare

    RTS

patch_load_store_edit_buffer_to_compare:
; Patch index is saved here.
    JSR     patch_set_new_index_and_copy_edit_to_compare
    JSR     midi_sysex_tx_program_change_current_patch
    JSR     midi_sysex_tx_bulk_data_single_voice

patch_load_clear_compare_mode_state:
    CLR     patch_compare_mode_active

patch_deserialise_current_to_edit:
    JSR     patch_get_ptr_to_current
; Falls-through below.

; ==============================================================================
; PATCH_DESERIALISE_TO_EDIT_FROM_PTR_AND_RELOAD
; ==============================================================================
; DESCRIPTION:
; Takes a pointer to a patch, and deserialises it into the synth's edit buffer.
; The flag is then set to force the activation of the newly loaded patch.
; This subroutine is the main point of loading a patch into memory.
; The loaded patch will also be validated in this routine.
;
; ARGUMENTS:
; Registers:
; * IX:   A pointer to the patch buffer to deserialise.
;
; ==============================================================================
patch_deserialise_to_edit_from_ptr_and_reload:  SUBROUTINE
    STX     <memcpy_ptr_src

; The destination pointer is stored in the deserialise routine below.
    LDX     #patch_buffer_edit

; Forces patch reload.
    LDAB    #EVENT_HALT_VOICES_RELOAD_PATCH
    STAB    main_patch_event_flag
    JSR     patch_deserialise
    JSR     patch_validate

    RTS
