bits 64
default rel
; =========================================================
; Snake Game - x64 NASM - Snake System
; =========================================================

%include "basic_data.inc"
%include "snake_data.inc"
%include "snake_state_data.inc"
%include "hud_data.inc"

;========================================
;EXTERNS
;========================================

extern SpawnFood
extern DrawTile
extern GetSnakeState

extern isInputLocked

section .data

global ResetSnake
global SetupSnake

global MoveSnake
global DrawSnake
global GrowSnake
global ShrinkSnake
global ResetSnakeSize

global GetLivesSnake
global SetLivesSnake
global AddLiveSnake
global RemoveLiveSnake

global GetSnakeSpeed
global SetSnakeSpeed
global ResetSnakeSpeed
global IncreaseSnakeSpeed

global SnakeDirection
SnakeDirection dq SNAKE_DEFAULT_DIRECTION

global SnakeTileSize
SnakeTileSize dd SNAKE_TILE_SIZE

global SnakeX
SnakeX dq SNAKE_MOVEMENT_CELL

global SnakeY
SnakeY dq 0

global SnakeLives
SnakeLives dq SNAKE_INITIAL_LIVES

global SnakeSize
SnakeSize dq SNAKE_INITIAL_SIZE

SnakeSpeed dq SNAKE_DEFAULT_SPEED

global SnakeHeadX
SnakeHeadX dq 0

global SnakeHeadY
SnakeHeadY dq 0

previousSegmentX dq 0
previousSegmentY dq 0

previousSnakeSegment dq 0

global snakeCounter
snakeCounter dq 0

section .bss
global SnakeSegments
SnakeSegments resb SNAKESEGMENT_size * 50

section .text

ResetSnake:
    mov qword [SnakeLives], SNAKE_INITIAL_LIVES
    mov qword [SnakeSize], SNAKE_INITIAL_SIZE
    mov qword [SnakeSpeed], SNAKE_DEFAULT_SPEED
    ret

SetupSnake:

    push r14
    push r15

    xor r14, r14

    mov qword [SnakeDirection], SNAKE_DEFAULT_DIRECTION
    mov qword [SnakeX], SNAKE_MOVEMENT_CELL
    mov qword [SnakeY], 0

    mov r15, [SnakeSize]
    dec r15
    imul r15d, [SnakeTileSize]

    add r15, SNAKE_START_X

    SetupLoopSnake:

        cmp r14, [SnakeSize]
        je SetupFinish

        imul rdx, r14, SNAKESEGMENT_size

        mov rax, r15

        lea r11, [rel SnakeSegments]
        add r11, rdx

        mov qword [r11 + SNAKESEGMENT.X], rax
        mov qword [r11 + SNAKESEGMENT.Y], SNAKE_START_Y

        cmp r14, 0
        jne ContinueLoop

    SetupSetSnakeHead:
        mov qword [SnakeHeadX], r15
        mov qword [SnakeHeadY], 0

    ContinueLoop:

        sub r15, [SnakeX]
        inc r14
        jmp SetupLoopSnake

    SetupFinish:
        sub rsp, 8h
            call SpawnFood
        add rsp, 8h

        pop r15
        pop r14
        ret

MoveSnake:

    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, [SnakeX] ; X
    mov r13, [SnakeY] ; Y
    mov r15, [SnakeDirection]

    xor r14, r14

    imul rbx, r14, SNAKESEGMENT_size

    lea rcx, [rel SnakeSegments]
    add rcx, rbx

    mov r10, [rcx + SNAKESEGMENT.X]
    mov r11, [rcx + SNAKESEGMENT.Y]

    cmp r15, SNAKE_RIGHT_DIRECTION
    je RIGHT

    cmp r15, SNAKE_LEFT_DIRECTION
    je LEFT

    cmp r15, SNAKE_UP_DIRECTION
    je UP

    cmp r15, SNAKE_DOWN_DIRECTION
    je DOWN

    RIGHT:
        mov rax,[rcx + SNAKESEGMENT.X]
        add rax, r12
        jmp SetX

    LEFT:
        mov rax, [rcx + SNAKESEGMENT.X]
        sub rax, r12
        jmp SetX

    SetX:

    mov qword [rcx + SNAKESEGMENT.X], rax

    UP:
        mov rax, [rcx + SNAKESEGMENT.Y]
        sub rax, r13
        jmp SetY

    DOWN:
        mov rax, [rcx + SNAKESEGMENT.Y]
        add rax, r13
        jmp SetY

    SetY:
        mov qword [rcx + SNAKESEGMENT.Y], rax

    cmp r14, 0
    je MoveSetSnakeHead

    jmp Increment

    MoveSetSnakeHead:
        mov rax, [rcx + SNAKESEGMENT.X]
        mov [SnakeHeadX], rax

        mov rax, [rcx + SNAKESEGMENT.Y]
        mov [SnakeHeadY], rax

    Increment:
        inc r14

