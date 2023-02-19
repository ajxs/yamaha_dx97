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
; adc.asm
; ==============================================================================
; DESCRIPTION:
; This file contains all definitions, and code used to interact with the
; synth's analog-to-digital conversion chip.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; ADC Input Source Codes.
; These are the codes of the analog-to-digital converter input lines.
; ==============================================================================
ADC_SOURCE_PITCH_BEND:                          EQU 0
ADC_SOURCE_MOD_WHEEL:                           EQU 1
ADC_SOURCE_BREATH_CONTROLLER:                   EQU 2
ADC_SOURCE_SLIDER:                              EQU 3
ADC_SOURCE_BATTERY:                             EQU 4


; ==============================================================================
; ADC_SET_SOURCE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Sets the code of the next A/D input source to be read by the synth's A/D
; converter circuitry.
;
; ARGUMENTS:
; Registers:
; * ACCB: The next A/D converter source number.
;
; MEMORY MODIFIED:
; * adc_source
;
; ==============================================================================
adc_set_source:                                 SUBROUTINE
    STAB    <adc_source
    DELAY_SHORT
    STAB    <adc_source
    RTS


; ==============================================================================
; ADC_READ
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Reads data from the synth's analog/digital converter.
; This subroutine is part of the larger 'ADC_PROCESS' routine. The source from
; which the analog data is to be read is set in this parent subroutine.
; This subroutine will loop until the EOC pin on the ADC indicates that the
; data is ready to be read.
;
; RETURNS:
; * ACCA: The data read from the analog/digital converter.
;
; ==============================================================================
adc_read:                                       SUBROUTINE
    TIMD   #PORT_1_ADC_EOC, io_port_1_data

; Loop until the ADC's EOC line goes high, indicating that the analog data has
; been converted.
    BEQ     adc_read
    LDAA    <adc_data
    RTS


; ==============================================================================
; ADC_UPDATE_INPUT_SOURCE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; This subroutine updates a particular analog input source.
; It reads an individual input source, then tests to see how much the source
; has changed since the previous read. This subroutine then test whether the
; input value has only changed by 1 'unit' in either direction, if so this
; is not considered to be a proper update, and the subroutine will return
; as the value having been unchanged.
; This code here is likely similar to the analog data conversion code contained
; in the DX7's sub-CPU mask ROM.
;
; ARGUMENTS:
; Registers:
; * ACCB: The ADC source number to update.
;
; MEMORY MODIFIED:
; * analog_input_current
;
; REGISTERS MODIFIED:
; * ACCA, IX
;
; RETURNS:
; The carry flag will be set in the event that the ADC input is unchanged.
;
; ==============================================================================
adc_update_input_source:                        SUBROUTINE
; Read the analog input for the specified source.
    JSR     adc_read

; Compare the newly read analog data to the previously recorded data from
; this source.
    LDX     #analog_input_previous
    ABX
    CMPA    0,x
    BEQ     .exit_input_source_unchanged

; Increment this value to test whether it was 0xFF prior to incrementing.
; If it was, the zero flag will be set, and the branch will be taken.
; If the value is already at its maximum of 0xFF, don't bother testing
; whether the NEW value is 1 below the previous.
    INCA
    BEQ     .new_input_value_is_ff

; Test whether the NEW value is 1 below the OLD value.
; If so, consider it unchanged.
    CMPA    0,x
    BEQ     .exit_input_source_unchanged

.new_input_value_is_ff:
; Decrement the NEW value to return it to its original value, then compare it
; against 0.
; If the NEW value is 0, don't bother checking whether it is 1 above
; the OLD value.
    DECA
    BEQ     .exit_input_source_changed

; Test whether the NEW value is 1 above the OLD value.
; If so, consider it unchanged.
    DECA
    CMPA    0,x
    BEQ     .exit_input_source_unchanged

; Increment the NEW value again to return it to its original value.
    INCA

.exit_input_source_changed:
    STAA    0,x

; Logical shift right, then arithmetic shift left.
; This clears bit 0, and the carry flag.
    LSRA
    ASLA

; Since the OLD, and NEW ADC value arrays are next to one another, this
; store instruction updates the NEW value array.
    STAA    4,x
    RTS

.exit_input_source_unchanged:
    SEC
    RTS


; ==============================================================================
; ADC_PROCESS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Processes the synth's analog input.
; This subroutine will process the currently selected analog input source,
; sending a MIDI event as necessary if the input was updated.
; The input source is then decremented, so the next invocation will update
; the next input source.
; Note: This subroutine does not periodically scan the battery voltage.
;
; ARGUMENTS:
; Memory:
; * analog_input_source_next: The 'next' A/D input source to scan. This source
; number will be incremented by the operation.
;
; REGISTERS MODIFIED:
; * ACCB
;
; ==============================================================================
adc_process:                                    SUBROUTINE
; Update the specified 'next' input source.
    LDAB    analog_input_source_next
    JSR     adc_update_input_source

; The CPU carry-flag being set indicates that the value is unchanged.
    BCS     .update_next_input_source

; Test whether the input source number is zero, which would indicate that
; it is a pitch bend event.
; Otherwise, test if it is a slider event.
    TSTB
    BNE     .test_if_slider_event

; If this is a pitch-bend event, send a corresponding MIDI event.
    JSR     midi_tx_pitch_bend
    BRA     .reload_and_update_next_input_source

; This code matches the code in the DX7 v1.8 ROM at 0xEAE3.
.test_if_slider_event:
    CMPB    #ADC_SOURCE_SLIDER
    BNE     .send_midi_cc_message
    LDAB    #MIDI_CC_DATA_ENTRY

.send_midi_cc_message:
; If this is not a pitch-bend event, send a generic analog input event
; via MIDI.
    JSR     midi_tx_analog_input_event

.reload_and_update_next_input_source:
    LDAB    analog_input_source_next

.update_next_input_source:
; The source value cycles 3-2-1-0.
; This is facilitated by decrementing the value until it underflows,
; then masking it to 0b11.
    DECB
    ANDB    #%11
    STAB    analog_input_source_next
    JSR     adc_set_source

    RTS
