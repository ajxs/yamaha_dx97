; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; keyboard.asm
; ==============================================================================
; DESCRIPTION:
; This file contains the definitions, and code related to scanning the synth's
; keyboard.
; ==============================================================================

    .PROCESSOR HD6303

; ==============================================================================
; KEYBOARD_SCAN
; ==============================================================================
; DESCRIPTION:
; The keyboard circuitry is grouped by key, with the same key from each octave
; wired together. The individual keys of an octive are wired to lines 4-15 of
; the key switch scan driver. The value returned is the octave of the pressed
; key (1 << octave).
; This subroutine iterates over the 12 different keys, checking whether each
; read value has changed since the last call.
; If the value read for a key has changed, the value is rotated to find which
; octave changed.
; @NOTE: Previously temporary variables were used in the keyboard scan routine.
; These have been moved to internal RAM to save CPU cycles.
; The difference between DIRECT, and EXTENDED mode loads/stores adds up to
; around 40 cycles.
;
; MEMORY MODIFIED:
; * keyboard_scan_current_key
; * keyboard_scan_current_octave
; * keyboard_last_scanned_values
; * note_number
;
; REGISTERS MODIFIED:
; * ACCA, ACCB, IX
;
; ==============================================================================
keyboard_scan:                                  SUBROUTINE
    LDX     #keyboard_last_scanned_values
    LDAB    <io_port_1_data
    ANDB    #%11110000
    ORAB    #KEY_SWITCH_SCAN_DRIVER_SOURCE_KEYBOARD
    STAB    <keyboard_scan_current_key

; Iterate over each key.
.scan_key_loop:
    LDAB    <keyboard_scan_current_key
    STAB    <io_port_1_data
    DELAY_SINGLE

; Read the status of each octave for this key.
    LDAA    <key_switch_scan_driver_input

; Test if the value has changed since the last check.
    EORA    0,x
    BNE     .key_changed

    INX
    LDAB    <keyboard_scan_current_key
    INCB
    STAB    <keyboard_scan_current_key

; Test if ACCB % 16 is zero.
; ACCB started at 4, so this will loop 12 times (once for each key).
    ANDB    #%1111
    BNE     .scan_key_loop

; If no keys have changed state, set the note number event dispatch
; flag to a null value.
    LDAA    #$FF
    STAA    <note_number
    BRA     .exit

.key_changed:
    LDAB    <keyboard_scan_current_key
    ANDB    #%1111
    CLR     <keyboard_scan_current_octave
    INC     <keyboard_scan_current_octave

.get_updated_octave:
; Rotate this value right until the carry bit is set, indicating that the
; updated octave has been reached.
    RORA
    BCS     .get_updated_keycode

; 12 is added to the key value with each iteration on account of the number
; of keys in an octave. 21 (the base key value) is added to the final value
; to yield the final key code.
    ADDB    #12
    ASL     <keyboard_scan_current_octave
    BRA     .get_updated_octave

.get_updated_keycode:
    ADDB    #21
    STAB    <note_number
    LDAA    <keyboard_scan_current_octave

; Test whether this key is being pressed. If so, set bit 7.
    BITA    0,x
    BNE     .store_updated_value

    OIMD    #$80, note_number

; Store the updated input.
.store_updated_value:
    EORA    0,x
    STAA    0,x

; Set the note velocity of a keypress to its maximum.
; @NOTE: Internally a value of '0' represents the maximum velocity.
; Refer to the 'table_midi_velocity' table used to translate between an
; incoming MIDI 'Note On' message's velocity, and the synth's internal
; representation.
; Also refer to the 'voice_add_operator_level_voice_frequency' method.
    LDAA    #0
    STAA    <note_velocity

.exit:
    RTS


; ==============================================================================
; KEYBOARD_EVENT_HANDLER
; ==============================================================================
; DESCRIPTION:
; Handles keyboard events.
; This is called periodically as part of the synth's main executive loop.
; This subroutine is controlled by the main 'Note Number' register. If a
; keyboard 'Key Down' event is triggered, the note will be stored in this
; register with bit 7 set to indicate a 'Key Down' event. This subroutine will
; subsequently trigger adding the note's voice.
; Alternatively, if bit 7 is clear, it is considered a 'Key Up' event, and the
; synth will initiate the process of removing a voice with the selected note,
; if it exists.
;
; ARGUMENTS:
; Memory:
; * note_number: The keyboard event note number.
; If this value is 0xFF, it indicates there is no key event pending.
; If bit 7 of this byte is set, it indicates that this note event is a
; 'Key Down' event originating from the keyboard.
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
keyboard_event_handler:                         SUBROUTINE
; Test whether the pending note number is 0xFF, indicating that there is
; no pending key event to handle.
    LDAB    <note_number
    CMPB    #$FF
    BEQ     .exit

; Check whether bit 7 is clear, indicating that the pending key event is a key
; being released. In this case handle it as a 'Key Off' event.
    BPL     .key_up_event

; Otherwise consider this a 'Key On' event.
; Mask the note number.
    ANDB    #%1111111

; Test whether the 'Set Key Tranpose' mode is active.
; In this case the next keypress sets the root note.
    LDAA    <key_transpose_set_mode_active
    BNE     keyboard_set_key_transpose

; Send the MIDI 'Note On' event, then jump to adding a new voice with the
; selected note.
    JSR     midi_tx_note_on
    JMP     voice_add

.key_up_event:
; Send the MIDI 'Note Off' event, then jump to removing the note.
    JSR     midi_tx_note_off
    JMP     voice_remove

.exit:
    RTS


; ==============================================================================
; KEYBOARD_SET_KEY_TRANSPOSE
; ==============================================================================
; DESCRIPTION:
; This subroutine sets the 'Key Transpose' centre-note value.
; This function is called as part of the 'keyboard_event_handler' routine if
; the appropriate flag is set to indicate that the synth is in
; 'Set Key Tranpose' mode. If this flag is set the next key note value is to
; be stored as the centre-note value.
;
; ARGUMENTS:
; Registers:
; * ACCB: The note of the triggering key event.
;
; MEMORY MODIFIED:
; * patch_edit_key_transpose
;
; REGISTERS MODIFIED:
; * ACCA, ACCB
;
; ==============================================================================
keyboard_set_key_transpose:                     SUBROUTINE
; Test whether the note is below 48.
; If so, set to 48 to initialise the tranpose key at the minimum.
    CMPB    #48
    BMI     .key_under_48

; Test whether the tranpose key is above 72.
; If so, set to its maximum of 72.
    CMPB    #72
    BLS     .set_transpose_key

    LDAB    #72
    BRA     .set_transpose_key

.key_under_48:
    LDAB    #48

.set_transpose_key:
    SUBB    #48
    CMPB    patch_edit_key_transpose
    BEQ     .clear_key_transpose_flag

    STAB    patch_edit_key_transpose

; After the key transpose has been set, send the new value via SysEx.
    JSR     midi_sysex_tx_key_transpose

; Set the patch edit buffer as having been modified.
    LDAA    #1
    STAA    patch_current_modified_flag
    JSR     ui_print_update_led_and_menu

.clear_key_transpose_flag:
    CLR     key_transpose_set_mode_active

    RTS
