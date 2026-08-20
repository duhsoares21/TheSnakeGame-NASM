#include <Windows.h>
#include <Xinput.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <SDL3/SDL.h>

#include "platform.h"

//=======================================
// RENDER - WIN32 (GDI)
//======================================

struct RENDER_CONTEXT
{
    HDC     WindowDC;
    HDC     RenderDC;
    HBITMAP BackBitmap;
    HBITMAP OldBitmap;
    uint64_t ScreenWidth;
    uint64_t ScreenHeight;
};

struct U_RECT
{
    LONG left;
    LONG top;
    LONG right;
    LONG bottom;
};

struct SOUND
{
    const char *alias;
    SDL_AudioStream *stream;
    Uint8 *data;
    Uint32 length;
};

#define MAX_AUDIO_SOUNDS 32

static SOUND AudioSounds[MAX_AUDIO_SOUNDS];
static int AudioSoundCount = 0;
static bool SDLInitialized = false;

//=======================================
// WINDOW - WIN32
//======================================

extern PLATFORM_ABI void MainOnCreate(PlatformHandle windowHandle);
extern PLATFORM_ABI void MainOnTimer(uint64_t timerId);
extern PLATFORM_ABI void MainOnKeyboard(uint64_t key);
extern PLATFORM_ABI void MainOnRender(void);
extern PLATFORM_ABI void MainOnClose(void);

extern PLATFORM_ABI void GameOnCreate(PlatformHandle windowHandle);
extern PLATFORM_ABI void GameOnTimer(uint64_t timerId);
extern PLATFORM_ABI void GameOnKeyboard(uint64_t key);
extern PLATFORM_ABI void GameOnRender(void);
extern PLATFORM_ABI void GameOnClose(void);

#define BLINK_TIMER_ID 1
#define MAIN_INPUT_TIMER_ID 2
#define GAME_INPUT_TIMER_ID 3
#define BLINK_FREQUENCY_MS 500
#define INPUT_FREQUENCY_MS 16

static HWND MainWindow = NULL;
static HWND GameWindow = NULL;
static bool MainWindowVisible = false;
static bool GameWindowVisible = false;
static bool GameTimerRunning = false;
static bool PlatformRunning = true;
static uint64_t GameTimerValue = INPUT_FREQUENCY_MS;

static HDC MainPaintDC = NULL;
static HDC GamePaintDC = NULL;
static LARGE_INTEGER GameFPSFrequency;
static LARGE_INTEGER LastGameFPSCounter;
static uint64_t GameFrameCounter = 0;
static uint64_t GameCurrentFPS = 0;
static bool GameFPSInitialized = false;
static RENDER_CONTEXT *MainRenderContext = NULL;
static RENDER_CONTEXT *GameRenderContext = NULL;

static const wchar_t MainClassName[] = L"Main";
static const wchar_t MainWindowTitle[] = L"Main Menu - Snake Game";
static const wchar_t GameWindowTitle[] = L"Playing - Snake Game";

PLATFORM_ABI void BeginRender(RENDER_CONTEXT *context, int32_t right, int32_t bottom);
PLATFORM_ABI void EndRender(PlatformHandle deviceContext, RENDER_CONTEXT *context);
HDC GetRenderDC(RENDER_CONTEXT *context);

static LRESULT CALLBACK MainWindowProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam);

static void CleanupAudio(void)
{
    for (int i = 0; i < AudioSoundCount; ++i) {
        if (AudioSounds[i].stream) {
            SDL_DestroyAudioStream(AudioSounds[i].stream);
            AudioSounds[i].stream = NULL;
        }

        if (AudioSounds[i].data) {
            SDL_free(AudioSounds[i].data);
            AudioSounds[i].data = NULL;
        }

        AudioSounds[i].alias = NULL;
        AudioSounds[i].length = 0;
    }

    AudioSoundCount = 0;
}

static void CleanupRenderContext(RENDER_CONTEXT *context)
{
    if (!context) {
        return;
    }

    if (context->RenderDC) {
        if (context->OldBitmap) {
            SelectObject(context->RenderDC, (HGDIOBJ)context->OldBitmap);
        }

        DeleteDC(context->RenderDC);
        context->RenderDC = NULL;
    }

    if (context->BackBitmap) {
        DeleteObject(context->BackBitmap);
        context->BackBitmap = NULL;
    }

    if (context->WindowDC) {
        HWND window =
                WindowFromDC(context->WindowDC);

        if (window) {
            ReleaseDC(window, context->WindowDC);
        }

        context->WindowDC = NULL;
    }

    context->OldBitmap = NULL;
}

