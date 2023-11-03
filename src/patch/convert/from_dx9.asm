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

; Copy first bytes 0-7 (Operator EG).
    LDAB    #8
    JSR     memcpy

    LDX     <memcpy_ptr_dest
; DX9 patches don't store a breakpoint, so clear this byte.
    CLR     0,x
; DX9 patches don't store a left level scaling depth, so clear this byte.
    CLR     1,x

    INX
    INX
    STX     <memcpy_ptr_dest

; Load Keyboard level scaling - byte 8.
    LDX     <memcpy_ptr_src
    LDAA    0,x
    INX
    STX     <memcpy_ptr_src

; Store the keyboard level scaling as the keyboard scaling right depth.
    LDX     <memcpy_ptr_dest
    STAA    0,x

; Clear the left/right scaling curves.
    CLR     1,x

    INX
    INX
    STX     <memcpy_ptr_dest

; Load Keyboard rate scaling / amp mod sens - byte 9.
    LDX     <memcpy_ptr_src
    LDAA    0,x
; Load Detune - byte 13.
    LDAB    4,x
    INX
    STX     <memcpy_ptr_src

; Combine the keyboard rate scaling, and detune bytes.
    PSHA
    ANDA    #%111

    ASLB
    ASLB
    ASLB
    ABA

    LDX     <memcpy_ptr_dest
    STAA    0,x

; Store the Amp Mod Sens byte. The DX9 doesn't store any key velocity
; sensitivity, so this field remains clear.
    PULA
    LSRA
    LSRA
    LSRA
    STAA    1,x

    INX
    INX
    STX     <memcpy_ptr_dest

; Output Level - byte 10.
    LDX     <memcpy_ptr_src
    LDAA    0,x
    INX
    STX     <memcpy_ptr_src

; Store output level - byte 14
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    STX     <memcpy_ptr_dest

    LDX     <memcpy_ptr_src
; Freq coarse - byte 11.
    LDAA    0,x
; Freq fine - byte 12.
    LDAB    1,x
    INX
    INX
; Add 1 to take into account the detune loaded earlier.
    INX
    STX     <memcpy_ptr_src

    LDX     <memcpy_ptr_dest
; Store freq coarse - byte 15.
; The DX9 doesn't store the oscillator mode, so this field is clear.
    ASLA
    STAA    0,x

; Store freq fine - byte 16.
    STAB    1,x

    INX
    INX
    STX     <memcpy_ptr_dest

    PULB
    DECB
    BNE     .convert_operator_loop

; Clear operator 1/2 structures.
    LDAB    #2

.clear_operator_1_2_loop:
    PSHB

; Set the operator EG rates, and levels to their maximum (99).
    LDAB    #7
.clear_operator_eg_loop:
    LDAA    #99
    STAA    0,x
    INX
    DECB
    BNE     .clear_operator_eg_loop

; Clear the final operator EG level.
    CLR     0,x
    INX

    LDAB    #4
.clear_scaling_bytes_loop:
    CLR     0,x
    INX
    DECB
    BNE     .clear_scaling_bytes_loop

; Set the detune value to '7', rate scaling to '0.
    LDAA    #$38
    STAA    0,x
    INX

; Clear the remaining fields by storing '0' in the fine/coarse freq,
; and setting the modulation sense, and output level to '0'.
    LDAB    #4
.clear_operator_fields_loop:
    CLR     0,x
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

; Copy in the dummy patch name.
    LDX     #str_dx9_patch_name
    JSR     lcd_strcpy

    RTS

str_dx9_patch_name:           DC "DX9 PATCH ", 0
