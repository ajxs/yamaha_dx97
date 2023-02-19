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
; portamento.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the code, and definitions related to the synth's
; portamento functionality.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; PORTAMENTO_CONVERT_INCOMING_MIDI_VALUE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Converts an incoming portamento time value received via a MIDI control code
; message to the synth's internal format.
;
; ARGUMENTS:
; Registers:
; * ACCA: The value to scale.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; RETURNS:
; * ACCD: The scaled value.
;
; ==============================================================================
portamento_convert_incoming_midi_value:         SUBROUTINE
    LDAB    #200
    MUL
    RTS


; ==============================================================================
; PORTAMENTO_CALCULATE_RATE
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; Calculates the correct portamento frequency scale rate corresponding to a
; patch's portamento time.
; This value is then stored internally, and used in various voice-related
; calculations.
;
; MEMORY MODIFIED:
; * portamento_rate_scaled
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
portamento_calculate_rate:                      SUBROUTINE
    LDAB    portamento_time
    LDX     #table_porta_time
    ABX
    LDAB    0,x
    STAB    <portamento_rate_scaled

    RTS

table_porta_time:
    DC.B $FF, $FE, $F3, $E8, $D3    ; 0
    DC.B $CA, $C1, $B9, $B2, $AB    ; 5
    DC.B $A5, $9F, $99, $93, $8D    ; 10
    DC.B $87, $82, $7D, $78, $73    ; 15
    DC.B $6E, $6A, $66, $62, $5E    ; 20
    DC.B $5B, $58, $55, $52, $4F    ; 25
    DC.B $4C, $4A, $48, $46, $44    ; 30
    DC.B $42, $40, $3E, $3C, $3A    ; 35
    DC.B $38, $36, $35, $33, $31    ; 40
    DC.B $2F, $2E, $2C, $2A, $29    ; 45
    DC.B $27, $26, $25, $24, $22    ; 50
    DC.B $21, $1F, $1E, $1C, $1B    ; 55
    DC.B $1A, $19, $18, $17, $16    ; 60
    DC.B $15, $14, $13, $12, $12    ; 65
    DC.B $11, $10, $10, $F, $E      ; 70
    DC.B $E, $D, $D, $C, $C, $B     ; 75
    DC.B $B, $A, $A, 9, 9, 8        ; 81
    DC.B 8, 7, 7, 6, 6, 5, 5        ; 87
    DC.B 4, 4, 3, 3, 2, 1           ; 94


; ==============================================================================
; PORTAMENTO_PROCESS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE
; DESCRIPTION:
; This subroutine is where the current portamento frequency for each of the
; synth's voices is updated, and loaded to the EGS chip.
; This is called periodically as part of the OCF interrupt routine.
;
; MEMORY MODIFIED:
; * portamento_base_frequency
; * portamento_final_increment
; * porta_process_loop_index
; * porta_process_target_frequency
; * voice_frequency_target
; * voice_frequency_current
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
portamento_process:                             SUBROUTINE
; Calculate the base logarithmic frequency that will be added to the note.
    GET_VOICE_BASE_FREQUENCY
    STD     <portamento_base_frequency

; This is the final entry in the voice target frequency array.
    LDX     #(voice_frequency_target + 30)
    LDAB    #15
    STAB    <porta_process_loop_index

; If the synth is poly, test whether the pedal is active.
    TST     mono_poly
    BEQ     .is_porta_pedal_active

; If the portamento mode is 'Fingered', don't test whether the portamento
; pedal is active. Process all the voices regardless.
    TST     portamento_mode
    BNE     .loop_start

.is_porta_pedal_active:
    TIMD   #PEDAL_INPUT_PORTA, pedal_status_current
    BEQ     .no_portamento_loop

.loop_start:
    LDD     0,x
    STD     <porta_process_target_frequency

; Subtract the _current_ frequency from the target.
    SUBD    32,x
; If there is no difference between the target, and current frequencies, store
; the target to the EGS.
    BEQ     .store_target_frequency

; Test if the target frequency is higher than the current.
    BPL     .target_frequency_higher_than_current

; If the portamento rate is instantaneous, don't do any processing.
    LDAB    <portamento_rate_scaled
    CMPB    #$FF
    BEQ     .store_target_frequency

; Scale the MSB of the frequency difference by the portamento increment.
; The total calculalation is:
; Increment := Portamento_Rate * (((current_freq - target_freq) >> 10) + 1)
    NEGA
    LSRA
    LSRA
    INCA
    MUL
    STD     <portamento_final_increment

; Load the current frequency, and subtract the calculated decrement.
    LDD     32,x
    SUBD    <portamento_final_increment
; If this value underflows and sets the carry bit, it means the target
; frequency has been reached. In that case, store the target frequency instead.
    XGDX
    CPX     <porta_process_target_frequency
    XGDX
    BCC     .write_frequency_to_egs

    BRA     .store_target_frequency

.target_frequency_higher_than_current:
; If the portamento rate is instantaneous, don't do any processing.
    LDAB    <portamento_rate_scaled
    CMPB    #$FF
    BEQ     .store_target_frequency

; Scale the MSB of the frequency difference by the portamento increment.
; See similar comment earlier in the file for more information.
    LSRA
    LSRA
    INCA
    MUL
    ADDD    32,x
; If this value overflows and sets the carry bit, it means the target
; frequency has been reached. In that case, store the target frequency instead.
    XGDX
    CPX     <porta_process_target_frequency
    XGDX
    BCS     .write_frequency_to_egs

.store_target_frequency:
    LDD     <porta_process_target_frequency

.write_frequency_to_egs:
; Add the base logarithmic frequency calculated at the start of the routine.
    STD     32,x
    ADDD    <portamento_base_frequency

; Write the portamento frequency to the EGS voice frequency register.
    STAA    64,x
    STAB    65,x

    DEX
    DEX
    DEC     porta_process_loop_index
    BPL     .loop_start

    RTS

.no_portamento_loop:
; Set each voice's current frequency to the target, and write this value to
; the EGS voice frequency register.
    LDD     0,x
    STD     32,x
    ADDD    <portamento_base_frequency

; Write the portamento frequency to the EGS voice frequency register.
    STAA    64,x
    STAB    65,x

    DEX
    DEX
    DEC     porta_process_loop_index
    BPL     .no_portamento_loop

    RTS
