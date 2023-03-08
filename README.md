# Yamaha DX9/7 Alternate Firmware

## What is this?

This repository contains the source code for alternate firmware for the Yamaha DX9 synthesiser. This alternate firmware intends to make the DX9's functionality more closely match that of the DX7 by restoring functionality that was intentionally restricted at the firmware level, such as restoring the use of six operators, and the pitch envelope generator.

## Build Dependencies

* GNU Make
* Dasm Assembler

## Build instructions

Simply run `make` from the root directory to produce the final binary.

## FAQ
**Q: Will editing of all DX7 parameters be possible from the front-panel?**

**A:** Unfortunately, no.

The DX9 has considerably less front-panel buttons than that of the DX7. As a result editing of all the DX7-specific parameters via the front-panel just isn't going to be possible. In some cases the editing of these parameters has been made possible via the alternate-functionality of individual buttons, however this just isn't practical for all parameters.


**Q: Will this functionality introduce velocity sensitivity?**

**A:** Unfortunately, this isn't possible. As best as I'm currently aware, this just isn't supported by the keyboard used in the DX9. However the DX9 now responds to velocity in MIDI messages in the same way the DX7 does. Keyboard events also now transmit velocity values of 127, as opposed to '64' in the original ROM.


**Q: Why is patch storage so limited?**

**A:** Unfortunately the DX9 features considerably less RAM than the DX7. 4Kb versus 6Kb, respectively. The DX7's 32 patch storage buffer takes up 4Kb by itself.

Each DX7 patch is 128 bytes in size, as opposed to a DX9 patch being 64 bytes. This means that even if no extra RAM space was used for the additional features added in this firmware, only ten DX7 patches would fit in the existing space.

The DX7 firmware uses several internal buffers that don't exist in that of the DX9, such as the data structures related to the pitch EG, and glissando, for instance. These take up additional space that could otherwise be used for patch storage.

All efforts are being made to optimise the RAM usage for additional patch storage.


**Q: Can aftertouch modulation be implemented?**

**A:** Unfortunately the hardware doesn't support aftertouch. Support for the DX9's missing modulation sources via MIDI is not currently planned: The synth will not respond to aftertouch MIDI messages.


**Q: After editing the ROM, is it possible to get the ROM diagnostic test to pass?**

**A:** Yes! 
Please refer to this helper script for instructions on how to resovle this: `etc/get_checksum_remainder_byte`.


**Q: How do I check which version of the DX9/7 ROM I'm using?**

**A:** Like in the original DX7 firmware, the ROM version is displayed in the 'Test Mode' entry prompt. To display this, hold down the 'Test Mode' button combination: Function+10+20.

**Q: Is the cassette interface still functional?**

**A:** Yes. Although with some limitations. 
Unlike the DX9's SysEx implementation, which serialised patches in a DX7-compatible format, patches output over the cassette interface are serialised in the DX9's native format. To ensure that DX9 patches serialised to tape can still be read this firmware preserves the original formatting. Patches read over the cassette interface will be converted from the DX9 format to the DX7 format used by this firmware. Conversely, patches output to cassette will be converted to DX9 format. This means that certain patches that depend on DX7 functionality may be corrupted in the process. It is not recommended to use this feature.
