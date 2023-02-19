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
; reset.asm
; ==============================================================================
; DESCRIPTION:
; This file contains functionality related to the synth's main reset handler.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; HANDLER_RESET_INITIALISE_UI_VARIABLES
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Reset the UI variables to a known-state on system reset.
;
; MEMORY MODIFIED:
; * key_transpose_set_mode_active
; * memory_protect
; * operator_selected_dest
; * ui_mode_memory_protect_state
; * main_patch_event_flag
; * ui_btn_function_6_sub_function
; * ui_btn_function_7_sub_function
; * ui_btn_function_19_sub_function
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
handler_reset_initialise_ui_variables:          SUBROUTINE
; Clear the 'Key Transpose' mode flag.
    CLR     key_transpose_set_mode_active

; Sets the internal patch memory in a protected state.
    LDAA    #1
    STAA    memory_protect

; Clear the UI selected operator variable.
    LDAA    #$FF
    STAA    operator_selected_dest

; Reset the memory protection flags stored in the UI state variable.
    LDAA    ui_mode_memory_protect_state
    ANDA    #%11
    STAA    ui_mode_memory_protect_state

    CLR     sys_info_avail

; Clear these 'alternate button function' variables.
; These are used to track the function of individual 'multi-function'
; buttons that change UI function over sequential presses.
; This clears the selected UI function, since this is in non-volatile RAM.
    CLR     ui_btn_function_6_sub_function
    CLR     ui_btn_function_7_sub_function
    CLR     ui_btn_function_19_sub_function

; If the synth has been reset after the diagnostic test routines have
; been performed, reload the currently selected patch.
    LDAA    ui_btn_numeric_last_pressed
    CMPA    #BUTTON_TEST_ENTRY_COMBO
    BNE     .exit

    JSR     ui_test_entry_reload_patch_and_exit

.exit:
    RTS


; ==============================================================================
; HANDLER_RESET_WELCOME_MESSAGE_DELAY
; ==============================================================================
; @PRIVATE
; DESCRIPTION:
; Creates a suitable delay for displaying the welcome message.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
handler_reset_welcome_message_delay:            SUBROUTINE
    LDAA    #3
.welcome_message_delay_loop:
    DELAY_LONG

    DECA
    BNE     .welcome_message_delay_loop

    RTS


; ==============================================================================
; HANDLER_RESET_PRINT_WELCOME_MESSAGE
; ==============================================================================
; @PRIVATE
; DESCRIPTION:
; Prints the welcome message shown when the device is powered up.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
handler_reset_print_welcome_message:            SUBROUTINE
; Directly copy the welcome message to the LCD buffer.
    LDX     #str_welcome_message
    STX     <memcpy_ptr_src
    LDX     #lcd_buffer_next
    STX     <memcpy_ptr_dest
    LDAB    #32
    JSR     memcpy

    JSR     lcd_update

; Print 'AJ' to the LED display.
    LDAA    #%10001000
    LDAB    #%11100001
    STAA    led_1
    STAB    led_2
    BSR     handler_reset_welcome_message_delay

; Print 'XS' to LEDs.
    LDAA    #%10001001
    LDAB    #%10010010
    STAA    led_1
    STAB    led_2
    BSR     handler_reset_welcome_message_delay

; Clear the LCD.
    JSR     lcd_clear
    JSR     lcd_update

; Clear the LEDs.
    LDAA    #$FF
    STAA    led_1
    STAA    led_2

    RTS


; ==============================================================================
; HANDLER_RESET
; ==============================================================================
; DESCRIPTION:
; Initialises all of the synthesiser's subsystems.
; This routine clears the volatile internal memory, and initialises all of the
; synth's peripheral devices.
;
; MEMORY MODIFIED:
; * midi_channel_rx
; * midi_channel_tx
; * analog_input_battery_voltage
; * analog_input_previous_slider
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
handler_reset:                                  SUBROUTINE
    CLRA
    STAA    <timer_ctrl_status
    LDS     #stack_top

; Set Port 1 direction.
; A '1' bit specifies an output line.
; In this case, the input lines are the cassette interface input, and the
; ADC EOC line.
    LDAA    #%1101111
    STAA    <io_port_1_dir