static void CleanupPlatform(void)
{
    CleanupAudio();
    CleanupRenderContext(GameRenderContext);
    CleanupRenderContext(MainRenderContext);

    GameRenderContext = NULL;
    MainRenderContext = NULL;

    if (SDLInitialized) {
        SDL_Quit();
        SDLInitialized = false;
    }
}

static void ResizePlatformWindow(HWND window, int32_t width, int32_t height)
{
    RECT rect = {
            .left = 0,
            .top = 0,
            .right = width,
            .bottom = height
    };

    DWORD style =
            (DWORD)GetWindowLongPtrW(
                    window,
                    GWL_STYLE
            );

    DWORD exStyle =
            (DWORD)GetWindowLongPtrW(
                    window,
                    GWL_EXSTYLE
            );

    AdjustWindowRectEx(&rect, style, FALSE, exStyle);

    SetWindowPos(
            window,
            NULL,
            0,
            0,
            rect.right - rect.left,
            rect.bottom - rect.top,
            SWP_NOMOVE | SWP_NOZORDER
    );
}

static void UpdateGameFPS(void)
{
    LARGE_INTEGER currentCounter;

    if (!GameFPSInitialized) {
        QueryPerformanceFrequency(&GameFPSFrequency);
        QueryPerformanceCounter(&LastGameFPSCounter);
        GameFPSInitialized = true;
    }

    ++GameFrameCounter;
    QueryPerformanceCounter(&currentCounter);

    uint64_t elapsed =
            currentCounter.QuadPart -
            LastGameFPSCounter.QuadPart;

    if (elapsed >= (uint64_t)GameFPSFrequency.QuadPart) {
        GameCurrentFPS =
                (GameFrameCounter * (uint64_t)GameFPSFrequency.QuadPart) /
                elapsed;

        GameFrameCounter = 0;
        LastGameFPSCounter = currentCounter;
    }
}

static uint64_t GetPerformanceTicksFromMilliseconds(
        LARGE_INTEGER frequency,
        uint64_t milliseconds
)
{
    return ((uint64_t)frequency.QuadPart * milliseconds) / 1000;
}

static bool RegisterPlatformWindowClass(const wchar_t *className, WNDPROC windowProc)
{
    WNDCLASSEXW windowClass;

    windowClass.cbSize = sizeof(windowClass);
    windowClass.style = 0;
    windowClass.lpfnWndProc = windowProc;
    windowClass.cbClsExtra = 0;
    windowClass.cbWndExtra = 0;
    windowClass.hInstance = GetModuleHandleW(NULL);
    windowClass.hIcon = LoadIconW(windowClass.hInstance, MAKEINTRESOURCEW(101));
    windowClass.hCursor = NULL;
    windowClass.hbrBackground = NULL;
    windowClass.lpszMenuName = NULL;
    windowClass.lpszClassName = className;
    windowClass.hIconSm = windowClass.hIcon;

    if (RegisterClassExW(&windowClass)) {
        return true;
    }

    return GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}

static HWND CreatePlatformWindow(
        const wchar_t *className,
        const wchar_t *windowTitle,
        WNDPROC windowProc,
        int32_t width,
        int32_t height
)
{
    if (!RegisterPlatformWindowClass(className, windowProc)) {
        return NULL;
    }

    RECT rect = {
            .left = 0,
            .top = 0,
            .right = width,
            .bottom = height
    };

    DWORD style =
            WS_CAPTION |
            WS_SYSMENU |
            WS_MINIMIZEBOX;

    AdjustWindowRectEx(&rect, style, FALSE, 0);

    return CreateWindowExW(
            0,
            className,
            windowTitle,
            style,
            650,
            200,
            rect.right - rect.left,
            rect.bottom - rect.top,
            NULL,
            NULL,
            GetModuleHandleW(NULL),
            NULL
    );
}

