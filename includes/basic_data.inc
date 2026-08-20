; =========================================================
;STRUCTS
; =========================================================

struc RECT
    .left    resd 1
    .top     resd 1
    .right   resd 1
    .bottom  resd 1
endstruc

; =========================================================
; TYPEDEFS
; =========================================================

%define HWND        dq
%define HDC         dq
%define HINSTANCE   dq

%define BYTE_size   1
%define WORD_size   2
%define DWORD_size  4
%define QWORD_size  8

BLINK_TIMER_ID equ 1
BLINK_FREQUENCY_MS equ 500

MAIN_INPUT_TIMER_ID equ 2
GAME_INPUT_TIMER_ID equ 3
INPUT_FREQUENCY_MS equ 16