; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; patch/convert/to_dx9.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE: 0xF698
; DESCRIPTION:
; Converts a DX7 bulk packed patch (128 bytes) to the equivalent
; DX9 format (64 bytes).
;
; ARGUMENTS:
; Memory:
; * memcpy_ptr_src: The source patch in DX7 format.
; * memcpy_ptr_dest: The destination buffer to store the converted patch in.
;
; RETURNS:
; The carry bit is set in the case of a failure in the conversion process.
;
; ==============================================================================

    .PROCESSOR HD6303

; =============================================================================
; PATCH_CONVERT_TO_DX9_FORMAT
; =============================================================================
patch_convert_to_dx9_format:                    SUBROUTINE
; The following code converts the DX7 algorithm to its DX9 equivalent.
    LDX     <memcpy_ptr_src
    LDAA    PATCH_PACKED_ALGORITHM,x
    CLRB

; This table acts as a translation table between the DX7 algorithm numbers,
; and those of the DX9.
; Load this translation table, and iterate over it until the specified
; DX7 algorithm is found. The index into the table will be the corresponding
; DX9 algorithm.
    LDX     #table_algorithm_conversion

.convert_algorithm_loop:
    CMPA    0,x
    BEQ     .store_algorithm

    INX
    INCB
    CMPB    #8
    BCS     .convert_algorithm_loop

; If the correct algorithm cannot be found, set the carry flag to
; indicate the error state, and exit.
    SEC
    BRA     .exit

.store_algorithm:
    LDX     <memcpy_ptr_dest
    STAB    PATCH_DX9_PACKED_ALGORITHM,x

; Convert each operator.
    LDAB    #4

.convert_operator_loop:
    PSHB

; Copy first 8 bytes (Operator EG).
    LDAB    #8
    JSR     memcpy
    STX     <memcpy_ptr_dest
    LDX     <memcpy_ptr_src

; Load breakpoint right depth, and store.
    LDAA    2,x
    LDX     <memcpy_ptr_dest
    STAA    0,x
    LDX     <memcpy_ptr_src

; Load oscillator rate scale.
    LDAA    4,x
    ANDA    #%111

; Load amp modulation sensitivity.
    LDAB    5,x
    ANDB    #%11

; Shift and combine, then store.
    ASLB
    ASLB
    ASLB
    ABA
    LDX     <memcpy_ptr_dest
    STAA    1,x

; Load output level, and coarse frequency, then store.
    LDX     <memcpy_ptr_src
    LDD     6,x
    LSRB
    LDX     <memcpy_ptr_dest
    STD     2,x

; Load fine frequency.
    LDX     <memcpy_ptr_src
    LDAA    8,x

; Load oscillator detune.
    LDAB    4,x
    LSRB
    LSRB
    LSRB
    LDX     <memcpy_ptr_dest
    STD     4,x

; Increment the operator read pointer by 9.
    LDX     <memcpy_ptr_src
    LDAB    #9
    ABX
    STX     <memcpy_ptr_src

; Increment the operator write pointer by 6.
    LDX     <memcpy_ptr_dest
    LDAB    #6
    ABX
    PULB

; Decrement the operator index.
    DECB
    BNE     .convert_operator_loop

; Skip over copying the algorithm, since it has already been converted.
    INX
    STX     <memcpy_ptr_dest

; Increment the read pointer by 43 bytes to skip over the unused operators.
; The read pointer is now at byte 111.
    LDX     <memcpy_ptr_src
    LDAB    #43
    ABX
    STX     <memcpy_ptr_src

; Copy the next 5 bytes.
    LDX     <memcpy_ptr_dest
    LDAB    #5
    JSR     memcpy_store_dest_and_copy_accb_bytes
    STX     <memcpy_ptr_dest

; Copy LFO Pitch Mod Sensitivity, and LFO wave.
; Shift right to remove the LFO sync setting.
    LDX     <memcpy_ptr_src
    LDD     0,x
    LSRA

; Ensure the key transpose setting is between 12, and 24.
    SUBB    #12
    BCC     .is_transpose_above_24

    CLRB

.is_transpose_above_24:
    CMPB    #24
    BCS     .store_transpose

    LDAA    #24

.store_transpose:
; Store the key transpose value.
; Clear the carry bit to indicate the patch has been successfully parsed.
    LDX     <memcpy_ptr_dest
    STD     0,x
    CLC

.exit:
    RTS


; =============================================================================
; Algorithm Conversion Table
; This table is used to convert algorithms between the DX9 format, and the
; original DX7 format used in SysEx transmission, and in patch activation.
; Each index contains the DX7/OPS algorithm corresponding to the index
; number's algorithm on the DX9.
; =============================================================================
table_algorithm_conversion:
    DC.B 0
    DC.B 13
    DC.B 7
    DC.B 6
    DC.B 4
    DC.B 21
    DC.B 30
    DC.B 31
