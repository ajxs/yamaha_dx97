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
; test/eg_op.asm
; ==============================================================================
; DESCRIPTION:
; Contains the diagnostic routine used to test the synth's EGS/OPS chips.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_EG_OP
; ==============================================================================
; @NEEDS_TO_BE_REMADE_FOR_6_OP
; DESCRIPTION:
; This diagnostic routine tests the synth's EGS, and OP chips.
; It does so by playing notes from several preset test patches.
;
; ==============================================================================
test_eg_op:                                     SUBROUTINE
    LDAB    <test_stage_sub
    JSR     jumpoff

    DC.B test_eg_op_wait_to_start - *
    DC.B 1
    DC.B test_eg_op_load_next_test_stage - *
    DC.B 2
    DC.B test_eg_op_add_voice - *
    DC.B 3
    DC.B test_eg_op_prompt_for_advance - *
    DC.B $67
    DC.B test_eg_op_remove_voice - *
    DC.B $68
    DC.B test_eg_op_prompt_for_advance - *
    DC.B $CC
    DC.B test_eg_op_repeat - *
    DC.B $FF
    DC.B test_eg_op_init - *
    DC.B 0


; ==============================================================================
; TEST_EG_OP_INIT
; ==============================================================================
; DESCRIPTION:
; Initialises the test stage, and prints the test stage name.
;
; ==============================================================================
test_eg_op_init:                                SUBROUTINE
; Print the test name.
    LDX     #str_eg_op
    JSR     test_lcd_set_write_pointer_to_position_7
    LDX     #str_push_1_button
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update

; Test stage sub 2 is the 'type' of EGS/OPS test.
    CLR     test_stage_sub_2

    CLR     test_stage_sub

    RTS


; ==============================================================================
; TEST_EG_OP_WAIT_TO_START
; ==============================================================================
; DESCRIPTION:
; Scans for front panel input to test whether the '1' button was pressed.
; This initiates the test routine.
; Until this is pressed, the diagnostic routine will 'wait' by re-entering this
; subroutine repeatedly.
;
; ==============================================================================
test_eg_op_wait_to_start:                       SUBROUTINE
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_1
    BNE     .exit

    INC     test_stage_sub

.exit:
    RTS


; ==============================================================================
; TEST_EG_OP_LOAD_NEXT_TEST_STAGE
; ==============================================================================
; DESCRIPTION:
; Loads the next test 'sub-stage'.
; This prints the test stage name, and loads the associated patch.
;
; ==============================================================================
test_eg_op_load_next_test_stage:                SUBROUTINE
    JSR     lcd_clear_line_2

; Load the test stage string offset.
    LDX     #table_test_eg_op_string_offsets
    LDAB    <test_stage_sub_2
    ABX
    LDAB    0,x
    ABX

; Print the test stage string.
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    JSR     voice_reset_egs
    JSR     voice_reset_frequency_data

; Load the test patch.
    LDX     #test_eg_op_patch_buffer
    LDAB    <test_stage_sub_2
    LDAA    #64
    MUL
    ABX
    JSR     patch_deserialise_to_edit_from_ptr_and_reload
    JSR     patch_activate

; Increment the test sub-stage.
    LDAA    <test_stage_sub_2
    INCA
    CMPA    #3
    BCS     .store_sub_stage

; If the sub-stage has reached 3, reset.
    CLRA

.store_sub_stage:
    STAA    <test_stage_sub_2
    INC     test_stage_sub

    RTS


; ==============================================================================
; TEST_EG_OP_ADD_VOICE
; ==============================================================================
; DESCRIPTION:
; Initiates playing of the test note.
;
; ==============================================================================
test_eg_op_add_voice:                           SUBROUTINE
    LDAB    #69
    JSR     voice_add
    INC     test_stage_sub

    RTS


