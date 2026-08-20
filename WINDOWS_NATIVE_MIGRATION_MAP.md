# Mapa de migracao do codigo nativo Windows para C

Este documento mapeia o que hoje esta no assembly NASM, mas depende diretamente de Windows/Win32/GDI/XInput, e portanto deve migrar para o wrapper C antes de transformar o core assembly em codigo universal.

Escopo desta etapa:

- Nao mudar ABI ainda.
- Nao alterar a logica do jogo ainda.
- Primeiro remover do assembly as chamadas diretas para APIs Windows.
- Deixar o assembly chamando funcoes de plataforma criadas em C.

## Resumo executivo

Hoje o assembly ainda contem quatro grupos de codigo nativo Windows:

1. Janela, message loop, timers e transicao menu/jogo.
2. Render GDI/backbuffer/texto/fontes.
3. Input Windows/XInput.
4. Audio via `Beep`.

Os arquivos mais afetados sao:

- `main.asm`
- `game.asm`
- `render.asm`
- `hud.asm`
- `input.asm`
- `audio.asm`
- `game_state_machine.asm`
- `collision.asm`, parcialmente
- `snake.asm` e `food.asm`, apenas pela dependencia de desenho

O core assembly idealmente deveria ficar com:

- snake state machine
- game state abstrato
- colisao logica
- movimento
- score
- spawn da comida
- crescimento/encolhimento
- leitura/escrita de estado do jogo

O wrapper C deveria assumir:

- criacao/destruicao de janelas
- loop de mensagens/eventos
- timers ou delta time
- invalidacao/redraw
- backbuffer
- desenho de retangulos
- desenho de texto
- input de teclado/gamepad
- audio
- obtencao da area util da janela

## APIs Windows chamadas diretamente

### Window/app lifecycle

Encontradas em `main.asm`, `game.asm` e `game_state_machine.asm`.

- `GetModuleHandleW`
- `RegisterClassExW`
- `UnregisterClassW`
- `CreateWindowExW`
- `DestroyWindow`
- `ShowWindow`
- `UpdateWindow`
- `DefWindowProcW`
- `GetMessageW`
- `TranslateMessage`
- `DispatchMessageW`
- `PostQuitMessage`
- `PostMessageW`
- `ExitProcess`
- `GetLastError`
- `AdjustWindowRectEx`
- `LoadIconW`

Estas chamadas devem sair do assembly e ir para um modulo C de plataforma, por exemplo `platform_win32.c`.

### Paint/render lifecycle

Encontradas em `main.asm`, `game.asm` e `render.asm`.

- `BeginPaint`
- `EndPaint`
- `GetDC`
- `ReleaseDC`
- `CreateCompatibleDC`
- `CreateCompatibleBitmap`
- `SelectObject`
- `DeleteDC`
- `DeleteObject`
- `BitBlt`
- `CreateSolidBrush`
- `FillRect`

Estas chamadas compoem o backend GDI atual. O assembly deveria chamar apenas funcoes abstratas como:

- `platform_render_begin`
- `platform_render_end`
- `platform_fill_rect`
- `platform_draw_tile`

### Texto/HUD

Encontradas em `hud.asm`, `main.asm` e `game.asm`.

- `CreateFontW`
- `DrawTextW`
- `SetBkMode`
- `SetTextColor`
- `SelectObject`
- `DeleteObject`

O desenho de texto e fontes deveria migrar para C. O assembly pode continuar calculando ou mantendo valores de score/velocidade/vidas, mas nao deveria chamar GDI para renderizar texto.

### Timers/redraw

Encontradas em `main.asm`, `game.asm` e `game_state_machine.asm`.

- `SetTimer`
- `KillTimer`
- `InvalidateRect`

Esse controle deve ir para C. Idealmente o wrapper decide quando chamar o tick/update do jogo, em vez do assembly controlar timers Windows diretamente.

### Client/window metrics

Encontradas em `collision.asm` e `game.asm`.

- `GetClientRect`
- `AdjustWindowRectEx`

