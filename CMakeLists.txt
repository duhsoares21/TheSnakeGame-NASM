cmake_minimum_required(VERSION 3.25)

if(WIN32)
    set(CMAKE_ASM_NASM_OBJECT_FORMAT win64)
elseif(APPLE)
    # The game itself contains x86-64 NASM, so one x86_64 build is the only
    # binary that can run on both Intel Macs and Apple Silicon Macs (via
    # Rosetta 2).  An arm64/universal build requires an arm64 port of the ASM.
    if(NOT DEFINED CMAKE_OSX_ARCHITECTURES)
        set(CMAKE_OSX_ARCHITECTURES x86_64 CACHE STRING "macOS target architecture")
    endif()
    if(NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
        # The currently supported Homebrew SDL_ttf dependencies target macOS
        # 14, so advertising an older target here would produce a misleading
        # binary that fails at runtime on that older OS.
        set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "Oldest supported macOS version")
    endif()

    set(CMAKE_ASM_NASM_OBJECT_FORMAT macho64)
else()
    set(CMAKE_ASM_NASM_OBJECT_FORMAT elf64)
endif()

if(WIN32)
    find_program(SNAKE_CLANG_CL_EXECUTABLE
            NAMES clang-cl
            PATHS
                "C:/Program Files/LLVM/bin"
                "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/Llvm/x64/bin"
                "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/Llvm/bin"
            NO_DEFAULT_PATH
    )

    if(SNAKE_CLANG_CL_EXECUTABLE)
        set(CMAKE_C_COMPILER "${SNAKE_CLANG_CL_EXECUTABLE}" CACHE FILEPATH "C compiler" FORCE)
        set(CMAKE_CXX_COMPILER "${SNAKE_CLANG_CL_EXECUTABLE}" CACHE FILEPATH "C++ compiler" FORCE)
    endif()
endif()

project(SnakeGame LANGUAGES C ASM_NASM)

if(WIN32)
    enable_language(RC)
endif()

if(WIN32 AND NOT CMAKE_C_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "SnakeGame requires Clang on Windows because the ASM/C platform boundary uses System V ABI.")
endif()

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(SNAKE_PLATFORM "AUTO" CACHE STRING "Platform backend: AUTO, WINDOWS, SDL")
set_property(CACHE SNAKE_PLATFORM PROPERTY STRINGS AUTO WINDOWS SDL)

add_subdirectory(vendored/SDL EXCLUDE_FROM_ALL)

option(SNAKE_USE_VENDORED_TTF_DEPS "Build SDL_ttf third-party dependencies from vendored sources" OFF)
set(SDLTTF_VENDORED ${SNAKE_USE_VENDORED_TTF_DEPS} CACHE BOOL "" FORCE)

add_subdirectory(vendored/SDL_ttf EXCLUDE_FROM_ALL)

set(SNAKE_ASM_SOURCES
        main.asm
        hud.asm
        input.asm
        audio.asm
        food.asm
        snake.asm
        snake_controller.asm
        snake_state_machine.asm
        collision.asm
        game_state_machine.asm
        game.asm
)

set(SNAKE_ICON_ICO "${CMAKE_SOURCE_DIR}/icon.ico")
set(SNAKE_ICON_ICNS "${CMAKE_SOURCE_DIR}/packaging/icons/icon.icns")
set(SNAKE_ICON_PNG "${CMAKE_SOURCE_DIR}/packaging/icons/icon_32.png")

