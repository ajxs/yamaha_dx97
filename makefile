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

EPROM_TYPE     := M27128A@DIP28

all: ${BIN_OUTPUT}

${BIN_OUTPUT}: ${BUILD_DIR}
	dasm ${INPUT_ASM} -f3 -v4 -o${BIN_OUTPUT}

dev: ${BUILD_DIR}
	dasm ${INPUT_ASM} -f3 -v4 -o${BIN_OUTPUT} -l${LISTING_TXT} -s${SYMBOLS_TXT}

${BUILD_DIR}:
	mkdir -p ${BUILD_DIR}

burn: ${BIN_OUTPUT}
	minipro -p "${EPROM_TYPE}" -w ${BIN_OUTPUT}

burn_pin_test:
	minipro -p "${EPROM_TYPE}" --pin_check

burn_verify:
	minipro -p "${EPROM_TYPE}" --verify ${BIN_OUTPUT}

clean:
	rm -rf ${BUILD_DIR}

lint:
	./etc/lint_all_files
