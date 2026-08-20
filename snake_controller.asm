bits 64
default rel
; =========================================================
; Snake Game - x64 NASM - Snake Controller
; =========================================================

%include "snake_data.inc"

; =========================================================
; EXTERNS
; =========================================================

extern SnakeDirection
extern SnakeX
extern SnakeY

; =========================================================
; DATA
; =========================================================

section .data

global MoveRight
global MoveLeft
global MoveUp
global MoveDown

global isInputLocked
isInputLocked dq 0

; =========================================================
; CODE
; =========================================================

section .text

MoveRight:
    cmp [isInputLocked], 1
    je MoveRightEndInput

    cmp [SnakeDirection], SNAKE_LEFT_DIRECTION
    je MoveRightEndInput

    mov qword [SnakeDirection], SNAKE_RIGHT_DIRECTION
    mov qword [SnakeX], SNAKE_MOVEMENT_CELL
    mov qword [SnakeY], 0

    mov qword [isInputLocked], 1

    MoveRightEndInput:
        ret

MoveLeft:
    cmp [isInputLocked], 1
    je MoveLeftEndInput

    cmp [SnakeDirection], SNAKE_RIGHT_DIRECTION
    je MoveLeftEndInput

    mov qword [SnakeDirection], SNAKE_LEFT_DIRECTION
    mov qword [SnakeX], SNAKE_MOVEMENT_CELL
    mov qword [SnakeY], 0

    mov qword [isInputLocked], 1

    MoveLeftEndInput:
        ret

MoveUp:
    cmp [isInputLocked], 1
    je MoveUpEndInput

    cmp [SnakeDirection], SNAKE_DOWN_DIRECTION
    je MoveUpEndInput

    mov qword [SnakeDirection], SNAKE_UP_DIRECTION
    mov qword [SnakeX], 0
    mov qword [SnakeY], SNAKE_MOVEMENT_CELL

    mov qword [isInputLocked], 1

    MoveUpEndInput:
        ret

MoveDown:
    cmp [isInputLocked], 1
    je MoveDownEndInput

    cmp [SnakeDirection], SNAKE_UP_DIRECTION
    je MoveDownEndInput

    mov qword [SnakeDirection], SNAKE_DOWN_DIRECTION
    mov qword [SnakeX], 0
    mov qword [SnakeY], SNAKE_MOVEMENT_CELL

    mov qword [isInputLocked], 1

    MoveDownEndInput:
        ret