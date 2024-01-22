; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; ocf.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the OCF interrupt routine, and its various subroutines.
; ==============================================================================

    .PROCESSOR HD6303

; The period between the synth's periodic interrupts.
; This value is taken from the DX7 ROM.
SYSTEM_TICK_PERIOD:                             EQU 3140


; ==============================================================================
; ACTIVE_SENSING_TEST_FOR_TIMEOUT
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @CHANGED_FOR_6_OP
; @NEEDS_TESTING
; @PRIVATE
; DESCRIPTION:
; This subroutine is run as part of the periodic 'OCF' interrupt.
; When active sensing is enabled this function will count up to 255 invocations,
; and then reset the synth's voice parameters if an active sensing 'pulse' has
; not been received.
;
; MEMORY MODIFIED:
; * midi_active_sensing_rx_counter
; * midi_active_sensing_rx_counter_enabled
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
active_sensing_test_for_timeout:             SUBROUTINE
; Test whether the active sensing timeout is active. If not, exit.
    TST     midi_active_sensing_rx_counter_enabled
    BEQ     .exit

; Test whether the synth is currently receiving SysEx data. If so, exit.
    TST     midi_sysex_receive_data_active
    BNE     .exit

; If incrementing the active sensing timeout counter causes it to overflow,
; reset the active sensing flags, and all the synth's voice data.
    INC     midi_active_sensing_rx_counter
    BNE     .exit

    CLRA
    STAA    <midi_active_sensing_rx_counter_enabled
    STAA    <midi_active_sensing_rx_counter

    JSR     voice_reset

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
; * midi_active_sensing_tx_counter
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
active_sensing_update_tx_counter:               SUBROUTINE
    INC     midi_active_sensing_tx_counter

; Test whether this counter byte has reached 64.
; If so, clear.
    TIMD   #%1000000, midi_active_sensing_tx_counter
    BEQ     .exit

; This CLRA/STRA combination is used to save CPU cycles.
    CLRA
    STAA    <midi_active_sensing_tx_pending_flag
    STAA    <midi_active_sensing_tx_counter

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

; This CLRA/STRA combination is used to save CPU cycles.
    CLRA
    STAA    led_compare_mode_blink_counter
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
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Handles the OCF (Output Compare Counter) timer interrupt (IRQ2).
; This is where all of the synth's periodicly repeated functions are called.
;
; According to the schematics, the CPU is clocked with a 3.77MHz crystal.
; The HD63B03RP has built in divide-by-4 circuitry, so the synth's actual clock
; rate is 0.9425MHz.
; The DX7's OCF interrupt resets the 'Output Compare' register to '3140'.
; From this we can use the following formula to calculate the actual rate of
; the periodic interrupt:
; ((3.77 / 4) ⋅ 10^6) / 3140 = 300.15924Hz

; MEMORY MODIFIED:
; * pitch_eg_update_toggle
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
handler_ocf:                                    SUBROUTINE
    CLR     <timer_ctrl_status

; Clear the OCF interrupt flag by reading from the timer control register.
    LDAA    <timer_ctrl_status

; Reset the free running counter.
    LDX     #0
    STX     <free_running_counter

    LDX     #SYSTEM_TICK_PERIOD
    STX     <output_compare

; Clear the interrupt bit in the condition code register.
    CLI

    BSR     active_sensing_update_tx_counter
    BSR     active_sensing_test_for_timeout

    JSR     lfo_process
    JSR     mod_amp_update
    JSR     voice_update_sustain_status

; If there is received MIDI data pending processing skip processing the
; portamento, and pitch EG processing.
; This logic is taken from the DX7.
    TST     midi_rx_processing_pending
    BNE     .process_pitch_modulation

    JSR     portamento_process

; Toggle the flag to determine whether portamento, or pitch modulation are
; updated in this interrupt.
; Refer to documentation in the variable definition file `ram.asm`.
    COM     pitch_eg_update_toggle
    BNE     .process_pitch_modulation

    JSR     pitch_eg_process
    JSR     handler_ocf_compare_mode_led_blink

.process_pitch_modulation:
    JSR     pitch_bend_process
    JSR     mod_pitch_update

    LDAA    #TIMER_CTRL_EOCI
    STAA    <timer_ctrl_status

    RTI
