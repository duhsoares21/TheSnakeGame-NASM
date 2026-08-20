#include <SDL3/SDL.h>
#include <SDL3_ttf/SDL_ttf.h>

#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef __APPLE__
#include <unistd.h>
#endif

#include <math.h>

#include "platform.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

struct RENDER_CONTEXT
{
    SDL_Window *Window;
    SDL_Renderer *Renderer;
    void *BackBitmap;
    void *OldBitmap;

    uint64_t ScreenWidth;
    uint64_t ScreenHeight;
};

struct U_RECT
{
    int32_t  left;
    int32_t  top;
    int32_t  right;
    int32_t  bottom;
};

struct SOUND
{
    const char *alias;
    Uint8 *data;
    Uint32 length;
};

#define MAX_AUDIO_SOUNDS 32
#define MAX_AUDIO_VOICES 16

typedef struct AUDIO_VOICE
{
    SOUND *sound;
    Uint32 position;
    bool active;
} AUDIO_VOICE;

static SOUND AudioSounds[MAX_AUDIO_SOUNDS];
static AUDIO_VOICE AudioVoices[MAX_AUDIO_VOICES];
static int AudioSoundCount = 0;
static SDL_AudioStream *AudioStream = NULL;
static SDL_AudioSpec AudioSpec = {
        .format = SDL_AUDIO_F32,
        .channels = 2,
        .freq = 48000
};

static SDL_Renderer *SharedRenderer = NULL;
static RENDER_CONTEXT *MainRenderContext = NULL;
static RENDER_CONTEXT *GameRenderContext = NULL;
static SDL_Gamepad *GameController = NULL;
static uint32_t PrevGamepadButtons = 0;
static bool TTFInitialized = false;

static void UseBundledResourceDirectory(void)
{
#ifdef __APPLE__
    /* Finder does not launch an app with Contents/Resources as its working
       directory. The assembly uses paths such as audio/intro.wav, so anchor
       relative assets to the app bundle before any of them are opened. */
    const char *basePath = SDL_GetBasePath();
    if (basePath) {
        char resourcePath[4096];
        int length = snprintf(resourcePath, sizeof(resourcePath),
                              "%s../Resources", basePath);
        if (length > 0 && (size_t)length < sizeof(resourcePath)) {
            (void)chdir(resourcePath);
        }
    }
#endif
}

static bool FileExists(const char *path)
{
    if (!path || !path[0]) {
        return false;
    }

    FILE *file = fopen(path, "rb");

    if (!file) {
        return false;
    }

    fclose(file);
    return true;
}

static uint16_t ReadLE16(const uint8_t *data)
{
    return (uint16_t)(data[0] | (data[1] << 8));
}

static uint32_t ReadLE32(const uint8_t *data)
{
    return (uint32_t)data[0] |
           ((uint32_t)data[1] << 8) |
           ((uint32_t)data[2] << 16) |
           ((uint32_t)data[3] << 24);
}

static bool LoadFile(const char *path, uint8_t **data, size_t *size)
{
    FILE *file = fopen(path, "rb");

    if (!file) {
        return false;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return false;
    }

    long length = ftell(file);

    if (length <= 0) {
        fclose(file);
        return false;
    }

    rewind(file);

    uint8_t *buffer = malloc((size_t)length);

    if (!buffer) {
        fclose(file);
        return false;
    }

    if (fread(buffer, 1, (size_t)length, file) != (size_t)length) {
        free(buffer);
        fclose(file);
        return false;
    }

    fclose(file);
    *data = buffer;
    *size = (size_t)length;
    return true;
}