PLATFORM_ABI bool PlatformCreateMainWindow(int32_t width, int32_t height)
{
    MainWindow =
            CreatePlatformWindow(
                    MainClassName,
                    MainWindowTitle,
                    MainWindowProc,
                    width,
                    height
            );

    if (!MainWindow) {
        return false;
    }

    ShowWindow(MainWindow, SW_SHOW);
    UpdateWindow(MainWindow);
    MainWindowVisible = true;

    return true;
}

PLATFORM_ABI bool PlatformCreateGameWindow(int32_t width, int32_t height)
{
    if (!MainWindow) {
        return false;
    }

    GameWindow = MainWindow;
    MainWindowVisible = false;
    GameWindowVisible = true;
    GameTimerRunning = true;
    GameTimerValue = INPUT_FREQUENCY_MS;

    SetWindowTextW(MainWindow, GameWindowTitle);
    ResizePlatformWindow(MainWindow, width, height);

    GameOnCreate((PlatformHandle)MainWindow);
    GameOnRender();
    GdiFlush();

    return true;
}

PLATFORM_ABI void PlatformRunMessageLoop(void)
{
    MSG message;
    LARGE_INTEGER frequency;
    LARGE_INTEGER lastCounter;

    QueryPerformanceFrequency(&frequency);
    QueryPerformanceCounter(&lastCounter);

    uint64_t blinkTicks =
            GetPerformanceTicksFromMilliseconds(
                    frequency,
                    BLINK_FREQUENCY_MS
            );

    uint64_t inputTicks =
            GetPerformanceTicksFromMilliseconds(
                    frequency,
                    INPUT_FREQUENCY_MS
            );

    uint64_t renderTicks =
            (uint64_t)frequency.QuadPart / 60;

    uint64_t blinkAccumulator = 0;
    uint64_t mainInputAccumulator = 0;
    uint64_t gameInputAccumulator = 0;
    uint64_t renderAccumulator = 0;

    while (PlatformRunning) {
        uint64_t frameStart =
                0;

        LARGE_INTEGER frameCounter;
        QueryPerformanceCounter(&frameCounter);
        frameStart = frameCounter.QuadPart;

        while (PeekMessageW(&message, NULL, 0, 0, PM_REMOVE)) {
            if (message.message == WM_QUIT) {
                PlatformRunning = false;
                break;
            }

            TranslateMessage(&message);
            DispatchMessageW(&message);
        }

        LARGE_INTEGER currentCounter;
        QueryPerformanceCounter(&currentCounter);

        uint64_t delta =
                currentCounter.QuadPart -
                lastCounter.QuadPart;

        lastCounter = currentCounter;

        if (delta > renderTicks) {
            delta = renderTicks;
        }

        blinkAccumulator += delta;
        mainInputAccumulator += delta;
        gameInputAccumulator += delta;
        renderAccumulator += delta;

        if (MainWindowVisible) {
            if (blinkAccumulator >= blinkTicks) {
                MainOnTimer(BLINK_TIMER_ID);
                blinkAccumulator = 0;
            }

            if (MainWindowVisible && mainInputAccumulator >= inputTicks) {
                MainOnTimer(MAIN_INPUT_TIMER_ID);
                mainInputAccumulator -= inputTicks;
            }

            if (MainWindowVisible && renderAccumulator >= renderTicks) {
                MainOnRender();
                renderAccumulator -= renderTicks;
            }
        }

        if (GameWindowVisible) {
            uint64_t gameInputTicks =
                    GetPerformanceTicksFromMilliseconds(
                            frequency,
                            GameTimerValue
                    );

            if (GameTimerRunning) {
                if (GameWindowVisible && GameTimerRunning && gameInputAccumulator >= gameInputTicks) {
                    GameOnTimer(GAME_INPUT_TIMER_ID);
                    gameInputAccumulator -= gameInputTicks;
                }
            } else {
                gameInputAccumulator = 0;
            }

            if (GameWindowVisible && renderAccumulator >= renderTicks) {
                GameOnRender();
                renderAccumulator -= renderTicks;
            }
        }

        LARGE_INTEGER frameEndCounter;
        QueryPerformanceCounter(&frameEndCounter);

        uint64_t frameElapsed =
                frameEndCounter.QuadPart -
                frameStart;

        if (frameElapsed < renderTicks) {
            uint64_t remainingTicks =
                    renderTicks -
                    frameElapsed;

            DWORD remainingMs =
                    (DWORD)((remainingTicks * 1000) / (uint64_t)frequency.QuadPart);

            if (remainingMs > 1) {
                Sleep(remainingMs - 1);
            }
        }
    }
}

