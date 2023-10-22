; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; patch/convert/from_dx9.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Converts a DX9 bulk packed patch (64 bytes) to the equivalent
; DX7 format (128 bytes)
;
; ARGUMENTS:
; Memory:
; * memcpy_ptr_src: The source patch in DX9 format.
; * memcpy_ptr_dest: The destination buffer to store the converted patch in.
;
; ==============================================================================

    .PROCESSOR HD6303

; =============================================================================
; PATCH_CONVERT_FROM_DX9_FORMAT
; =============================================================================
patch_convert_from_dx9_format:                  SUBROUTINE
; Convert each operator.
    LDAB    #4

.convert_operator_loop:
    PSHB

; Copy first 8 bytes (Operator EG).
    LDAB    #8
    JSR     memcpy

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
    BNE     .convert_operator_loop

; Clear operator 1/2 structures.
    LDAB    #2

.clear_operator_1_2_loop:
    PSHB


    LDAB    #$C
    CLRA

.clear_first_12_bytes_loop:
    STAA    0,x
    INX
    DECB
    BNE     .clear_first_12_bytes_loop

; Set the detune value to '7'.
    LDAA    #7
    STAA    0,x
    INX

; Clear the remaining fields by storing '0' in the fine/coarse freq,
; and setting the modulation sense, and output level to '0'.
    LDAB    #4
    CLRA

.clear_operator_fields_loop:
    STAA    0,x
    INX
    DECB
    BNE     .clear_operator_fields_loop

    PULB
    DECB
    BNE     .clear_operator_1_2_loop

; Reset the pitch EG rate.
    LDAB    #4
    LDAA    #$63
.reset_pitch_eg_rate_loop:
    STAA    0,x
    INX
    DECB
    BNE     .reset_pitch_eg_rate_loop

; Reset the pitch EG level.
    LDAB    #4
    LDAA    #$32
.reset_pitch_eg_level_loop:
    STAA    0,x
    INX
    DECB
    BNE     .reset_pitch_eg_level_loop

    STX     <memcpy_ptr_dest

    LDX     <memcpy_ptr_src
    LDAB    0,x
    INX
    STX     <memcpy_ptr_src

; Convert the algorithm from the DX9 equivalent.
    LDX     #table_algorithm_conversion
    ABX
    LDAA    0,x
    LDX     <memcpy_ptr_dest
    STAA    0,x

; Copy the Key Sync, and LFO settings.
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
    LDX     #str_dx9_patch_name
    JSR     lcd_strcpy

    RTS

str_dx9_patch_name:           DC "DX9 PATCH ", 0
