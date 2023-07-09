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
; voice/remove.asm
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; Removes a voice with the specified note.
; This routine is called by both MIDI, and keyboard events.
;
; ARGUMENTS:
; Registers:
; * ACCB: The MIDI note number of the note to remove.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
; ==============================================================================

    .PROCESSOR HD6303

voice_remove:                                   SUBROUTINE
    STAB    <note_number

    TBA
    LDAB    mono_poly
    BEQ     .synth_is_poly

    JMP     voice_remove_mono

.synth_is_poly:
    JMP     voice_remove_poly
