bits 64
default rel
; =========================================================
; Snake Game - x64 NASM - Main Window
; =========================================================

%include "basic_data.inc"
%include "window_data.inc"
%include "render_data.inc"
%include "snake_data.inc"
%include "snake_state_data.inc"
%include "game_state_data.inc"
%include "hud_data.inc"
%include "input_data.inc"

extern PlatformCreateGameWindow
extern PlatformBeginWindowRender
extern PlatformEndWindowRender
extern PlatformGetFPS
extern PlatformGetInputLabel

extern InitRender

extern HandleSnakeState
extern DrawSnake
extern FillRectangle

extern HandleInput
extern SetGameState
extern IsGamePaused

extern DrawFood
extern GetFoodCount
extern GetSnakeSpeed

extern CallMenu

extern snakeCounter
extern SnakeSize
extern SpawnPointX
extern SpawnPointY
extern HasSpawnedFood

extern CurrentScore
extern ConvertIntToString
extern ScoreText
extern FoodCountText

extern LiveText
extern SnakeLives

extern CurrentSpeed
extern SpeedText

extern InputType
extern CurrentKeyPress

extern timerValue

extern DrawHUD

extern ResetSnake
extern ResetSnakeSpeed
extern ResetSpeedLabel
extern ResetScore
extern ResetFoodCount
extern SetSnakeState
extern SetupSnake

section .data

HUDFont db "C:\Windows\Fonts\arial.ttf", 0

HUDFontSize dd -12

ScoreLabel      db "Score",0
FoodLabel      db "Food",0
SpeedLabel      db "Speed",0
LivesLabel      db "Lives",0
FPSLabel        db "FPS",0
InputLabel      db "Input",0

XboxControllerLabel db "XBOX CONTROLLER",0
KeyboardLabel db "KEYBOARD",0
FPSText db "0000000000",0

ScoreLabelRect:
    istruc RECT
        at RECT.left,   dd 0
        at RECT.top,    dd 5
        at RECT.right,  dd 50
        at RECT.bottom, dd 100
    iend

ScoreRect:
    istruc RECT
        at RECT.left,   dd 0
        at RECT.top,    dd 25
        at RECT.right,  dd 90
        at RECT.bottom, dd 100
    iend

FoodLabelRect:
    istruc RECT
        at RECT.left,   dd 150
        at RECT.top,    dd 5
        at RECT.right,  dd 80
        at RECT.bottom, dd 100
    iend

FoodRect:
    istruc RECT
        at RECT.left,   dd 150
        at RECT.top,    dd 25
        at RECT.right,  dd 80
        at RECT.bottom, dd 100
    iend

SpeedLabelRect:
    istruc RECT
        at RECT.left,   dd 320
        at RECT.top,    dd 5
        at RECT.right,  dd 80
        at RECT.bottom, dd 100
    iend

SpeedRect:
    istruc RECT
        at RECT.left,   dd 320
        at RECT.top,    dd 25
        at RECT.right,  dd 80
        at RECT.bottom, dd 100
    iend

LivesLabelRect:
    istruc RECT
        at RECT.left,   dd 640
        at RECT.top,    dd 5
        at RECT.right,  dd 80
        at RECT.bottom, dd 100
    iend

LivesRect:
    istruc RECT
        at RECT.left,   dd 640
        at RECT.top,    dd 25
        at RECT.right,  dd 80
        at RECT.bottom, dd 100
    iend

InputTypeRect:
    istruc RECT
        at RECT.left,   dd 390
        at RECT.top,    dd 25
        at RECT.right,  dd 600
        at RECT.bottom, dd 45
    iend

InputLabelRect:
    istruc RECT
        at RECT.left,   dd 390
        at RECT.top,    dd 5
        at RECT.right,  dd 600
        at RECT.bottom, dd 25
    iend

FPSLabelRect:
    istruc RECT
        at RECT.left,   dd 550
        at RECT.top,    dd 5
        at RECT.right,  dd 580
        at RECT.bottom, dd 45
    iend

FPSRect:
    istruc RECT
        at RECT.left,   dd 530
        at RECT.top,    dd 25
        at RECT.right,  dd 600
        at RECT.bottom, dd 45
    iend

