; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; patch/patch.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions and code used for working with patches.
; ==============================================================================

    .PROCESSOR HD6303

PATCH_DX7_PACKED_OP_STRUCTURE_SIZE              EQU 17
PATCH_DX7_UNPACKED_OP_STRUCTURE_SIZE            EQU 21

; ==============================================================================
; Patch Edit Buffer Offsets.
; These offsets can be used to access an individual field inside the patch
; edit buffer, or an unpacked SysEx patch dump.
; ==============================================================================
PATCH_OP_EG_RATE_1                              EQU 0
PATCH_OP_EG_RATE_2                              EQU 1
PATCH_OP_EG_RATE_3                              EQU 2
PATCH_OP_EG_RATE_4                              EQU 3
PATCH_OP_EG_LEVEL_1                             EQU 4
PATCH_OP_EG_LEVEL_2                             EQU 5
PATCH_OP_EG_LEVEL_3                             EQU 6
PATCH_OP_EG_LEVEL_4                             EQU 7
PATCH_OP_LVL_SCL_BREAK_POINT                    EQU 8
PATCH_OP_LVL_SCL_LT_DEPTH                       EQU 9
PATCH_OP_LVL_SCL_RT_DEPTH                       EQU 10
PATCH_OP_LVL_SCL_LT_CURVE                       EQU 11
PATCH_OP_LVL_SCL_RT_CURVE                       EQU 12
PATCH_OP_RATE_SCALING                           EQU 13
PATCH_OP_AMP_MOD_SENS                           EQU 14
PATCH_OP_KEY_VEL_SENS                           EQU 15
PATCH_OP_OUTPUT_LEVEL                           EQU 16
PATCH_OP_MODE                                   EQU 17
PATCH_OP_FREQ_COARSE                            EQU 18
PATCH_OP_FREQ_FINE                              EQU 19
PATCH_OP_DETUNE                                 EQU 20

PATCH_PITCH_EG_R1                               EQU 126
PATCH_PITCH_EG_R2                               EQU 127
PATCH_PITCH_EG_R3                               EQU 128
PATCH_PITCH_EG_R4                               EQU 129
PATCH_PITCH_EG_L1                               EQU 130
PATCH_PITCH_EG_L2                               EQU 131
PATCH_PITCH_EG_L3                               EQU 132
PATCH_PITCH_EG_L4                               EQU 133
PATCH_ALGORITHM                                 EQU 134
PATCH_FEEDBACK                                  EQU 135
PATCH_OSC_SYNC                                  EQU 136
PATCH_LFO_SPEED                                 EQU 137
PATCH_LFO_DELAY                                 EQU 138
PATCH_LFO_PITCH_MOD_DEPTH                       EQU 139
PATCH_LFO_AMP_MOD_DEPTH                         EQU 140
PATCH_LFO_SYNC                                  EQU 141
PATCH_LFO_WAVEFORM                              EQU 142
PATCH_LFO_PITCH_MOD_SENS                        EQU 143
PATCH_KEY_TRANSPOSE                             EQU 144
PATCH_PATCH_NAME                                EQU 145

; From https://homepages.abdn.ac.uk/d.j.benson/pages/dx7/sysex-format.txt
; "Note that there are actually 156 parameters listed here, one more than in
; a single voice dump. The OPERATOR ON/OFF parameter is not stored with the
; voice, and is only transmitted or received while editing a voice. So it
; only shows up in parameter change SYS-EX's."
PATCH_OPERATOR_ON_OFF_STATUS                    EQU 155


PATCH_PACKED_ALGORITHM                          EQU 110

PATCH_DX9_PACKED_ALGORITHM                      EQU 56

; The index of the incoming patch buffer.
PATCH_INCOMING_BUFFER_INDEX                     EQU PATCH_BUFFER_COUNT

; ==============================================================================
; Serialisation/Deserialisation macros.
; These macros simply compress some repetitive sequences used in the
; patch deserialisation routine.
; ==============================================================================
    .MACRO INCREMENT_SRC_PTR_AND_STORE
        INX
        STX     <memcpy_ptr_src
    .ENDM

    .MACRO INCREMENT_DEST_PTR_AND_STORE
        INX
        STX     <memcpy_ptr_dest
    .ENDM

    .MACRO LOAD_SRC_PTR_AND_LOAD_ACCA
        LDX     <memcpy_ptr_src
        LDAA    0,x
    .ENDM

    .MACRO LOAD_DEST_PTR_AND_STORE_ACCA
        LDX     <memcpy_ptr_dest
        STAA    0,x
    .ENDM