PLATFORM_ABI void PlatformShowMainWindow(void)
{
    if (MainWindow) {
        ShowWindow(MainWindow, SW_SHOW);
        SetWindowTextW(MainWindow, MainWindowTitle);
        ResizePlatformWindow(MainWindow, 600, 600);
        MainWindowVisible = true;
        GameWindowVisible = false;
        GameTimerRunning = false;
        GameWindow = NULL;
    }
}

PLATFORM_ABI void PlatformHideMainWindow(void)
{
    if (MainWindow) {
        MainWindowVisible = false;
    }
}

PLATFORM_ABI void PlatformDestroyMainWindow(void)
{
    if (MainWindow) {
        DestroyWindow(MainWindow);
    }
}

PLATFORM_ABI void PlatformCloseGameWindow(void)
{
    if (GameWindowVisible) {
        GameWindowVisible = false;
        GameTimerRunning = false;
        GameWindow = NULL;
        GameOnClose();
    }
}

PLATFORM_ABI void PlatformExitProcess(uint64_t exitCode)
{
    ExitProcess((UINT)exitCode);
}

PLATFORM_ABI void PlatformStartGameTimer(uint64_t timerValue)
{
    if (MainWindow && GameWindowVisible) {
        GameTimerValue = timerValue;
        GameTimerRunning = true;
    }
}

PLATFORM_ABI void PlatformStopGameTimer(void)
{
    if (MainWindow && GameWindowVisible) {
        GameTimerRunning = false;
    }
}

PLATFORM_ABI uint64_t PlatformGetFPS(void)
{
    return GameCurrentFPS;
}

PLATFORM_ABI PlatformHandle PlatformBeginWindowRender(
        uint64_t window,
        RENDER_CONTEXT *context,
        int32_t width,
        int32_t height
)
{
    (void)window;

    HWND nativeWindow = MainWindow;

    HDC *paintDC =
            window == PLATFORM_WINDOW_MAIN ?
            &MainPaintDC :
            &GamePaintDC;

    *paintDC = GetDC(nativeWindow);

    BeginRender(context, width, height);

    return (PlatformHandle)GetRenderDC(context);
}

PLATFORM_ABI void PlatformEndWindowRender(uint64_t window, RENDER_CONTEXT *context)
{
    HWND nativeWindow = MainWindow;

    HDC paintDC =
            window == PLATFORM_WINDOW_MAIN ?
            MainPaintDC :
            GamePaintDC;

    EndRender((PlatformHandle)paintDC, context);
    ReleaseDC(nativeWindow, paintDC);

    if (window == PLATFORM_WINDOW_GAME) {
        UpdateGameFPS();
    }
}

static LRESULT CALLBACK MainWindowProc(HWND window, UINT message, WPARAM wParam, LPARAM lParam)
{
    switch (message) {
        case WM_NCHITTEST: {
            LRESULT result = DefWindowProcW(window, message, wParam, lParam);

            if (result >= HTLEFT && result <= HTBOTTOMRIGHT) {
                return HTCLIENT;
            }

            return result;
        }

        case WM_CREATE:
            MainWindow = window;
            MainWindowVisible = true;
            MainOnCreate((PlatformHandle)window);
            return 0;

        case WM_KEYDOWN:
            if (GameWindowVisible) {
                GameOnKeyboard((uint64_t)wParam);
            } else {
                MainOnKeyboard((uint64_t)wParam);
            }
            return 0;

        case WM_PAINT:
            ValidateRect(window, NULL);
            return 0;

        case WM_ERASEBKGND:
            return 0;

        case WM_CLOSE:
            DestroyWindow(window);
            return 0;

        case WM_DESTROY:
            GameWindowVisible = false;
            GameWindow = NULL;
            GameTimerRunning = false;
            MainOnClose();
            CleanupPlatform();
            MainWindow = NULL;
            MainWindowVisible = false;
            PlatformRunning = false;
            PostQuitMessage(0);
            return 0;

        default:
            return DefWindowProcW(window, message, wParam, lParam);
    }
}

