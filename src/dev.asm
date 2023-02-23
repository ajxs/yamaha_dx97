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
    LDD     #$100
    STD     master_tune

    LDAA    #0
    STAA    midi_channel_rx

; Reset the UI mode to 'Function'.
    CLR     ui_mode_memory_protect_state

    CLR     memory_protect

    LDAA    #1
    STAA    sys_info_avail

    LDAA    #$80
    STAA    patch_index_current

    CLR     patch_compare_mode_active

; Reset performance parameters.
    CLR     mono_poly

; Set the portamento time to instantaneous.
; The internal scaled rate will be calculated when the patch is 'activated'.
    CLR     portamento_time
    CLR     portamento_mode
    CLR     portamento_glissando_enabled

    CLR     mod_wheel_range
    CLR     mod_wheel_pitch
    CLR     mod_wheel_amp
    CLR     mod_wheel_eg_bias

    CLR     breath_control_range
    CLR     breath_control_pitch
    CLR     breath_control_amp
    CLR     breath_control_eg_bias

; Initialise the patch edit buffer.
    JSR     patch_init_edit_buffer
    JSR     patch_activate

    RTS
