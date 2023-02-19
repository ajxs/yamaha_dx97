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
; voice/add.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the subroutines used to add a voice with a new note, in
; response to an incoming 'Note On' MIDI message, or a key being pressed.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; VOICE_ADD
; ==============================================================================
; DESCRIPTION:
; This subroutine is the main entry point to 'adding' a new voice event.
; It is effectively the entry point to actually playing a note over one of the
; synth's voices. This function branches to more specific functions, depending
; on whether the synth is in monophonic, or polyphonic mode.
; This subroutine is where a note keycode is converted to the EGS chip's
; internal representation of pitch. The various voice buffers related to pitch
; transitions are set, and reset here.
;
; ARGUMENTS:
; Registers:
; * ACCB: The note number to add to the new voice.
;
; ==============================================================================
voice_add:                                      SUBROUTINE
; Add the current transpose value, and subtract 24,  to take into account
; that it has a -24 - 24 range.
    ADDB    patch_edit_key_transpose
    SUBB    #24

; If the result is > 127, clamp at 127.
    CMPB    #127
    BLS     .get_note_frequency

    LDAB    #127

.get_note_frequency:
    JSR     voice_convert_midi_note_to_log_freq

    LDAB    mono_poly
    BNE     .synth_in_mono_mode

    JMP     voice_add_poly

.synth_in_mono_mode:
    JMP     voice_add_mono


; ==============================================================================
; VOICE_ADD_OPERATOR_LEVEL_VOICE_FREQUENCY
; ==============================================================================
; @REMADE_FOR_6_OP
; DESCRIPTION:
; Loads the operator scaling, and frequency for a new note to the EGS chip.
; Tests whether the current portamento settings mean the new note frequency
; should not be loaded immediately.
;
; ARGUMENTS:
; Registers:
; * IX:   The frequency for the new note.
; * ACCA: The zero-indexed voice number.
;
; ==============================================================================
voice_add_operator_level_voice_frequency:       SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.new_voice_frequency:                           EQU #temp_variables
.new_voice_number:                              EQU #(temp_variables + 2)
.operator_index:                                EQU #(temp_variables + 3)
.operator_velocity_sens_pointer                 EQU #(temp_variables + 4)
.operator_volume_pointer                        EQU #(temp_variables + 6)
.operator_status                                EQU #(temp_variables + 8)
; ==============================================================================
    STX     .new_voice_frequency
    STAA    .new_voice_number

; Setup pointers.
    LDX     #patch_operator_velocity_sensitivity
    STX     .operator_velocity_sens_pointer

    LDX     #operator_volume
    STX     .operator_volume_pointer

; Load the 'Operator Volume Velocity Scale Factor' value into ACCB.
; This value is used to scale the operator volume according to the
; velocity of the last note.
    LDAB    <note_velocity
    LSRB
    LSRB
    LDX     #table_operator_velocity_scale
    ABX
    LDAB    0,x

; Use this scaling factor to scale the output volume of each of the
; synth's six operators.
    LDAA    #6
    STAA    .operator_index

.get_operator_volume_loop:
    LDX     .operator_velocity_sens_pointer
    PSHB

; Multiply the lower byte of the 'Op Key Sens' value with the velocity
; sensitivity scale factor in ACCB, and then add the higher byte of the
; 'Op Key Sens' back to this value.
    LDAA    1,x
    MUL
    ADDA    0,x

; If this value overflows, clamp at 0xFF.
    BCC     .increment_operator_velocity_sens_pointer
    LDAA    #$FF

.increment_operator_velocity_sens_pointer:
    INX
    INX
    STX     .operator_velocity_sens_pointer

; Store the operator volume.
    LDX     .operator_volume_pointer
    STAA    0,x
    INX
    STX     .operator_volume_pointer

    PULB
; Decrement the loop index.
    DEC     .operator_index
    BNE     .get_operator_volume_loop

    CLR     .operator_index
    LDAA    patch_edit_operator_status
    STAA    .operator_status

; Logically shift the 'Operator On/Off' register value right with each
; iteration. This loads the previous bit 0 into the carry flag, which is
; then checked to determined whether the operator is enabled, or disabled.
.check_operator_enabled_loop:
    LSR     .operator_status
    BCS     .apply_keyboard_scaling

    JSR     delay
    BRA     .clear_operator_volume

.apply_keyboard_scaling:
; Load the current operator's keyboard scaling curve into IX.
    LDAB    .operator_index
    LDAA    #KEYBOARD_SCALE_CURVE_LENGTH
    MUL
    LDX     #operator_keyboard_scaling
    ABX