; ==============================================================================
; PATCH_OPERATOR_GET_PTR_TO_SELECTED
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDD9B
; DESCRIPTION:
; Gets a pointer to the selected operator's data in the patch edit buffer.
;
; ARGUMENTS:
; Memory:
; * operator_selected_src: The currently selected operator.
;
; RETURNS:
; * IX: A pointer to the selected operator.
;
; ==============================================================================
patch_operator_get_ptr_to_selected:             SUBROUTINE
    LDAB    operator_selected_src
; Falls-through below.

; ==============================================================================
; PATCH_OPERATOR_GET_PTR
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDD9E
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Gets a pointer to the specified operator's data in the patch edit buffer.
;
; ARGUMENTS:
; Registers:
; * ACCB: The operator number (from 0-5) to get a pointer to.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * IX: A pointer to the selected operator.
;
; ==============================================================================
patch_operator_get_ptr:                         SUBROUTINE
; 'Reverse' the operator numbering from 0-5 to 5-0, since the ordering in the
; edit buffer is in reverse.
    LDAA    #5
.reverse_operator_number_loop:
    DECB
    BMI     .get_offset_into_edit_buffer
    DECA
    BRA     .reverse_operator_number_loop

.get_offset_into_edit_buffer:
    TAB

; Get the offset into the patch edit buffer by multiplying the selected
; operator number by the size of an operator.
    LDAA    #PATCH_DX7_UNPACKED_OP_STRUCTURE_SIZE
    MUL
    ADDD    #patch_buffer_edit
    XGDX

    RTS


; ==============================================================================
; PATCH_GET_PTR_TO_CURRENT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDD89
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Gets a pointer to the currently selected patch in the synth's memory.
;
; ARGUMENTS:
; Memory:
; * patch_index_current: The 0-indexed patch number to get the pointer to.
;   If this is a negative number, a pointer to the initialised patch
;   buffer will be returned.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * IX: A pointer to the currently selected patch.
;
; ==============================================================================
patch_get_ptr_to_current:                       SUBROUTINE
    LDAB    patch_index_current
    BPL     patch_get_ptr

    LDX     #patch_buffer_init_voice
    RTS


; ==============================================================================
; PATCH_GET_PTR
; ==============================================================================
; DESCRIPTION:
; Gets a pointer to the a specified patch in the synth's memory.
;
; ARGUMENTS:
; Registers:
; * ACCB: The 0-indexed patch number to get a pointer to.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * IX: A pointer to the currently selected patch.
;
; ==============================================================================
patch_get_ptr:                                  SUBROUTINE
    LDAA    #PATCH_SIZE_PACKED_DX7
    MUL
    ADDD    #patch_buffer
    XGDX
    RTS


; ==============================================================================
; PATCH_COPY_EDIT_TO_COMPARE_AND_LOAD_CURRENT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Serialises the currently loaded patch in the edit buffer to the compare
; buffer, then loads the 'current' patch (based off the selected patch index)
; into the edit buffer.
;
; ==============================================================================
patch_copy_edit_to_compare_and_load_current:    SUBROUTINE
    LDX     #patch_buffer_edit
    STX     <memcpy_ptr_src

    LDX     #patch_buffer_compare
    JSR     patch_serialise

    JMP     patch_deserialise_current_to_edit


; ==============================================================================
; PATCH_RESTORE_EDIT_BUFFER_FROM_COMPARE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Deserialises the 'Patch Compare' buffer into the 'Patch Edit' buffer.
;
; REGISTERS MODIFIED:
; * IX
;
; ==============================================================================
patch_restore_edit_buffer_from_compare:         SUBROUTINE
    LDX     #patch_buffer_compare
    JMP     patch_deserialise_to_edit_from_ptr_and_reload


; ==============================================================================
; PATCH_SET_NEW_INDEX_AND_SAVE_EDIT_BUFFER_TO_COMPARE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xE22F
; DESCRIPTION:
; This subroutine is invoked when changing patches.
; It sets the newly selected patch index, and if the currently loaded patch
; has been edited, it will backup the edit buffer by serialising it to the
; patch compare buffer.
;
; ARGUMENTS:
; Registers:
; * ACCB: The new patch index.
;
; MEMORY MODIFIED:
; * patch_current_modified_flag
; * patch_index_current
; * patch_index_compare
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
patch_set_new_index_and_copy_edit_to_compare:   SUBROUTINE
; If the patch in the edit buffer has not been modified, it will not be backed
; up to the compare buffer.
    TST     patch_current_modified_flag
    BEQ     .patch_unmodified

; Save the current patch index to the compare index, and set the current
; patch as being unmodified.
    LDAA    patch_index_current
    STAA    patch_index_compare
    STAB    patch_index_current
    CLR     patch_current_modified_flag

