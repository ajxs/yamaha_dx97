.POSIX:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.PHONY: clean

SRC_DIR        := src
BUILD_DIR      := build
BIN_OUTPUT     := ${BUILD_DIR}/yamaha_dx97.bin
INPUT_ASM      := ${SRC_DIR}/yamaha_dx97.asm
LISTING_TXT    := listing.txt
SYMBOLS_TXT    := symbols.txt

FLASH_BIN      := ~/src/EPROM-EMU-NG/Software/EPROM_NG_v2.0rc3.py

EPROM_TYPE     := M27128A@DIP28

all: ${BIN_OUTPUT}

${BIN_OUTPUT}: ${BUILD_DIR}
	dasm ${INPUT_ASM} -f3 -v4 -o${BIN_OUTPUT}

dev: ${BUILD_DIR}
	dasm ${INPUT_ASM} -f3 -v4 -o${BIN_OUTPUT} -l${LISTING_TXT} -s${SYMBOLS_TXT}

${BUILD_DIR}:
	mkdir -p ${BUILD_DIR}

flash: ${BIN_OUTPUT}
	python3 ${FLASH_BIN} -mem 27128 -spi y -auto y ${BIN_OUTPUT} /dev/ttyUSB0

flash_original:
	python3 ${FLASH_BIN} -mem 27128 -spi y -auto y ./original_rom.hex /dev/ttyUSB0

burn: ${BIN_OUTPUT}
	minipro -p "${EPROM_TYPE}" -w ${BIN_OUTPUT}

burn_original:
	minipro -p "${EPROM_TYPE}" -w etc/original_rom.hex

burn_pin_test:
	minipro -p "${EPROM_TYPE}" --pin_check

burn_verify:
	minipro -p "${EPROM_TYPE}" --verify ${BIN_OUTPUT}

clean:
	rm -rf ${BUILD_DIR}

lint:
	./lint_all_files
