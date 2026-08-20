bits 64
default rel
; =========================================================
; Snake Game - x64 NASM - Audio System
; =========================================================

;========================================
;EXTERNS
;========================================

extern LoadAudio
extern PlayAudio

section .data

global PlayIntroBGM

IntroMusic db "audio/intro.wav", 0
IntroAlias db "Intro", 0

section .text

PlayIntroBGM:

    lea rdi, [IntroAlias]
    lea rsi, [IntroMusic]

    sub rsp, 8h
        call LoadAudio
    add rsp, 8h

    lea rdi, [IntroAlias]
    mov rsi, 0

	sub rsp, 8h
	    call PlayAudio
	add rsp, 8h
	ret
