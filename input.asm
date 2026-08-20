bits 64
default rel

; =========================================================
; Snake Game - x64 NASM - Input System
; =========================================================

;========================================
;INCLUDES
;========================================

%include "input_data.inc"

;========================================
;EXTERNS
;========================================

extern GetKeyboardInput
extern GetControllerInput
extern HandleGameState

section .data

global HandleInput

global InputType
InputType dq INPUT_TYPE_KEYBOARD

global CurrentKeyPress
CurrentKeyPress dq GAME_INPUT_NONE

section .text

;========================================================
;HandleInput - Parameters Sheet
;
;RDI = Type of input
;RSI = Native key pressed (Keyboard Only)
;========================================================

HandleInput:
    mov r8, rdi
    mov r9, rsi

    cmp r8, INPUT_TYPE_KEYBOARD
    je UseKeyboard

    cmp r8, INPUT_TYPE_CONTROLLER
    je UseController

    jmp HandleInput_Return

    UseKeyboard:
        mov rdi, r9

        sub rsp, 8h
            call GetKeyboardInput
        add rsp, 8h

        test rax, rax
        jz HandleInput_Return

        mov r8, rax
        mov qword [InputType], INPUT_TYPE_KEYBOARD
        jmp HandleGameStateLabel

    UseController:
        sub rsp, 8h
            call GetControllerInput
        add rsp, 8h

        test rax, rax
        jz HandleInput_Return

        mov r8, rax
        mov qword [InputType], INPUT_TYPE_CONTROLLER
        jmp HandleGameStateLabel

HandleGameStateLabel:
    mov qword [CurrentKeyPress], r8

    sub rsp, 8h
        call HandleGameState
    add rsp, 8h

    ret

HandleInput_Return:
    ret
