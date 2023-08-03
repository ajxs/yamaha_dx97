; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; cpu.asm
; ==============================================================================
; DESCRIPTION:
; This file contains definitions related to the Hitachi HD63B03 CPU.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; Hitachi 6303 IO Port Registers.
; The addresses of the Hitachi 6303 CPU's internal IO port registers.
; ==============================================================================
io_port_1_dir:                      EQU 0
io_port_2_dir:                      EQU 1
io_port_1_data:                     EQU 2
io_port_2_data:                     EQU 3
timer_ctrl_status:                  EQU 8
free_running_counter:               EQU 9
output_compare:                     EQU $B
rate_mode_ctrl:                     EQU $10
sci_ctrl_status:                    EQU $11
sci_rx:                             EQU $12
sci_tx:                             EQU $13

TIMER_CTRL_EOCI                     EQU 1 << 3

RATE_MODE_CTRL_CC0                  EQU 1 << 2
RATE_MODE_CTRL_CC1                  EQU 1 << 3

SCI_CTRL_TE                         EQU 1 << 1
SCI_CTRL_TIE                        EQU 1 << 2
SCI_CTRL_RE                         EQU 1 << 3
SCI_CTRL_RIE                        EQU 1 << 4
SCI_CTRL_TDRE                       EQU 1 << 5
SCI_CTRL_ORFE                       EQU 1 << 6
