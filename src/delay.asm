; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
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