HUDRectangle:
    istruc RECT
        at RECT.left,   dd 0
        at RECT.top,    dd 0
        at RECT.right,  dd 600
        at RECT.bottom, dd HUD_AREA
    iend

ScreenRectangle:
    istruc RECT
        at RECT.left,   dd 0
        at RECT.top,    dd HUD_AREA
        at RECT.right,  dd 600
        at RECT.bottom, dd 645
    iend

hDeviceContext: HDC 0

gameRender:
    istruc RENDER_CONTEXT
        at RENDER_CONTEXT.WindowDC,     dq 0
        at RENDER_CONTEXT.RenderDC,     dq 0
        at RENDER_CONTEXT.BackBitmap,   dq 0
        at RENDER_CONTEXT.OldBitmap,    dq 0
        at RENDER_CONTEXT.ScreenWidth,  dq 600
        at RENDER_CONTEXT.ScreenHeight, dq 645
    iend

elapsedTime dq 0
ShowFPS dq 0

global Game
global GameOnCreate
global GameOnTimer
global GameOnKeyboard
global GameOnRender
global GameOnClose
global ToggleFPS

section .text

Game:
    ; ----------------------------------------
    ; Seed for the Random Generator
    ; ----------------------------------------

    rdtsc
    shl rdx, 32
    or rax, rdx

    test rax, rax
    jnz SetSpawnPointX

    mov rax, 1

    SetSpawnPointX:
        mov qword [SpawnPointX], rax

    rdtsc
    shl rdx, 32
    or rax, rdx

    test rax, rax
    jnz SetSpawnPointY

    mov rax, 1

    SetSpawnPointY:
        mov qword [SpawnPointY], rax

    mov qword [HasSpawnedFood], 0

    mov rdi, 600
    mov rsi, 645

    sub rsp, 8h
        call PlatformCreateGameWindow
    add rsp, 8h

    ret

;========================================================
;GameOnCreate - Parameters Sheet
;
;RDI = Platform Window Handle
;========================================================

GameOnCreate:
    lea rsi, [gameRender]

    sub rsp, 8h
        call InitRender
    add rsp, 8h

    ret

;========================================================
;GameOnTimer - Parameters Sheet
;
;RDI = Timer Id
;========================================================

GameOnTimer:
    mov rdi, INPUT_TYPE_CONTROLLER
    xor rsi, rsi

    sub rsp, 8h
        call HandleInput
    add rsp, 8h

    sub rsp, 8h
        call IsGamePaused
    add rsp, 8h

    cmp rax, 1
    je ContinueTimer

    mov rax, [elapsedTime]
    add rax, [timerValue]
    mov [elapsedTime], rax

    sub rsp, 8h
        call GetSnakeSpeed
    add rsp, 8h

    cmp [elapsedTime], rax
    jl ContinueTimer

    sub rsp, 8h
        call HandleSnakeState
        mov qword [elapsedTime], 0
    add rsp, 8h

    ContinueTimer:
        ret

;========================================================
;GameOnKeyboard - Parameters Sheet
;
;RDI = Native Key
;========================================================

GameOnKeyboard:
    mov rsi, rdi
    mov rdi, INPUT_TYPE_KEYBOARD

    sub rsp, 8h
        call HandleInput
    add rsp, 8h

    ret

