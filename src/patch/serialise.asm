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
; DESCRIPTION:
; This file contains the code for serialising a patch from the synth's edit
; buffer into non-volatile storage.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PATCH_SERIALISE
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
; Serialises a patch from the 'unpacked' edit buffer format to the 64 byte
; 'packed' format in the synth's internal memory.
;
; ARGUMENTS:
; Memory:
; * memcpy_ptr_src:  The source patch buffer pointer.
; * memcpy_ptr_dest: The destination patch buffer pointer.
;
; ==============================================================================
patch_serialise:                                SUBROUTINE
    LDAB    #4

.serialise_operator_loop:
    PSHB
    LDAB    #9
    JSR     memcpy_store_dest_and_copy_accb_bytes
    LDX     <memcpy_ptr_src
    LDAA    0,x
    INX
    ANDA    #%111
    LDAB    0,x
    INX
    STX     <memcpy_ptr_src
    ANDB    #%11
    ASLB
    ASLB
    ASLB
    ABA
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    LDAB    #4
    JSR     memcpy_store_dest_and_copy_accb_bytes
    PULB
    DECB
    BNE     .serialise_operator_loop
    LDAB    #1
    JSR     memcpy_store_dest_and_copy_accb_bytes
    LDX     <memcpy_ptr_src
    LDAA    0,x
    INX
    ANDA    #7
    LDAB    0,x
    INX
    STX     <memcpy_ptr_src
    ANDB    #1
    ASLB
    ASLB
    ASLB
    ABA
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    LDAB    #4
    JSR     memcpy_store_dest_and_copy_accb_bytes
    LDX     <memcpy_ptr_src
    LDAA    0,x
    INX
    ANDA    #7
    LDAB    0,x
    INX
    STX     <memcpy_ptr_src
    ANDB    #7
    ASLB
    ASLB
    ASLB
    ABA
    LDX     <memcpy_ptr_dest
    STAA    0,x
    INX
    LDAB    #1
    JSR     memcpy_store_dest_and_copy_accb_bytes
