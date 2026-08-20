if(NOT DEFINED APPDIR)
    message(FATAL_ERROR "APPDIR is required")
endif()

if(NOT DEFINED EXECUTABLE)
    message(FATAL_ERROR "EXECUTABLE is required")
endif()

if(NOT DEFINED SDL_LIB)
    message(FATAL_ERROR "SDL_LIB is required")
endif()

if(NOT DEFINED SDL_TTF_LIB)
    message(FATAL_ERROR "SDL_TTF_LIB is required")
endif()

if(NOT DEFINED SOURCE_DIR)
    message(FATAL_ERROR "SOURCE_DIR is required")
endif()

if(NOT DEFINED ICON_PNG)
    message(FATAL_ERROR "ICON_PNG is required")
endif()

if(NOT DEFINED OUTPUT_DIR)
    message(FATAL_ERROR "OUTPUT_DIR is required")
endif()

if(NOT DEFINED ARCH)
    set(ARCH "x86_64")
endif()

if(NOT DEFINED DOWNLOAD_APPIMAGETOOL)
    set(DOWNLOAD_APPIMAGETOOL OFF)
endif()

if(NOT DEFINED DOWNLOAD_APPIMAGE_RUNTIME)
    set(DOWNLOAD_APPIMAGE_RUNTIME OFF)
endif()

if(NOT DEFINED TOOLS_DIR)
    set(TOOLS_DIR "${CMAKE_CURRENT_BINARY_DIR}/tools")
endif()

file(REMOVE_RECURSE "${APPDIR}")
file(MAKE_DIRECTORY
        "${APPDIR}/usr/bin"
        "${APPDIR}/usr/lib"
        "${APPDIR}/usr/share/applications"
        "${APPDIR}/usr/share/icons/hicolor/32x32/apps"
)

file(COPY_FILE "${EXECUTABLE}" "${APPDIR}/usr/bin/SnakeGame")
file(CHMOD "${APPDIR}/usr/bin/SnakeGame"
        PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)

file(COPY "${SOURCE_DIR}/audio" DESTINATION "${APPDIR}/usr/bin")
file(COPY_FILE "${SOURCE_DIR}/icon.ico" "${APPDIR}/usr/bin/icon.ico")

function(copy_shared_library library soname)
    get_filename_component(library_name "${library}" NAME)
    file(COPY_FILE "${library}" "${APPDIR}/usr/lib/${library_name}")

    if(NOT library_name STREQUAL soname)
        file(CREATE_LINK "${library_name}" "${APPDIR}/usr/lib/${soname}" SYMBOLIC)
    endif()
endfunction()

copy_shared_library("${SDL_LIB}" "libSDL3.so.0")
copy_shared_library("${SDL_TTF_LIB}" "libSDL3_ttf.so.0")

set(copied_runtime_libraries "")