function(configure_snake_target target_name backend output_dir)
    set(platform_source)
    set(executable_options)
    set(extra_sources)

    if(backend STREQUAL "WINDOWS")
        if(NOT WIN32)
            message(FATAL_ERROR "The WINDOWS backend can only be built on Windows.")
        endif()

        set(platform_source platform/windows.c)
    elseif(backend STREQUAL "SDL")
        set(platform_source platform/sdl.c)
    else()
        message(FATAL_ERROR "Unknown backend value: ${backend}")
    endif()

    if(WIN32)
        list(APPEND extra_sources platform/windows_resources.rc)
    endif()

    if(APPLE)
        list(APPEND executable_options MACOSX_BUNDLE)
        list(APPEND extra_sources "${SNAKE_ICON_ICNS}")
        set_source_files_properties("${SNAKE_ICON_ICNS}" PROPERTIES
                MACOSX_PACKAGE_LOCATION Resources
        )
    endif()

    add_executable(${target_name}
            ${executable_options}
            ${SNAKE_ASM_SOURCES}
            ${platform_source}
            ${extra_sources}
    )

    set_target_properties(${target_name} PROPERTIES
            LINKER_LANGUAGE C
            OUTPUT_NAME SnakeGame
            RUNTIME_OUTPUT_DIRECTORY "${output_dir}"
            LIBRARY_OUTPUT_DIRECTORY "${output_dir}"
            ARCHIVE_OUTPUT_DIRECTORY "${output_dir}"
    )

    target_include_directories(${target_name} PRIVATE
            ${CMAKE_CURRENT_SOURCE_DIR}/includes
            ${CMAKE_CURRENT_SOURCE_DIR}/platform
    )

    target_link_libraries(${target_name} PRIVATE
            SDL3::SDL3
            SDL3_ttf::SDL3_ttf
    )

    if(WIN32)
        target_compile_definitions(${target_name} PRIVATE
                _CRT_SECURE_NO_WARNINGS
        )

        target_link_libraries(${target_name} PRIVATE
                ucrt
        )

        target_link_options(${target_name} PRIVATE
                "LINKER:/ENTRY:main"
                "LINKER:/SUBSYSTEM:WINDOWS"
        )

        if(backend STREQUAL "WINDOWS")
            target_link_libraries(${target_name} PRIVATE
                    winmm
                    kernel32
                    user32
                    gdi32
                    xinput
            )
        endif()
    endif()

    if(APPLE)
        set_target_properties(${target_name} PROPERTIES
                BUNDLE_OUTPUT_DIRECTORY "${output_dir}"
                MACOSX_BUNDLE_BUNDLE_NAME "Snake Game"
                MACOSX_BUNDLE_GUI_IDENTIFIER "com.snakegame.SnakeGame"
                MACOSX_BUNDLE_ICON_FILE "icon.icns"
                MACOSX_BUNDLE_INFO_STRING "Snake Game"
                BUILD_RPATH "@executable_path/../Frameworks"
                INSTALL_RPATH "@executable_path/../Frameworks"
        )

        target_compile_options(${target_name} PRIVATE
                $<$<COMPILE_LANGUAGE:ASM_NASM>:--prefix=_>
        )

        add_custom_command(
                TARGET ${target_name} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_BUNDLE_CONTENT_DIR:${target_name}>/Resources"
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_SOURCE_DIR}/audio"
                "$<TARGET_BUNDLE_CONTENT_DIR:${target_name}>/Resources/audio"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${SNAKE_ICON_ICO}"
                "$<TARGET_BUNDLE_CONTENT_DIR:${target_name}>/Resources/icon.ico"
                COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_BUNDLE_CONTENT_DIR:${target_name}>/Frameworks"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:SDL3::SDL3>"
                "$<TARGET_BUNDLE_CONTENT_DIR:${target_name}>/Frameworks/"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "$<TARGET_FILE:SDL3_ttf::SDL3_ttf>"
                "$<TARGET_BUNDLE_CONTENT_DIR:${target_name}>/Frameworks/"
        )
    else()
        add_custom_command(
                TARGET ${target_name} POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_SOURCE_DIR}/audio"
                "$<TARGET_FILE_DIR:${target_name}>/audio"
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${SNAKE_ICON_ICO}"
                "$<TARGET_FILE_DIR:${target_name}>/icon.ico"
        )
    endif()

    if(WIN32 AND backend STREQUAL "SDL")
        add_custom_command(
                TARGET ${target_name} POST_BUILD
                COMMAND ${CMAKE_COMMAND}
                -DEXECUTABLE=$<TARGET_FILE:${target_name}>
                -DOUTPUT_DIR=$<TARGET_FILE_DIR:${target_name}>
                -DSEARCH_DIRS=$<TARGET_FILE_DIR:SDL3::SDL3>\\;$<TARGET_FILE_DIR:SDL3_ttf::SDL3_ttf>
                -P ${CMAKE_SOURCE_DIR}/cmake/CopyWindowsRuntimeDependencies.cmake
                COMMENT "Copying SDL Windows runtime dependencies"
                VERBATIM
        )
    endif()
endfunction()

if(WIN32)
    set(SNAKE_WINDOWS_BUILD_DIR "${CMAKE_BINARY_DIR}/Windows Build")

    if(SNAKE_PLATFORM STREQUAL "AUTO")
        configure_snake_target(SnakeGameWin32 WINDOWS "${SNAKE_WINDOWS_BUILD_DIR}/Win32")
        configure_snake_target(SnakeGameSDL SDL "${SNAKE_WINDOWS_BUILD_DIR}/SDL")
        add_custom_target(publish DEPENDS SnakeGameWin32 SnakeGameSDL)
    elseif(SNAKE_PLATFORM STREQUAL "WINDOWS")
        configure_snake_target(SnakeGameWin32 WINDOWS "${SNAKE_WINDOWS_BUILD_DIR}/Win32")
        add_custom_target(publish DEPENDS SnakeGameWin32)
    elseif(SNAKE_PLATFORM STREQUAL "SDL")
        configure_snake_target(SnakeGameSDL SDL "${SNAKE_WINDOWS_BUILD_DIR}/SDL")
        add_custom_target(publish DEPENDS SnakeGameSDL)
    else()
        message(FATAL_ERROR "Unknown SNAKE_PLATFORM value: ${SNAKE_PLATFORM}")
    endif()