`GetClientRect` e qualquer calculo dependente do tamanho real da janela devem migrar para C ou virar parametro fornecido ao core assembly.

O core nao deveria conhecer `HWND` nem chamar `GetClientRect`. Ele deveria receber algo como:

- `playfield_width`
- `playfield_height`
- `hud_height`
- `tile_size`

### Input

Encontrada em `input.asm`.

- `XInputGetState`

Tambem ha uso direto de constantes Windows/XInput:

- `VK_RIGHT`
- `VK_LEFT`
- `VK_UP`
- `VK_DOWN`
- `VK_RETURN`
- `VK_ESCAPE`
- `XINPUT_GAMEPAD_DPAD_RIGHT`
- `XINPUT_GAMEPAD_DPAD_LEFT`
- `XINPUT_GAMEPAD_DPAD_UP`
- `XINPUT_GAMEPAD_DPAD_DOWN`
- `XINPUT_GAMEPAD_START`
- `XINPUT_GAMEPAD_BACK`

O wrapper C deveria transformar eventos nativos em input abstrato do jogo, por exemplo:

- `GAME_INPUT_RIGHT`
- `GAME_INPUT_LEFT`
- `GAME_INPUT_UP`
- `GAME_INPUT_DOWN`
- `GAME_INPUT_CONFIRM`
- `GAME_INPUT_BACK`
- `GAME_INPUT_PAUSE`

### Audio

Encontrada em `audio.asm`.

- `Beep`

O wrapper C deveria expor uma funcao abstrata, por exemplo:

- `platform_play_tone(frequency, duration_ms)`
- ou `platform_play_sound(sound_id)`

## Arquivos e funcoes a migrar

### `main.asm`

Este arquivo e praticamente todo nativo/plataforma.

Responsabilidades atuais:

- cria a janela do menu principal
- registra classe Win32
- carrega icone
- cria fontes
- cria timers
- roda message loop
- processa `WndProc`
- chama render do menu
- chama input
- finaliza processo

APIs Windows usadas:

- `AdjustWindowRectEx`
- `CreateWindowExW`
- `UpdateWindow`
- `TranslateMessage`
- `ShowWindow`
- `SetTimer`
- `KillTimer`
- `RegisterClassExW`
- `GetModuleHandleW`
- `GetMessageW`
- `GetLastError`
- `ExitProcess`
- `DispatchMessageW`
- `DefWindowProcW`
- `PostQuitMessage`
- `InvalidateRect`
- `SelectObject`
- `DeleteObject`
- `CreateFontW`
- `BeginPaint`
- `EndPaint`
- `LoadIconW`

Funcoes/rotulos candidatos a migrar para C:

- `main`
- `MainWndProc`
- criacao da janela do menu
- message loop
- render do menu
- criacao/destruicao de fontes
- timers do menu

O assembly nao deveria manter:

- `mainHWND`
- `hEditInstance`
- `hMainDeviceContext`
- `hDeviceContext`
- `WndClass`
- `Paint`
- `MsgData`
- `rc`
- `mainRender`
- retangulos puramente visuais do menu

Pode permanecer no assembly, se voce quiser manter logica de estados:

- estado atual do menu/jogo
- decisao de iniciar jogo, pausar, sair

Mas a acao concreta de mostrar/esconder/destruir janela deve ser C.

### `game.asm`

Este arquivo mistura logica de jogo com janela/render Windows. E um dos principais candidatos a quebrar em duas partes.

Responsabilidades nativas atuais:

- seed inicial por `rdtsc`
- registra/cria janela do jogo
- processa `WndProc`
- cria render context
- configura timer do jogo
- invalida janela
- executa `BeginPaint`/`EndPaint`
- desenha HUD, comida e cobra
- fecha janela e volta ao menu

APIs Windows usadas:

- `GetModuleHandleW`
- `RegisterClassExW`
- `UnregisterClassW`
- `GetLastError`
- `AdjustWindowRectEx`
- `CreateWindowExW`
- `ShowWindow`
- `UpdateWindow`
- `DefWindowProcW`
- `GetMessageW`
- `TranslateMessage`
- `DispatchMessageW`
- `ExitProcess`
- `SetTimer`
- `KillTimer`
- `InvalidateRect`
- `GetClientRect`
- `DestroyWindow`
- `BeginPaint`
- `EndPaint`

