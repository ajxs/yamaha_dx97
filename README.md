# Yamaha DX9/7 Alternate Firmware ROM

## What is this?

This is an alternate firmware ROM for the Yamaha DX9 synthesiser. Its aim is to make the DX9's functionality more closely match that of the DX7 by restoring features that were intentionally restricted in the firmware, such as increasing the operator count to six, and adding a pitch envelope generator. This ROM makes the synth properly patch-compatible with the DX7.

This is not a patch for the existing DX9 firmware, it is an entirely new firmware ROM. It has been assembled from the original binary, together with code from the DX7's V1.8 ROM, as well as new code written from scratch.

### New Features:
* Makes the DX9 able to play DX7 patches.
* Restores the use of all six operators.
* The synth is now sensitive to velocity of incoming MIDI notes.
* Implements the DX7's pitch EG.
* Implements DX7 style operator scaling.
* Implements DX7 style portamento/glissando.

## What is the current status of the ROM?

This firmware is currently highly experimental. Although the main features are fully working, testing and bugfixes are ongoing. Installing the firmware for everyday general use is currently not recommended. As additional testing is performed this will improve. If you do intend to use the ROM despite this warning, please refer to the section on reporting issues.

The risk of any harm coming to your DX9 as a result of using this ROM is incredibly, *incredibly* small, however the developers take no responsibility for any issues that may arise as a result of using this alternate firmware. All care has been taken, and considerable testing has been performed, however the developers accept no liability for any issues.

## Known Issues
* Despite this firmware making the DX9 patch-compatible with the DX7, it cannot properly emulate all of the DX7's functionality. While your DX9 might think that it's actually a DX7, your patch editor might not be so easily fooled. Certain MIDI functionality, such as triggering button-presses via SysEx, and function parameter changes, simply can't be emulated in any reasonable way. This might cause issues communicating with common patch editors.
Receiving individual/bulk patch dumps via SysEx *does* work, however. Every effort is being made to make the ROM as compatible as possible, however some issues will inevitably remain.

* In some cases pitch-bend input is updated at a slightly lower frequency than in the original ROM. If the pitch bend wheel is moved quickly this can result in a noticeable gradation in pitch transition. This is due to the pitch-bend input being processed as part of the main periodic timer interrupt. In the original DX7 pitch-bend input is read by the sub-cpu, and the input is parsed in the firmware only when updated. In the DX9 the pitch-bend's analog input is wired directly to the CPU's I/O ports, and is parsed periodically as part of the OCF interrupt routine. In time this routine may be further optimised to mitigate this issue.

## Reporting Issues

If you encounter any issues, or discrepancies while using this ROM, please report them using either the 'Issues' tab in Github, or by emailing the lead maintainer (@ajxs). 

When reporting issues, please describe the expected result, and any steps necessary to recreate the issue.

## Contributing

Contributions to the codebase, or documentation are definitely welcome! The preferred way to contribute to the project is by raising a Pull Request on Github. If you do not have a Github account, please send a patch to the lead maintainer (@ajxs).

## Build Dependencies

* GNU Make
* Dasm Assembler

## Build instructions

Simply run `make` from the root directory to produce the final binary.

## FAQ
**Q: How do I install this new ROM in my DX9?**

**A:** To install this new ROM, you'll need to flash the firmware onto an EPROM chip, and install it into your DX9 synthesiser in place of the DX9's original mask ROM.
According to the DX7/9 Service Manual, early model DX9s had the ROM installed on two 2764 series EPROM chips (IC4, and IC5), with later revisions using a single 27128-series EPROM. Replacement with a single EPROM chip socket will likely be necessary for installing a new ROM.
Fortunately most DX9s feature a single socketed ROM chip which makes replacement enormously simpler. The firmware can be flashed to any 27128-series EPROM for installation.

Note: This ROM is still highly experimental, and is not recommended for everyday use. Refer to the *What is the current status of the ROM?* message above.

**Q: Are you selling programmed EPROM chips, or distributing binaries?**

**A:** Not at this point, unfortunately. Once the ROM reaches a V1.0 release binaries will be distributed, until then users will need to compile their own binaries, and flash it to an EPROM chip themselves.
With regards to selling programmed EPROM chips, this is currently not on the project's roadmap. This may be considered in the future, as reliability improves.

**Q: Will editing of all DX7 parameters be possible from the front-panel?**

**A:** Unfortunately, no.

The DX9 has considerably less front-panel buttons than that of the DX7. As a result editing of all the DX7-specific parameters via the front-panel just isn't going to be possible. In some cases the editing of these parameters has been made possible via the alternate-functionality of individual buttons, however this just isn't practical for all parameters.


**Q: Will this functionality introduce keyboard velocity sensitivity?**

**A:** Unfortunately, this isn't possible. As best as I'm currently aware, this just isn't supported by the keyboard used in the DX9. However the DX9 now responds to velocity in MIDI messages in the same way the DX7 does. Keyboard events also now transmit velocity values of 127, as opposed to '64' in the original ROM.


**Q: Why is patch storage so limited?**

**A:** Unfortunately the DX9 features considerably less RAM than the DX7. 4Kb versus 6Kb, respectively. The DX7's 32 patch storage buffer takes up 4Kb by itself.

Each DX7 patch is 128 bytes in size, as opposed to a DX9 patch being 64 bytes. This means that even if no extra RAM space was used by the additional features added in this firmware, only ten DX7 patches would fit in the existing space.

The DX7 firmware uses several internal buffers that don't exist in that of the DX9, such as the data structures related to the pitch EG, and glissando, for instance. These take up additional space that could otherwise be used for patch storage.

All efforts are being made to optimise the RAM usage for additional patch storage.


**Q: Can aftertouch modulation be implemented?**

**A:** Unfortunately the hardware doesn't support aftertouch. Support for the DX9's missing modulation sources via MIDI is not currently planned: The synth will not respond to aftertouch MIDI messages.


**Q: After editing the ROM, is it possible to get the ROM diagnostic test stage to pass?**

**A:** Yes! 
Please refer to this helper script for instructions on how to resovle this: `etc/get_checksum_remainder_byte`.


**Q: How do I check which version of the DX9/7 ROM I'm using?**

**A:** Like in the original DX7 firmware, the ROM version is displayed in the 'Test Mode' entry prompt. To display this, hold down the 'Test Mode' button combination: Function+10+20.

**Q: Is the cassette interface still functional?**

**A:** Yes. Although with some limitations. 
Unlike the DX9's SysEx implementation, which serialised patches in a DX7-compatible format, patches output over the cassette interface are serialised in the DX9's native format. To ensure that DX9 patches serialised to tape can still be read this firmware preserves the original formatting. Patches read over the cassette interface will be converted from the DX9 format to the DX7 format used by this firmware. Conversely, patches output to cassette will be converted to DX9 format. This means that certain patches that depend on DX7 functionality may be corrupted in the process. It is not recommended to use this feature.