else()
    if(SNAKE_PLATFORM STREQUAL "WINDOWS")
        message(FATAL_ERROR "The WINDOWS backend can only be built on Windows.")
    elseif(NOT SNAKE_PLATFORM STREQUAL "AUTO" AND NOT SNAKE_PLATFORM STREQUAL "SDL")
        message(FATAL_ERROR "Unknown SNAKE_PLATFORM value: ${SNAKE_PLATFORM}")
    endif()

    if(APPLE)
        configure_snake_target(SnakeGame SDL "${CMAKE_BINARY_DIR}/MacOS Build/Build")
    else()
        configure_snake_target(SnakeGame SDL "${CMAKE_BINARY_DIR}/Linux Build")
    endif()
endif()

if(UNIX AND NOT APPLE)
    set(SNAKE_PUBLISH_DIR "${CMAKE_BINARY_DIR}/Linux Build")
elseif(APPLE)
    set(SNAKE_PUBLISH_DIR "${CMAKE_BINARY_DIR}/MacOS Build")
else()
    set(SNAKE_PUBLISH_DIR "${CMAKE_BINARY_DIR}/Windows Build")
endif()

if(UNIX AND NOT APPLE)
    set(APPIMAGETOOL_EXECUTABLE "" CACHE FILEPATH "Path to appimagetool for Linux AppImage publishing.")
    set(APPIMAGE_RUNTIME_FILE "" CACHE FILEPATH "Path to the statically linked type-2 AppImage runtime.")
    option(SNAKE_DOWNLOAD_APPIMAGETOOL "Download appimagetool into the build directory when it is not found." ON)
    option(SNAKE_DOWNLOAD_APPIMAGE_RUNTIME "Download the statically linked AppImage runtime into the build directory." ON)

    if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64)$")
        set(SNAKE_APPIMAGE_ARCH "x86_64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64|ARM64)$")
        set(SNAKE_APPIMAGE_ARCH "aarch64")
    else()
        set(SNAKE_APPIMAGE_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
    endif()

    add_custom_target(package_appimage ALL
            DEPENDS SnakeGame
            COMMAND ${CMAKE_COMMAND}
            -DAPPDIR=${CMAKE_BINARY_DIR}/SnakeGame.AppDir
            -DEXECUTABLE=$<TARGET_FILE:SnakeGame>
            -DSDL_LIB=$<TARGET_FILE:SDL3::SDL3>
            -DSDL_TTF_LIB=$<TARGET_FILE:SDL3_ttf::SDL3_ttf>
            -DSOURCE_DIR=${CMAKE_SOURCE_DIR}
            -DOUTPUT_DIR=${SNAKE_PUBLISH_DIR}
            -DICON_PNG=${SNAKE_ICON_PNG}
            -DARCH=${SNAKE_APPIMAGE_ARCH}
            -DAPPIMAGETOOL_EXECUTABLE=${APPIMAGETOOL_EXECUTABLE}
            -DAPPIMAGE_RUNTIME_FILE=${APPIMAGE_RUNTIME_FILE}
            -DDOWNLOAD_APPIMAGETOOL=${SNAKE_DOWNLOAD_APPIMAGETOOL}
            -DDOWNLOAD_APPIMAGE_RUNTIME=${SNAKE_DOWNLOAD_APPIMAGE_RUNTIME}
            -DTOOLS_DIR=${CMAKE_BINARY_DIR}/tools
            -P ${CMAKE_SOURCE_DIR}/cmake/PackageAppImage.cmake
            COMMENT "Publishing SnakeGame AppImage"
            VERBATIM
    )

    add_custom_target(publish DEPENDS package_appimage)
elseif(APPLE)
    # Include packaging in CLion's normal Build Project action. Each profile
    # gets its own dist/SnakeGame.app containing all non-system dependencies.
    add_custom_target(package_macos_app ALL
            DEPENDS SnakeGame
            COMMAND ${CMAKE_COMMAND}
            -DBUNDLE_PATH=$<TARGET_BUNDLE_DIR:SnakeGame>
            -DOUTPUT_DIR=${SNAKE_PUBLISH_DIR}
            -DSDL_LIB=$<TARGET_FILE:SDL3::SDL3>
            -DSDL_TTF_LIB=$<TARGET_FILE:SDL3_ttf::SDL3_ttf>
            -P ${CMAKE_SOURCE_DIR}/cmake/PackageMacOSApp.cmake
            COMMENT "Publishing SnakeGame macOS app bundle"
            VERBATIM
    )

    add_custom_target(publish DEPENDS package_macos_app)
endif()