Funcoes/rotulos candidatos a migrar para C:

- `Game`, ao menos a parte de criacao/registro da janela
- `WndProc`
- branch `CreateWindow`
- branch `GameLoop`
- branch `Render`
- branch `CloseGame`
- chamadas para `BeginPaint`/`EndPaint`
- chamadas para `InitRender`/`BeginRender`/`EndRender`
- desenho do HUD

O assembly deveria deixar de manter:

- `gameHWND`
- `hMainDeviceContext`
- `hDeviceContext`
- `hEditInstance`
- `WndClass`
- `Paint`
- `MsgData`
- `rc`
- `ClientRect` local do arquivo, se usado so para janela
- `gameRender`
- retangulos de HUD vinculados a GDI

Pode ficar no assembly:

- score atual
- vidas
- velocidade
- contagem de comidas
- estado da cobra
- estado do jogo
- chamada de update/tick

O render ideal deveria virar uma chamada de alto nivel do C para o assembly, por exemplo:

- C chama `game_render()`
- `game_render()` em assembly chama `platform_fill_rect`/`platform_draw_text`

Ou, numa separacao mais limpa:

- C chama `game_get_render_commands(buffer)`
- C desenha tudo sozinho

### `render.asm`

Este arquivo e 100% backend GDI/Win32 e deveria migrar inteiro para C.

Funcoes atuais:

- `InitRender`
- `BeginRender`
- `EndRender`
- `GetRenderDC`
- `DrawTile`
- `FillRectangle`

APIs Windows usadas:

- `CreateCompatibleDC`
- `CreateCompatibleBitmap`
- `SelectObject`
- `DeleteDC`
- `DeleteObject`
- `BitBlt`
- `CreateSolidBrush`
- `FillRect`
- `GetDC`
- `ReleaseDC`

Recomendacao:

- Remover `render.asm` do core universal.
- Reimplementar estas funcoes em C no backend Win32.
- Manter os mesmos nomes inicialmente para reduzir impacto.

Possivel API C inicial, ainda sem mudar ABI:

- `InitRender(hwnd, render_context*)`
- `BeginRender(render_context*, width, height)`
- `EndRender(hwnd, render_context*)`
- `DrawTile(hdc_or_context, x, y, color)`
- `FillRectangle(hdc_or_context, rect*, color)`

Depois, numa etapa posterior, trocar para nomes neutros:

- `platform_render_init`
- `platform_render_begin`
- `platform_render_end`
- `platform_fill_rect`

### `hud.asm`

Este arquivo mistura duas coisas:

1. logica de score/velocidade/string
2. desenho de texto via GDI

APIs Windows usadas:

- `SetBkMode`
- `SetTextColor`
- `DrawTextW`

Funcoes que deveriam migrar para C:

- `DrawHUD`
- qualquer dependencia de `RECT`
- qualquer dependencia de `DrawTextW`
- formatacao se voce quiser centralizar texto no wrapper

Funcoes que podem permanecer no assembly:

- `AddScore`
- `SetScore`
- `ResetScore`
- `GetSpeedLabel`
- `IncreaseSpeedLabel`
- `ResetSpeedLabel`

Funcao que pode ser reavaliada:

- `ConvertIntToString`

Ela nao e nativa Windows por si so, mas hoje existe para alimentar `DrawTextW`. Se o C passar a desenhar HUD, pode ser mais simples o C ler numeros do core e formatar o texto.

### `input.asm`

Este arquivo tem dependencia direta de XInput e constantes Windows.

API Windows usada:

- `XInputGetState`

Dependencias de constantes:

- virtual keys `VK_*`
- botoes `XINPUT_GAMEPAD_*`
- layout `XINPUT_STATE`

Funcoes candidatas a migrar para C:

- `HandleInput`, se ele continuar lendo teclado/controle nativo
- `ControllerInput`, se continuar interpretando XInput
- `KeyboardInput`, se continuar interpretando `VK_*`

Alternativa recomendada:

- C captura teclado/gamepad.
- C converte para input abstrato.
- Assembly recebe so comandos do jogo.

Exemplo de fronteira:

- `game_handle_input(input_action)`
- `game_set_direction(direction)`
- `game_toggle_pause()`
- `game_confirm()`
- `game_back()`

Nesse desenho, `snake_controller.asm` pode continuar em assembly, porque `MoveRight`, `MoveLeft`, `MoveUp`, `MoveDown` sao logica universal.

### `audio.asm`

Este arquivo tem dependencia direta de Windows.

API Windows usada:

- `Beep`

Funcoes candidatas a migrar para C:

- `PlayNote`

Pode permanecer no assembly:

- `PlayIntroBGM`, se ela for tratada como sequencia logica de notas e chamar `platform_play_tone`.

Mas ha um ponto pratico: `Beep` e chamadas bloqueantes de audio podem travar ou atrasar o update. Ao migrar para C/SDL/nativo, talvez valha transformar audio em eventos:

- assembly chama `platform_play_sound(SOUND_EAT)`
- C decide como tocar

### `game_state_machine.asm`

Este arquivo e majoritariamente logica, mas ainda chama APIs Windows diretamente para mostrar/esconder/destruir janelas e controlar timers.

APIs Windows usadas:

- `SetTimer`
- `KillTimer`
- `ShowWindow`
- `PostMessageW`
- `DestroyWindow`

Partes nativas a migrar:

- `StartGame`: `ShowWindow(mainHWND, SW_HIDE)` e chamada direta de `Game`
- `OpenMenu`: `ShowWindow(mainHWND, SW_SHOW)`
- `QuitMenu`: `DestroyWindow(mainHWND)`
- `PauseGame`: `SetTimer`/`KillTimer`
- `QuitGame`: `PostMessageW(gameHWND, WM_CLOSE, ...)`

O que deveria ficar no assembly:

- `gameState`
- `paused`
- decisao de transicao de estado
- chamada de `MoveRight/MoveLeft/MoveUp/MoveDown`

O wrapper C deveria expor acoes abstratas:

- `platform_start_game_window`
- `platform_show_menu`
- `platform_close_menu`
- `platform_close_game`
- `platform_pause_game_timer`
- `platform_resume_game_timer`

Ou, melhor ainda, o assembly apenas retorna/intenciona eventos:

- `GAME_EVENT_START`
- `GAME_EVENT_SHOW_MENU`
- `GAME_EVENT_QUIT`
- `GAME_EVENT_PAUSE`
- `GAME_EVENT_RESUME`

E o C executa as acoes.

### `collision.asm`

Este arquivo e quase todo logica universal, com uma excecao importante.

APIs Windows usadas:

- `GetClientRect`
- `GetLastError`

Trecho dependente de Windows:

- `WallCollision` usa `gameHWND` e `GetClientRect` para descobrir limites reais da janela.

Recomendacao:

- Remover `GetClientRect` do assembly.
- O C deve passar o tamanho jogavel para o core.
- `WallCollision` deve comparar contra valores logicos do jogo, nao contra `HWND`.

Exemplo de estado/plataforma:

- `GameAreaWidth = 600`
- `GameAreaHeight = 600`
- `HudHeight = 45`
- ou `PlayfieldWidth`/`PlayfieldHeight`

Depois disso, `collision.asm` pode permanecer no core assembly.

### `snake.asm`

Este arquivo e majoritariamente universal, exceto pelo desenho.

Dependencia indireta de plataforma:

- `DrawSnake` chama `DrawTile`

Funcoes candidatas a manter no assembly:

- `ResetSnake`
- `SetupSnake`
- `MoveSnake`
- `GrowSnake`
- `ShrinkSnake`
- `ResetSnakeSize`
- `GetLivesSnake`
- `SetLivesSnake`
- `AddLiveSnake`
- `RemoveLiveSnake`
- `GetSnakeSpeed`
- `SetSnakeSpeed`
- `ResetSnakeSpeed`
- `IncreaseSnakeSpeed`