static SDL_Surface *LoadIconSurface(const char *path)
{
    uint8_t *fileData = NULL;
    size_t fileSize = 0;

    if (!LoadFile(path, &fileData, &fileSize)) {
        return NULL;
    }

    if (fileSize < 22 ||
        ReadLE16(fileData) != 0 ||
        ReadLE16(fileData + 2) != 1) {
        free(fileData);
        return NULL;
    }

    uint16_t imageCount = ReadLE16(fileData + 4);
    const uint8_t *selectedEntry = NULL;
    int selectedSize = 0;

    for (uint16_t i = 0; i < imageCount; ++i) {
        const uint8_t *entry = fileData + 6 + (size_t)i * 16;

        if (entry + 16 > fileData + fileSize) {
            break;
        }

        int width = entry[0] == 0 ? 256 : entry[0];
        int height = entry[1] == 0 ? 256 : entry[1];
        uint32_t bytesInResource = ReadLE32(entry + 8);
        uint32_t imageOffset = ReadLE32(entry + 12);

        if ((size_t)imageOffset + bytesInResource > fileSize) {
            continue;
        }

        if (!selectedEntry || width * height > selectedSize) {
            selectedEntry = entry;
            selectedSize = width * height;
        }
    }

    if (!selectedEntry) {
        free(fileData);
        return NULL;
    }

    uint8_t colorCount = selectedEntry[2];
    uint32_t bytesInResource = ReadLE32(selectedEntry + 8);
    uint32_t imageOffset = ReadLE32(selectedEntry + 12);
    const uint8_t *imageData = fileData + imageOffset;
    const uint8_t *imageEnd = imageData + bytesInResource;

    if (bytesInResource < 40 || ReadLE32(imageData) < 40) {
        free(fileData);
        return NULL;
    }

    int32_t dibWidth = (int32_t)ReadLE32(imageData + 4);
    int32_t dibHeight = (int32_t)ReadLE32(imageData + 8);
    uint16_t bitCount = ReadLE16(imageData + 14);
    uint32_t compression = ReadLE32(imageData + 16);

    if (dibWidth <= 0 || dibHeight == 0 || compression != 0) {
        free(fileData);
        return NULL;
    }

    int width = dibWidth;
    int height = dibHeight < 0 ? -dibHeight : dibHeight / 2;
    bool topDown = dibHeight < 0;
    uint32_t headerSize = ReadLE32(imageData);
    int paletteCount = 0;

    if (bitCount <= 8) {
        paletteCount = colorCount ? colorCount : (1 << bitCount);
    }

    const uint8_t *palette = imageData + headerSize;
    const uint8_t *pixels = palette + (size_t)paletteCount * 4;
    int xorStride = (int)(((uint64_t)width * bitCount + 31) / 32) * 4;
    int andStride = ((width + 31) / 32) * 4;
    const uint8_t *mask = pixels + (size_t)xorStride * height;

    if (pixels >= imageEnd || mask > imageEnd) {
        free(fileData);
        return NULL;
    }

    uint8_t *rgba = malloc((size_t)width * height * 4);

    if (!rgba) {
        free(fileData);
        return NULL;
    }

    bool hasAlpha = false;

    for (int y = 0; y < height; ++y) {
        int sourceY = topDown ? y : height - 1 - y;
        const uint8_t *row = pixels + (size_t)sourceY * xorStride;
        const uint8_t *maskRow = mask + (size_t)sourceY * andStride;

        for (int x = 0; x < width; ++x) {
            uint8_t r = 0;
            uint8_t g = 0;
            uint8_t b = 0;
            uint8_t a = 255;

            if (bitCount == 32) {
                const uint8_t *pixel = row + (size_t)x * 4;
                b = pixel[0];
                g = pixel[1];
                r = pixel[2];
                a = pixel[3];
                hasAlpha = hasAlpha || a != 0;
            } else if (bitCount == 24) {
                const uint8_t *pixel = row + (size_t)x * 3;
                b = pixel[0];
                g = pixel[1];
                r = pixel[2];
            } else if (bitCount == 8) {
                const uint8_t *color = palette + (size_t)row[x] * 4;
                b = color[0];
                g = color[1];
                r = color[2];
            } else if (bitCount == 4) {
                uint8_t index = row[x / 2];
                index = (x & 1) ? (index & 0x0F) : (index >> 4);
                const uint8_t *color = palette + (size_t)index * 4;
                b = color[0];
                g = color[1];
                r = color[2];
            } else if (bitCount == 1) {
                uint8_t index = (row[x / 8] >> (7 - (x & 7))) & 1;
                const uint8_t *color = palette + (size_t)index * 4;
                b = color[0];
                g = color[1];
                r = color[2];
            } else {
                free(rgba);
                free(fileData);
                return NULL;
            }

            if (!hasAlpha && mask + (size_t)andStride * height <= imageEnd) {
                uint8_t masked = (maskRow[x / 8] >> (7 - (x & 7))) & 1;

                if (masked) {
                    a = 0;
                }
            }

            uint8_t *destination = rgba + ((size_t)y * width + x) * 4;
            destination[0] = r;
            destination[1] = g;
            destination[2] = b;
            destination[3] = a;
        }
    }

    free(fileData);

    SDL_Surface *surface =
            SDL_CreateSurfaceFrom(
                    width,
                    height,
                    SDL_PIXELFORMAT_RGBA32,
                    rgba,
                    width * 4
            );

    if (!surface) {
        free(rgba);
        return NULL;
    }

    return surface;
}