; Use the MSB of the note pitch as an index into the keyboard scaling curve.
    LDAB    .new_voice_frequency
    LSRB
    LSRB
    ABX
    LDAA    0,x

; Add the operator scaling value to the logarithmic operator volume value.
; Clamp the resulting value at 0xFF.
    LDX     #operator_volume
    LDAB    .operator_index
    ABX
    ADDA    0,x
    BCC     .get_egs_register_index

.clear_operator_volume:
    LDAA    #$FF

.get_egs_register_index:
; Calculate the index into the EGS' 'Operator Levels' register.
; This register is 96 bytes long, arranged in the format of:
;   Operator[number][voice].
; The index is calculated by: (Current Operator * 16 + Current Voice).
    PSHA
    LDAA    #16
    LDAB    .operator_index
    MUL
    ADDB    .new_voice_number
    LDX     #egs_operator_level
    ABX

    PULA

; If the resulting amplitude value is less than 4, clamp at 4.
    CMPA    #3
    BHI     .write_operator_data_to_egs
    LDAA    #4

.write_operator_data_to_egs:
    STAA    0,x

; Increment loop index.
    INC     .operator_index

    LDAA    .operator_index
    CMPA    #6
    BNE     .check_operator_enabled_loop

; If the portamento rate is instantaneous, then write the pitch value to
; the EGS, and exit.
    LDAA    portamento_rate_scaled
    CMPA    #$FE
    BHI     voice_add_load_frequency_to_egs

; Check if the synth is in monophonic mode. If it is, then perform an
; additional check to determine the portamento mode.
    LDAA    mono_poly
    BEQ     .is_porta_pedal_active

; If the synth is monophonic, and in 'Fingered' portamento mode, load the
; pitch value for the current voice immediately.
    LDAA    portamento_mode
    BEQ     voice_add_load_frequency_to_egs

.is_porta_pedal_active:
; If the portamento pedal is active, exit.
; Otherwise this routine falls-through below to 'load pitch'.
    LDAA    pedal_status_current
    BITA    #PEDAL_INPUT_PORTA
    BEQ     voice_add_load_frequency_to_egs

    RTS

; ==============================================================================
; VOICE_ADD_LOAD_FREQUENCY_TO_EGS
; ==============================================================================
; DESCRIPTION:
; This function calculates the final current frequency value for the current
; voice, and loads it to the appropriate register in the EGS chip.
; @Note: This subroutine shares the temporary variables with the
; 'voice_add_operator_level_voice_frequency' routine.
;
; ==============================================================================
voice_add_load_frequency_to_egs:                SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
.new_voice_frequency:                           EQU #temp_variables
.new_voice_number:                              EQU #(temp_variables + 2)
.master_tune                                    EQU #(temp_variables + 9)
; ==============================================================================
    CLRA
    LDAB    master_tune
    LSLD
    LSLD
    STD     .master_tune

    LDAB    .new_voice_number
    ASLB

; Load the voice's current pitch EG level, and add this to the voice's
; current frequency, then subtract 0x1BA8.
    LDX     #pitch_eg_current_frequency
    ABX
    LDD     0,x
    ADDD    .new_voice_frequency
    SUBD    #$1BA8

; Clamp the frequency value to a minimum of zero.
; If it is below this minumum value, set to zero.
; If the current vaue of ACCD > 0, branch.
    BCC     .add_master_tune

    LDD     #0

.add_master_tune:
    ADDD    .master_tune

; Temporarily store the LSB.
    PSHB

; Write the frequency value to the EGS chip.
    LDX     #egs_voice_frequency
    LDAB    .new_voice_number
    ASLB
    ABX
    STAA    0,x

; Store previously saved LSB.
    PULB
    STAB    1,x

    RTS


; ==============================================================================
; Velocity to operator volume mapping table.
; Used when scaling an operator's amplitude value according to its volume.
; Length: 32.
; ==============================================================================
table_operator_velocity_scale:
    DC.B 4
    DC.B $C
    DC.B $15
    DC.B $1E
    DC.B $28
    DC.B $2E
    DC.B $34
    DC.B $3A
    DC.B $40
    DC.B $46
    DC.B $4C
    DC.B $52
    DC.B $58
    DC.B $5E
    DC.B $64
    DC.B $67
    DC.B $6A
    DC.B $6D
    DC.B $70
    DC.B $72
    DC.B $74
    DC.B $76
    DC.B $78
    DC.B $7A
    DC.B $7C
    DC.B $7E
    DC.B $80
    DC.B $82
    DC.B $83
    DC.B $84
    DC.B $85
