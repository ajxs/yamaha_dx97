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
; patch/deserialise.asm
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Deserialises a patch from the 'packed' format used to store patches in the
; synth's internal to the 'unpacked' format in the synth's edit buffer.
; @Note: This is largely taken from the DX7 firmware, but the call signature
; is modified to match that of the DX9.
;
; ARGUMENTS:
; Registers:
; * IX:   A pointer to the destination buffer for the deserialised patch.
;
; Memory:
; * memcpy_ptr_src:  The source patch buffer pointer.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================

    .PROCESSOR HD6303

patch_deserialise:                              SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.operator_counter:                              EQU #temp_variables
.temp_variable:                                 EQU #temp_variables + 1

; ==============================================================================
    STX     memcpy_ptr_dest

    LDAB    #6
    STAB    .operator_counter

.deserialise_operator_loop:
; Copy the first 11 bytes of the operator structure.
; These are identical in the packed/unpacked format.
    LDAB    #11
    JSR     memcpy

; Deserialise byte 11.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    STAA    .temp_variable

; Mask the left scaling curve value, and store.
    ANDA    #%11
    LOAD_DEST_PTR_AND_STORE_ACCA
    INX

; Mask the right curve value, and store.
    LDAA    .temp_variable
    ANDA    #%1100
    LSRA
    LSRA
    STAA    0,x
    INCREMENT_DEST_PTR_AND_STORE

; Deserialise byte 12.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    STAA    .temp_variable

; Mask, and store the oscillator rate scaling.
    ANDA    #%111
    INCREMENT_SRC_PTR_AND_STORE
    LOAD_DEST_PTR_AND_STORE_ACCA

; Mask, and store the oscillator detune value.
    LDAA    .temp_variable
    LSRA
    LSRA
    LSRA
    STAA    7,x
    INCREMENT_DEST_PTR_AND_STORE

; Deserialise byte 13.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    STAA    .temp_variable

; Mask, and store the amp modulation sensitivity value.
    ANDA    #%11
    LOAD_DEST_PTR_AND_STORE_ACCA
    INX

; Mask, and store the key velocity sensitivity value.
    LDAA    .temp_variable
    LSRA
    LSRA
    STAA    0,x
    INCREMENT_DEST_PTR_AND_STORE

; Deserialise byte 14.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Deserialise byte 15.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    STAA    .temp_variable

; Mask and store the oscillator mode value.
    ANDA    #1
    LOAD_DEST_PTR_AND_STORE_ACCA

; Mask, and store the coarse frequency value.
    INX
    LDAA    .temp_variable
    LSRA
    STAA    0,x
    INCREMENT_DEST_PTR_AND_STORE

; Deserialise byte 16.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    LOAD_DEST_PTR_AND_STORE_ACCA
    INX
    INCREMENT_DEST_PTR_AND_STORE

; Decrement the operator loop counter.
    DEC     .operator_counter
    BEQ     .copy_patch_values

    JMP     .deserialise_operator_loop

.copy_patch_values:
; Copy the pitch EG values.
    LDAB    #8
    JSR     memcpy

; Deserialise byte 110.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Deserialise byte 111.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    STAA    .temp_variable

; Mask, and store the feedback value.
    ANDA    #%111
    LOAD_DEST_PTR_AND_STORE_ACCA

; Mask, and store the oscillator key sync value.
    INX
    LDAA    .temp_variable
    LSRA
    LSRA
    LSRA
    STAA    0,x
    INCREMENT_DEST_PTR_AND_STORE

; Copy bytes 112-115.
    LDAB    #4
    JSR     memcpy

; Deserialise byte 116.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    STAA    .temp_variable

; Mask, and store the LFO Key Sync value.
    ANDA    #1
    LOAD_DEST_PTR_AND_STORE_ACCA

; Mask, and store the LFO Wave value.
    INX
    LDAA    .temp_variable
    LSRA
    ANDA    #%111
    STAA    0,x

; Mask, and store the LFO Pitch Mod Sensitivity value.
    INX
    LDAA    .temp_variable
    LSRA
    LSRA
    LSRA
    LSRA
    STAA    0,x
    INCREMENT_DEST_PTR_AND_STORE

; Deserialise byte 117.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Copy the patch name.
    LDAB    #10
    JMP     memcpy
