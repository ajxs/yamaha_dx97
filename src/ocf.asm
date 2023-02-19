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
; ocf.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the OCF interrupt routine, and its various subroutines.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; ACTIVE_SENSING_TEST_FOR_TIMEOUT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; This subroutine is run as part of the periodic 'OCF' interrupt.
; When active sensing is active this function will count up to 255 invocations,
; and then reset the synth's voice parameters if an active sensing 'pulse' has
; not been received.
;
; MEMORY MODIFIED:
; * active_sensing_rx_counter
; * active_sensing_rx_counter_enabled
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
active_sensing_test_for_timeout:             SUBROUTINE
; Test whether the active sensing timeout is active. If not, exit.
    TST     active_sensing_rx_counter_enabled
    BEQ     .exit

; Test whether the synth is currently receiving SysEx data. If so, exit.
    TST     midi_sysex_receive_data_active
    BNE     .exit

; Increment the timeout counter.
; If this counter reaches 255, clear the active sensing flags, and reset
; all the synth's voice data.
    INC     active_sensing_rx_counter
    LDAA    #254
    CMPA    <active_sensing_rx_counter
    BCC     .exit

    CLRA
    STAA    <active_sensing_rx_counter_enabled
    STAA    <active_sensing_rx_counter

    JSR     voice_reset_egs
    JSR     voice_reset_frequency_data
    CLR     active_voice_count

.exit:
    RTS


; ==============================================================================
; ACTIVE_SENSING_UPDATE_COUNTER
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; This subroutine is run as part of the periodic 'OCF' interrupt.
; Updates the active sensing transmit counter. If the counter reaches '64',
; then the flag to send an active sensing pulse is set.
;
; MEMORY MODIFIED:
; * active_sensing_tx_counter
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
active_sensing_update_counter:      SUBROUTINE
    INC     active_sensing_tx_counter

; Test whether this counter byte has reached 64.
; If so, clear.
    TIMD   #%1000000, active_sensing_tx_counter
    BEQ     .exit

    CLR     active_sensing_send_flag
    CLR     active_sensing_tx_counter

.exit:
    RTS


; ==============================================================================
; HANDLER_OCF_COMPARE_MODE_LED_BLINK
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Facilitates the 'blinking' of the LED panel when the synth is in 'compare
; patch' mode.
; This implements a counter, which toggles the LED blinking between the patch
; number and blank every 32 cycles.
;
; MEMORY MODIFIED:
; * led_compare_mode_blink_counter
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
handler_ocf_compare_mode_led_blink:             SUBROUTINE
    TST     patch_compare_mode_active
    BNE     .compare_mode_active

    CLR     led_compare_mode_blink_counter
    BRA     .exit

.compare_mode_active:
; If the compare mode is active, test whether the counter's low 5 bits are
; equal to zero. If not, increment the counter and exit.
    LDAA    led_compare_mode_blink_counter
    ANDA    #%11111
    BNE     .increment_counter

; If the counter's low bits are zero, test whether bit 5 is high.
; If so, show the patch number.
    LDAA    #%100000
    ANDA    led_compare_mode_blink_counter
    BNE     .print_patch_number

; Otherwise clear the LED display.
    LDD     #$FFFF
    BRA     .store_led_contents

.print_patch_number:
    LDD     led_contents

.store_led_contents:
    STD     <led_1

.increment_counter:
    INC     led_compare_mode_blink_counter

.exit:
    RTS


; ==============================================================================
; HANDLER_OCF
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Handles the OCF (Output Compare Counter) timer interrupt (IRQ2).
; This is where all of the synth's periodicly repeated functions are called.
;
; MEMORY MODIFIED:
; * portamento_update_toggle
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
handler_ocf:                                    SUBROUTINE
    CLR     timer_ctrl_status
    CLI

; Reset the free running counter.
    LDX     #0
    STX     <free_running_counter

; Toggle the flag to determine whether portamento, or pitch modulation are
; updated in this interrupt. Refer to documentation in the variable definition
; file `ram.asm`.
    COM     portamento_update_toggle

    JSR     active_sensing_update_counter
    JSR     active_sensing_test_for_timeout

    JSR     pitch_bend_process

    JSR     lfo_process
    JSR     mod_amp_update

    TST     portamento_update_toggle
    BPL     .process_portamento

    JSR     voice_update_sustain_status
    JSR     mod_pitch_update
    JSR     handler_ocf_compare_mode_led_blink
    BRA     .reset_timers_and_exit

.process_portamento:
    JSR     portamento_process

.reset_timers_and_exit:
; Clear the OCF interrupt flag by reading from the timer control register.
    LDAA    <timer_ctrl_status

    LDX     #2500
    STX     <output_compare

    LDAA    #TIMER_CTRL_EOCI1
    STAA    <timer_ctrl_status

    RTI
