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
; test/volume.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; This file contains the 'Volume' diagnostic test.
; It resets all the synth's voice params, then plays an A4 note.
; ==============================================================================

    .PROCESSOR HD6303

test_volume:                                    SUBROUTINE
; The test 'sub stage' will have been initialised as 0xFF.
    TST     test_stage_sub
    BEQ     .exit

    LDX     #str_fragment_level
    JSR     test_lcd_set_write_pointer_to_position_7
    LDX     #str_test_adj_vr5
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update

    LDD     #$100
    STD     master_tune
    JSR     patch_init_edit_buffer
    JSR     patch_activate

    LDAB    #69
    JSR     voice_add

; Clear this flag so that the voice will only be added once.
    CLR     test_stage_sub

.exit:
    RTS
