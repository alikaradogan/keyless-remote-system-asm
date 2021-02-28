@ STM32F4 Discovery - Remote Keyless System with Rolling Code
@ Gebze Technical University - Electronics Engineering Dept.
@ Authors: Ahmet Hamdi Coruk & Ali Sacid Karadogan
@ ELEC458 Course Project Team 1

.thumb
.syntax unified
@.arch armv7e-m

@ Constants
.equ LEDDELAY,      1000000
.equ IDENTIFIER,    0x01
.equ SRC_ADDRESS,   0x0100
.equ DST_ADDRESS,   0xA00000
.equ CYPHER,        0xFAFAFAFA
.equ FIRSTRCODE,    0x16        @ 151024036 + 161024086 = last 2 digits 22
.equ BUTTONDELAY,   200000
.equ MANDELAY,      1562        @ 100000/64 = 1562.5

@ RCC base address is 0x40023800
@ AHB1ENR register offset is 0x30
.equ RCC_AHB1ENR,   0x40023830      @ RCC AHB1 peripheral clock reg (page 180)

@ GPIOA base address is 0x40020000
@ MODER register offset is 0x00
@ IDR   register offset is 0x10

.equ GPIOA_MODER,   0x40020000      @ GPIOA port mode register (page 281)
.equ GPIOA_IDR,     0x40020010      @ GPIOA input data register (page 283)

@ GPIOD base address is 0x40020C00
@ MODER register offset is 0x00
@ ODR   register offset is 0x14

.equ GPIOD_MODER,   0x40020C00      @ GPIOD port mode register (page 281)
.equ GPIOD_ODR,     0x40020C14      @ GPIOD output data register (page 283)

@ GPIOB base address is 0x40020800
@ MODER register offset is 0x00
@ ODR   register offset is 0x14

.equ GPIOB_MODER,   0x40020400      @ GPIOB port mode register (page 281)
.equ GPIOB_ODR,     0x40020414      @ GPIOB output data register (page 283)

@ Start of text section
.section .text

@ Add all other processor specific exceptions/interrupts in order here
.long    __StackTop     @ Top of the stack. from linker script
.long    _start +1      @ reset location, +1 for thumb mode

@ Main code starts here

_start:

@ Enable GPIOA, GPIOB and GPIOD Peripheral Clock (bits 0 and 3 in AHB1ENR register)
    ldr r6, =RCC_AHB1ENR        @ Load peripheral clock reg address to r6
    ldr r5, [r6]                @ Read its content to r5
    orr r5, 0x0000000B          @ Set bits to enable GPIOA, GPIOB, GPIOD  clock
    str r5, [r6]                @ Store result in peripheral clock register
    mov r8, #0                  @ Reassign the r8 for using to check if the First Roll sent

@ Make GPIOB Pin1 as output pin (bits 3:2 in MODER register)
    ldr r6, =GPIOB_MODER        @ Load GPIOB MODER register address to r6
    ldr r5, [r6]                @ Read its content to r5
    mov r5, #0x00000280         @ Clear bits 2, 3 for P1
    orr r5, 0x00000004          @ Write 01 to bits 2,3 for P1
    str r5, [r6]                @ Store result in GPIOB MODER register

@ Make GPIOD Pin12,Pin13,Pin14,Pin15 as output pins (bits 31:30,29:28,27:26,25:24 in MODER register)
    ldr r6, =GPIOD_MODER        @ Load GPIOD MODER register address to r6
    ldr r5, [r6]                @ Read its content to r5
    and r5, r5, 0x00FFFFFF      @ Clear bits 24, 25, 26, 27, 28, 29, 30, 31 for P12,P13,P14,P15
    orr r5, 0x55000000          @ Write 01 to bits 24, 25, 26, 27, 28, 29, 30, 31 for P12,P13,P14,P15
    str r5, [r6]                @ Store result in GPIOD MODER register

@ Light LED's when program start or reset
LightLEDsFirstTime:
    ldr r5, =GPIOD_ODR          @ Load GPIOD output data register
    ldr r6, [r5]
    orr r6, r6, 0xF000          @ Take the last 4 bits of rolling code
    str r6, [r5]                @ Store result in GPIOD output data register
    
    ldr r7, =LEDDELAY
    bl Delay

TurnOffLEDs:

    and r6, r6, 0x0000          @ Take the last 4 bits of rolling code
    str r6, [r5]

@ Check the button on GPIOA Pin0 if it is pressed
CheckButton:
    mov r2, #32                 @ Set the counter for Manchester Encoding
    ldr r0, =GPIOA_IDR          @ Load GPIOA_IDR register address to r0

    ldr r7, =BUTTONDELAY
    bl Delay

    ldr r1, [r0]                @ Read its content to r1
    lsl r1, r1, #31

    cmp r1, 0x00000000          @ Compare r1 with 0
    beq CheckButton             @ If r1 equals 0 go CheckButton branch
    bne CheckFirstRoll

