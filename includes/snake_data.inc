;===============================
; SNAKE DEFAULT STATS
;===============================

SNAKE_TILE_SIZE				equ 20
SNAKE_MOVEMENT_CELL			equ 20
SNAKE_INITIAL_SIZE			equ 5
SNAKE_INITIAL_LIVES			equ 3
SNAKE_DEFAULT_DIRECTION		equ 1
SNAKE_DEFAULT_SPEED			equ 240
SNAKE_SPEED_INCREMENT		equ 10
SNAKE_GROWING_SPEED			equ 30

SNAKE_START_X				equ 40
SNAKE_START_Y				equ 40

;===============================
; SNAKE DIRECTIONS
;===============================

SNAKE_RIGHT_DIRECTION	equ 1
SNAKE_LEFT_DIRECTION	equ 2
SNAKE_UP_DIRECTION		equ 3
SNAKE_DOWN_DIRECTION	equ 4

;===============================
; SNAKE SEGMENT STRUCT
;===============================

struc SNAKESEGMENT
	.X	resq 1
	.Y	resq 1
endstruc