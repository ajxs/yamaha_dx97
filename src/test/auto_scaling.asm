; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; test/auto_scaling.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the auto-scaling diagnostic test.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; TEST_AUTO_SCALING
; ==============================================================================
; DESCRIPTION:
; This diagnostic test plays all notes in sequence.
; @TODO: I don't fully understand the significance of this test routine.
;
; ==============================================================================
test_auto_scaling:                              SUBROUTINE
; The test 'sub-stage' variable is reset to '0xFF' when the stage is
; incremented.
; This will cause the test stage to be initialised when this subroutine
; is initially called.
    LDAA    <test_stage_sub
    CMPA    #$FF
    BNE     .begin_note

; Initialise the patch edit buffer, and activate the loaded patch.
    JSR     patch_init_edit_buffer
    JSR     patch_activate
    CLR     test_stage_sub_2

    LDX     #str_auto_scal
    JSR     test_lcd_set_write_pointer_to_position_7
    JSR     lcd_update

    BRA     .decrement_sub_stage_and_delay

.begin_note:
; The test sub stage variable tracks how long to play each note.
; If it has reached zero, remove the voice, and begin again.
    LDAA    <test_stage_sub
    BEQ     .remove_voice

; This value was decremented at the start of the function.
; If it is one below this value, add the voice. Otherwise delay.
    CMPA    #$FE
    BNE     .decrement_sub_stage_and_delay

; If the sub stage 2 is below 61, branch.
; This effectively causes the note range to span from C2 (36) - C7 (96).
    LDAB    <test_stage_sub_2
    CMPB    #61
    BCS     .add_voice

; Reset the test sub stage.
    CLRB
    STAB    <test_stage_sub_2

.add_voice:
; Add '36' so the notes begin at C2.
    ADDB    #36
    JSR     voice_add

.decrement_sub_stage_and_delay:
    DEC     test_stage_sub

.initialise_delay:
    LDX     #200

.delay_loop:
    DEX
    BNE     .delay_loop

    RTS

.remove_voice:
    LDAB    <test_stage_sub_2
    ADDB    #36
    JSR     voice_remove
    LDAA    #$FE
    STAA    <test_stage_sub
    INC     test_stage_sub_2
    BRA     .initialise_delay
