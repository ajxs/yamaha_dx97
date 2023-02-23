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
; patch/serialise.asm
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Serialises a patch from the 'unpacked' edit buffer format to the 128 byte
; 'packed' format in the synth's internal memory.
; This subroutine is used when saving a
; patch.
; Refer to the following for the patch format:
; https://github.com/asb2m10/dexed/blob/master/Documentation/sysex-format.txt
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

patch_serialise:                                SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.operator_counter:                              EQU #temp_variables
.temp_variable:                                 EQU #temp_variables + 1
.temp_variable_2:                               EQU #temp_variables + 2

; ==============================================================================
    STX     memcpy_ptr_dest

    LDAB    #6
    STAB    .operator_counter

.copy_operator_loop:
; Copy the first 11 bytes.
    LDAB    #11
    JSR     memcpy

; Copy keyboard scaling curves.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INX
    STAA    .temp_variable

; Load the 'Right Curve' value, shift this value left twice, and combine to
; create the serialised format.
    LDAA    0,x
    ASLA
    ASLA
    ADDA    .temp_variable

; Increment source pointer.
    INCREMENT_SRC_PTR_AND_STORE

; Store value and increment destination pointer.
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Copy 'Keyboard Rate Scale', and 'Oscillator detune'.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    STAA    .temp_variable

; Load the Osc detune value, shift left three times, and combine.
    LDAA    7,x
    ASLA
    ASLA
    ASLA
    ADDA    .temp_variable

; Increment source pointer.
    INCREMENT_SRC_PTR_AND_STORE

; Store value and increment destination pointer.
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Copy 'Amp Mod Sensitivity', and 'Key Velocity Sensitivity'.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INX
    STAA    .temp_variable

; Load the 'Key Velocity Sens' value, shift left three times, and combine.
    LDAA    0,x
    INX
    ASLA
    ASLA
    ADDA    .temp_variable
    STX     <memcpy_ptr_src

; Store value and increment destination pointer.
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Copy 'Output Level'.
    LOAD_SRC_PTR_AND_LOAD_ACCA

; Increment source pointer.
    INCREMENT_SRC_PTR_AND_STORE

; Store value and increment destination pointer.
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Copy 'Coarse Frequency', and 'Oscillator Mode'.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INX
    STAA    .temp_variable

; Load 'Coarse Frequency', shift left, and combine.
    LDAA    0,x
    INX
    ASLA
    ADDA    .temp_variable
    STX     <memcpy_ptr_src

    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Copy oscillator fine frequency.
    LOAD_SRC_PTR_AND_LOAD_ACCA

; Increment source pointer.
    INX
    INCREMENT_SRC_PTR_AND_STORE

; Store value and increment destination pointer.
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Decrement loop index.
    DEC     .operator_counter
    BEQ     .copy_patch_values

    JMP     .copy_operator_loop

.copy_patch_values:
; Copy the 8 pitch EG values, then copy the algorithm value.
    LDAB    #8
    JSR     memcpy

; Copy 'Feedback', and 'Key Sync'.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE

; Store value and increment destination pointer.
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

    LOAD_SRC_PTR_AND_LOAD_ACCA
    INX
    STAA    .temp_variable

; Load value, increment origin pointer, shift left 3 times, and combine.
    LDAA    0,x
    INCREMENT_SRC_PTR_AND_STORE
    ASLA
    ASLA
    ASLA
    ADDA    .temp_variable

; Store value and increment destination pointer.
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Copy the LFO values:
; * LFO Speed.
; * LFO Delay.
; * LFO Pitch Mod Depth.
; * LFO Amp Mod Depth.
    LDAB    #4
    JSR     memcpy

; Copy, and combine into one byte:
; * LFO Sync.
; * LFO Wave.
; * LFO Pitch Mod Sensitivity.
    LOAD_SRC_PTR_AND_LOAD_ACCA
    INX
    STAA    .temp_variable

    LDAA    0,x
    INX
    ASLA
    STAA    .temp_variable_2

    LDAA    0,x
    INX
    ASLA
    ASLA
    ASLA
    ASLA

; Combine the two temporary variables.
    ADDA    .temp_variable
    ADDA    .temp_variable_2

; Store incremented origin ptr.
    STX     <memcpy_ptr_src
    LDX     <memcpy_ptr_dest

; Store value, and increment destination pointer.
    STAA    0,x
    INCREMENT_DEST_PTR_AND_STORE

    LOAD_SRC_PTR_AND_LOAD_ACCA
    INCREMENT_SRC_PTR_AND_STORE
    LOAD_DEST_PTR_AND_STORE_ACCA
    INCREMENT_DEST_PTR_AND_STORE

; Copy the patch name.
    LDAB    #10
    JMP     memcpy
