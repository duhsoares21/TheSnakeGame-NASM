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
    if(NOT ARCH STREQUAL "x86_64")
        message(FATAL_ERROR
                "appimagetool was not found and automatic download is only configured for x86_64. Install appimagetool, put it on PATH, or set APPIMAGETOOL_EXECUTABLE."
        )
    endif()

    set(DOWNLOADED_APPIMAGETOOL "${TOOLS_DIR}/appimagetool-x86_64.AppImage")
    file(MAKE_DIRECTORY "${TOOLS_DIR}")

    if(NOT EXISTS "${DOWNLOADED_APPIMAGETOOL}")
        message(STATUS "Downloading appimagetool to ${DOWNLOADED_APPIMAGETOOL}")
        file(DOWNLOAD
                "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
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

file(MAKE_DIRECTORY "${OUTPUT_DIR}")

execute_process(
        COMMAND "${CMAKE_COMMAND}" -E env
                "ARCH=${ARCH}"
                "APPIMAGE_EXTRACT_AND_RUN=1"
                "${APPIMAGETOOL_EXECUTABLE}"
                "${APPDIR}"
                "${OUTPUT_DIR}/SnakeGame-${ARCH}.AppImage"
        RESULT_VARIABLE appimage_result
)

if(NOT appimage_result EQUAL 0)
    message(FATAL_ERROR "appimagetool failed with exit code ${appimage_result}")
endif()

message(STATUS "Created ${OUTPUT_DIR}/SnakeGame-${ARCH}.AppImage")
