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
; event.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; This subroutine processes some of the synth's periodic events, as well as
; triggering the reloading of patch data to the voice chips based upon the
; value of an event dispatch flag variable
;
; MEMORY USED:
; * main_patch_event_flag: This is used as an event dispatch flag.
;           Depending on the value set, it will either cause the patch data
;           to be reloaded to the EGS/OPS, or the data reloaded and all
;           active voices halted.
;
; ==============================================================================

    .PROCESSOR HD6303

EVENT_RELOAD_PATCH:                             EQU 1
EVENT_HALT_VOICES_RELOAD_PATCH:                 EQU 2

; ==============================================================================
; MAIN_PROCESS_EVENTS
; ==============================================================================
main_process_events:                            SUBROUTINE
    LDAA    main_patch_event_flag
    BEQ     .send_remote_signal

    CMPA    #EVENT_RELOAD_PATCH
    BEQ     .reload_patch

    JSR     voice_reset_egs

.reload_patch:
    JSR     patch_activate

; In the original DX9 firmware, this was not reset when the patch was reloaded.
; This line prevents activation happening twice in the main loop.
    CLR     main_patch_event_flag

.send_remote_signal:
; @TODO: Why is this done here?
; Possibly this is ideally performed a certain number of cycles _before_ the
; MIDI processing occurs?
    JSR     tape_remote_output_signal

    TST     midi_active_sensing_send_flag
    BNE     .exit

    JSR     midi_tx_active_sensing
    LDAA    #$FF
    STAA    <midi_active_sensing_send_flag

.exit:
    RTS
