; ==============================================================================
; TEST_TAPE
; ==============================================================================
; DESCRIPTION:
; @TODO
; ==============================================================================
test_tape:                                      SUBROUTINE
    TST     test_stage_sub
    BEQ     .exit

; The test stage was initialised at 0xFF.
; This effectively tests whether the test has been setup already.
    BPL     loc_FB5D

; Write test stage string to the LCD.
    LDX     #str_cassette
    JSR     test_lcd_set_write_pointer_to_position_7
    LDX     #str_push_1_button
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    CLR     test_stage_sub_2
    LDAA    #1
    STAA    <test_stage_sub
    BRA     .exit

loc_FB5D:
    LDAA    <test_stage_sub
    CMPA    #1
    BNE     loc_FB70

    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_1
    BNE     .exit

    LDAA    #2
    STAA    <test_stage_sub
    BRA     .exit

loc_FB70:
    JSR     lcd_clear_line_2
    CLRB

loc_FB74:
    EIMD    #PORT_1_TAPE_OUTPUT, io_port_1_data
    BSR     .tape_delay

    LDAA    <io_port_1_data
    ANDA    #PORT_1_TAPE_INPUT
    STAA    <tape_input_polarity_previous
    DECB
    BNE     loc_FB74

    LDAB    #$80

loc_FB84:
    EIMD    #PORT_1_TAPE_OUTPUT, io_port_1_data
    BSR     test_tape_read_input

    DECB
    BNE     loc_FB84

    LDAA    <test_stage_sub_2

; Is the number of pulses detected less than 126?
; If so, this constitutes an error.
    CMPA    #126
    BCS     .print_error_string

; Is the number of pulses detected more than 130?
; If so, this constitutes an error.
    CMPA    #130
    BCC     .print_error_string

    LDX     #str_ok

.print_status_string:
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    CLR     test_stage_sub

.exit:
    RTS

.print_error_string:
    LDX     #str_test_err
    BRA     .print_status_string

.tape_delay:
    LDX     #90
    NOP
    NOP

.tape_delay_loop:
    DEX
    BNE     .tape_delay_loop

    RTS


; ==============================================================================
; TEST_TAPE_READ_INPUT
; ==============================================================================
; DESCRIPTION:
; Reads the tape input over an arbitrary period of 12 cycles, incrementing the
; test sub stage variable to count the number of 'pulses' that occur within
; the period.
;
; ==============================================================================
test_tape_read_input:                           SUBROUTINE
    LDX     #12

.read_input_loop:
    LDAA    <io_port_1_data
    ANDA    #PORT_1_TAPE_INPUT

; Test whether the polarity has changed.
    EORA    <tape_input_polarity_previous
    BPL     .input_loop_delay

    EORA    <tape_input_polarity_previous
    STAA    <tape_input_polarity_previous
    INC     test_stage_sub_2
    BRA     .advance_loop

.input_loop_delay:
    DELAY_SINGLE
    DELAY_SHORT
    DELAY_SHORT

.advance_loop:
    DEX
    BNE     .read_input_loop

    DELAY_SINGLE
    NOP

    RTS


; ==============================================================================
; TEST_TAPE_REMOTE
; ==============================================================================
; DESCRIPTION:
; @TODO
; ==============================================================================
test_tape_remote:                               SUBROUTINE
    TST     test_stage_sub
    BEQ     loc_FBFA

    AIMD    #~PORT_1_TAPE_REMOTE, io_port_1_data
    LDX     #str_remote
    JSR     test_lcd_set_write_pointer_to_position_7
    LDX     #str_push_1_button
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    CLR     test_stage_sub_2
    CLR     test_stage_sub
    BRA     .exit

loc_FBFA:
    TST     test_stage_sub_2
    BNE     .exit

    JSR     input_read_front_panel
    CMPB    #INPUT_BUTTON_1
    BNE     .exit

    OIMD    #PORT_1_TAPE_REMOTE, io_port_1_data
    JSR     lcd_clear_line_2
    LDX     #str_test_on
    JSR     test_lcd_set_write_pointer_to_line_2
    JSR     lcd_update
    LDAA    #$FF
    STAA    <test_stage_sub_2

.exit:
    RTS
