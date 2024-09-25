# Yamaha DX9/7 Alternative Firmware ROM

## What is this?

DX9/7 is an alternative firmware ROM for the Yamaha DX9 synthesiser. Its aim is to uplift the DX9's functionality to more closely match that of the DX7. It restores features that were intentionally restricted in the firmware, such as increasing the operator count to six, and adding a pitch envelope generator. This ROM makes the synth properly patch-compatible with the DX7.

This is not a patch for the existing DX9 firmware, it is an entirely new firmware ROM. It has been assembled from the original binary, together with code from the DX7's V1.8 ROM, as well as new code written from scratch.

**Where to get the ROM**

You can download the pre-compiled ROM binary from the [Releases](https://github.com/ajxs/yamaha_dx97) tab on the [Yamaha DX9/7 Github page](https://github.com/ajxs/yamaha_dx97/releases).
For more information on how to install the ROM in your DX9, see the entry in the FAQ below.
If you would like to try this firmware ROM, but you're unable to flash this ROM to an EPROM chip yourself, feel free to contact me (@ajxs) directly.

### New Features:
* Makes the DX9 able to play DX7 patches.
* Restores the use of all six operators.
* The synth is now sensitive to the velocity of incoming MIDI notes.
* Implements the DX7's pitch EG.
* Implements DX7 style operator scaling.

## Important: First Time Installation or Upgrade

**Important: Back up your patches before installation!** 

When installing this firmware ROM for the first time, or upgrading to a new version, all of the synth's internal parameters will be filled with random data. This is because the locations of important data in the synth's RAM will have changed. 

To initialise all of the synth's parameters and voice data, hold down the **FUNCTION** button as the synth boots up. This will reset the synth to a fresh, safe state. The potential effects of running the synth with random voice data loaded is not known.

**Note:** Newer versions of this ROM use a fixed location for patch storage at the starting address of the external RAM. This means that upgrading to a new version *should* not corrupt the current patch memory. The original published version did not do this. So please be sure to back up your patches before upgrading.

## What is the current status of the ROM?

This alternative firmware ROM has been thoroughly tested, and is considered ready for everyday use. The possibility of minor bugs does still exist however. Please be sure to read the section on *reporting issues*.

The risk of any harm coming to your DX9 as a result of using this ROM is incredibly, *incredibly* small, however the developers take no responsibility for any issues that may arise as a result of using this alternate firmware. All care has been taken, and considerable testing has been performed, however you are using this software at your own risk.

## Known Issues
* There are currently some performance issues related to the extra processing required to run the synth's pitch EG. The DX9's CPU runs at a lower clock rate than the DX7, which means that there is less time to process user input between periodically updating the voice chips, which occurs at a fixed rate. The effect of this is that real-time control may be slightly slower in some cases than the DX7, or the original DX9 firmware. This is a known issue, and work is ongoing to optimise the firmware.

* The pitch EG, and portamento rate is *slightly* different than the original DX7. The DX9's CPU runs at a different clock rate than the DX7, and the periodic interrupt rate used in the DX9 firmware is slightly different. The original DX7's periodic interrupt runs at 375.258758Hz, whereas the DX9's runs at 377Hz. This leads to *slight* discrepancies in the timing. In most cases this won't be noticeable. This may be corrected in a future release.

* Despite this firmware making the DX9 patch-compatible with the DX7, it can't emulate *all* of the DX7's functionality. While your DX9 might think that it's actually a DX7, your patch editor might not be so easily fooled. Some SysEx functionality just can't be emulated in any reasonable way, such as triggering DX7-specific button-presses, and changes to the DX7-specific function parameters. This might cause issues communicating with some patch editors.
Receiving individual/bulk patch dumps via SysEx *does* work, however. Every effort is being made to make the ROM as compatible as possible, however some discrepancies will inevitably remain.

## Currently Not Implemented
* Pitch-bend step
* MIDI Output Channel Selection
* Patch name editing
* Glissando

## Reporting Issues

If you encounter any issues, or discrepancies while using this ROM, please report them using either the 'Issues' tab in Github, or by emailing the lead maintainer (@ajxs). 

## Contributing

Contributions to the codebase, or documentation are definitely welcome! The preferred way to contribute to the project is by raising a *Pull Request* on Github. If you do not have a Github account, feel free to send a patch to the lead maintainer (@ajxs).

## Build Dependencies

* [GNU Make](https://www.gnu.org/software/make)
* [Dasm Assembler](https://dasm-assembler.github.io/)

## Build instructions

To build the firmware, run `make` from the root directory to produce the final binary: `build/yamaha_dx97.bin`.

If you are unable to use GNU Make, you can build the executable by invoking dasm directly on the command line:

```shell
dasm src/yamaha_dx97.asm -f3 -v4 -obuild/yamaha_dx97.bin
```

If you use a Unix-based system, and the [Minipro](https://gitlab.com/DavidGriffith/minipro/) software, several convenience recipes exist in the makefile to help with burning the binary to an EPROM chip (`burn`, `burn_verify`, `burn_pin_test`).
The `EPROM_TYPE` variable in the makefile can be altered as needed to select the correct EPROM chip type.
For more information refer to the `Makefile`.

## FAQ
**Q: How do I install this new ROM in my DX9?**

**A:** To install this new ROM, you'll need to write the firmware onto an EPROM chip, and install it into your DX9 synthesiser in place of the DX9's original mask ROM chip.
According to the DX7/9 Service Manual, early model DX9s had the ROM installed on two 2764 series EPROM chips (IC4, and IC5), with later revisions using a single 27128-series EPROM. Replacement with a single EPROM chip socket will likely be necessary for installing a new ROM.
Fortunately most DX9s feature a single socketed ROM chip which makes replacement much simpler. The firmware can be flashed to any 27128-series EPROM for installation.

**Q: Are you selling programmed EPROM chips?**

**A:** Not at this point. Once the ROM reaches a V1.0 release the possibility of distributing programmed EPROM chips might be reconsidered. At this point bugs are still being found and fixed, and the binary is changing too often to consider distributing pre-programmed EPROMs with pre-release versions.

**Q: Will editing of all DX7 parameters be possible from the front-panel?**

**A:** Unfortunately, no.

Due to the DX9 having different front-panel buttons than the DX7, editing of all the DX7-specific parameters via the front-panel just isn't going to be possible. In some cases the editing of these parameters has been made possible via the alternate-functionality of individual buttons, however this just isn't practical for all parameters.


**Q: Will this functionality introduce keyboard velocity sensitivity, or aftertouch?**

**A:** Unfortunately, this isn't possible. As best as I'm currently aware, velocity and aftertouch just aren't supported by the DX9's keyboard hardware. However this firmware makes the DX9 respond to MIDI velocity the same way the DX7 does. Keyboard events also now transmit velocity values of 127, as opposed to '64' in the original ROM. Support for the DX9's missing modulation sources via MIDI is not currently planned.


**Q: Why is patch storage so limited?**

**A:** Unfortunately the DX9 features considerably less RAM than the DX7. 4Kb versus 6Kb, respectively. The DX7's 32 patch storage buffer takes up 4Kb by itself.

Each DX7 patch is 128 bytes in size, as opposed to a DX9 patch being 64 bytes. This means that even if no extra RAM space was used by the additional features added in this firmware, only ten DX7 patches would fit in the existing space. The DX7's missing firmware firmware features, such as pitch EG and glissando, also use a reasonable amount of additional memory that could otherwise be used for patch storage.

All efforts are being made to optimise the RAM usage for additional patch storage.


**Q: After editing the ROM, is it possible to get the ROM diagnostic test stage to pass?**

**A:** Yes! 
Please refer to this helper script for instructions on how to resolve this: `etc/get_checksum_remainder_byte`.


**Q: How do I check which version of the DX9/7 ROM I'm using?**

**A:** Like in the original DX7 firmware, the ROM version is displayed in the 'Test Mode' entry prompt. To display this, hold down the 'Test Mode' button combination: Function+10+20.


**Q: Is the cassette interface still functional?**

**A:** Yes. Although with some limitations. 
Unlike the DX9's SysEx implementation, which serialises patches in a DX7-compatible format, patches output over the cassette interface are serialised in the DX9's native format. To ensure that DX9 patches saved to tape can still be read, this firmware preserves the original formatting. This means that patches saved to cassette will be converted to the original DX9 format. Unfortunately this means that patches which depend on DX7-specific functionality will be corrupted by outputting them over tape. It is not recommended to use this feature. Patches input from the cassette interface will automatically be converted to the DX7 format used by this firmware. 

**Q: If I use this ROM, is it possible to reinstall the original?**

**A:** Yes, of course! 
To go back to using the original ROM, just replace the original mask ROM IC, and run the synth's diagnostic test routines to reset the synth's internal parameters to their default values.
