; ==============================================================================
; PATCH_ACTIVATE_OPERATOR_EG_RATE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
; Loads and parses the current operator's EG rate values, then loads these
; values to the appropriate registers in the EGS.
;
; ARGUMENTS:
; Memory:
; * patch_activate_operator_number: The operator number being activated.
; * patch_activate_operator_offset: The offset of the current operator in
;     patch memory.
;
; MEMORY MODIFIED:
; * copy_ptr_src
; * copy_ptr_dest
; * copy_counter
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
patch_activate_operator_eg_rate:                SUBROUTINE
    LDX     #patch_buffer_edit
    LDAB    <patch_activate_operator_offset
    ABX
    STX     <copy_ptr_src

; Set the destination pointer to the EGS EG rate register.
    LDX     #egs_operator_eg_rate

; Shift the operator number left twice to increment by 4.
    LDAB    <patch_activate_operator_number
    ASLB
    ASLB
    ABX
    STX     <copy_ptr_dest

; Store the loop counter.
    LDAB    #4
    STAB    <copy_counter

.activate_eg_rate_loop:
    LDX     <copy_ptr_src
    LDAA    0,x

; The EG rate value (stored in range 0 - 99) is multiplied by 164, and then
; (effectively) shifted >> 8. This quantises it to a value between 0-64.
    LDAB    #164
    MUL

; Increment the source, and destination pointers.
    INX
    STX     <copy_ptr_src
    LDX     <copy_ptr_dest
    STAA    0,x
    INX
    STX     <copy_ptr_dest

; Decrement the loop counter.
    DEC     copy_counter
    BNE     .activate_eg_rate_loop

    RTS


; ==============================================================================
; PATCH_ACTIVATE_OPERATOR_EG_LEVEL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; @TODO
;
; ARGUMENTS:
; Memory:
; * patch_activate_operator_number: The operator number being activated.
; * patch_activate_operator_offset: The offset of the current operator in
;     patch memory.
;
; MEMORY MODIFIED:
; * copy_ptr_src
; * copy_ptr_dest
; * copy_counter
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
patch_activate_operator_eg_level:               SUBROUTINE
    LDX     #(patch_buffer_edit + PATCH_DX9_OP_EG_LEVEL_1)
    LDAB    <patch_activate_operator_offset
    ABX
    STX     <copy_ptr_src
    LDX     #egs_operator_eg_level
    LDAB    <patch_activate_operator_number
    ASLB
    ASLB
    ABX
    STX     <copy_ptr_dest

    LDAB    #4
    STAB    <copy_counter

.activate_eg_level_loop:
    LDX     <copy_ptr_src
    LDAA    0,x
    LDAB    #$A5
    MUL
    ADDA    #$C0
    COMA
    INX
    STX     <copy_ptr_src
    LDX     <copy_ptr_dest
    STAA    0,x
    INX
    STX     <copy_ptr_dest
    DEC     copy_counter
    BNE     .activate_eg_level_loop

    RTS
