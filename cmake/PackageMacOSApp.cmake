if(NOT DEFINED BUNDLE_PATH)
    message(FATAL_ERROR "BUNDLE_PATH is required")
endif()

if(NOT DEFINED OUTPUT_DIR)
    message(FATAL_ERROR "OUTPUT_DIR is required")
endif()

file(MAKE_DIRECTORY "${OUTPUT_DIR}")
file(REMOVE_RECURSE "${OUTPUT_DIR}/SnakeGame.app")
file(COPY "${BUNDLE_PATH}" DESTINATION "${OUTPUT_DIR}")

set(PUBLISHED_APP "${OUTPUT_DIR}/SnakeGame.app")
set(PUBLISHED_EXECUTABLE "${PUBLISHED_APP}/Contents/MacOS/SnakeGame")

# Copy every non-system dylib used by the executable (including indirect
# dependencies such as FreeType/HarfBuzz) into Contents/Frameworks and rewrite
# their install names to @executable_path-relative paths. This is what makes the
# app independent of Homebrew, MacPorts, and the build machine's directories.
include(BundleUtilities)
get_filename_component(SDL_LIB_DIR "${SDL_LIB}" DIRECTORY)
get_filename_component(SDL_TTF_LIB_DIR "${SDL_TTF_LIB}" DIRECTORY)
fixup_bundle(
        "${PUBLISHED_APP}"
        ""
        "${SDL_LIB_DIR};${SDL_TTF_LIB_DIR}"
)

# FAT/NTFS-mounted workspaces can create AppleDouble sidecar files (._*) while
# the bundle is assembled. codesign treats these as invalid bundle components.
file(GLOB_RECURSE APPLEDOUBLE_FILES LIST_DIRECTORIES FALSE
        "${PUBLISHED_APP}/._*")
if(APPLEDOUBLE_FILES)
    file(REMOVE ${APPLEDOUBLE_FILES})
endif()

# fixup_bundle changes Mach-O files, invalidating any previous signatures.
# An ad-hoc signature is enough for local/direct distribution; a Developer ID
# signature and notarization can be applied later for Gatekeeper-friendly public
# distribution.
execute_process(
        COMMAND /usr/bin/codesign --force --deep --sign - "${PUBLISHED_APP}"
        RESULT_VARIABLE CODESIGN_RESULT
        ERROR_VARIABLE CODESIGN_ERROR
)
if(NOT CODESIGN_RESULT EQUAL 0)
    message(FATAL_ERROR "Could not ad-hoc sign the app: ${CODESIGN_ERROR}")
endif()

execute_process(
        COMMAND /usr/bin/lipo -archs "${PUBLISHED_EXECUTABLE}"
        OUTPUT_VARIABLE APP_ARCHS
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE LIPO_RESULT
)
if(NOT LIPO_RESULT EQUAL 0 OR NOT APP_ARCHS MATCHES "(^| )x86_64($| )")
    message(FATAL_ERROR "Published app is not an x86_64/Rosetta-compatible binary (architectures: ${APP_ARCHS})")
endif()

message(STATUS "Created self-contained ${PUBLISHED_APP} (${APP_ARCHS}; Apple Silicon uses Rosetta 2)")