; ==============================================================================
; TEST_EG_OP_PROMPT_FOR_ADVANCE
; ==============================================================================
; DESCRIPTION:
; Scans for front panel input to test whether the '1' button was pressed.
; This resets the test back to the start, and initiates the loading of the next
; test stage.
; This test subroutine will be loaded continuously until the test 'stage' will
; have advanced enough to proceed.
;
; ==============================================================================
test_eg_op_prompt_for_advance:                  SUBROUTINE
; Wait for button 1 to be pushed.
; If any other button pushed, reset the test stage?
    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_1
    BNE     .delay_and_advance_stage

; If the '1' button is pressed, reset the test back to the first stage.
    LDAA    #1
    STAA    <test_stage_sub
    BRA     .exit

.delay_and_advance_stage:
    LDX     #1000

.delay_loop:
    DEX
    BNE     .delay_loop

    INC     test_stage_sub

.exit:
    RTS


; ==============================================================================
; TEST_EG_OP_REMOVE_VOICE
; ==============================================================================
; DESCRIPTION:
; Removes the test voice/
;
; ==============================================================================
test_eg_op_remove_voice:                        SUBROUTINE
    LDAB    #69
    JSR     voice_remove
    INC     test_stage_sub

    RTS


; ==============================================================================
; TEST_EG_OP_REPEAT
; ==============================================================================
; DESCRIPTION:
; Repeats the diagnostic routine by resetting the test sub-stage.
; This causes a new note to be played.
;
; ==============================================================================
test_eg_op_repeat:                              SUBROUTINE
    LDAA    #2
    STAA    <test_stage_sub

    RTS


; ==============================================================================
; The patches used in the EG/OP test stages.
; ==============================================================================
test_eg_op_patch_buffer:
; Envelope Test Patch.
    DC.B $63, $63, $63, $63, $63    ; 0
    DC.B $63, $63, 0, 0, 0, 0       ; 5
    DC.B 1, 0, 7, $32, $63, $63     ; 11
    DC.B $38, $63, $63, $63, 0      ; 17
    DC.B 0, 0, $63, 1, 0, 7, $32    ; 22
    DC.B $63, $63, $38, $63, $63    ; 29
    DC.B $63, 0, 0, 0, $63, 1       ; 34
    DC.B 0, 7, $32, $63, $63        ; 40
    DC.B $38, $63, $63, $63, 0      ; 45
    DC.B 0, 0, $63, 1, 0, 7, 7      ; 50
    DC.B 8, 0, 0, 0, 0, 0, $C       ; 57

; Modulation Test Patch.
    DC.B $63, $63, $63, $63, $63    ; 64
    DC.B $63, $63, 0, 0, 0, 0       ; 69
    DC.B 1, 0, 7, $63, $63, $63     ; 75
    DC.B $63, $63, $63, $63, 0      ; 81
    DC.B 0, 0, 0, 1, 0, 7, $43      ; 86
    DC.B $32, $20, $32, $4B, $4F    ; 93
    DC.B $59, 0, 0, 0, $5B, 1       ; 98
    DC.B 0, 7, $63, $63, $63        ; 104
    DC.B $31, $63, $63, $63, 0      ; 109
    DC.B 0, 0, $63, 1, 0, 7, 0      ; 114
    DC.B 8, 0, 0, 0, 0, 0, $C       ; 121

; Feedback Test Patch.
    DC.B $63, $63, $63, $63, $63    ; 128
    DC.B $63, $63, 0, 0, 0, 0       ; 133
    DC.B 1, 0, 7, $63, $63, $63     ; 139
    DC.B $63, $63, $63, $63, 0      ; 145
    DC.B 0, 0, 0, 1, 0, 7, $4B      ; 150
    DC.B $36, $23, 0, $1B, $39      ; 157
    DC.B $63, 0, 0, 0, $44, 1       ; 162
    DC.B 0, 7, $63, $63, $63        ; 168
    DC.B $37, $63, $63, $63, 0      ; 173
    DC.B 0, 0, $63, 1, 0, 7, 2      ; 178
    DC.B $F, 0, 0, 0, 0, 0, $C      ; 185
