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
; dev.asm
; ==============================================================================
; DESCRIPTION:
; Contains routines used for development purposes.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; Resets the main synth parameters.
; ==============================================================================
developer_reset_parameters:                     SUBROUTINE
; Reset master tune and performance parameters.
    LDAA    #64
    STAA    master_tune

    CLR     mono_poly

    CLR     patch_compare_mode_active

; Set the portamento time to instantaneous.
    LDAA    #0
    STAA    portamento_time

    LDAA    #0
    STAA    midi_channel_rx

; Reset the UI mode to 'Function'.
    CLR     ui_mode_memory_protect_state

    CLR     memory_protect

    LDAA    #1
    STAA    sys_info_avail

; Initialise the patch edit buffer.
    JSR     patch_init_edit_buffer
    JSR     patch_activate

    RTS
