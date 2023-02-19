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
; DESCRIPTION:
; This file contains the code for deserialising a patch from storage into the
; synth's edit buffer.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_DESERIALISE
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
; Deserialises a patch from the 'packed' format used to store patches in the
; synth's internal to the 'unpacked' format in the synth's edit buffer.
;
; ARGUMENTS:
; Memory:
; * memcpy_ptr_src:  The source patch buffer pointer.
; * memcpy_ptr_dest: The destination patch buffer pointer.
;
; ==============================================================================
patch_deserialise:                              SUBROUTINE
    LDAB    #4

.deserialise_operator_loop:
    PSHB
    LDAB    #9
    JSR     memcpy_store_dest_and_copy_accb_bytes
    LDX     <memcpy_ptr_src
    LDAA    0,x
    ANDA    #7
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    STX     <memcpy_ptr_dest
    LDX     <memcpy_ptr_src
    LDAA    0,x
    INX
    STX     <memcpy_ptr_src
    LSRA
    LSRA
    LSRA
    ANDA    #3
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    LDAB    #4
    JSR     memcpy_store_dest_and_copy_accb_bytes
    PULB
    DECB
    BNE     .deserialise_operator_loop

    LDAB    #1
    JSR     memcpy_store_dest_and_copy_accb_bytes
    LDX     <memcpy_ptr_src
    LDAA    0,x
    ANDA    #7
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    STX     <memcpy_ptr_dest
    LDX     <memcpy_ptr_src
    LDAA    0,x
    INX
    STX     <memcpy_ptr_src
    LSRA
    LSRA
    LSRA
    ANDA    #1
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    LDAB    #4
    JSR     memcpy_store_dest_and_copy_accb_bytes
    LDX     <memcpy_ptr_src
    LDAA    0,x
    ANDA    #7
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    STX     <memcpy_ptr_dest
    LDX     <memcpy_ptr_src
    LDAA    0,x
    INX
    STX     <memcpy_ptr_src
    LSRA
    LSRA
    LSRA
    ANDA    #7
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    LDAB    #1
    JMP     memcpy_store_dest_and_copy_accb_bytes