function(should_skip_runtime_library library_name result_variable)
    if(library_name MATCHES "^(ld-linux|ld64|linux-vdso|libc\\.so|libm\\.so|libdl\\.so|libpthread\\.so|librt\\.so|libresolv\\.so|libgcc_s\\.so)")
        set(${result_variable} TRUE PARENT_SCOPE)
    else()
        set(${result_variable} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(copy_runtime_dependency_tree binary)
    if(NOT EXISTS "${binary}")
        return()
    endif()

    execute_process(
            COMMAND ldd "${binary}"
            OUTPUT_VARIABLE ldd_output
            ERROR_QUIET
    )

    string(REGEX MATCHALL "=> /[^ \n]+|[\t ]/[^ \n]+" dependency_matches "${ldd_output}")

    foreach(dependency_match IN LISTS dependency_matches)
        string(REGEX REPLACE "^=> " "" dependency_path "${dependency_match}")
        string(STRIP "${dependency_path}" dependency_path)

        if(NOT EXISTS "${dependency_path}")
            continue()
        endif()

        get_filename_component(dependency_name "${dependency_path}" NAME)
        should_skip_runtime_library("${dependency_name}" skip_library)

        if(skip_library)
            continue()
        endif()

        list(FIND copied_runtime_libraries "${dependency_name}" already_copied)

        if(NOT already_copied EQUAL -1)
            continue()
        endif()

        file(COPY_FILE "${dependency_path}" "${APPDIR}/usr/lib/${dependency_name}")
        list(APPEND copied_runtime_libraries "${dependency_name}")
        set(copied_runtime_libraries "${copied_runtime_libraries}" PARENT_SCOPE)

        copy_runtime_dependency_tree("${dependency_path}")
    endforeach()
endfunction()

copy_runtime_dependency_tree("${EXECUTABLE}")
copy_runtime_dependency_tree("${SDL_LIB}")
copy_runtime_dependency_tree("${SDL_TTF_LIB}")

file(WRITE "${APPDIR}/AppRun" [=[
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$HERE/usr/bin" || exit 1
exec "$HERE/usr/bin/SnakeGame" "$@"
]=])

file(CHMOD "${APPDIR}/AppRun"
        PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)

file(WRITE "${APPDIR}/SnakeGame.desktop" [=[
[Desktop Entry]
Type=Application
Name=Snake Game
Exec=SnakeGame
Icon=SnakeGame
Categories=Game;
Terminal=false
]=])

file(COPY_FILE
        "${APPDIR}/SnakeGame.desktop"
        "${APPDIR}/usr/share/applications/SnakeGame.desktop"
)

file(COPY_FILE
        "${ICON_PNG}"
        "${APPDIR}/usr/share/icons/hicolor/32x32/apps/SnakeGame.png"
)

file(COPY_FILE
        "${ICON_PNG}"
        "${APPDIR}/SnakeGame.png"
)

file(COPY_FILE "${ICON_PNG}" "${APPDIR}/.DirIcon")

if(NOT DEFINED APPIMAGETOOL_EXECUTABLE)
    find_program(APPIMAGETOOL_EXECUTABLE appimagetool)
endif()

if(NOT APPIMAGETOOL_EXECUTABLE)
    find_program(APPIMAGETOOL_EXECUTABLE appimagetool)
endif()

if(NOT APPIMAGETOOL_EXECUTABLE AND DOWNLOAD_APPIMAGETOOL)
    set(SUPPORTED_APPIMAGE_ARCHITECTURES
            x86_64
            i686
            aarch64
            armhf
    )

    if(NOT ARCH IN_LIST SUPPORTED_APPIMAGE_ARCHITECTURES)
        message(FATAL_ERROR
                "appimagetool was not found and automatic download is not available for ${ARCH}. Install appimagetool, put it on PATH, or set APPIMAGETOOL_EXECUTABLE."
        )
    endif()

    set(APPIMAGETOOL_DIR "${TOOLS_DIR}/appimagetool")
    set(DOWNLOADED_APPIMAGETOOL "${APPIMAGETOOL_DIR}/appimagetool-${ARCH}.AppImage")
    file(MAKE_DIRECTORY "${APPIMAGETOOL_DIR}")

    if(NOT EXISTS "${DOWNLOADED_APPIMAGETOOL}")
        message(STATUS "Downloading appimagetool to ${DOWNLOADED_APPIMAGETOOL}")
        file(DOWNLOAD
                "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
                "${DOWNLOADED_APPIMAGETOOL}"
                SHOW_PROGRESS
                STATUS download_status
        )

        list(GET download_status 0 download_result)
        list(GET download_status 1 download_message)

        if(NOT download_result EQUAL 0)
            file(REMOVE "${DOWNLOADED_APPIMAGETOOL}")
            message(FATAL_ERROR
                    "Could not download appimagetool: ${download_message}\n"
                    "Install appimagetool on PATH, or configure CMake with "
                    "-DAPPIMAGETOOL_EXECUTABLE=/absolute/path/to/appimagetool."
            )
        endif()
    endif()

    file(CHMOD "${DOWNLOADED_APPIMAGETOOL}"
            PERMISSIONS
            OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE
            WORLD_READ WORLD_EXECUTE
    )

    set(APPIMAGETOOL_EXECUTABLE "${DOWNLOADED_APPIMAGETOOL}")
endif()

if(NOT APPIMAGETOOL_EXECUTABLE)
    message(FATAL_ERROR
            "appimagetool was not found. Install appimagetool, put it on PATH, set APPIMAGETOOL_EXECUTABLE, or enable SNAKE_DOWNLOAD_APPIMAGETOOL. AppDir was staged at: ${APPDIR}"
    )
endif()

execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env
                "APPIMAGE_EXTRACT_AND_RUN=1"
                "${APPIMAGETOOL_EXECUTABLE}"
                --help
        OUTPUT_VARIABLE appimagetool_help
        ERROR_VARIABLE appimagetool_help_error
        RESULT_VARIABLE appimagetool_help_result
)

