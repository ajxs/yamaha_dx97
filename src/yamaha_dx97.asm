; ==============================================================================
; YAMAHA DX9/7 FIRMWARE
; Copyright (C) 2022 AJXS (https://ajxs.me/)
;
; SPDX-License-Identifier: GPL-3.0-or-later
; ==============================================================================
; yamaha_dx97.asm
; ==============================================================================
; DESCRIPTION:
; This is the full 'unity build' (https://en.wikipedia.org/wiki/Unity_build)
; file containing the Yamaha DX9/7 firmware ROM.
; This file is assembled into the full ROM image.
; @NOTE: The individual file paths are relative to the makefile.
; ==============================================================================

    .PROCESSOR HD6303

    INCLUDE "src/macro.asm"
    INCLUDE "src/cpu.asm"
    INCLUDE "src/peripherals.asm"
    INCLUDE "src/ram.asm"

    SEG rom
    ORG $C000

    INCLUDE "src/adc.asm"
    INCLUDE "src/delay.asm"
    INCLUDE "src/event.asm"
    INCLUDE "src/jumpoff.asm"
    INCLUDE "src/keyboard.asm"
    INCLUDE "src/lcd.asm"
    INCLUDE "src/led.asm"
    INCLUDE "src/lfo.asm"
    INCLUDE "src/input/front_panel.asm"
    INCLUDE "src/input/input.asm"
    INCLUDE "src/log.asm"
    INCLUDE "src/midi/midi.asm"
    INCLUDE "src/midi/process.asm"
    INCLUDE "src/midi/control_code.asm"
    INCLUDE "src/midi/sysex/rx/rx.asm"
    INCLUDE "src/midi/sysex/rx/voice_param.asm"
    INCLUDE "src/midi/sysex/tx.asm"
    INCLUDE "src/midi/tx.asm"
    INCLUDE "src/memcpy.asm"
    INCLUDE "src/mod.asm"
    INCLUDE "src/ocf.asm"
    INCLUDE "src/patch/activate/activate.asm"
    INCLUDE "src/patch/activate/operator_eg.asm"
    INCLUDE "src/patch/activate/operator_frequency.asm"
    INCLUDE "src/patch/activate/operator_scaling.asm"
    INCLUDE "src/patch/activate/pitch_eg.asm"
    INCLUDE "src/patch/activate/lfo.asm"
    INCLUDE "src/patch/convert/from_dx9.asm"
    INCLUDE "src/patch/convert/to_dx9.asm"
    INCLUDE "src/patch/deserialise.asm"
    INCLUDE "src/patch/initialise.asm"
    INCLUDE "src/patch/load.asm"
    INCLUDE "src/patch/serialise.asm"
    INCLUDE "src/patch/patch.asm"
    INCLUDE "src/patch/validate.asm"
    INCLUDE "src/pitch_bend.asm"
    INCLUDE "src/pitch_eg.asm"
    INCLUDE "src/portamento.asm"
    INCLUDE "src/pedals.asm"
    INCLUDE "src/reset.asm"
    INCLUDE "src/sci.asm"
    INCLUDE "src/string.asm"
    INCLUDE "src/tape/tape.asm"
    INCLUDE "src/tape/input/input.asm"
    INCLUDE "src/tape/input/all.asm"
    INCLUDE "src/tape/input/single.asm"
    INCLUDE "src/tape/output.asm"
    INCLUDE "src/tape/verify.asm"
    INCLUDE "src/test/adc.asm"
    INCLUDE "src/test/auto_scaling.asm"
    INCLUDE "src/test/eg_op.asm"
    INCLUDE "src/test/kbd.asm"
    INCLUDE "src/test/lcd.asm"
    INCLUDE "src/test/ram.asm"
    INCLUDE "src/test/rom.asm"
    INCLUDE "src/test/switch.asm"
    INCLUDE "src/test/tape.asm"
    INCLUDE "src/test/test.asm"
    INCLUDE "src/test/volume.asm"
    INCLUDE "src/ui/button/main.asm"
    INCLUDE "src/ui/button/numeric.asm"
    INCLUDE "src/ui/button/test_mode_combo.asm"
    INCLUDE "src/ui/increment_decrement.asm"
    INCLUDE "src/ui/slider.asm"
    INCLUDE "src/ui/ui.asm"
    INCLUDE "src/ui/yes_no.asm"
    INCLUDE "src/ui/print/print.asm"
    INCLUDE "src/ui/print/value.asm"
    INCLUDE "src/ui/print/osc_frequency.asm"
    INCLUDE "src/voice/add/add.asm"
    INCLUDE "src/voice/add/mono.asm"
    INCLUDE "src/voice/add/poly.asm"
    INCLUDE "src/voice/remove/remove.asm"
    INCLUDE "src/voice/remove/mono.asm"
    INCLUDE "src/voice/remove/poly.asm"
    INCLUDE "src/voice/reset.asm"
    INCLUDE "src/voice/voice.asm"

; The 'ROM' diagnostic test performs a checksum of the ROM.
; It loops over each byte in the ROM in 256 byte blocks, adding the value of
; each byte to a total checksum byte. This checksum is expected to add up, with
; integer overflow, to '0'. This byte placed here is the final remainder byte
; that will cause the ROM checksum to total to '0'.
; To calculate this value for the ROM, set this value to '0', build the ROM,
; then run the associated script to generate the remainder byte.
; Refer to the external documentation for the tools used to calculate this.
checksum_remainder_byte:
    DC.B #69

    ORG $FFEE

; This is the main hardware vector table.
; This table contains the various interrupt vectors used by the HD6303 CPU. It
; always sits in a fixed position at the end of the ROM.
vector_trap:                                    DC.W handler_reset
vector_sci:                                     DC.W handler_sci
vector_tmr_tof:                                 DC.W handler_reset
vector_tmr_ocf:                                 DC.W handler_ocf
vector_tmr_icf:                                 DC.W handler_reset
vector_irq:                                     DC.W handler_reset
vector_swi:                                     DC.W handler_reset
vector_nmi:                                     DC.W handler_reset
vector_reset:                                   DC.W handler_reset

    END