; Serialise the patch edit buffer to the compare buffer.
    LDX     #patch_buffer_edit
    STX     <memcpy_ptr_src
    LDX     #patch_buffer_compare
    JSR     patch_serialise

.exit:
    RTS

.patch_unmodified:
; If the patch is unmodified, simply update the selected patch index.
    STAB    patch_index_current
    BRA     .exit


; ==============================================================================
; PATCH_EDIT_RECALL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Recalls a patch from the 'Patch Compare' buffer.
; This routine is called from the UI function mode menu.
;
; ==============================================================================
patch_edit_recall:                              SUBROUTINE
    LDAA    patch_index_compare
    STAA    patch_index_current
    CLR     patch_compare_mode_active

; Set the patch edit buffer as having been modified.
    LDAA    #1
    STAA    patch_current_modified_flag
    JSR     midi_sysex_tx_recalled_patch

; Reset operator 'On/Off' status.
    RESET_OPERATOR_STATUS

    BRA     patch_restore_edit_buffer_from_compare


; ==============================================================================
; PATCH_SAVE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Serialises the patch edit buffer to the specified index into the synth's
; patch memory, saving the patch to the synth's non-volatile storage.
;
; ARGUMENTS:
; Registers:
; * ACCB: The index into the synth's patch memory to save the edit buffer to.
;
; ==============================================================================
patch_save:
    STAB    patch_index_current
    CLR     patch_current_modified_flag
    CLR     patch_compare_mode_active
    LDX     #patch_buffer_edit
    STX     <memcpy_ptr_src

; Get a pointer to the currently selected patch in the device's main patch
; memory buffer.
; This pointer is stored to the copy destination pointer in the
; 'patch_serialise' function.
    JSR     patch_get_ptr_to_current

; Force stopping of all voices, and reloading of the patch.
    LDAB    #EVENT_HALT_VOICES_RELOAD_PATCH
    STAB    main_patch_event_flag
    JMP     patch_serialise


; ==============================================================================
; PATCH_OPERATOR_EG_COPY
; ==============================================================================
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Copies the envelope settings from the currently selected operator, to the
; specified destination operator.
;
; ARGUMENTS:
; Registers:
; * ACCB: The number of the operator to copy the EG settings to.
;
; MEMORY MODIFIED:
; * operator_selected_dest: The selected operator number, which will be the
;    source of the copied EG information.
;
; ==============================================================================
patch_operator_eg_copy:                         SUBROUTINE
; Validate the specified operator number.
; If >= 7, exit.
    CMPB    #7
    BCC     .exit

    STAB    operator_selected_dest
    JSR     patch_operator_get_ptr
    STX     <memcpy_ptr_dest

    JSR     patch_operator_get_ptr_to_selected
    STX     <memcpy_ptr_src

    LDAB    #12
    JSR     memcpy

; Trigger a patch reload.
    LDAB    #EVENT_RELOAD_PATCH

; Set the patch edit buffer as having been modified.
    STAB    patch_current_modified_flag
    STAB    main_patch_event_flag

.exit:
    RTS


; ==============================================================================
; PATCH_CONVERT_SERIALISED_VALUE_TO_INTERNAL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD005
; DESCRIPTION:
; Scales a particular patch value from its serialised range of 0-99, to its
; scaled 16-bit representation. Returning the result in ACCD.
; e.g.
;   Scale(50) = 33000
;   Scale(99) = 65340
;
; This is performed by multiplying the source value by 665. Since the HD6303
; can only perform 8-bit arithmetic, this is done by multiplying the value
; by 165 (665/4), and then doubling it twice by bit-shifts.
;
; ARGUMENTS:
; Registers:
; * ACCA: The byte to scale to 16-bit form.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; RETURNS:
; * ACCD: The scaled value.
;
; ==============================================================================
patch_convert_serialised_value_to_internal:     SUBROUTINE
    LDAB    #165
    MUL
    LSLD
    LSLD

    RTS


; ==============================================================================
; PATCH_PRINT_CURRENT_NAME
; ==============================================================================
; @NEW_FUNCTIONALITY
; @NEEDS_TESTING
; DESCRIPTION:
; These annotations are used so that subroutines can be easily searched by
; category.
;
; ARGUMENTS:
; Memory:
; * memcpy_pointer_dest: A pointer to where in the LCD buffer to print the
;     patch name to.
;
; MEMORY MODIFIED:
; * memcpy_pointer_source
; * memcpy_pointer_dest
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
patch_print_current_name:                       SUBROUTINE
    LDX     #patch_edit_name

.print_name_loop:
    LDAB    0,x
    JSR     lcd_store_character_and_increment_ptr
    INX
    CPX     #patch_edit_name + 10
    BNE     .print_name_loop

    JMP     lcd_update
