bits 64
default rel

; =========================================================
; Snake Game - x64 NASM - HUD
; =========================================================

;========================================
;INCLUDES
;========================================

%include "hud_data.inc"

section .data

global CurrentScore
CurrentScore dq 0

global CurrentSpeed
CurrentSpeed dq START_SPEED_LABEL

global ScoreText
ScoreText db "0000000000",0

global FoodCountText
FoodCountText db "00000",0

global LiveText
LiveText db "0", 0

global SpeedText
SpeedText db "0", 0

global AddScore
global SetScore
global ResetScore
global ConvertIntToString
global GetSpeedLabel
global IncreaseSpeedLabel
global ResetSpeedLabel

section .text

AddScore:
    mov rax, [CurrentScore]
    add rax, GET_FOOD_POINTS
    mov [CurrentScore], rax
    ret

;===========================================
;SetScore - Parameters Sheet
;
;RDI = Current Score Value
;===========================================

SetScore:
    mov [CurrentScore], rdi
    ret

ResetScore:
    mov qword [CurrentScore], 0
    ret

;===========================================
;ConvertIntToString - Parameters Sheet
;
;RDI = value to be converted
;RSI = number of characters in the string
;RDX = address to the string
;===========================================

ConvertIntToString:

    push rbx
    push rdi

    mov rax, rdi
    mov r10, rsi

    mov r9, r10
    dec r9

    mov rdi, rdx
    add rdi, r9
    mov ecx, r10d

ConvertLoop:

    xor edx, edx
    mov ebx, r10d
    div ebx

    add dl, '0' ;'0' == 48 (ascii table)
    mov [rdi], dl

    dec rdi

    dec ecx
    jnz ConvertLoop

    pop rdi
    pop rbx
    ret

GetSpeedLabel:
    mov rax, [CurrentSpeed]
    ret

IncreaseSpeedLabel:
    mov rax, [CurrentSpeed]
    inc rax
    mov qword [CurrentSpeed], rax
    ret

ResetSpeedLabel:
    mov qword [CurrentSpeed], 1
    ret
