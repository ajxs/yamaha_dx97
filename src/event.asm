; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; event.asm
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xC410
; DESCRIPTION:
; This subroutine processes some of the synth's periodic events, as well as
; triggering the reloading of patch data to the voice chips based upon the
; value of an event dispatch flag variable
;
; MEMORY MODIFIED:
; * main_patch_event_flag: This is used as an event dispatch flag.
;    Depending on the value set, it will either cause the patch data to be
;    reloaded to the EGS/OPS, or the data reloaded and all active voices halted.
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

; 'main_patch_event_flag' is cleared by the main input handler, which is called
; earlier in the main loop than this routine.
; In the original DX9 firmware, the 'main_patch_event_flag' is not reset
; when the patch is reloaded.
; If this event processing routine is called multiple times, this flag should
; be cleared to ensure that the patch is not reloaded twice in one iteration
; of the main loop.
;    CLR     main_patch_event_flag

.send_remote_signal:
; I'm not sure why the tape remote signal is set here in the main loop.
; Is this because reading the ADC disrupts the status of the output lines?
    JSR     tape_remote_output_signal

    TST     midi_active_sensing_tx_pending_flag
    BNE     .exit

    JSR     midi_tx_active_sensing
    LDAA    #$FF
    STAA    <midi_active_sensing_tx_pending_flag

.exit:
    RTS
