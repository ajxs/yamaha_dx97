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
; vectors.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the main hardware vector table.
; This hardware vector table is placed in a fixed position at the end of the
; firmware ROM. It contains the various interupt vectors used by the HD6303
; processor.
; ==============================================================================

    .PROCESSOR HD6303

vector_trap:                                    DC.W handler_reset
vector_sci:                                     DC.W handler_sci
vector_tmr_tof:                                 DC.W handler_reset
vector_tmr_ocf:                                 DC.W handler_ocf
vector_tmr_icf:                                 DC.W handler_reset
vector_irq:                                     DC.W handler_reset
vector_swi:                                     DC.W handler_reset
vector_nmi:                                     DC.W handler_reset
vector_reset:                                   DC.W handler_reset