static void SetPlatformWindowIcon(SDL_Window *window)
{
    SDL_Surface *icon = LoadIconSurface("icon.ico");

    if (!icon) {
        return;
    }

    SDL_SetWindowIcon(window, icon);
    void *pixels = icon->pixels;
    SDL_DestroySurface(icon);
    free(pixels);
}

static TTF_Font *OpenHUDFont(const char *font, int fontSize)
{
    const char *fontOverride = getenv("SNAKE_FONT_PATH");

    if (FileExists(fontOverride)) {
        TTF_Font *overrideFont = TTF_OpenFont(fontOverride, (float)fontSize);

        if (overrideFont) {
            return overrideFont;
        }
    }

    if (FileExists(font)) {
        TTF_Font *requestedFont = TTF_OpenFont(font, (float)fontSize);

        if (requestedFont) {
            return requestedFont;
        }
    }

    static const char *fallbackFonts[] = {
            "/usr/share/fonts/TTF/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/liberation/LiberationSans-Regular.ttf",
            "/usr/share/fonts/liberation-fonts/LiberationSans-Regular.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
            "/usr/share/fonts/noto/NotoSans-Regular.ttf",
            "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf",
            "/usr/share/fonts/gnu-free/FreeSans.ttf",
            "/Library/Fonts/Arial.ttf",
            "/Library/Fonts/Arial Unicode.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
            "/System/Library/Fonts/Supplemental/Helvetica.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/Supplemental/Times New Roman.ttf",
            "/System/Library/Fonts/Supplemental/Verdana.ttf",
            "/System/Library/Fonts/SFNS.ttf",
            "C:\\Windows\\Fonts\\arial.ttf",
    };

    for (size_t i = 0; i < sizeof(fallbackFonts) / sizeof(fallbackFonts[0]); i++) {
        if (!FileExists(fallbackFonts[i])) {
            continue;
        }

        TTF_Font *fallbackFont = TTF_OpenFont(fallbackFonts[i], (float)fontSize);

        if (fallbackFont) {
            return fallbackFont;
        }
    }

    printf("TTF_OpenFont failed for '%s' and no fallback font was found: %s\n",
           font ? font : "",
           SDL_GetError());
    return NULL;
}

PLATFORM_ABI void BeginRender(RENDER_CONTEXT *context, int32_t right, int32_t bottom);
PlatformHandle GetRenderDC(RENDER_CONTEXT *context);
PLATFORM_ABI void EndRender(PlatformHandle deviceContext, RENDER_CONTEXT *context);

//=======================================
// WINDOW - SDL
//=======================================

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

static SDL_Window *MainWindow = NULL;
static SDL_Window *GameWindow = NULL;
static bool MainWindowVisible = false;
static bool GameWindowVisible = false;
static bool GameTimerRunning = false;
static bool PlatformRunning = true;
static uint64_t LastBlinkTick = 0;
static uint64_t LastMainInputTick = 0;
static uint64_t LastGameInputTick = 0;
static uint64_t GameTimerValue = INPUT_FREQUENCY_MS;
static uint64_t LastGameFPSCounter = 0;
static uint64_t GameFPSFrequency = 0;
static uint64_t GameFrameCounter = 0;
static uint64_t GameCurrentFPS = 0;
static bool GameFPSInitialized = false;

static void CleanupAudio(void)
{
    if (AudioStream) {
        SDL_DestroyAudioStream(AudioStream);
        AudioStream = NULL;
    }

    for (int i = 0; i < AudioSoundCount; ++i) {
        if (AudioSounds[i].data) {
            SDL_free(AudioSounds[i].data);
            AudioSounds[i].data = NULL;
        }

        AudioSounds[i].alias = NULL;
        AudioSounds[i].length = 0;
    }

    for (int i = 0; i < MAX_AUDIO_VOICES; ++i) {
        AudioVoices[i].sound = NULL;
        AudioVoices[i].position = 0;
        AudioVoices[i].active = false;
    }

    AudioSoundCount = 0;
}

static void CleanupRender(void)
{
    if (SharedRenderer) {
        SDL_DestroyRenderer(SharedRenderer);
        SharedRenderer = NULL;
    }

    if (MainRenderContext) {
        MainRenderContext->Window = NULL;
        MainRenderContext->Renderer = NULL;
        MainRenderContext = NULL;
    }

    if (GameRenderContext) {
        GameRenderContext->Window = NULL;
        GameRenderContext->Renderer = NULL;
        GameRenderContext = NULL;
    }
}

