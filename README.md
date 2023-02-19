# Yamaha DX9/7 Alternate Firmware

## What is this?

This repository contains the source code for alternate firmware for the Yamaha DX9 synthesiser. This alternate firmware intends to make the DX9's functionality more closely match that of the DX7 by restoring functionality that was intentionally restricted at the firmware level, such as restoring the use of six operators, and the pitch envelope generator.

## Build Dependencies

* GNU Make
* Dasm Assembler

## Build instructions

Simply run `make` from the root directory to produce the final binary.

## What has been changed?

* MIDI velocity is now acknowledged.

## What functionality will not match that of the DX7?

* Editing of DX7-specific patch parameters via the front-panel buttons will not be implemented. The function of existing front-panel controls will not be modified. Doing so would likely cause considerable confusion for little benefit.
* DX7 style glissando will not be implemented. As fantastic as this feature is, porting the related code from the DX7's firmware is non-trivial, and is considered out-of-scope.
* Support for the DX9's missing modulation sources via MIDI will not be implemented: The synth will not respond to aftertouch MIDI messages.