Funcao a reavaliar:

- `DrawSnake`

Opcoes:

1. Manter `DrawSnake` em assembly, mas trocar `DrawTile` por `platform_draw_tile`.
2. Remover desenho do assembly e deixar C iterar os segmentos via API de leitura.
3. Assembly gerar comandos de render para C consumir.

Para uma migracao incremental, a opcao 1 e a menos invasiva.

### `food.asm`

Este arquivo e majoritariamente universal, exceto pelo desenho.

Dependencia indireta de plataforma:

- `DrawFood` chama `DrawTile`

Funcoes que podem permanecer no assembly:

- `GetFoodCount`
- `IncreaseFoodCount`
- `ResetFoodCount`
- `SpawnFood`

Funcao a reavaliar:

- `DrawFood`

Como em `snake.asm`, a opcao incremental e manter `DrawFood`, mas fazer ela chamar uma funcao C neutra, como `platform_draw_tile`.

### `snake_controller.asm`

Este arquivo nao chama Windows diretamente.

Pode permanecer no assembly:

- `MoveRight`
- `MoveLeft`
- `MoveUp`
- `MoveDown`

O unico cuidado e que ele nao deveria receber `VK_*` nem `XINPUT_*` diretamente no futuro. Ele deveria receber direcao abstrata ja processada pelo wrapper/input layer.

### `snake_state_machine.asm`

Este arquivo nao chama Windows diretamente.

Pode permanecer no assembly:

- `GetSnakeState`
- `SetSnakeState`
- `HandleSnakeState`

Dependencias indiretas a observar:

- chama `PlayNote` e `PlayIntroBGM`, que hoje acabam em `Beep`
- chama `WallCollision`, que hoje usa `GetClientRect`
- chama `SpawnFood`, `MoveSnake`, `GrowSnake`, etc.

Depois que audio e wall metrics forem abstraidos, este arquivo pode continuar no core universal.

## Arquivos `.inc` com dados Windows

### `basic_data.inc`

Contem estruturas/tipos Windows ou equivalentes:

- `RECT`
- `PAINTSTRUCT`
- `HWND`
- `HDC`
- `HINSTANCE`
- constantes de timer

Recomendacao:

- Remover do core universal tudo que represente `HWND`, `HDC`, `HINSTANCE`, `PAINTSTRUCT`.
- `RECT` pode continuar existindo apenas se virar uma estrutura generica do jogo, sem dependencia semantica de Win32.

### `window_data.inc`

Contem dados/constantes ligados a Win32 windowing:

- `WNDCLASSEXW`
- estilos de janela
- mensagens Windows
- parametros de `CreateWindowExW`
- constantes como `WM_*`, `SW_*`, `HT*`, etc.

Recomendacao:

- Deve migrar para C ou ficar restrito ao backend Win32.
- Nao deveria ser incluido pelo core assembly universal.

### `input_data.inc`

Contem constantes e estruturas de input Windows/XInput.

Recomendacao:

- Separar constantes universais de input do jogo das constantes nativas.
- `VK_*`, `XINPUT_*` e `XINPUT_STATE` devem ir para C/backend.
- O core deve receber enums proprios do jogo.

### `render_data.inc`

Contem `RENDER_CONTEXT`, atualmente acoplado ao backend GDI:

- `WindowDC`
- `RenderDC`
- `BackBitmap`
- `OldBitmap`
- `ScreenWidth`
- `ScreenHeight`

Recomendacao:

- Migrar para C/backend Win32.
- O core assembly nao deveria conhecer DC/bitmap.

## Fronteira C sugerida para a primeira etapa

Para reduzir risco, a primeira etapa pode manter os nomes parecidos com os atuais, mas implementados em C:

- `InitRender`
- `BeginRender`
- `EndRender`
- `GetRenderDC`
- `DrawTile`
- `FillRectangle`
- `DrawHUD`
- `PlayNote`

Isso permite mover bastante codigo nativo para C sem redesenhar toda a arquitetura de uma vez.