static void CleanupPlatform(void)
{
    CleanupAudio();
    CleanupRender();

    if (GameController) {
        SDL_CloseGamepad(GameController);
        GameController = NULL;
        PrevGamepadButtons = 0;
    }

    if (TTFInitialized) {
        TTF_Quit();
        TTFInitialized = false;
    }

}

static void UpdateGameFPS(void)
{
    if (!GameFPSInitialized) {
        GameFPSFrequency = SDL_GetPerformanceFrequency();
        LastGameFPSCounter = SDL_GetPerformanceCounter();
        GameFPSInitialized = true;
    }

    ++GameFrameCounter;

    uint64_t currentCounter =
            SDL_GetPerformanceCounter();

    uint64_t elapsed =
            currentCounter -
            LastGameFPSCounter;

    if (elapsed >= GameFPSFrequency) {
        GameCurrentFPS =
                (GameFrameCounter * GameFPSFrequency) /
                elapsed;

        GameFrameCounter = 0;
        LastGameFPSCounter = currentCounter;
    }
}

PLATFORM_ABI bool PlatformCreateMainWindow(int32_t width, int32_t height)
{
    UseBundledResourceDirectory();

    if (!SDL_WasInit(SDL_INIT_VIDEO)) {
        if (!SDL_InitSubSystem(SDL_INIT_VIDEO)) {
            return false;
        }
    }

    MainWindow =
            SDL_CreateWindow(
                    "Main Menu - Snake Game",
                    width,
                    height,
                    0
            );

    if (!MainWindow) {
        return false;
    }

    SetPlatformWindowIcon(MainWindow);

    MainWindowVisible = true;
    MainOnCreate((PlatformHandle)MainWindow);

    return true;
}

PLATFORM_ABI bool PlatformCreateGameWindow(int32_t width, int32_t height)
{
    if (!SDL_WasInit(SDL_INIT_VIDEO)) {
        if (!SDL_InitSubSystem(SDL_INIT_VIDEO)) {
            return false;
        }
    }

    if (!MainWindow) {
        return false;
    }

    SDL_SetWindowTitle(
            MainWindow,
            "Playing - Snake Game"
    );

    SDL_SetWindowSize(
            MainWindow,
            width,
            height
    );

    GameWindow = MainWindow;
    MainWindowVisible = false;
    GameWindowVisible = true;
    GameTimerRunning = true;
    LastGameInputTick = SDL_GetTicks();
    GameOnCreate((PlatformHandle)MainWindow);

    return true;
}

PLATFORM_ABI void PlatformRunMessageLoop(void)
{
    LastBlinkTick = SDL_GetTicks();
    LastMainInputTick = LastBlinkTick;

    uint64_t performanceFrequency =
            SDL_GetPerformanceFrequency();

    uint64_t targetFrameTicks =
            performanceFrequency / 60;

    while (PlatformRunning) {
        uint64_t frameStart =
                SDL_GetPerformanceCounter();

        SDL_Event event;

        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                PlatformRunning = false;
                break;
            }

            if (event.type == SDL_EVENT_KEY_DOWN) {
                SDL_Window *eventWindow =
                        SDL_GetWindowFromID(
                                event.key.windowID
                        );

                if (eventWindow == MainWindow && GameWindowVisible) {
                    GameOnKeyboard((uint64_t)event.key.key);
                }

                if (eventWindow == MainWindow && MainWindowVisible) {
                    MainOnKeyboard((uint64_t)event.key.key);
                }
            }

            if (event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED) {
                SDL_Window *eventWindow =
                        SDL_GetWindowFromID(
                                event.window.windowID
                        );

                if (eventWindow == MainWindow) {
                    PlatformDestroyMainWindow();
                }
            }
        }

        uint64_t now = SDL_GetTicks();

        if (MainWindowVisible && now - LastBlinkTick >= BLINK_FREQUENCY_MS) {
            MainOnTimer(BLINK_TIMER_ID);
            LastBlinkTick = now;
        }

        if (MainWindowVisible && now - LastMainInputTick >= INPUT_FREQUENCY_MS) {
            MainOnTimer(MAIN_INPUT_TIMER_ID);
            LastMainInputTick = now;
        }

        if (GameWindowVisible && GameTimerRunning && now - LastGameInputTick >= GameTimerValue) {
            GameOnTimer(GAME_INPUT_TIMER_ID);
            LastGameInputTick = now;
        }

        if (MainWindowVisible) {
            MainOnRender();
        }

        if (GameWindowVisible) {
            GameOnRender();
        }

        uint64_t frameEnd =
                SDL_GetPerformanceCounter();

        uint64_t frameElapsed =
                frameEnd - frameStart;

        if (frameElapsed < targetFrameTicks) {
            uint64_t remainingTicks =
                    targetFrameTicks - frameElapsed;

            uint64_t remainingMs =
                    (remainingTicks * 1000) / performanceFrequency;

            if (remainingMs > 1) {
                SDL_Delay((Uint32)(remainingMs - 1));
            }

            while (SDL_GetPerformanceCounter() - frameStart < targetFrameTicks) {
            }
        }
    }

    if (MainWindow) {
        PlatformDestroyMainWindow();
    }
}

