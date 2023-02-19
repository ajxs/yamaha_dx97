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
; yamaha_dx97.asm
; ==============================================================================
; DESCRIPTION:
; This is the full 'unity build' (https://en.wikipedia.org/wiki/Unity_build)
; file containing the Yamaha DX9/7 firmware ROM.
; This file is assembled into the full ROM image.
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
    INCLUDE "src/dev.asm"
    INCLUDE "src/event.asm"
    INCLUDE "src/jumpoff.asm"
    INCLUDE "src/keyboard.asm"
    INCLUDE "src/lcd.asm"
    INCLUDE "src/led.asm"
    INCLUDE "src/lfo.asm"
    INCLUDE "src/input/front_panel.asm"
    INCLUDE "src/input/input.asm"
    INCLUDE "src/midi/midi.asm"
    INCLUDE "src/midi/process.asm"
    INCLUDE "src/midi/control_code.asm"
    INCLUDE "src/midi/sysex/rx/rx.asm"
    INCLUDE "src/midi/sysex/rx/voice_param.asm"
    INCLUDE "src/midi/sysex/tx.asm"
    INCLUDE "src/midi/transmit.asm"
    INCLUDE "src/memcpy.asm"
    INCLUDE "src/mod.asm"
    INCLUDE "src/ocf.asm"
    INCLUDE "src/patch/activate/activate.asm"
    INCLUDE "src/patch/activate/operator_eg.asm"
    INCLUDE "src/patch/activate/operator_frequency.asm"
    INCLUDE "src/patch/activate/operator_scaling.asm"
    INCLUDE "src/patch/activate/lfo.asm"
    INCLUDE "src/patch/deserialise.asm"
    INCLUDE "src/patch/initialise.asm"
    INCLUDE "src/patch/load.asm"
    INCLUDE "src/patch/serialise.asm"
    INCLUDE "src/patch/patch.asm"
    INCLUDE "src/patch/validate.asm"
    INCLUDE "src/pitch_bend.asm"
    INCLUDE "src/portamento.asm"
    INCLUDE "src/pedals.asm"
    INCLUDE "src/reset.asm"
    INCLUDE "src/sci.asm"
    INCLUDE "src/string.asm"
    INCLUDE "src/tape/tape.asm"
    INCLUDE "src/tape/input.asm"
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
    INCLUDE "src/ui/print.asm"
    INCLUDE "src/voice/add/add.asm"
    INCLUDE "src/voice/add/mono.asm"
    INCLUDE "src/voice/add/poly.asm"
    INCLUDE "src/voice/remove.asm"
    INCLUDE "src/voice/reset.asm"
    INCLUDE "src/voice/voice.asm"

; The 'ROM' diagnostic test performs a checksum of the ROM.
; It loops over each byte in the ROM in 256 byte blocks, adding the value of
; each byte to a total checksum byte. This checksum is expected to add up, with
; integer overflow, to '0'. This byte placed here is the final remainder byte
; that will cause the ROM  checksum to total to '0'.
; To calculate this value for the ROM, set this value to '0', build the ROM,
; then run the associated script to generate the remainder byte.
; Refer to the external documentation for the tools used to calculate this.
checksum_remainder_byte:
    DC.B #75

    ORG $FFEE
    INCLUDE "src/vectors.asm"

    END