if(NOT appimagetool_help_result EQUAL 0 OR
        NOT "${appimagetool_help}${appimagetool_help_error}" MATCHES "--runtime-file")
    message(FATAL_ERROR
            "The configured appimagetool does not support --runtime-file. Use the current AppImage/appimagetool release or enable SNAKE_DOWNLOAD_APPIMAGETOOL."
    )
endif()

if(NOT APPIMAGE_RUNTIME_FILE AND DOWNLOAD_APPIMAGE_RUNTIME)
    set(SUPPORTED_APPIMAGE_ARCHITECTURES
            x86_64
            i686
            aarch64
            armhf
    )

    if(NOT ARCH IN_LIST SUPPORTED_APPIMAGE_ARCHITECTURES)
        message(FATAL_ERROR
                "The static AppImage runtime cannot be downloaded automatically for ${ARCH}. Set APPIMAGE_RUNTIME_FILE to a compatible runtime."
        )
    endif()

    set(APPIMAGE_RUNTIME_DIR "${TOOLS_DIR}/type2-runtime")
    set(DOWNLOADED_APPIMAGE_RUNTIME "${APPIMAGE_RUNTIME_DIR}/runtime-${ARCH}")
    file(MAKE_DIRECTORY "${APPIMAGE_RUNTIME_DIR}")

    if(NOT EXISTS "${DOWNLOADED_APPIMAGE_RUNTIME}")
        message(STATUS "Downloading static AppImage runtime to ${DOWNLOADED_APPIMAGE_RUNTIME}")
        file(DOWNLOAD
                "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-${ARCH}"
                "${DOWNLOADED_APPIMAGE_RUNTIME}"
                SHOW_PROGRESS
                STATUS runtime_download_status
        )

        list(GET runtime_download_status 0 runtime_download_result)
        list(GET runtime_download_status 1 runtime_download_message)

        if(NOT runtime_download_result EQUAL 0)
            file(REMOVE "${DOWNLOADED_APPIMAGE_RUNTIME}")
            message(FATAL_ERROR
                    "Could not download the static AppImage runtime: ${runtime_download_message}\n"
                    "Set APPIMAGE_RUNTIME_FILE to a compatible statically linked type-2 runtime."
            )
        endif()
    endif()

    set(APPIMAGE_RUNTIME_FILE "${DOWNLOADED_APPIMAGE_RUNTIME}")
endif()

if(NOT APPIMAGE_RUNTIME_FILE OR NOT EXISTS "${APPIMAGE_RUNTIME_FILE}")
    message(FATAL_ERROR
            "A statically linked type-2 AppImage runtime is required. Set APPIMAGE_RUNTIME_FILE or enable SNAKE_DOWNLOAD_APPIMAGE_RUNTIME."
    )
endif()

find_program(FILE_EXECUTABLE file REQUIRED)
execute_process(
        COMMAND "${FILE_EXECUTABLE}" "${APPIMAGE_RUNTIME_FILE}"
        OUTPUT_VARIABLE appimage_runtime_description
        ERROR_VARIABLE appimage_runtime_error
        RESULT_VARIABLE appimage_runtime_result
)

if(NOT appimage_runtime_result EQUAL 0 OR
        NOT appimage_runtime_description MATCHES "static")
    message(FATAL_ERROR
            "APPIMAGE_RUNTIME_FILE must point to a statically linked type-2 runtime: ${appimage_runtime_error}${appimage_runtime_description}"
    )
endif()

file(MAKE_DIRECTORY "${OUTPUT_DIR}")

execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env
                "ARCH=${ARCH}"
                "APPIMAGE_EXTRACT_AND_RUN=1"
                "${APPIMAGETOOL_EXECUTABLE}"
                --runtime-file "${APPIMAGE_RUNTIME_FILE}"
                "${APPDIR}"
                "${OUTPUT_DIR}/SnakeGame-${ARCH}.AppImage"
        RESULT_VARIABLE appimage_result
)

if(NOT appimage_result EQUAL 0)
    message(FATAL_ERROR "appimagetool failed with exit code ${appimage_result}")
endif()

message(STATUS "Created ${OUTPUT_DIR}/SnakeGame-${ARCH}.AppImage")