CheckFirstRoll:
    cmp r8, #0
    beq FirstRoll
    bne	RollingCode

FirstRoll:
    mov r8, #1
    ldr r4, =FIRSTRCODE         @ Take the first rolling code
    b LightLEDs                 @ go FrameEncrypt branch

@ Generate Rolling Code after reading the button
RollingCode:

    add r4, r4, #1              @ Add 1 to the previous rolling code
    and r4, r4, #255            @ Take the modulo 256
    b LightLEDs                 @ go LED lighting branch


LightLEDs:
    ldr r5, =GPIOD_ODR          @ Load GPIOD output data register
    mov r6, r4                  @ Copy r4 value to r6 to keep rolling code value
    and r6, r6, 0xF0            @ Take the last 4 bits of rolling code
    lsl r6, r6, #8              @ Shift rolling code to make it 16 bits
    str r6, [r5]                @ Store result in GPIOD output data register

    b FrameEncrypt              @ go to FrameEncrypt branch

FrameEncrypt:
    ldr r3, =IDENTIFIER         @ Load identifer to r3
    add r3, r3, SRC_ADDRESS     @ Add source address to r3
    add r3, r3, DST_ADDRESS     @ Add destination address to r3
    add r3, r3, r4              @ Add rolling code to r3
    eor r3, r3, CYPHER          @ Encrypt r3 with hardcoded key

    b ManEncFirst

ManEncFirst:
    and r9, r3, #1
    cmp r9, #1
    beq ManHighFirst
    bne ManLowFirst

ManHighFirst:
    @0 of 10 (Rising Edge)
    ldr r11, =GPIOB_ODR
    ldr r10, [r11]
    and r10, 0xFFFFFFFD
    and r10, 0x0                @ bit '0' (low) sent to PB1 pin
    str r10, [r11]

    ldr r7, =MANDELAY
    bl Delay

    @1 of 10 (Rising Edge)
    ldr r11, =GPIOB_ODR
    ldr r10, [r11]
    and r10, 0xFFFFFFFD
    orr r10, 0x2                @ bit '1' (high) sent to PB1 pin
    str r10, [r11]
    sub r2, #1

    ldr r7, =MANDELAY
    bl Delay

    b ManEncRest

ManLowFirst:
    @1 of 01 (Falling Edge)
    ldr r11, =GPIOB_ODR
    ldr r10, [r11]
    and r10, 0xFFFFFFFD
    orr r10, 0x2                @ bit '1' (high) sent to PB1 pin
    str r10, [r11]

    ldr r7, =MANDELAY
    bl Delay

    @0 of 01 (Falling Edge)
    ldr r11, =GPIOB_ODR
    ldr r10, [r11]
    and r10, 0xFFFFFFFD
    and r10, 0x0                @ bit '0' (low) sent to PB1 pin
    str r10, [r11]
    sub r2, #1

    ldr r7, =MANDELAY
    bl Delay

    b ManEncRest

ManEncRest:
    cmp r2, #0
    beq	CheckButton
    lsr r3, r3, #1
    mov r9, r3
    and r9, r9, #1
    cmp r9, #1
    beq ManHighRest
    bne ManLowRest

ManHighRest:
    @0 of 10 (Rising Edge)
    ldr r11, =GPIOB_ODR
    ldr r10, [r11]
    and r10, 0xFFFFFFFD
    and r10, 0x0                @ bit '0' (low) sent to PB1 pin
    str r10, [r11]

    ldr r7, =MANDELAY
    bl Delay

    @1 of 10 (Rising Edge)
    ldr r11, =GPIOB_ODR
    ldr r10, [r11]
    and r10, 0xFFFFFFFD
    orr r10, 0x2                @ bit '1' (high) sent to PB1 pin
    str r10, [r11]
    sub r2, #1

    ldr r7, =MANDELAY
    bl Delay

    b ManEncRest

ManLowRest:
    @1 of 01 (Falling Edge)
    ldr r11, =GPIOB_ODR
    ldr r10, [r11]
    and r10, 0xFFFFFFFD
    orr r10, 0x2                @ bit '1' (high) sent to PB1 pin
    str r10, [r11]

    ldr r7, =MANDELAY
    bl Delay

    @0 of 01 (Falling Edge)
    ldr r11, =GPIOB_ODR
    ldr r10, [r11]
    and r10, 0xFFFFFFFD
    and r10, 0x0                @ bit '0' (low) sent to PB1 pin
    str r10, [r11]
    sub r2, #1

    ldr r7, =MANDELAY
    bl Delay

    b ManEncRest

Delay:
    sub r7, #1
    cmp r7, #0
    bne Delay
    bx lr