; Set Port 2 direction.
    CLR     io_port_2_dir

; Clear both LEDs.
    LDAA    #$FF
    STAA    led_1
    STAA    led_2

; Clear internal RAM.
; Unlike the external RAM, the processor's internal RAM is not powered, and
; thus will not persist when power cycled. In order to ensure a stable
; operating state, this memory is initialised to zero on reset.
    CLEAR_BUFFER internal_ram_start, 128

; Store 0xFF in the note number variable to indicate a 'NULL' value.
; This will be intepreted as a no-operation by the note handler in the main
; event loop.
    LDAA    #$FF
    STAA    <note_number
    JSR     midi_init

    JSR     lcd_init

; Print the synth's Welcome Message to the LCD.
    JSR     handler_reset_print_welcome_message


; Initialise the main system, and user-interface variables.
; This will set the event dispatch flag to reload the patch data to the EGS
; chip, which will be performed in the subsequent subroutine call.
    JSR     handler_reset_initialise_ui_variables

; Ensure that the MIDI RX channel is valid.
; This checks that '16' is higher than the MIDI channel.
    LDAA    #16
    CMPA    midi_channel_rx
    BHI     .reset_midi_channel_tx

    CLR     midi_channel_rx

.reset_midi_channel_tx:
    CLR     midi_channel_tx

; Read, and store the battery voltage.
; This is the only point that the battery voltage is actually read.
    LDAA    <adc_data
    DELAY_SINGLE

    LDAB    #ADC_SOURCE_BATTERY
    JSR     adc_set_source
    JSR     adc_read
    STAA    analog_input_battery_voltage

; If the battery voltage value reads less than 110, print the battery warning
; message. Otherwise print the menu.
    CMPA    #110
    BCC     .battery_voltage_test_successful

    LDX     #str_battery_warning
    JSR     lcd_strcpy
    JSR     lcd_update
    BRA     .reset_voice_data

.battery_voltage_test_successful:
    JSR     ui_print_update_led_and_menu

.reset_voice_data:
; Reset the EGS, and the internal voice frequency buffers.
    JSR     voice_reset_egs
    JSR     voice_reset_frequency_data

; Reload of all patch data to the EGS chip.
; This is necessary here since no data is currently loaded.
    JSR     patch_activate

; Read the slider input, and store this as the 'initial' previous slider
; input reading. This is necessary so that the next analog input update
; does not immediately trigger a slider input event.
; This would occur because the update compares the current reading against
; the previous to test for a change.
    LDAB    #ADC_SOURCE_SLIDER
    JSR     adc_set_source
    JSR     adc_read
    STAA    analog_input_previous_slider

; Reset the free-running, and output compare counters.
    LDD     #0
    STD     <free_running_counter
    LDD     #2500
    STD     <output_compare

    JSR     developer_reset_parameters

; Enable the output-compare interrupt, and clear condition flags.
    LDAA    #TIMER_CTRL_EOCI1
    STAA    <timer_ctrl_status
    CLRA
    TAP
; Falls-through below to main loop.

; ==============================================================================
; MAIN_LOOP
; ==============================================================================
; DESCRIPTION:
; Synth firmware executive main loop.
; This is where the bulk of the synth's functionaly is implemented.
; The keyboard, and pedal input are first scanned here. Unlike other Yamaha
; FM synthesisers, the 'Note On', and 'Note Off' functionaliy is implemented
; via a flag set in the keyboard scan routine. This flag records whether a
; key on, or off event has occurred, and which key triggered it. After the
; input scan routine is completed, the 'Note On', and 'Note Off' handlers are
; invoked. which check this flag, and action key events accordingly.
;
; ==============================================================================
main_loop:
    JSR     pedals_update
    JSR     keyboard_scan
    JSR     keyboard_event_handler
    JSR     adc_process
    JSR     main_input_handler
    JSR     main_process_events
    JSR     midi_process_incoming_data
    JSR     main_process_events
; The exact reason for this 'NOP' instruction will never be known, however it
; was likely put here to slightly decrease the polling rate of the synth's
; various peripherals.
    NOP
    BRA     main_loop
