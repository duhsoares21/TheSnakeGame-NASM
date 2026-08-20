bits 64
default rel
; =========================================================
; Snake Game - x64 NASM - Snake State Machine System
; =========================================================

%include "snake_data.inc"
%include "snake_state_data.inc"
%include "hud_data.inc"

;========================================
;EXTERNS
;========================================

extern SnakeSize

extern SetupSnake
extern ResetSnake
extern ResetScore
extern MoveSnake
extern GrowSnake
extern ShrinkSnake
extern ResetSnakeSize
extern GetLivesSnake
extern SetLivesSnake
extern RemoveLiveSnake
extern ResetFoodCount
extern IncreaseSnakeSpeed
extern GetSpeedLabel
extern ResetSnakeSpeed
extern IncreaseSpeedLabel
extern ResetSpeedLabel

extern SpawnFood

extern AddScore
extern LoadAudio
extern PlayAudio
extern PlayIntroBGM

extern WallCollision
extern SelfCollision
extern FoodCollision

extern HasSpawnedFood

section .data
	global GetSnakeState
	global SetSnakeState
	global HandleSnakeState

	SnakeState dq SNAKE_STATE_START

	MoveAudio db "audio/move.wav", 0
	MoveAlias db "Move", 0

	EatAudio db "audio/eat.wav", 0
	EatAlias db "Eat", 0

section .text

	GetSnakeState:
		mov rax, [SnakeState]
		ret

	;==================================
	;SetSnakeState - Parameters Sheet
	;
	;RDI = State of the snake
	;==================================

	SetSnakeState:
		mov [SnakeState], rdi
		ret

	HandleSnakeState:
		cmp [SnakeState], SNAKE_STATE_START
		je SnakeStart

		cmp [SnakeState], SNAKE_STATE_ALIVE
		je SnakeAlive

		cmp [SnakeState], SNAKE_STATE_HIT
		je SnakeHit

		cmp [SnakeState], SNAKE_STATE_EATING
		je SnakeEating

		cmp [SnakeState], SNAKE_STATE_DEAD
		je SnakeDead

		SnakeStart:
			sub rsp, 8h
				call SetupSnake
			add rsp, 8h

			mov rdi, SNAKE_STATE_ALIVE

			sub rsp, 8h
				call SetSnakeState
			add rsp, 8h

			sub rsp, 8h
				call PlayIntroBGM
			add rsp, 8h

            lea rdi, [MoveAlias]
            lea rsi, [MoveAudio]

            sub rsp, 8h
                call LoadAudio
            add rsp, 8h

            lea rdi, [EatAlias]
            lea rsi, [EatAudio]

            sub rsp, 8h
                call LoadAudio
            add rsp, 8h

			ret

		SnakeAlive:
			sub rsp, 8h
				call WallCollision
			add rsp, 8h

			sub rsp, 8h
				call SelfCollision
			add rsp, 8h

			cmp [SnakeState], SNAKE_STATE_HIT
			je CollisionDetected

			sub rsp, 8h
				call MoveSnake
			add rsp, 8h

			sub rsp, 8h
				call FoodCollision
			add rsp, 8h

			lea rdi, [MoveAlias]
			mov rsi, 1

            sub rsp, 8h
                call PlayAudio
            add rsp, 8h

			CollisionDetected:

			ret

		SnakeHit: 
			sub rsp, 8h
				call SetupSnake
			add rsp, 8h

			sub rsp, 8h
				call ShrinkSnake
			add rsp, 8h

			sub rsp, 8h
				call GetLivesSnake
			add rsp, 8h

			dec rax
			mov rdi, rax

			sub rsp, 8h
				call SetLivesSnake
			add rsp, 8h

			sub rsp, 8h
				call GetLivesSnake
			add rsp, 8h

			cmp rax, 0
			je SnakeDead

			mov rdi, SNAKE_STATE_ALIVE

			sub rsp, 8h
				call SetSnakeState
			add rsp, 8h

			ret

		SnakeEating:
			
			sub rsp, 8h
				call GrowSnake
			add rsp, 8h

			mov rax, [SnakeSize]

			xor rdx, rdx
			mov rcx, SNAKE_GROWING_SPEED

			div rcx             

			test rdx, rdx
			jz SpeedUp    
			
			jmp DontSpeedUp

			SpeedUp:
				sub rsp, 8h
					call GetSpeedLabel
				add rsp, 8h

				cmp rax, MAXIMUM_SPEED_LABEL
				je DontSpeedUp

				sub rsp, 8h
					call IncreaseSnakeSpeed
				add rsp, 8h

				sub rsp, 8h
					call IncreaseSpeedLabel
				add rsp, 8h

				sub rsp, 8h
					call ResetSnakeSize
				add rsp, 8h

			DontSpeedUp:

			sub rsp, 8h
				call AddScore
			add rsp, 8h

			mov qword [HasSpawnedFood], 0

			sub rsp, 8h
				call SpawnFood
			add rsp, 8h

			mov rdi, SNAKE_STATE_ALIVE

			sub rsp, 8h
				call SetSnakeState
			add rsp, 8h

            lea rdi, [EatAlias]
            mov rsi, 1
			sub rsp, 8h
				call PlayAudio
			add rsp, 8h

			ret

		SnakeDead:
			sub rsp, 8h
				call ResetSnake
			add rsp, 8h

			sub rsp, 8h
				call ResetScore
			add rsp, 8h

			sub rsp, 8h
				call ResetFoodCount
			add rsp, 8h

			sub rsp, 8h
				call ResetSnakeSpeed
			add rsp, 8h

			sub rsp, 8h
				call ResetSpeedLabel
			add rsp, 8h

			sub rsp, 8h
				call SetupSnake
			add rsp, 8h

			mov qword [HasSpawnedFood], 0

			sub rsp, 8h
				call SpawnFood
			add rsp, 8h

			mov rdi, SNAKE_STATE_ALIVE

			sub rsp, 8h
				call SetSnakeState
			add rsp, 8h

			ret
