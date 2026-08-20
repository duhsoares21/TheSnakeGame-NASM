bits 64
default rel

; =========================================================
; Snake Game - x64 NASM - Main Menu
; =========================================================

%include "basic_data.inc"
%include "render_data.inc"
%include "input_data.inc"
%include "window_data.inc"

;========================================
;EXTERNS
;========================================

extern PlatformCreateMainWindow
extern PlatformRunMessageLoop
extern PlatformExitProcess
extern PlatformBeginWindowRender
extern PlatformEndWindowRender

extern InitRender
extern DrawHUD
extern FillRectangle

extern HandleInput

section .data

BlinkState dq 1

hDeviceContext: HDC 0

global GameIcon
GameIcon dq 0

TitleFont db 'C:\Windows\Fonts\arial.ttf',0
SubtitleFont db 'C:\Windows\Fonts\arial.ttf',0

GameTitleLabel  db "The Snake Game", 0
GameTitleRect:
    istruc RECT
        at RECT.left,   dd 0
        at RECT.top,    dd 120
        at RECT.right,  dd 600
        at RECT.bottom, dd 600
    iend

PressAnyKeyLabel  db "Press enter or Start Key",0
PressAnyKeyRect:
    istruc RECT
        at RECT.left,   dd 0
        at RECT.top,    dd 420
        at RECT.right,  dd 600
        at RECT.bottom, dd 600
    iend

TopHalfRectangle:
    istruc RECT
        at RECT.left,   dd 0
        at RECT.top,    dd 0
        at RECT.right,  dd 600
        at RECT.bottom, dd 285
    iend

BottomHalfRectangle:
    istruc RECT
        at RECT.left,   dd 0
        at RECT.top,    dd 285
        at RECT.right,  dd 600
        at RECT.bottom, dd 600
    iend

global timerValue
timerValue dq INPUT_FREQUENCY_MS

mainRender:
    istruc RENDER_CONTEXT
        at RENDER_CONTEXT.WindowDC,     dq 0
        at RENDER_CONTEXT.RenderDC,     dq 0
        at RENDER_CONTEXT.BackBitmap,   dq 0
        at RENDER_CONTEXT.OldBitmap,    dq 0
        at RENDER_CONTEXT.ScreenWidth,  dq 600
        at RENDER_CONTEXT.ScreenHeight, dq 600
    iend

global main
global MainOnCreate
global MainOnTimer
global MainOnKeyboard
global MainOnRender
global MainOnClose

section .text

main:
    mov rdi, 600
    mov rsi, 600

    sub rsp, 8h
        call PlatformCreateMainWindow
    add rsp, 8h

    sub rsp, 8h
        call PlatformRunMessageLoop
    add rsp, 8h

    xor rdi, rdi

    sub rsp, 8h
        call PlatformExitProcess
    add rsp, 8h

    ret

;========================================================
;MainOnCreate - Parameters Sheet
;
;RDI = Platform Window Handle
;========================================================

MainOnCreate:
    lea rsi, [mainRender]

    sub rsp, 8h
        call InitRender
    add rsp, 8h

    ret

;========================================================
;MainOnTimer - Parameters Sheet
;
;RDI = Timer Id
;========================================================

MainOnTimer:
    cmp rdi, BLINK_TIMER_ID
    je BlinkTick

    cmp rdi, MAIN_INPUT_TIMER_ID
    je InputTick

    ret

    BlinkTick:
        xor [BlinkState], 1
        ret

    InputTick:
        mov rdi, INPUT_TYPE_CONTROLLER
        xor rsi, rsi

        sub rsp, 8h
            call HandleInput
        add rsp, 8h

        ret

;========================================================
;MainOnKeyboard - Parameters Sheet
;
;RDI = Native Key
;========================================================

MainOnKeyboard:
    mov rsi, rdi
    mov rdi, INPUT_TYPE_KEYBOARD

    sub rsp, 8h
        call HandleInput
    add rsp, 8h

    ret

MainOnRender:
    mov rdi, PLATFORM_WINDOW_MAIN
    lea rsi, [mainRender]
    mov edx, 600
    mov ecx, 600

    sub rsp, 8h
        call PlatformBeginWindowRender
    add rsp, 8h

    mov [hDeviceContext], rax

    sub rsp, 8h
        mov rdi, [hDeviceContext]
        lea rsi, [TopHalfRectangle]
        mov edx, 00001100h
        call FillRectangle
    add rsp, 8h

    sub rsp, 8h
        mov rdi, [hDeviceContext]
        lea rsi, [BottomHalfRectangle]
        mov edx, 0077ff00h
        call FillRectangle
    add rsp, 8h

    mov rdi, [hDeviceContext]
    lea rsi, [GameTitleLabel]
    lea rdx, [GameTitleRect]
    mov ecx, 0077ff00h

    sub rsp, 8h
        lea r8, [TitleFont]
        mov r9d, -42
        call DrawHUD
    add rsp, 8h

    cmp [BlinkState], 0
    je SkipPressText

    mov rdi, [hDeviceContext]
    lea rsi, [PressAnyKeyLabel]
    lea rdx, [PressAnyKeyRect]
    mov ecx, 00001100h

    sub rsp, 8h
        lea r8, [SubtitleFont]
        mov r9d, -32
        call DrawHUD
    add rsp, 8h

    SkipPressText:
        mov rdi, PLATFORM_WINDOW_MAIN
        lea rsi, [mainRender]

        sub rsp, 8h
            call PlatformEndWindowRender
        add rsp, 8h

        ret

MainOnClose:
    ret
