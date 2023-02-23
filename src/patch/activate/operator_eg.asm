; ==============================================================================
; PATCH_ACTIVATE_OPERATOR_EG_RATE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Loads and parses the current operator's EG rate values, then sends these
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

; Shift the operator number left twice to multiply by 4.
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
; @TAKEN_FROM_DX7_FIRMWARE
; @CHANGED_FOR_6_OP
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
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.operator_eg_level_pointer:                     EQU #temp_variables
.egs_register_offset:                           EQU #temp_variables + 2
.loop_counter:                                  EQU #temp_variables + 3
.parsed_operator_eg_levels:                     EQU #temp_variables + 4

; ==============================================================================
    LDX     #(patch_buffer_edit + PATCH_OP_EG_LEVEL_4)
    LDAB    <patch_activate_operator_offset
    ABX
    STX     .operator_eg_level_pointer

    LDAA    #4
    STAA    .loop_counter

; This loop retrieves the logarithmic values of the operator EG levels.
.parse_eg_level_loop:
; Load the EG level value into ACCB, and decrement the pointer to the
; operator EG level values in patch memory.
    LDX     .operator_eg_level_pointer
    LDAB    0,x
    DEX
    STX     .operator_eg_level_pointer

; Use the loaded operator EG level value as an index into the logarithmic
; table to get the full operator EG volume level.
    LDX     #table_curve_log
    ABX
    LDAA    0,x
    LSRA

; Use the loop index (0 .. 3) as an offset to determine where to store the
; parsed EG level value.
    LDAB    .loop_counter
    LDX     #.parsed_operator_eg_levels
    DECB
    ABX
    STAA    0,x

    DEC     .loop_counter
    BNE     .parse_eg_level_loop

; The following section writes the parsed values to the EGS chip.
    LDAA    patch_activate_operator_number
    LDAB    #4
    MUL
    STAB    .egs_register_offset

    LDAB    #4
    CLR     .loop_counter

; This loop Loads the parsed operator EG level values into the appropriate EGS
; envelope levels register.
.store_eg_level_loop:
    PSHB
    JSR     delay

; Load the parsed level value.
    LDX     #.parsed_operator_eg_levels
    LDAB    .loop_counter
    ABX
    LDAA    0,x

; Write the parsed value to the appropriate EGS register.
    LDX     #egs_operator_eg_level
    LDAB    .egs_register_offset
    ABX
    STAA    0,x

    INC     .egs_register_offset

    INC     .loop_counter
    PULB
    DECB
    BNE     .store_eg_level_loop

    RTS