PLATFORM_ABI void PlatformShowMainWindow(void)
{
    if (MainWindow) {
        SDL_ShowWindow(MainWindow);
        SDL_SetWindowTitle(
                MainWindow,
                "Main Menu - Snake Game"
        );
        SDL_SetWindowSize(
                MainWindow,
                600,
                600
        );
        MainWindowVisible = true;
        GameWindowVisible = false;
        GameTimerRunning = false;
        GameWindow = NULL;
        LastBlinkTick = SDL_GetTicks();
        LastMainInputTick = LastBlinkTick;
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
    GameWindowVisible = false;
    GameTimerRunning = false;
    GameWindow = NULL;

    if (MainWindow) {
        MainOnClose();
        CleanupPlatform();
        SDL_DestroyWindow(MainWindow);
        MainWindow = NULL;
    }

    MainWindowVisible = false;
    PlatformRunning = false;
    SDL_Quit();
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
    exit((int)exitCode);
}

PLATFORM_ABI void PlatformStartGameTimer(uint64_t timerValue)
{
    GameTimerValue = timerValue;
    GameTimerRunning = true;
    LastGameInputTick = SDL_GetTicks();
}

PLATFORM_ABI void PlatformStopGameTimer(void)
{
    GameTimerRunning = false;
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

    BeginRender(context, width, height);
    return GetRenderDC(context);
}

PLATFORM_ABI void PlatformEndWindowRender(
        uint64_t window,
        RENDER_CONTEXT *context
)
{
    EndRender(0, context);

    if (window == PLATFORM_WINDOW_GAME) {
        UpdateGameFPS();
    }
}

//=======================================
// RENDER - SDL
//=======================================

PLATFORM_ABI void InitRender(
        PlatformHandle windowHandle,
        RENDER_CONTEXT *context
)
{
    if (!SDL_WasInit(SDL_INIT_VIDEO) && !SDL_InitSubSystem(SDL_INIT_VIDEO)) {
        return;
    }

    context->Window = (SDL_Window *)windowHandle;
    
    if (!context->Window) {
        return;
    }

    if (!SharedRenderer) {
        SharedRenderer =
                SDL_CreateRenderer(
                        context->Window,
                        NULL
                );
    }

    context->Renderer = SharedRenderer;

    if (context->ScreenHeight == 600) {
        MainRenderContext = context;
    } else {
        GameRenderContext = context;
    }
}

PLATFORM_ABI void BeginRender(
        RENDER_CONTEXT *context,
        int32_t right,
        int32_t bottom
)
{
    (void)right;
    (void)bottom;

    SDL_SetRenderDrawColor(
            context->Renderer,
            0,
            0,
            0,
            255
    );

    SDL_RenderClear(context->Renderer);
}

PlatformHandle GetRenderDC(
        RENDER_CONTEXT *context
)
{
    return (PlatformHandle)context->Renderer;
}

PLATFORM_ABI void DrawTile(
        PlatformHandle renderHandle,
        int32_t x,
        int32_t y,
        uint32_t color,
        int32_t tileSize
)
{
    SDL_Renderer *renderer =
            (SDL_Renderer *)renderHandle;

    uint8_t r = color & 0xFF;
    uint8_t g = (color >> 8)  & 0xFF;
    uint8_t b = (color >> 16) & 0xFF;

    SDL_SetRenderDrawColor(
            renderer,
            r,
            g,
            b,
            255
    );

    SDL_FRect rect = {
            .x = (float)x,
            .y = (float)y,
            .w = (float)tileSize,
            .h = (float)tileSize
    };

    SDL_RenderFillRect(
            renderer,
            &rect
    );
}

PLATFORM_ABI void FillRectangle(
        PlatformHandle renderHandle,
        U_RECT *rect,
        uint32_t color
)
{
    SDL_Renderer *renderer =
            (SDL_Renderer *)renderHandle;

    uint8_t r = color & 0xFF;
    uint8_t g = (color >> 8)  & 0xFF;
    uint8_t b = (color >> 16) & 0xFF;

    SDL_SetRenderDrawColor(
            renderer,
            r,
            g,
            b,
            255
    );

    SDL_FRect sdlRect = {
            .x = (float)rect->left,
            .y = (float)rect->top,
            .w = (float)(rect->right - rect->left),
            .h = (float)(rect->bottom - rect->top)
    };

    SDL_RenderFillRect(
            renderer,
            &sdlRect
    );
}

PLATFORM_ABI void EndRender(
        PlatformHandle deviceContext,
        RENDER_CONTEXT *context
)
{
    (void)deviceContext;

    SDL_RenderPresent(
            context->Renderer
    );
}

//=======================================
// HUD - SDL
//======================================

PLATFORM_ABI void DrawHUD(
        PlatformHandle deviceContext,
        char *text,
        U_RECT *U_Rectangle,
        int32_t Color,
        char *font,
        int fontSize
) {
    SDL_Renderer *renderer = (SDL_Renderer *)deviceContext;

    uint8_t r = Color & 0xFF;
    uint8_t g = (Color >> 8)  & 0xFF;
    uint8_t b = (Color >> 16) & 0xFF;

    int sdlFontSize = fontSize < 0 ? -fontSize : fontSize;

    if (!TTFInitialized && !TTF_Init()) {
        printf("TTF_Init failed: %s\n", SDL_GetError());
        return;
    }

    TTFInitialized = true;

    TTF_Font *sdlFont = OpenHUDFont(font, sdlFontSize);

    if (!sdlFont) {
        return;
    }

    SDL_Color color = {
            .r = r,
            .g = g,
            .b = b,
            .a = 255
    };

    SDL_Surface *surface = TTF_RenderText_Blended(
            sdlFont,
            text,
            strlen(text),
            color
    );

    if (!surface) {
        TTF_CloseFont(sdlFont);
        return;
    }

    SDL_Texture *texture =
            SDL_CreateTextureFromSurface(
                    renderer,
                    surface
            );

    if (!texture) {
        SDL_DestroySurface(surface);
        TTF_CloseFont(sdlFont);
        return;
    }

    int32_t rectWidthValue =
            U_Rectangle->right - U_Rectangle->left;

    if (rectWidthValue <= 0) {
        rectWidthValue = U_Rectangle->right;
    }

    float rectWidth = (float)rectWidthValue;

    float textWidth =
            (float)surface->w;

    float textHeight =
            (float)surface->h;

    float x =
            (float)U_Rectangle->left +
            (rectWidth - textWidth) / 2.0f;

    float y =
            (float)U_Rectangle->top;

    SDL_FRect destination = {
            .x = x,
            .y = y,
            .w = textWidth,
            .h = textHeight
    };

    SDL_RenderTexture(
            renderer,
            texture,
            NULL,
            &destination
    );

    SDL_DestroyTexture(texture);
    SDL_DestroySurface(surface);
    TTF_CloseFont(sdlFont);
}

//=======================================
// INPUT - SDL
//=======================================

PLATFORM_ABI uint64_t GetKeyboardInput(uint64_t key)
{
    switch ((SDL_Keycode)key) {
        case SDLK_RIGHT:
            return GAME_INPUT_RIGHT;

        case SDLK_LEFT:
            return GAME_INPUT_LEFT;

        case SDLK_UP:
            return GAME_INPUT_UP;

        case SDLK_DOWN:
            return GAME_INPUT_DOWN;

        case SDLK_RETURN:
            return GAME_INPUT_CONFIRM;

        case SDLK_ESCAPE:
            return GAME_INPUT_PAUSE;

        case SDLK_F3:
            return GAME_INPUT_TOGGLE_FPS;

        default:
            return GAME_INPUT_NONE;
    }
}

static bool InitGameController(void)
{
    if (!SDL_WasInit(SDL_INIT_GAMEPAD)) {
        if (!SDL_InitSubSystem(SDL_INIT_GAMEPAD)) {
            return false;
        }
    }

    if (GameController && SDL_GamepadConnected(GameController)) {
        return true;
    }

    if (GameController) {
        SDL_CloseGamepad(GameController);
        GameController = NULL;
        PrevGamepadButtons = 0;
    }

    int count = 0;
    SDL_JoystickID *controllers =
            SDL_GetGamepads(&count);

    if (!controllers) {
        return false;
    }

    for (int i = 0; i < count; ++i) {
        if (!SDL_IsGamepad(controllers[i])) {
            continue;
        }

        GameController =
                SDL_OpenGamepad(
                        controllers[i]
                );

        if (GameController) {
            break;
        }
    }

    SDL_free(controllers);

    return GameController != NULL;
}

static uint32_t GetGameControllerButtons(void)
{
    uint32_t buttons = 0;

    if (SDL_GetGamepadButton(GameController, SDL_GAMEPAD_BUTTON_DPAD_RIGHT)) {
        buttons |= 1u << SDL_GAMEPAD_BUTTON_DPAD_RIGHT;
    }

    if (SDL_GetGamepadButton(GameController, SDL_GAMEPAD_BUTTON_DPAD_LEFT)) {
        buttons |= 1u << SDL_GAMEPAD_BUTTON_DPAD_LEFT;
    }

    if (SDL_GetGamepadButton(GameController, SDL_GAMEPAD_BUTTON_DPAD_UP)) {
        buttons |= 1u << SDL_GAMEPAD_BUTTON_DPAD_UP;
    }

    if (SDL_GetGamepadButton(GameController, SDL_GAMEPAD_BUTTON_DPAD_DOWN)) {
        buttons |= 1u << SDL_GAMEPAD_BUTTON_DPAD_DOWN;
    }

    if (SDL_GetGamepadButton(GameController, SDL_GAMEPAD_BUTTON_START)) {
        buttons |= 1u << SDL_GAMEPAD_BUTTON_START;
    }

    if (SDL_GetGamepadButton(GameController, SDL_GAMEPAD_BUTTON_BACK)) {
        buttons |= 1u << SDL_GAMEPAD_BUTTON_BACK;
    }

    return buttons;
}

PLATFORM_ABI uint64_t GetControllerInput(void)
{
    if (!InitGameController()) {
        return GAME_INPUT_NONE;
    }

    SDL_UpdateGamepads();

    uint32_t buttons =
            GetGameControllerButtons();

    uint32_t pressed =
            (buttons ^ PrevGamepadButtons) & buttons;

    PrevGamepadButtons = buttons;

    if (!pressed) {
        return GAME_INPUT_NONE;
    }

    if (pressed & (1u << SDL_GAMEPAD_BUTTON_DPAD_RIGHT)) {
        return GAME_INPUT_RIGHT;
    }

    if (pressed & (1u << SDL_GAMEPAD_BUTTON_DPAD_LEFT)) {
        return GAME_INPUT_LEFT;
    }

    if (pressed & (1u << SDL_GAMEPAD_BUTTON_DPAD_UP)) {
        return GAME_INPUT_UP;
    }

    if (pressed & (1u << SDL_GAMEPAD_BUTTON_DPAD_DOWN)) {
        return GAME_INPUT_DOWN;
    }

    if (pressed & (1u << SDL_GAMEPAD_BUTTON_START)) {
        return GAME_INPUT_CONFIRM;
    }

    if (pressed & (1u << SDL_GAMEPAD_BUTTON_BACK)) {
        return GAME_INPUT_BACK;
    }

    return GAME_INPUT_NONE;
}

PLATFORM_ABI const char *PlatformGetInputLabel(uint64_t inputType)
{
    if (inputType != INPUT_TYPE_CONTROLLER) {
        return "KEYBOARD";
    }

    if (!InitGameController()) {
        return "CONTROLLER";
    }

    SDL_GamepadType type =
            SDL_GetGamepadType(GameController);

    switch (type) {
        case SDL_GAMEPAD_TYPE_PS4:
            return "DUALSHOCK";

        case SDL_GAMEPAD_TYPE_PS5:
            return "DUALSENSE";

        case SDL_GAMEPAD_TYPE_XBOX360:
        case SDL_GAMEPAD_TYPE_XBOXONE:
            return "XBOX CONTROLLER";

        default:
            return "CONTROLLER";
    }
}

//=======================================
// AUDIO - SDL
//=======================================

static void SDLCALL MixAudioCallback(
        void *userdata,
        SDL_AudioStream *stream,
        int additionalAmount,
        int totalAmount
)
{
    (void)userdata;
    (void)totalAmount;

    if (additionalAmount <= 0) {
        return;
    }

    Uint8 *buffer =
            SDL_calloc(1, (size_t)additionalAmount);

    if (!buffer) {
        return;
    }

    for (int i = 0; i < MAX_AUDIO_VOICES; ++i) {
        AUDIO_VOICE *voice =
                &AudioVoices[i];

        if (!voice->active || !voice->sound || !voice->sound->data) {
            continue;
        }

        Uint32 remaining =
                voice->sound->length -
                voice->position;

        Uint32 bytesToMix =
                remaining < (Uint32)additionalAmount ?
                remaining :
                (Uint32)additionalAmount;

        if (bytesToMix > 0) {
            SDL_MixAudio(
                    buffer,
                    voice->sound->data + voice->position,
                    AudioSpec.format,
                    bytesToMix,
                    1.0f
            );

            voice->position += bytesToMix;
        }

        if (voice->position >= voice->sound->length) {
            voice->sound = NULL;
            voice->position = 0;
            voice->active = false;
        }
    }

    SDL_PutAudioStreamData(stream, buffer, additionalAmount);
    SDL_free(buffer);
}

PLATFORM_ABI bool InitAudio(void)
{
    if (!SDL_WasInit(SDL_INIT_AUDIO)) {
        if (!SDL_InitSubSystem(SDL_INIT_AUDIO)) {
            return false;
        }
    }

    if (AudioStream) {
        return true;
    }

    AudioStream =
            SDL_OpenAudioDeviceStream(
                    SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
                    NULL,
                    MixAudioCallback,
                    NULL
            );

    if (!AudioStream) {
        return false;
    }

    SDL_AudioSpec streamSpec;

    if (!SDL_GetAudioStreamFormat(
            AudioStream,
            &streamSpec,
            NULL
    )) {
        SDL_DestroyAudioStream(AudioStream);
        AudioStream = NULL;
        return false;
    }

    AudioSpec = streamSpec;

    SDL_ResumeAudioStreamDevice(AudioStream);

    return true;
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
    Uint8 *wavData = NULL;
    Uint32 wavLength = 0;
    Uint8 *convertedData = NULL;
    int convertedLength = 0;
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
        sound->data = NULL;
        sound->length = 0;
    }

    if (AudioStream) {
        SDL_LockAudioStream(AudioStream);
    }

    if (sound->data) {
        SDL_free(sound->data);
        sound->data = NULL;
        sound->length = 0;
    }

    for (int i = 0; i < MAX_AUDIO_VOICES; ++i) {
        if (AudioVoices[i].sound == sound) {
            AudioVoices[i].sound = NULL;
            AudioVoices[i].position = 0;
            AudioVoices[i].active = false;
        }
    }

    if (AudioStream) {
        SDL_UnlockAudioStream(AudioStream);
    }

    if (!InitAudio()) {
        return false;
    }

    if (!SDL_LoadWAV(
            file,
            &spec,
            &wavData,
            &wavLength
    )) {
        return false;
    }

    if (!SDL_ConvertAudioSamples(
            &spec,
            wavData,
            (int)wavLength,
            &AudioSpec,
            &convertedData,
            &convertedLength
    )) {
        SDL_free(wavData);
        return false;
    }

    SDL_free(wavData);

    sound->data = convertedData;
    sound->length = (Uint32)convertedLength;

    return true;
}