MoveLoopSnake:

    cmp r14, [SnakeSize]
    je MoveFinish

    imul rbx, r14, SNAKESEGMENT_size

    lea rcx, [rel SnakeSegments]
    add rcx, rbx

    mov r8, [rcx + SNAKESEGMENT.X]
    mov r9, [rcx + SNAKESEGMENT.Y]

    mov qword [rcx + SNAKESEGMENT.X], r10
    mov qword [rcx + SNAKESEGMENT.Y], r11

    mov r10, r8
    mov r11, r9

    inc r14
    jmp MoveLoopSnake

MoveFinish:

    mov qword [isInputLocked], 0

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx

    ret

;========================================================
;DrawSnake - Parameters Sheet
;
;RDI = Device Context
;========================================================

DrawSnake:

    sub rsp, 8h
        call GetSnakeState
    add rsp, 8h

    cmp rax, SNAKE_STATE_DEAD
    je DrawFinish

    mov r10, rdi ;hDeviceContext

    mov rax, [snakeCounter]
    and rax, 1

    test rax, rax
    jz DarkColor

    LightColor:
        mov ecx, 0077ff00h
        jmp DrawRect

    DarkColor:
        mov ecx, 0000bb00h

    DrawRect:
        mov r11, [snakeCounter]
        imul r11, SNAKESEGMENT_size
        lea rax, [SnakeSegments]
        add rax, r11

        mov rdi, r10
        mov rsi, [rax + SNAKESEGMENT.X]
        mov rdx, [rax + SNAKESEGMENT.Y]
        add rdx, HUD_AREA

        sub rsp, 8h
            mov rax, [SnakeTileSize]
            mov r8, rax
            call DrawTile
        add rsp, 8h

        DrawFinish:
            ret

GrowSnake:
    push rbx
    mov rax, [SnakeSize]

    mov rbx, rax
    dec rbx
    imul rbx, SNAKESEGMENT_size

    lea r10, [rel SnakeSegments]
    add r10, rbx

    mov rcx, rax
    imul rcx, SNAKESEGMENT_size

    lea r11, [rel SnakeSegments]
    add r11, rcx

    mov rdx, [r10 + SNAKESEGMENT.X]
    mov qword [r11 + SNAKESEGMENT.X], rdx

    mov rdx, [r10 + SNAKESEGMENT.Y]
    mov qword [r11 + SNAKESEGMENT.Y], rdx

    inc rax
    mov qword [SnakeSize], rax

    pop rbx
    ret

ShrinkSnake:

    mov rax, [SnakeSize]

    mov rbx, rax
    inc rbx
    imul rbx, SNAKESEGMENT_size

    lea r10, [rel SnakeSegments]
    add r10, rbx

    mov rcx, rax
    imul rcx, SNAKESEGMENT_size

    lea r11, [rel SnakeSegments]
    add r11, rcx

    mov rdx, [r10 + SNAKESEGMENT.X]
    mov qword [r11 + SNAKESEGMENT.X], rdx

    mov rdx, [r10 + SNAKESEGMENT.Y]
    mov qword [r11 + SNAKESEGMENT.Y], rdx

    mov rax, [SnakeSize]

    mov rcx, rax
    shr rcx, 1

    sub rax, rcx

    mov qword [SnakeSize], rax

    ret

ResetSnakeSize:
    cmp [SnakeSize], SNAKE_INITIAL_SIZE
    jle Return

    mov rax, SNAKE_INITIAL_SIZE
    mov qword [SnakeSize], rax

    Return:
        ret

AddLiveSnake:
    mov rax, [SnakeLives]
    inc rax
    mov [SnakeLives], rax
    ret

RemoveLiveSnake:
    mov rax, [SnakeLives]
    dec rax
    mov [SnakeLives], rax
    ret

;==================================
;SetLivesSnake - Parameters Sheet
;
;RDI = Number of lives
;==================================

SetLivesSnake:
    mov qword [SnakeLives], rdi
    ret

GetLivesSnake:
    mov rax, [SnakeLives]
    ret

GetSnakeSpeed:
    mov rax, [SnakeSpeed]
    ret

;==================================
;SetLivesSnake - Parameters Sheet
;
;RDI = Snake Speed
;==================================

SetSnakeSpeed:
    mov qword [SnakeSpeed], rdi
    ret

ResetSnakeSpeed:
    mov qword [SnakeSpeed], SNAKE_DEFAULT_SPEED
    ret

IncreaseSnakeSpeed:
    mov rax, [SnakeSpeed]
    sub rax, SNAKE_SPEED_INCREMENT
    mov [SnakeSpeed], rax
    ret
