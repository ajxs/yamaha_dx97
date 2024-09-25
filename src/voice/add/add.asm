; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
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
; @TAKEN_FROM_DX7_FIRMWARE
; DESCRIPTION:
; This subroutine is the main entry point to 'adding' a new voice event.
; It is effectively the entry point to actually playing a note over one of the
; synth's voices. This function branches to more specific functions, depending
; on whether the synth is in monophonic, or polyphonic mode.
; This subroutine is where a note keycode is converted to the EGS chip's
; internal representation of pitch. The various voice buffers related to pitch
; transitions are set, and reset here.
;
; @NOTE: The DX9/7 firmware follows the DX7 convention of storing the MIDI note
; number in the voice status array, _without_ any transposition.
; The DX9 code stores the MSB of the logarithmic frequency instead.
;
; ARGUMENTS:
; Registers:
; * ACCB: The note number to add to the new voice.
;
; ==============================================================================
voice_add:                                      SUBROUTINE
    STAB    <note_number
    JSR     voice_transpose_and_convert_note_to_log_freq

    LDAB    mono_poly
    BNE     .synth_in_mono_mode

    JMP     voice_add_poly

.synth_in_mono_mode:
    JMP     voice_add_mono


; ==============================================================================
; VOICE_ADD_OPERATOR_LEVEL_VOICE_FREQUENCY
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE:0xDD90
; DESCRIPTION:
; Loads the operator scaling, and frequency for a new note to the EGS chip.
; Tests whether the current portamento settings mean the new note frequency
; should not be loaded immediately.
;
; ARGUMENTS:
; Registers:
; * IX:   The initial frequency for the new note.
; * ACCA: The zero-indexed voice number.
;
; ==============================================================================
voice_add_operator_level_voice_frequency:       SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
; @WARNING: These temporary variable definitions are shared across all of the
; 'Voice Add' subroutines.
.voice_frequency_target_ptr:                    EQU #temp_variables
.voice_status_ptr:                              EQU #temp_variables + 2
.operator_sensitivity_ptr:                      EQU #temp_variables + 4
.operator_volume_ptr:                           EQU #temp_variables + 6
.voice_frequency_initial:                       EQU #temp_variables + 8
.voice_index:                                   EQU #temp_variables + 10
.voice_buffer_offset:                           EQU #temp_variables + 11
.operator_status:                               EQU #temp_variables + 12
.operator_loop_index:                           EQU #temp_variables + 13

; ==============================================================================
    STX     .voice_frequency_initial
    STAA    .voice_index

; Setup pointers.
    LDX     #patch_operator_velocity_sensitivity
    STX     .operator_sensitivity_ptr

    LDX     #operator_volume
    STX     .operator_volume_ptr

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
    STAA    .operator_loop_index

.calculate_operator_volume_loop:
    LDX     .operator_sensitivity_ptr
    PSHB

; Multiply the lower byte of the 'Op Key Sens' value with the velocity scale
; value in B, and then add the higher byte of the 'Op Key Sens' back to
; this value.
    LDAA    1,x
    MUL
    ADDA    0,x

; If this value overflows, clamp at 0xFF.
    BCC     .increment_operator_sensitivity_ptr
    LDAA    #$FF

.increment_operator_sensitivity_ptr:
    INX
    INX
    STX     .operator_sensitivity_ptr

; Store the operator volume.
    LDX     .operator_volume_ptr
    STAA    0,x
    INX
    STX     .operator_volume_ptr

; Decrement the loop index.
    PULB
    DEC     .operator_loop_index
    BNE     .calculate_operator_volume_loop

    CLR     .operator_loop_index
    LDAA    patch_edit_operator_status
    STAA    .operator_status

.write_operator_volume_data_loop:
; Logically shift the 'Operator On/Off' register value right with each
; iteration. This loads the previous bit 0 into the carry flag, which is
; then checked to determined whether the operator is enabled, or disabled.
    LSR     .operator_status
    BCS     .apply_keyboard_scaling

    JSR     delay
    BRA     .clear_operator_volume

.apply_keyboard_scaling:
    LDAB    .operator_loop_index
    LDAA    #KEYBOARD_SCALE_CURVE_LENGTH
    MUL

    LDX     #operator_keyboard_scaling_level_curve_table
    ABX

; Use the MSB of the note pitch as an index into the keyboard scaling curve.
    LDAB    .voice_frequency_initial
    LSRB
    LSRB
    ABX
    LDAA    0,x

; Add the operator scaling value to the logarithmic operator volume value.
; Clamp the resulting value at 0xFF.
    LDX     #operator_volume
    LDAB    .operator_loop_index
    ABX
    ADDA    0,x
    BCC     .get_egs_operator_volume_register_index

