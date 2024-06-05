; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; voice/reset.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the various subroutines used to reset the synth's voice
; parameters.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; VOICE_RESET
; ==============================================================================
; DESCRIPTION:
; Resets all of the synth's voices.
; This deactivates all active voices on the EGS, and then resets all of the
; synth's voice data.
;
; ==============================================================================
voice_reset:                                    SUBROUTINE
    CLR     active_voice_count
    JSR     voice_reset_egs
; Falls-through below.

; ==============================================================================
; VOICE_RESET_FREQUENCY_DATA
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD00F
; @CHANGED_FOR_6_OP
; DESCRIPTION:
; Resets the synth's internal voice frequency data.
; This resets the status of each of the synth's 16 voices, and their associated
; frequency data.
; This includes the 'Note Frequency', and voice status, the 'Current', and
; 'Target' frequencies for each voice.
; The equivalent subroutine in the DX7 ROM is located at offset 0xD0AC.
;
; ==============================================================================
voice_reset_frequency_data:                     SUBROUTINE
    PSHA
    PSHB
    PSHX

; Reset the voice note frequency and status array.
; This is accomplished by writing 0x0000 in each entry, which sets a null
; note frequency, and a 'Voice Off' status.
    CLRA
    CLRB
    LDX     #voice_status

.reset_status_loop:
    STD     0,x
    INX
    INX
    CPX     #(voice_status + 32)
    BNE     .reset_status_loop

; Reset the voice frequency buffers.
; Writes a default value (@TODO) into the current, and target frequency arrays.
; This same default value is used in both the DX7, and DX9 ROMs.
    LDD     #$2EA8

.reset_frequency_buffers_loop:
    STD     0,x
    INX
    INX
    CPX     #(voice_frequency_current + 32)
    BNE     .reset_frequency_buffers_loop

    PULX
    PULB
    PULA

    RTS


; ==============================================================================
; VOICE_RESET_EGS
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD030
; DESCRIPTION:
; Resets all voices on the EGS chip.
; This involves resetting all of the operators to their default, maximum level,
; and then sending an 'off' voice event for all of the synth's 16 voices,
; followed by an 'on' event, and another 'off' event.
; It's quite likely that sending this sequence of events to the EGS resets the
; current envelope stage for all of the synth's notes.
;
; ==============================================================================
voice_reset_egs:                                SUBROUTINE
    PSHA
    PSHB
    PSHX

    JSR     voice_reset_egs_operator_level

    LDAA    #EGS_VOICE_EVENT_OFF
    JSR     voice_reset_egs_send_event_for_all_voices
    LDAA    #EGS_VOICE_EVENT_ON
    JSR     voice_reset_egs_send_event_for_all_voices
    LDAA    #EGS_VOICE_EVENT_OFF
    JSR     voice_reset_egs_send_event_for_all_voices

    PULX
    PULB
    PULA
    RTS


; ==============================================================================
; VOICE_RESET_EGS_OPERATOR_LEVEL
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD045
; DESCRIPTION:
; Resets the level of each of the synth's operators to their default
; maximum value.
; It does this by writing to the EGS chip's operator level array.
;
; ==============================================================================
voice_reset_egs_operator_level:                 SUBROUTINE
    LDAB    #96
    LDAA    #$FF
    LDX     #egs_operator_level

.reset_operator_level_loop:
; Reset every value in the EGS operator level array.
; 16 voices * 6 operators = 96.
    STAA    0,x
    JSR     delay
    INX
    DECB
    BNE     .reset_operator_level_loop

    RTS


; ==============================================================================
; VOICE_RESET_EGS_SEND_EVENT_FOR_ALL_VOICES
; ==============================================================================
; @TAKEN_FROM_DX9_FIRMWARE:0xD056
; DESCRIPTION:
; Sends a particular 'event' byte to the EGS for all 16 voices.
; This is used in resetting the synth's voices.
;
; ARGUMENTS:
; Registers:
; * ACCA: The 'event' data to the EGS chip for all voices.
;
; ==============================================================================
voice_reset_egs_send_event_for_all_voices:      SUBROUTINE
    LDAB    #16

.send_event_for_all_voices_loop:
    STAA    egs_key_event
    JSR     delay

; Since the voice number is stored in fields 2-5, incrementing the index
; by 4 will increment the voice number field by one.
    ADDA    #4
    DECB
    BNE     .send_event_for_all_voices_loop

    RTS


; ==============================================================================
; VOICE_RESET_PITCH_EG_CURRENT_FREQUENCY
; ==============================================================================
; DESCRIPTION:
; Reset the current pitch EG frequency offset for all 16 voices to 0x4000.
; This is the middle point in the EG level.
;
; ==============================================================================
voice_reset_pitch_eg_current_frequency:         SUBROUTINE
; Reset the current pitch EG frequency offset for all 16 voices to 0x4000.
    LDAB    #16
    LDX     #pitch_eg_current_frequency

.reset_pitch_eg_loop:
    LDAA    #64
    STAA    0,x
    INX
    CLR     0,x
    INX
    DECB
    BNE     .reset_pitch_eg_loop

    RTS
