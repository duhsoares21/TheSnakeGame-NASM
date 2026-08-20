bits 64
default rel
; =========================================================
; Snake Game - x64 NASM - Collision System
; =========================================================

;========================================
;INCLUDES
;========================================

%include "basic_data.inc"
%include "collision_data.inc"
%include "snake_data.inc"
%include "snake_state_data.inc"
%include "hud_data.inc"

;========================================
;EXTERNS
;========================================

extern SetupSnake
extern SetSnakeState

extern GetFoodCount
extern IncreaseFoodCount
extern ResetFoodCount

extern SnakeHeadX
extern SnakeHeadY
extern SnakeSegments
extern SnakeSize
extern SnakeX
extern SnakeY
extern SnakeDirection

extern SpawnPointX
extern SpawnPointY

section .data

global WallCollision
global SelfCollision
global FoodCollision

section .text

WallCollision:
    mov rax, [SnakeHeadX]
    mov rdx, [SnakeHeadY]

    cmp [SnakeDirection], SNAKE_RIGHT_DIRECTION
    je NextRight

    cmp [SnakeDirection], SNAKE_LEFT_DIRECTION
    je NextLeft

    cmp [SnakeDirection], SNAKE_UP_DIRECTION
    je NextUp

    cmp [SnakeDirection], SNAKE_DOWN_DIRECTION
    je NextDown

    NextRight:
        add rax, SNAKE_MOVEMENT_CELL
        jmp CheckBounds
    NextLeft:
        sub rax, SNAKE_MOVEMENT_CELL
        jmp CheckBounds
    NextUp:
        sub rdx, SNAKE_MOVEMENT_CELL
        jmp CheckBounds
    NextDown:
        add rdx, SNAKE_MOVEMENT_CELL
        jmp CheckBounds

    CheckBounds:
        mov r10d, RIGHT_WALL_LIMIT
        sub r10d, SNAKE_MOVEMENT_CELL

        mov r11d, BOTTOM_WALL_LIMIT
        sub r11d, HUD_AREA
        sub r11d, SNAKE_MOVEMENT_CELL

        cmp rax, 0
        jl WallCollisionHit

        cmp rax, r10
        jg WallCollisionHit

        cmp rdx, 0
        jl WallCollisionHit

        cmp rdx, r11
        jg WallCollisionHit

        jmp WallCollisionNotHit

    WallCollisionHit:
        sub rsp, 8h
            mov rdi, SNAKE_STATE_HIT
            call SetSnakeState
        add rsp, 8h
        jmp Cleanup

    WallCollisionNotHit:

        jmp Cleanup

    Cleanup:
        ret

SelfCollision:

    push r14
    push rbx

    mov r14, 1

    LoopSnake:

        cmp r14, [SnakeSize]
        je Finish

        imul rbx, r14, SNAKESEGMENT_size

        lea r11, [rel SnakeSegments]
        add r11, rbx

        mov rax, [SnakeHeadX]
        cmp rax, [r11 + SNAKESEGMENT.X]

        je CollisionX

        jmp NextCheck

	CollisionX:
		mov rcx, [SnakeHeadY]
		cmp rcx, [r11 + SNAKESEGMENT.Y]
		je CollisionY

		jmp NextCheck

	CollisionY:
		sub rsp, 8h
			mov rdi, SNAKE_STATE_HIT
			call SetSnakeState
		add rsp, 8h

		jmp Finish
		
	NextCheck:
		inc r14

		jmp LoopSnake

    Finish:

        pop rbx
        pop r14
        ret

FoodCollision:
	mov rax, [SnakeHeadX]
	
	mov rcx, [SpawnPointX]

	cmp rax, rcx
	je CheckY

	jmp FoodCollisionNotHit

	CheckY:
		mov rax, [SnakeHeadY]
		mov rcx, [SpawnPointY]

		cmp rax, rcx
		je FoodCollisionHit

		jmp FoodCollisionNotHit

	FoodCollisionHit:
		sub rsp, 8h
			mov rdi, SNAKE_STATE_EATING
			call SetSnakeState
		add rsp, 8h

		sub rsp, 8h
			call IncreaseFoodCount
		add rsp, 8h
		ret

	FoodCollisionNotHit:
		ret
