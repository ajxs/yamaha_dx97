; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; memcpy.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the definitions for the 'memcpy' routine.
; This routine is used to copy blocks of memory from one location to another.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; MEMCPY_STORE_DEST_AND_COPY_ACCB_BYTES
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDC54
; DESCRIPTION:
; This subroutine is used throughout the DX9 firmware to set the destination,
; and then begin the copy procedure.
;
; ARGUMENTS:
; Registers:
; * ACCB: The number of bytes to copy.
; * IX:   The destination address.
;
; ==============================================================================
memcpy_store_dest_and_copy_accb_bytes:          SUBROUTINE
    STX     memcpy_ptr_dest
; Falls-through below.

; ==============================================================================
; MEMCPY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDC56
; DESCRIPTION:
; Copies ACCB bytes from the address in the source pointer to the address in
; the destination pointer.
;
; ARGUMENTS:
; Registers:
; * ACCB: The number of bytes to copy.
;
; MEMORY MODIFIED:
; * memcpy_ptr_src
; * memcpy_ptr_dest
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
memcpy:                                         SUBROUTINE
    LDX     memcpy_ptr_src
    LDAA    0,x
    INX
    STX     memcpy_ptr_src

    LDX     memcpy_ptr_dest
    STAA    0,x
    INX
    STX     memcpy_ptr_dest

    DECB
    BNE     memcpy

    RTS
