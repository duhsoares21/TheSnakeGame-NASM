#include <stdint.h>
#include <stdbool.h>

typedef struct RENDER_CONTEXT RENDER_CONTEXT;
typedef struct U_RECT U_RECT;
typedef struct SOUND SOUND;
typedef uintptr_t PlatformHandle;
typedef uintptr_t PlatformSound;

#if defined(__x86_64__) || defined(_M_X64)
    #if defined(__clang__) || defined(__GNUC__)
        #define PLATFORM_ABI __attribute__((sysv_abi))
    #else
        #define PLATFORM_ABI
    #endif
#else
    #define PLATFORM_ABI
#endif

typedef enum
{
    GAME_INPUT_NONE = 0,
    GAME_INPUT_RIGHT = 1,
    GAME_INPUT_LEFT = 2,
    GAME_INPUT_UP = 3,
    GAME_INPUT_DOWN = 4,
    GAME_INPUT_CONFIRM = 5,
    GAME_INPUT_BACK = 6,
    GAME_INPUT_QUIT = 7,
    GAME_INPUT_PAUSE = 8,
    GAME_INPUT_TOGGLE_FPS = 9
} GAME_INPUT;

typedef enum
{
    INPUT_TYPE_KEYBOARD = 1,
    INPUT_TYPE_CONTROLLER = 2
} INPUT_TYPE;

typedef enum
{
    PLATFORM_WINDOW_MAIN = 1,
    PLATFORM_WINDOW_GAME = 2
} PLATFORM_WINDOW;

//WINDOW
PLATFORM_ABI bool PlatformCreateMainWindow(int32_t width, int32_t height);
PLATFORM_ABI bool PlatformCreateGameWindow(int32_t width, int32_t height);
PLATFORM_ABI void PlatformRunMessageLoop(void);
PLATFORM_ABI void PlatformShowMainWindow(void);
PLATFORM_ABI void PlatformHideMainWindow(void);
PLATFORM_ABI void PlatformDestroyMainWindow(void);
PLATFORM_ABI void PlatformCloseGameWindow(void);
PLATFORM_ABI void PlatformExitProcess(uint64_t exitCode);
PLATFORM_ABI void PlatformStartGameTimer(uint64_t timerValue);
PLATFORM_ABI void PlatformStopGameTimer(void);
PLATFORM_ABI uint64_t PlatformGetFPS(void);
PLATFORM_ABI PlatformHandle PlatformBeginWindowRender(uint64_t window, RENDER_CONTEXT *context, int32_t width, int32_t height);
PLATFORM_ABI void PlatformEndWindowRender(uint64_t window, RENDER_CONTEXT *context);

//RENDER
PLATFORM_ABI void InitRender(PlatformHandle window, RENDER_CONTEXT *context);
PLATFORM_ABI void BeginRender(RENDER_CONTEXT *context, int32_t right, int32_t  bottom);
PLATFORM_ABI void EndRender(PlatformHandle deviceContext, RENDER_CONTEXT *context);

PLATFORM_ABI void DrawTile(PlatformHandle deviceContext, int32_t  x, int32_t  y, uint32_t Color, int32_t TileSize);
PLATFORM_ABI void FillRectangle(PlatformHandle deviceContext, U_RECT *U_Rectangle, uint32_t Color);

//HUD
PLATFORM_ABI void DrawHUD(PlatformHandle deviceContext, char *text, U_RECT *U_rectangle, int32_t Color, char *font, int fontSize);

//AUDIO
PLATFORM_ABI bool LoadAudio(const char *alias, const char *file);
PLATFORM_ABI void PlayAudio(const char *alias, bool async);

//INPUT
PLATFORM_ABI uint64_t GetKeyboardInput(uint64_t key);
PLATFORM_ABI uint64_t GetControllerInput(void);
PLATFORM_ABI const char *PlatformGetInputLabel(uint64_t inputType);