PLATFORM_ABI void PlayAudio(const char *alias, bool async)
{
    SOUND *sound = FindAudioSound(alias);

    if (!sound || !sound->data || sound->length == 0) {
        return;
    }

    if (!AudioStream && !InitAudio()) {
        return;
    }

    if (!SDL_LockAudioStream(AudioStream)) {
        return;
    }

    AUDIO_VOICE *selectedVoice = NULL;

    for (int i = 0; i < MAX_AUDIO_VOICES; ++i) {
        if (AudioVoices[i].active && AudioVoices[i].sound == sound) {
            selectedVoice = &AudioVoices[i];
            break;
        }
    }

    if (!selectedVoice) {
        for (int i = 0; i < MAX_AUDIO_VOICES; ++i) {
            if (!AudioVoices[i].active) {
                selectedVoice = &AudioVoices[i];
                break;
            }
        }
    }

    if (!selectedVoice) {
        selectedVoice = &AudioVoices[0];
    }

    selectedVoice->sound = sound;
    selectedVoice->position = 0;
    selectedVoice->active = true;

    SDL_UnlockAudioStream(AudioStream);

    if (!async) {
        bool stillPlaying = true;

        while (stillPlaying) {
            SDL_Delay(1);

            stillPlaying = false;

            if (SDL_LockAudioStream(AudioStream)) {
                for (int i = 0; i < MAX_AUDIO_VOICES; ++i) {
                    if (AudioVoices[i].active && AudioVoices[i].sound == sound) {
                        stillPlaying = true;
                        break;
                    }
                }

                SDL_UnlockAudioStream(AudioStream);
            }
        }
    }
}