GameOnRender:
    mov rdi, PLATFORM_WINDOW_GAME
    lea rsi, [gameRender]
    mov edx, 600
    mov ecx, 645

    sub rsp, 8h
        call PlatformBeginWindowRender
    add rsp, 8h

    mov [hDeviceContext], rax

    LabelDrawHUD:
        sub rsp, 8h
            mov rdi, [hDeviceContext]
            lea rsi, [ScreenRectangle]
            mov edx, 00FFFFFFh
            call FillRectangle
        add rsp, 8h

        sub rsp, 8h
            mov rdi, [hDeviceContext]
            lea rsi, [HUDRectangle]
            mov edx, 00000000h
            call FillRectangle
        add rsp, 8h

        mov rdi, [hDeviceContext]
        lea rsi, [ScoreLabel]
        lea rdx, [ScoreLabelRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        sub rsp, 8h
            mov rdi, [CurrentScore]
            mov rsi, 10
            lea rdx, [ScoreText]
            call ConvertIntToString
        add rsp, 8h

        mov rdi, [hDeviceContext]
        lea rsi, [ScoreText]
        lea rdx, [ScoreRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        mov rdi, [hDeviceContext]
        lea rsi, [FoodLabel]
        lea rdx, [FoodLabelRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        sub rsp, 8h
            call GetFoodCount
        add rsp, 8h

        mov rdi, rax
        mov rsi, 5
        lea rdx, [FoodCountText]

        sub rsp, 8h
            call ConvertIntToString
        add rsp, 8h

        mov rdi, [hDeviceContext]
        lea rsi, [FoodCountText]
        lea rdx, [FoodRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        mov rdi, [hDeviceContext]
        lea rsi, [SpeedLabel]
        lea rdx, [SpeedLabelRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        mov rdi, [hDeviceContext]
        mov rdx, [CurrentSpeed]
        add dl, '0'
        mov [SpeedText], dl

        lea rsi, [SpeedText]
        lea rdx, [SpeedRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        mov rdi, [hDeviceContext]
        lea rsi, [LivesLabel]
        lea rdx, [LivesLabelRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        mov rdi, [hDeviceContext]
        mov rdx, [SnakeLives]
        add dl, '0'
        mov [LiveText], dl

        lea rsi, [LiveText]
        lea rdx, [LivesRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        mov rdi, [hDeviceContext]
        lea rsi, [InputLabel]
        lea rdx, [InputLabelRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        mov rdi, [InputType]

        sub rsp, 8h
            call PlatformGetInputLabel
        add rsp, 8h

        mov rdi, [hDeviceContext]
        mov rsi, rax

        DrawInputType:
            lea rdx, [InputTypeRect]
            mov ecx, 00FFFFFFh

            sub rsp, 8h
                lea r8, [HUDFont]
                mov r9d, [HUDFontSize]
                call DrawHUD
            add rsp, 8h

        cmp qword [ShowFPS], 1
        jne DrawFoodLabel

        mov rdi, [hDeviceContext]
        lea rsi, [FPSLabel]
        lea rdx, [FPSLabelRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

        sub rsp, 8h
            call PlatformGetFPS
        add rsp, 8h

        mov rdi, rax
        mov rsi, 10
        lea rdx, [FPSText]

        sub rsp, 8h
            call ConvertIntToString
        add rsp, 8h

        mov rdi, [hDeviceContext]
        lea rsi, [FPSText + 7]
        lea rdx, [FPSRect]
        mov ecx, 00FFFFFFh

        sub rsp, 8h
            lea r8, [HUDFont]
            mov r9d, [HUDFontSize]
            call DrawHUD
        add rsp, 8h

    DrawFoodLabel:
        sub rsp, 8h
            mov rdi, [hDeviceContext]
            call DrawFood
        add rsp, 8h

        mov qword [snakeCounter], 0
        xor rax, rax

    LabelDrawSnake:
        cmp rax, [SnakeSize]
        jge LabelEndPaint

        mov rdi, [hDeviceContext]

        sub rsp, 8h
            call DrawSnake
        add rsp, 8h

        mov rax, [snakeCounter]
        inc rax
        mov [snakeCounter], rax
        jmp LabelDrawSnake

    LabelEndPaint:
        mov rdi, PLATFORM_WINDOW_GAME
        lea rsi, [gameRender]

        sub rsp, 8h
            call PlatformEndWindowRender
        add rsp, 8h

        ret

GameOnClose:
    sub rsp, 8h
        call ResetSnake
    add rsp, 8h

    sub rsp, 8h
        call ResetScore
    add rsp, 8h

    sub rsp, 8h
        call ResetFoodCount
    add rsp, 8h

    mov qword [HasSpawnedFood], 0

    sub rsp, 8h
        call ResetSnakeSpeed
    add rsp, 8h

    sub rsp, 8h
        call ResetSpeedLabel
    add rsp, 8h

    sub rsp, 8h
        mov rdi, SNAKE_STATE_START
        call SetSnakeState
    add rsp, 8h

    sub rsp, 8h
        call SetupSnake
    add rsp, 8h

    mov qword [CurrentKeyPress], 0

    sub rsp, 8h
        mov rdi, GAME_STATE_MENU
        call SetGameState
    add rsp, 8h

    sub rsp, 8h
        call CallMenu
    add rsp, 8h

    ret

ToggleFPS:
    xor qword [ShowFPS], 1
    ret
