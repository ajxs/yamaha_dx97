; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; input/front_panel.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the subroutines for reading input from the synth's front
; panel button interface.
;
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; INPUT_READ_FRONT_PANEL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDBD4
; DESCRIPTION:
; This subroutine reads the key/switch scan driver to get the state of the
; synth's front-panel switch input.
; This routine will return a value suitable for reading in the UI functions.
;
; Input line 0 covers the 'main' front-panel switches.
; Input line 1 covers the numeric front-panel switches 1 through 8.
; Input line 2 covers the numeric front-panel switches 9 though 16.
; Input line 3 covers the numeric front-panel switches 17 though 20, as well
; as the modulation pedal inputs: The Portamento, and Sustain pedals are
; mapped to bits 6, and 7 respectively.
;
; MEMORY MODIFIED:
; * key_switch_scan_input;
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCB: A numeric code indicating the last input source received.
;         0:    Slider
;         1:    "YES/INCREMENT"
;         2:    "NO/DECREMENT"
;         3:    "STORE"
;         4:    -Button Released-
;         5:    "FUNCTION"
;         6:    "EDIT"
;         7:    "MEMORY"
;         8-27: Buttons 1-20
;
; ==============================================================================
input_read_front_panel:                         SUBROUTINE
    LDX     #key_switch_scan_input

; Set the key/switch scan input driver source to its initial value of 0.
    LDAB    <io_port_1_data
    ANDB    #%11110000

.test_key_switch_input_source_loop:
    STAB    <io_port_1_data
    DELAY_SINGLE

; Read the new data for the selected source, and test whether the data has
; changed since the last read.
    LDAA    <key_switch_scan_driver_input
    CMPA    0,x

; Function returns from this call.
    BNE     input_read_front_panel_source_updated

    INX
    INCB

; If the input source is less than 4, loop.
    BITB    #%100
    BEQ     .test_key_switch_input_source_loop

    CLRB
    RTS


; ==============================================================================
; INPUT_READ_FRONT_PANEL_SOURCE_UPDATED
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; @PRIVATE
; DESCRIPTION:
; Handles the situation where a particular key/switch interface input line has
; been updated. This subroutine is responsible for creating the final result
; value corresponding to the input line.
;
; ARGUMENTS:
; Registers:
; * ACCA: The updated input value.
; * ACCB: The selected input line (non-masked).
; * IX:   A pointer to the previous input line value.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCB: The 'source' of the numeric button that is updated.
;         Refer to the documentation for the 'input_read_front_panel'
;         subroutine above.
;
; ==============================================================================
input_read_front_panel_source_updated:          SUBROUTINE
; Mask the peripheral source.
; Only input sources 0-3 are updated in this routine.
    ANDB    #%11

; If source is input line 1/2/3 - The 'numeric' front-panel switches.
    BNE     input_read_front_panel_numeric_switches

; If source is input line 0 - The 'main' front-panel switches.
    PSHA

; Test whether input line 0, bit 4 has changed.
; Branch if a button other than 'Store' was pushed.
    EORA    0,x
    ANDA    #%100
    PULA
    BEQ     input_read_front_panel_numeric_switches

; If the 'Store' button has changed.
; Store the updated value.
    STAA    0,x

; Check whether the store button is active.
; If so, return '3', else return the default of '4'.
    LDAB    #3
    BITA    #%100
    BNE     .exit_store_button_active

; If this point is reached, the store button is inactive.
    INCB

.exit_store_button_active:
    RTS


; ==============================================================================
; INPUT_READ_FRONT_PANEL_NUMERIC_SWITCHES
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xDC03
; @PRIVATE
; DESCRIPTION:
; Scans a particular input line to update the numeric front-panel switches.
;
; ARGUMENTS:
; Registers:
; * ACCA: The updated input value.
; * ACCB: The selected input line.
; * IX:   A pointer to the previous input line value.
;
; MEMORY MODIFIED:
; * key_switch_scan_input;
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; RETURNS:
; * ACCB: The 'source' of the numeric button that is updated.
;         Refer to the documentation for the 'input_read_front_panel'
;         subroutine above.
;
; ==============================================================================
input_read_front_panel_numeric_switches:        SUBROUTINE
; Shift the source left 3 times to create an offset so that the buttons can be
; grouped sequentially in groups of 8.
; i.e: Front-panel button 1 has value '8', and is read by input source 1.
; i.e: Front-panel button 20 has value '27', and is read by input source 3.
    ASLB
    ASLB
    ASLB
    PSHB

; Load previous value...
    LDAB    0,x

; Store updated value.
    STAA    0,x

; If the inverted old value, AND the new value is not equal to 0, it shows this
; switch has transitioned from OFF to ON.
    COMB
    ANDB    0,x
    BNE     .switch_transitioned_to_on

; If the switch is transitioning to an 'Off' state, increment the stack, and
; return to go back to the main loop.
    INS
    CLRB
    RTS

.switch_transitioned_to_on:
    TBA
    EORB    0,x
    STAB    0,x

; The following section performs the arithmetic necessary to transform the
; button input codes into sequential values.
; It's not particularly necessary to understand the logic here. The aim of this
; code is simply to transform the result read from the key/switch scan driver
; into the appropriate button code for the firmware.
    CLR     updated_input_source

; Rotate the updated source right, incrementing the result source byte so it
; becomes an offset from the previously created base.
.convert_source_to_offset_loop:
    INC     updated_input_source
    LSRA
    BCC     .convert_source_to_offset_loop

    PULB
    ADDB    updated_input_source
    CLRA

; Recreate the input line bitmask, and store it.
    SEC
.create_bitmask_loop:
    ROLA
    DEC     updated_input_source
    BNE     .create_bitmask_loop

    ORAA    0,x
    STAA    0,x

; Jumpoff based on the result byte stored in ACCB.
; The following 'jumpoff' subroutines are used to alter the result accordingly.
; These are arbitrary, and match the DX9 ROM.
    JSR     jumpoff

    DC.B .exit - *
    DC.B 4
    DC.B .exit_add_1 - *
    DC.B 5
    DC.B .exit - *
    DC.B 9
    DC.B .exit_subtract_1 - *
    DC.B 25
    DC.B .exit_clear_result - *
    DC.B 26
    DC.B .exit_subtract_2 - *
    DC.B 30
    DC.B .exit_clear_result - *
    DC.B 0

.exit_subtract_2:
    DECB

.exit_subtract_1:
    DECB

.exit:
    RTS

.exit_add_1:
    INCB
    RTS

.exit_clear_result:
    CLRB
    RTS