.clear_operator_volume:
    LDAA    #$FF

.get_egs_operator_volume_register_index:
; Calculate the index into the EGS' 'Operator Levels' register.
; This register is 96 bytes long, arranged in the format of:
;   Operator[number][voice].
; The index is calculated by: (Current Operator * 16 + Current Voice).
    PSHA
    LDAA    #16
    LDAB    .operator_loop_index
    MUL
    ADDB    .voice_index
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
    INC     .operator_loop_index
    LDAA    .operator_loop_index
    CMPA    #6
    BNE     .write_operator_volume_data_loop

; If the portamento rate is instantaneous, then write the pitch value to
; the EGS, and exit.
    LDAA    portamento_rate_scaled
    CMPA    #$FE
    BHI     voice_add_load_frequency_to_egs

; Check if the synth is in monophonic mode. If it is, then perform an
; additional check to determine the portamento mode.
    LDAA    mono_poly
    BEQ     .is_portamento_pedal_active

; If the synth is monophonic, and in 'Fingered' portamento mode, load the
; pitch value for the current voice immediately.
    LDAA    portamento_mode
    BEQ     voice_add_load_frequency_to_egs

.is_portamento_pedal_active:
; If the portamento pedal is active, exit.
; Otherwise this routine falls-through below to 'load pitch'.
    TIMD    #PEDAL_INPUT_PORTA, pedal_status_current
    BEQ     voice_add_load_frequency_to_egs

    RTS


; ==============================================================================
; VOICE_ADD_LOAD_FREQUENCY_TO_EGS
; ==============================================================================
; @TAKEN_FROM_DX7_FIRMWARE:0xDE2D
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; This function calculates the final current frequency value for the current
; voice, and loads it to the appropriate register in the EGS chip.
; @Note: This subroutine shares the temporary variables with the
; 'voice_add_operator_level_voice_frequency', and 'voice_add_poly' routines.
;
; ==============================================================================
voice_add_load_frequency_to_egs:                SUBROUTINE
; ==============================================================================
; LOCAL TEMPORARY VARIABLES
; ==============================================================================
; @WARNING: These temporary variable definitions are shared across all of the
; 'Voice Add' subroutines.
.voice_frequency_target_ptr:                    EQU #temp_variables
.voice_status_ptr:                              EQU #temp_variables + 2
.operator_sensitivity_ptr:                      EQU #temp_variables + 4
.operator_volume_ptr:                           EQU #temp_variables + 6
.voice_frequency_initial:                       EQU #temp_variables + 8
.voice_index:                                   EQU #temp_variables + 10
.voice_buffer_offset:                           EQU #temp_variables + 11
.operator_status:                               EQU #temp_variables + 12
.operator_loop_index:                           EQU #temp_variables + 13

; ==============================================================================
    LDAB    .voice_index
    ASLB

; Load the voice's current pitch EG level, and add this to the voice's
; current frequency, then subtract 0x1BA8.
    LDX     #pitch_eg_current_frequency
    ABX
    LDD     0,x
    ADDD    .voice_frequency_initial
    SUBD    #$1BA8

; Clamp the frequency value to a minimum of zero.
; If the current value of D > 0x1BA8, branch.
    BCC     .add_master_tune

    LDD     #0

.add_master_tune:
    ADDD    master_tune
    PSHB

; Write the frequency value to the EGS chip.
    LDX     #egs_voice_frequency
    LDAB    .voice_index
    ASLB
    ABX
    STAA    0,x
    PULB
    STAB    1,x

    RTS


; ==============================================================================
; Velocity to operator volume mapping table.
; Used when scaling an operator's amplitude value according to its volume.
; Length: 31.
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

; ==============================================================================
; VOICE_ADD_INITIALISE_LFO
; ==============================================================================
; Initialises the LFO when adding a new voice.
; This is used in both the polyphonic, and monophonic 'Voice Add' routines.
;
; ==============================================================================
    .MACRO VOICE_ADD_INITIALISE_LFO
; If the synth's LFO delay is not set to 0, reset the LFO delay accumulator.
        TST     patch_edit_lfo_delay
        BEQ     .is_lfo_sync_enabled

        LDD     #0
        STD     <lfo_delay_accumulator
        CLR     <lfo_delay_fadein_factor

.is_lfo_sync_enabled:
; If 'LFO Key Sync' is enabled, reset the LFO phase accumulator to its
; maximum positive value to coincide with the 'Key On' event.
        TST     patch_edit_lfo_sync
        BEQ     .end_initialise_lfo

        LDD     #$7FFF
        STD     <lfo_phase_accumulator

.end_initialise_lfo:
    .ENDM
