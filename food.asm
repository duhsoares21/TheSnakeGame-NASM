bits 64
default rel

; =========================================================
; Snake Game - x64 NASM - Main Window
; =========================================================

%include "food_data.inc"
%include "snake_data.inc"
%include "hud_data.inc"

;========================================
;EXTERNS
;========================================

extern DrawTile

extern SnakeTileSize
extern SnakeSize
extern SnakeSegments

section .data

global GetFoodCount
global IncreaseFoodCount
global ResetFoodCount
global SpawnFood
global DrawFood

RandomSeed dq 0

global SpawnPointX
SpawnPointX dq 0

global SpawnPointY
SpawnPointY dq 0

global HasSpawnedFood
HasSpawnedFood dq 0

global FoodCount
FoodCount dq 0

section .text

GetFoodCount:
	mov rax, [FoodCount]
	ret

IncreaseFoodCount:
	mov rax, [FoodCount]
	inc rax
	mov qword [FoodCount], rax
	ret

ResetFoodCount:
	mov qword [FoodCount], 0
	ret

SpawnFood:

	push r12
	push r13
	push r14
	push rbx

	cmp [HasSpawnedFood], 1
	je Finish

	mov rax, [RandomSeed]

    test rax, rax
    jnz RandomGen

    mov rax, [SpawnPointX]

    test rax, rax
    jnz RandomGen

    mov rax, 1

	;========================
	; RANDOM GENERATOR
	;========================

	RandomGen:
		mov rcx, rax
		shl rcx, 13
		xor rax, rcx

		mov rcx, rax
		shr rcx, 7
		xor rax, rcx

		mov rcx, rax
		shl rcx, 17
		xor rax, rcx

		test rax, rax
		jnz SetSpawnPoint

		mov rax, 1

	;========================
	; SPAWN
	;========================

	SetSpawnPoint:
        mov qword [RandomSeed], rax

        xor rdx, rdx
        mov rcx, RANDOM_RANGE
        div rcx
        mov r12, rdx

        mov rax, [RandomSeed]

        mov rcx, rax
        shl rcx, 13
        xor rax, rcx

        mov rcx, rax
        shr rcx, 7
        xor rax, rcx

        mov rcx, rax
        shl rcx, 17
        xor rax, rcx

        test rax, rax
        jnz SaveRandomYSeed

        mov rax, 1

    SaveRandomYSeed:
        mov qword [RandomSeed], rax

        xor rdx, rdx
        mov rcx, RANDOM_RANGE
        div rcx
        mov r13, rdx

		;====================
		;CHECK IF TOUCH SNAKE
		;====================

		xor r14, r14

		imul r12, SNAKE_MOVEMENT_CELL
		imul r13, SNAKE_MOVEMENT_CELL

		LoopSnake:
			
			cmp r14, [SnakeSize]
			je SaveSpawnPoint

			imul rbx, r14, SNAKESEGMENT_size

			lea r11, [rel SnakeSegments]
            add r11, rbx

			cmp r12, [r11 + SNAKESEGMENT.X]

			je CollisionX

			jmp NextCheck

			CollisionX:
				cmp r13, [r11 + SNAKESEGMENT.Y]
				je CollisionY

				jmp NextCheck

			CollisionY:
				jmp RandomGen
		
			NextCheck:
				inc r14
				jmp LoopSnake

	;====================
	;SAVE THE SPAWN POINT
	;====================
	
	SaveSpawnPoint:
		mov qword [SpawnPointX], r12
		mov qword [SpawnPointY], r13

		mov qword [HasSpawnedFood], 1

		jmp Finish

	Finish:
		pop rbx
		pop r14
		pop r13
		pop r12

		ret

;============================
;DrawFood - Parameters Sheet
;
;RDI = Device Context
;============================

DrawFood:
	
	mov rsi, [SpawnPointX]
    mov rdx, [SpawnPointY]
    add rdx, HUD_AREA
    mov ecx, 0000ddffh

	sub rsp, 8h
	    mov rax, [SnakeTileSize]
	    mov r8, rax
		call DrawTile
	add rsp, 8h

	ret
