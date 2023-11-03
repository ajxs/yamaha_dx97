; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; jumpoff.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the definition of the jumpoff subroutine.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; JUMPOFF
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDC32
; DESCRIPTION:
; This subroutine pops a reference to a jump-table from the subroutine's
; return pointer on the stack, then unconditionally 'jumps' to the relative
; offset in the entry associated with the number in ACCB.
; The table is stored in a two-byte format (Entry Number):(Relative Offset).
; Once the correct entry in the table has been found, the relative offset is
; added to the pointer in IX, and then jumped to.
; This is effectively a switch statement, with a relative jump.
;
; ARGUMENTS:
; Registers:
; * IX:   The 'return address' is popped off the stack into IX.
; * ACCB: The 'number' of the entry to jump to.
;
; ==============================================================================
jumpoff:                                        SUBROUTINE
    PULX

.test_table_entry_offset:
; If the current jump table entry number is '0', the end of the jump table has
; been reached, so exit.
    TST     1,x
    BEQ     .load_offset_and_jump

; If the value in the entry 'index' is higher than the value in ACCB being
; tested, jump to the relative offset contained in this entry.
    CMPB    1,x
    BCS     .load_offset_and_jump
    INX
    INX
    BRA     .test_table_entry_offset

.load_offset_and_jump:
; Load the relative offset in the current entry, add this to the return
; address popped from the stack, and jump to it.
    PSHB
    LDAB    0,x
    ABX
    PULB
    JMP     0,x


; ==============================================================================
; JUMPOFF_INDEXED_FROM_ACCA
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDC46
; DESCRIPTION:
; Jumps to a relative function offset loaded from a relative offset
; supplied in the ACCA register argument.
; The functionality is the same as the 'JUMPOFF_INDEXED' subroutine, except
; with the relative offset provided in the ACCA register.
;
; ARGUMENTS:
; Registers:
; * ACCA: The relative offset of the function offset from the calling
;         function's return address.
;
; ==============================================================================
jumpoff_indexed_from_acca:
    PULX
    PSHB
    TAB
    BRA     jumpoff_indexed_from_accb


; ==============================================================================
; JUMPOFF_INDEXED
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDC4B
; DESCRIPTION:
; Jumps to a relative function offset loaded from a relative offset
; supplied in the ACCB register argument.
; The return address of this subroutine is popped off the stack, and the
; relative offset provided is added to this address. From this address, the
; second relative offset is loaded, which is added to the previous address.
; This pointer is then jumped to.
;
; ARGUMENTS:
; Registers:
; * ACCB: The relative offset of the function offset from the calling
;         function's return address.
;
; ==============================================================================
jumpoff_indexed:
    PULX
    PSHB

jumpoff_indexed_from_accb:
    ABX
    LDAB    0,x
    ABX
    PULB
    JMP     0,x