PLATFORM_ABI void InitRender(PlatformHandle windowHandle, RENDER_CONTEXT *context) {
    CleanupRenderContext(context);

    HWND hWnd = (HWND)windowHandle;
    HDC dc = GetDC(hWnd);
    context->WindowDC = dc;

    HDC compatDC = CreateCompatibleDC(dc);
    context->RenderDC = compatDC;

    HBITMAP bitmap = CreateCompatibleBitmap(context->WindowDC, context->ScreenWidth, context->ScreenHeight);
    context->BackBitmap = bitmap;

    HGDIOBJ selection = SelectObject(context->RenderDC, context->BackBitmap);
    context->OldBitmap = selection;

    if (context->ScreenHeight == 600) {
        MainRenderContext = context;
    } else {
        GameRenderContext = context;
    }
}

PLATFORM_ABI void BeginRender(RENDER_CONTEXT *context, int32_t right, int32_t bottom) {
    HBRUSH brush = CreateSolidBrush(0);

    RECT W_Rectangle;

    W_Rectangle.left = 0;
    W_Rectangle.top = 0;
    W_Rectangle.right = right;
    W_Rectangle.bottom = bottom;

    FillRect(context->RenderDC, &W_Rectangle, brush);
    DeleteObject(brush);
}

PLATFORM_ABI void EndRender(PlatformHandle deviceContext, RENDER_CONTEXT *context) {
    HDC hDC = (HDC)deviceContext;

    BitBlt(hDC, 0, 0, context->ScreenWidth, context->ScreenHeight, context->RenderDC,0, 0, SRCCOPY);
}

HDC GetRenderDC(RENDER_CONTEXT *context) {
    return context->RenderDC;
}

PLATFORM_ABI void DrawTile(PlatformHandle deviceContext, int32_t x, int32_t y, uint32_t Color, int32_t TileSize) {
    HDC hDC = (HDC)deviceContext;
    RECT W_Rectangle;

    W_Rectangle.left = x;
    W_Rectangle.top = y;
    W_Rectangle.right = x + TileSize;
    W_Rectangle.bottom = y + TileSize;

    HBRUSH brush = CreateSolidBrush(Color);

    FillRect(hDC, &W_Rectangle, brush);
    DeleteObject(brush);
}

PLATFORM_ABI void FillRectangle(PlatformHandle deviceContext, U_RECT *U_Rectangle, uint32_t Color) {
    HDC hDC = (HDC)deviceContext;

    RECT W_Rectangle;

    W_Rectangle.left = U_Rectangle->left;
    W_Rectangle.right = U_Rectangle->right;
    W_Rectangle.top = U_Rectangle->top;
    W_Rectangle.bottom = U_Rectangle->bottom;

    HBRUSH brush = CreateSolidBrush(Color);
    FillRect(hDC, &W_Rectangle, brush);

    DeleteObject(brush);
}

//=======================================
// HUD - WIN32
//======================================

PLATFORM_ABI void DrawHUD(PlatformHandle deviceContext, char *text, U_RECT *U_Rectangle, int32_t Color, char *font, int fontSize) {
    HDC hDC = (HDC)deviceContext;

    RECT W_Rectangle;

    W_Rectangle.left = U_Rectangle->left;
    W_Rectangle.right = U_Rectangle->right;
    W_Rectangle.top = U_Rectangle->top;
    W_Rectangle.bottom = U_Rectangle->bottom;

    SetBkMode(hDC, TRANSPARENT);
    SetTextColor(hDC, Color);

    HFONT hFont = CreateFontA(fontSize, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH | FF_DONTCARE, font);
    HGDIOBJ oldFont = SelectObject(hDC, hFont);

    DrawTextA(hDC,text, -1, &W_Rectangle, DT_CENTER);

    SelectObject(hDC, oldFont);
    DeleteObject(hFont);
}

//=======================================
// INPUT - WIN32
//======================================

PLATFORM_ABI uint64_t GetKeyboardInput(uint64_t key)
{
    switch (key) {
        case VK_RIGHT:
            return GAME_INPUT_RIGHT;

        case VK_LEFT:
            return GAME_INPUT_LEFT;

        case VK_UP:
            return GAME_INPUT_UP;

        case VK_DOWN:
            return GAME_INPUT_DOWN;

        case VK_RETURN:
            return GAME_INPUT_CONFIRM;

        case VK_ESCAPE:
            return GAME_INPUT_PAUSE;

        case VK_F3:
            return GAME_INPUT_TOGGLE_FPS;

        default:
            return GAME_INPUT_NONE;
    }
}

