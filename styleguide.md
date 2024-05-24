# Styleguide

## File Header

If you are adding a new file to the project, please add this header with the GPL3 license SPDX identifier string. Feel free to add your own details to the copyright notice.

	; ==============================================================================
	; YAMAHA DX9/7 FIRMWARE
	; Copyright (C) 2022 AJXS (https://ajxs.me/)
	;
	; SPDX-License-Identifier: GPL-3.0-or-later
	; ==============================================================================
	; filename.asm
	; ==============================================================================
	; DESCRIPTION:
	; @TODO
	; ==============================================================================

			.PROCESSOR HD6303

The `.PROCESSOR HD6303` dasm directive is added to new files, as some tooling uses this to determine the assembly dialect.

## Function Documentation

Functions should use the following documentation.
The various annotations can be used to categorise functions that need additional attention, and denote functions that have been adapted from the original DX7/9 firmware, as well as their original locations in their respective ROM.

	; ==============================================================================
	; FUNCTION_NAME
	; ==============================================================================
	; @TAKEN_FROM_DX9_FIRMWARE:0x1234
	; @NEEDS_TO_BE_REMADE_FOR_6_OP
	; @TAKEN_FROM_DX7_FIRMWARE:0x1234
	; @CHANGED_FOR_6_OP
	; @NEW_FUNCTIONALITY
	; @NEEDS_TESTING
	; @NEEDS_FIXING
	; @CALLED_DURING_OCF_HANDLER
	; @PRIVATE
	; DESCRIPTION:
	; These annotations are used so that subroutines can be easily searched by
	; category.
	; 
	; ARGUMENTS:
	; Registers:
	; * IX:   Argument passed in IX.
	; * ACCB: Argument passed in ACCB.
	; 
	; Memory:
	; * variable_name: Argument passed by memory.
	; * 0xCE:   The source string buffer pointer.
	; * 0xD0:   The destination string buffer pointer.
	; 
	; MEMORY MODIFIED:
	; * memcpy_pointer_source
	; * memcpy_pointer_dest
	;
	; REGISTERS MODIFIED:
	; * ACCA, ACCB, IX
	; 
	; RETURNS:
	; * ACCA: fjffjf
	; * CC:C: Carry bit.
	; 
	; ==============================================================================

## General Rules

* Line width must be less-than, or equal to 80.
* Place a line break after branch statements.
* Start line comments in column 0.
* When creating a new file, the directory structure, and file naming convention should model the hierarchy of the function definitions they contain. For example, the function `patch_activate_lfo` is contained in the file `src/patch/activate/lfo`. This format is just a recommendation. There is no specific requirement for *when* to create new files.
