if(NOT DEFINED EXECUTABLE)
    message(FATAL_ERROR "EXECUTABLE is required")
endif()

if(NOT DEFINED OUTPUT_DIR)
    message(FATAL_ERROR "OUTPUT_DIR is required")
endif()

if(NOT DEFINED SEARCH_DIRS)
    set(SEARCH_DIRS "")
endif()

file(GET_RUNTIME_DEPENDENCIES
        EXECUTABLES "${EXECUTABLE}"
        DIRECTORIES ${SEARCH_DIRS}
        RESOLVED_DEPENDENCIES_VAR RUNTIME_DEPENDENCIES
        UNRESOLVED_DEPENDENCIES_VAR UNRESOLVED_DEPENDENCIES
        PRE_EXCLUDE_REGEXES
            "api-ms-.*"
            "ext-ms-.*"
        POST_EXCLUDE_REGEXES
            ".*[Ww]indows[/\\\\][Ss]ystem32[/\\\\].*"
            ".*[Ww]indows[/\\\\][Ss]ysWOW64[/\\\\].*"
)

foreach(dependency IN LISTS RUNTIME_DEPENDENCIES)
    get_filename_component(dependency_name "${dependency}" NAME)
    file(TO_CMAKE_PATH "${dependency}" normalized_dependency)
    string(TOLOWER "${normalized_dependency}" normalized_dependency_lower)

    if(normalized_dependency_lower MATCHES ".*/windows/.*")
        continue()
    endif()

    if(normalized_dependency_lower MATCHES ".*/windowsapps/.*")
        continue()
    endif()

    file(COPY_FILE
            "${dependency}"
            "${OUTPUT_DIR}/${dependency_name}"
    )
endforeach()
