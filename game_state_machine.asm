bits 64
default rel
; =========================================================
; Snake Game - x64 NASM - Game State Machine System
; =========================================================

%include "basic_data.inc"
%include "game_state_data.inc"
%include "input_data.inc"

;========================================
;EXTERNS
;========================================

extern timerValue
extern CurrentKeyPress

extern main
extern Game
extern PlatformHideMainWindow
extern PlatformShowMainWindow
extern PlatformDestroyMainWindow
extern PlatformCloseGameWindow
extern ToggleFPS

;========================================
;ACTIONS
;========================================

extern MoveRight
extern MoveLeft
extern MoveUp
extern MoveDown

section .data

global SetGameState
global HandleGameState
global CallMenu
global IsGamePaused

gameState dq GAME_STATE_MENU

isMainMenuClosed dq 0
paused dq 0

section .text

SetGameState:
	mov [gameState], rdi
	ret

CallMenu:
    jmp MenuLabel

IsGamePaused:
    mov rax, [paused]
    ret

HandleGameState:

	mov r8, [CurrentKeyPress]
    mov qword [CurrentKeyPress], 0

    cmp r8, GAME_INPUT_TOGGLE_FPS
    je ToggleFPSCounter

	cmp [gameState], GAME_STATE_MENU
	je MenuLabel

	cmp [gameState], GAME_STATE_PLAYING
	je PlayingLabel

    cmp r8, 0
    je Return

MenuLabel:
    cmp r8, GAME_INPUT_BACK
    je QuitMenu

    cmp [isMainMenuClosed], 1
    je OpenMenu 

    cmp r8, GAME_INPUT_CONFIRM
    je StartGame

    jmp Return

	StartGame: 

        sub rsp, 8h
            call PlatformHideMainWindow
        add rsp, 8h

        mov qword [isMainMenuClosed], 1

        sub rsp, 8h
            mov rdi, GAME_STATE_PLAYING
            call SetGameState
        add rsp, 8h

        sub rsp, 8h
            call Game
        add rsp, 8h

        jmp Return

        OpenMenu: 
            mov qword [isMainMenuClosed], 0

            sub rsp, 8h
                call PlatformShowMainWindow
            add rsp, 8h

            jmp Return

        QuitMenu:
            sub rsp,8h
                call PlatformDestroyMainWindow
            add rsp,8h

            jmp Return

PlayingLabel:

    cmp r8, GAME_INPUT_RIGHT
    je MovePlayerRight

    cmp r8, GAME_INPUT_LEFT
    je MovePlayerLeft

    cmp r8, GAME_INPUT_UP
    je MovePlayerUp

    cmp r8, GAME_INPUT_DOWN
    je MovePlayerDown

    cmp r8, GAME_INPUT_CONFIRM
    je PauseGame

    cmp r8, GAME_INPUT_PAUSE
    je PauseGame

    cmp r8, GAME_INPUT_BACK
    je QuitGame

	MovePlayerRight:
        sub rsp, 8h
            call MoveRight
        add rsp, 8h
        ret

    MovePlayerLeft:
        sub rsp, 8h
            call MoveLeft
        add rsp, 8h
        ret

    MovePlayerUp:
        sub rsp, 8h
            call MoveUp
        add rsp, 8h
        ret

    MovePlayerDown:
        sub rsp, 8h
            call MoveDown
        add rsp, 8h
        ret

    PauseGame:
    
        cmp [paused], 0
        je DoPause

        DoResume: 

            mov qword [paused], 0

            jmp Return

        DoPause:
            mov qword [paused], 1

            jmp Return

        QuitGame:
            sub rsp,8h
                call PlatformCloseGameWindow
            add rsp,8h

            jmp Return

        ToggleFPSCounter:
            sub rsp, 8h
                call ToggleFPS
            add rsp, 8h

            jmp Return

Return:
    ret