Depois, numa etapa posterior, pode trocar para API neutra:

- `platform_window_create_menu`
- `platform_window_create_game`
- `platform_window_destroy`
- `platform_window_show`
- `platform_window_hide`
- `platform_request_redraw`
- `platform_timer_start`
- `platform_timer_stop`
- `platform_render_begin`
- `platform_render_end`
- `platform_fill_rect`
- `platform_draw_text`
- `platform_play_tone`
- `platform_get_playfield_size`

## Ordem de migracao recomendada

### Etapa 1: Render

Mover `render.asm` para C mantendo os mesmos exports:

- `InitRender`
- `BeginRender`
- `EndRender`
- `GetRenderDC`
- `DrawTile`
- `FillRectangle`

Motivo: e isolado, muito nativo, e `snake.asm`/`food.asm` podem continuar chamando as mesmas funcoes.

### Etapa 2: HUD/texto

Mover `DrawHUD` para C.

Manter inicialmente score/speed/count em assembly.

Motivo: remove GDI de `hud.asm` sem mexer ainda na logica do score.

### Etapa 3: Audio

Mover `PlayNote` para C.

Opcionalmente manter `PlayIntroBGM` em assembly chamando `PlayNote`.

Motivo: remove `Beep` direto do assembly com baixo impacto.

### Etapa 4: Input

Mover leitura de teclado/XInput para C.

O assembly deve receber comandos abstratos ou continuar recebendo os mesmos valores durante transicao.

Motivo: input e uma area onde SDL/Win32/Linux/macOS vao divergir bastante.

### Etapa 5: Window/timers/message loop

Mover `main.asm`, `game.asm` windowing e `game_state_machine.asm` platform actions para C.

Motivo: e a parte com maior superficie e maior risco, entao vale deixar para depois que render/input/audio ja estiverem isolados.

### Etapa 6: ClientRect/collision boundary

Remover `GetClientRect` de `collision.asm`.

O C passa dimensoes logicas para o core.

Motivo: evita que a logica de colisao dependa de `HWND` e tambem elimina a classe de bugs causada por diferenca entre tamanho de janela e area interna.

## O que nao precisa migrar agora

Estes arquivos/funcoes podem continuar em assembly na etapa atual:

- `snake.asm`, exceto desenho se voce decidir mover depois
- `food.asm`, exceto desenho se voce decidir mover depois
- `snake_controller.asm`
- `snake_state_machine.asm`, depois de abstrair audio/wall metrics
- partes logicas de `hud.asm`
- partes logicas de `game_state_machine.asm`
- `collision.asm`, depois de remover `GetClientRect`

## Ponto de arquitetura importante

O objetivo nao e simplesmente trocar chamadas WinAPI por chamadas C equivalentes. O objetivo e impedir que conceitos nativos vazem para o core.

Evitar no core assembly:

- `HWND`
- `HDC`
- `HINSTANCE`
- `RECT` como Win32
- `PAINTSTRUCT`
- `WNDCLASSEXW`
- `WM_*`
- `VK_*`
- `XINPUT_*`
- `SetTimer`/`KillTimer`
- `BeginPaint`/`EndPaint`

Preferir no core assembly:

- coordenadas logicas
- tamanho de grid
- input abstrato
- eventos de jogo
- comandos simples de render
- callbacks/funcoes `platform_*`

## Checklist de migracao

- [x] Mover backend GDI de `render.asm` para C.
- [x] Mover `DrawHUD`/texto/fontes para C.
- [x] Mover `PlayNote`/audio Windows para C.
- [x] Remover `GetClientRect` de `collision.asm`.
- [ ] Mover `XInputGetState` e traducao de teclado/gamepad para C.
- [ ] Mover criacao de janelas/menu/game para C.
- [ ] Mover message loop para C.
- [ ] Mover timers/redraw para C.
- [ ] Remover `window_data.inc` do core assembly.
- [ ] Remover handles Win32 globais do core assembly.
- [ ] Definir uma API `platform_*` estavel antes da conversao para System V.