PLATFORM_ABI uint64_t GetControllerInput(void)
{
    static WORD PrevButtons = 0;

    XINPUT_STATE ControllerState;
    DWORD result =
            XInputGetState(
                    0,
                    &ControllerState
            );

    if (result != ERROR_SUCCESS) {
        PrevButtons = 0;
        return GAME_INPUT_NONE;
    }

    WORD buttons =
            ControllerState.Gamepad.wButtons;

    WORD pressed =
            (buttons ^ PrevButtons) & buttons;

    PrevButtons = buttons;

    if (!pressed) {
        return GAME_INPUT_NONE;
    }

    if (pressed & XINPUT_GAMEPAD_DPAD_RIGHT) {
        return GAME_INPUT_RIGHT;
    }

    if (pressed & XINPUT_GAMEPAD_DPAD_LEFT) {
        return GAME_INPUT_LEFT;
    }

    if (pressed & XINPUT_GAMEPAD_DPAD_UP) {
        return GAME_INPUT_UP;
    }

    if (pressed & XINPUT_GAMEPAD_DPAD_DOWN) {
        return GAME_INPUT_DOWN;
    }

    if (pressed & XINPUT_GAMEPAD_START) {
        return GAME_INPUT_CONFIRM;
    }

    if (pressed & XINPUT_GAMEPAD_BACK) {
        return GAME_INPUT_BACK;
    }

    return GAME_INPUT_NONE;
}

PLATFORM_ABI const char *PlatformGetInputLabel(uint64_t inputType)
{
    if (inputType == INPUT_TYPE_CONTROLLER) {
        return "XBOX CONTROLLER";
    }

    return "KEYBOARD";
}

//=======================================
// AUDIO - SDL
//=======================================

PLATFORM_ABI bool InitAudio(void)
{
    if (SDL_WasInit(SDL_INIT_AUDIO)) {
        SDLInitialized = true;
        return true;
    }

    SDLInitialized = SDL_InitSubSystem(SDL_INIT_AUDIO);
    return SDLInitialized;
}

static SOUND *FindAudioSound(const char *alias)
{
    if (!alias) {
        return NULL;
    }

    for (int i = 0; i < AudioSoundCount; ++i) {
        if (strcmp(AudioSounds[i].alias, alias) == 0) {
            return &AudioSounds[i];
        }
    }

    return NULL;
}

PLATFORM_ABI bool LoadAudio(const char *alias, const char *file)
{
    SDL_AudioSpec spec;
    SOUND *sound = FindAudioSound(alias);

    if (!alias || !file) {
        return false;
    }

    if (!sound) {
        if (AudioSoundCount >= MAX_AUDIO_SOUNDS) {
            return false;
        }

        sound = &AudioSounds[AudioSoundCount++];
        sound->alias = alias;
        sound->stream = NULL;
        sound->data = NULL;
        sound->length = 0;
    }

    if (sound->stream) {
        SDL_DestroyAudioStream(sound->stream);
        sound->stream = NULL;
    }

    if (sound->data) {
        SDL_free(sound->data);
        sound->data = NULL;
        sound->length = 0;
    }

    if (!InitAudio()) {
        return false;
    }

    if (!SDL_LoadWAV(
            file,
            &spec,
            &sound->data,
            &sound->length
    )) {
        return false;
    }

    sound->stream = SDL_OpenAudioDeviceStream(
            SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
            &spec,
            NULL,
            NULL
    );

    if (!sound->stream) {
        SDL_free(sound->data);
        sound->data = NULL;
        sound->length = 0;
        return false;
    }

    SDL_ResumeAudioStreamDevice(sound->stream);

    return true;
}

PLATFORM_ABI void PlayAudio(const char *alias, bool async)
{
    SOUND *sound = FindAudioSound(alias);

    if (!sound || !sound->stream || !sound->data) {
        return;
    }

    SDL_ClearAudioStream(sound->stream);
    SDL_PutAudioStreamData(sound->stream, sound->data, sound->length);

    if (!async) {
        SDL_FlushAudioStream(sound->stream);

        while (SDL_GetAudioStreamAvailable(sound->stream) > 0) {
            SDL_Delay(1);
        }
    }
}
