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
; delay.asm
; ==============================================================================
; DESCRIPTION:
; This file contains all subroutines for creating arbitrary delays.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; DELAY
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Creates an artificial 'delay' in the system by pushing, and pulling from the
; stack.
; This whole sequence takes 14 CPU cycles in total. Four each for the pushes,
; three for the pulls.
;
; ==============================================================================
delay:                                          SUBROUTINE
    PSHA
    PULA
    PSHA
    PULA
    RTS
