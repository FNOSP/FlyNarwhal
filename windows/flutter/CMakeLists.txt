# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# TODO: Move the rest of this into files in ephemeral. See
# https://github.com/flutter/flutter/issues/57146.
set(FLUTTER_ENGINE_FALLBACK_ROOT "${FLUTTER_ROOT}/bin/cache/artifacts/engine/windows-x64")
set(WRAPPER_ROOT "${EPHEMERAL_DIR}/cpp_client_wrapper")
set(WRAPPER_FALLBACK_ROOT "${FLUTTER_ENGINE_FALLBACK_ROOT}/cpp_client_wrapper")
set(WRAPPER_BUILD_ROOT "${WRAPPER_FALLBACK_ROOT}")

# Sync the SDK wrapper sources into the ephemeral directory when Flutter only
# generates headers there. This keeps launch_app aligned with the template paths.
if (NOT EXISTS "${WRAPPER_ROOT}/core_implementations.cc")
  file(MAKE_DIRECTORY "${WRAPPER_ROOT}")
  file(COPY "${WRAPPER_FALLBACK_ROOT}/" DESTINATION "${WRAPPER_ROOT}")
endif()

# Set fallback configurations for older versions of the flutter tool.
if (NOT DEFINED FLUTTER_TARGET_PLATFORM)
  set(FLUTTER_TARGET_PLATFORM "windows-x64")
endif()

# Keep a lightweight repair step available for tool invocations that recreate
# the ephemeral directory with incomplete runtime or wrapper files.
set(FLUTTER_EPHEMERAL_REPAIR_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/cmake/ensure_ephemeral_artifacts.cmake")

# === Flutter Library ===
set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/flutter_windows.dll")
set(FLUTTER_LIBRARY_IMPORT "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_windows.dll.lib")

# Published to parent scope for install step.
set(FLUTTER_LIBRARY ${FLUTTER_LIBRARY} PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)
set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build/" PARENT_SCOPE)
set(AOT_LIBRARY "${PROJECT_DIR}/build/windows/app.so" PARENT_SCOPE)

list(APPEND FLUTTER_LIBRARY_HEADERS
  "flutter_export.h"
  "flutter_windows.h"
  "flutter_messenger.h"
  "flutter_plugin_registrar.h"
  "flutter_texture_registrar.h"
)
list(TRANSFORM FLUTTER_LIBRARY_HEADERS PREPEND "${EPHEMERAL_DIR}/")
add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${FLUTTER_ENGINE_FALLBACK_ROOT}"
  "${EPHEMERAL_DIR}"
)
target_link_libraries(flutter INTERFACE "${FLUTTER_LIBRARY_IMPORT}")
add_dependencies(flutter flutter_assemble)

# === Wrapper ===
# Compile wrapper sources from the Flutter SDK cache so builds remain stable
# even if the ephemeral tree is regenerated or partially cleaned mid-build.
list(APPEND CPP_WRAPPER_SOURCE_NAMES_CORE
  "core_implementations.cc"
  "standard_codec.cc"
)
set(CPP_WRAPPER_SOURCES_CORE ${CPP_WRAPPER_SOURCE_NAMES_CORE})
list(TRANSFORM CPP_WRAPPER_SOURCES_CORE PREPEND "${WRAPPER_BUILD_ROOT}/")
set(CPP_WRAPPER_OUTPUTS_CORE ${CPP_WRAPPER_SOURCE_NAMES_CORE})
list(TRANSFORM CPP_WRAPPER_OUTPUTS_CORE PREPEND "${WRAPPER_ROOT}/")
list(APPEND CPP_WRAPPER_SOURCE_NAMES_PLUGIN
  "plugin_registrar.cc"
)
set(CPP_WRAPPER_SOURCES_PLUGIN ${CPP_WRAPPER_SOURCE_NAMES_PLUGIN})
list(TRANSFORM CPP_WRAPPER_SOURCES_PLUGIN PREPEND "${WRAPPER_BUILD_ROOT}/")
set(CPP_WRAPPER_OUTPUTS_PLUGIN ${CPP_WRAPPER_SOURCE_NAMES_PLUGIN})
list(TRANSFORM CPP_WRAPPER_OUTPUTS_PLUGIN PREPEND "${WRAPPER_ROOT}/")
list(APPEND CPP_WRAPPER_SOURCE_NAMES_APP
  "flutter_engine.cc"
  "flutter_view_controller.cc"
)
set(CPP_WRAPPER_SOURCES_APP ${CPP_WRAPPER_SOURCE_NAMES_APP})
list(TRANSFORM CPP_WRAPPER_SOURCES_APP PREPEND "${WRAPPER_BUILD_ROOT}/")
set(CPP_WRAPPER_OUTPUTS_APP ${CPP_WRAPPER_SOURCE_NAMES_APP})
list(TRANSFORM CPP_WRAPPER_OUTPUTS_APP PREPEND "${WRAPPER_ROOT}/")

# Wrapper sources needed for a plugin.
add_library(flutter_wrapper_plugin STATIC
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_PLUGIN}
)
apply_standard_settings(flutter_wrapper_plugin)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_link_libraries(flutter_wrapper_plugin PUBLIC flutter)
target_include_directories(flutter_wrapper_plugin PUBLIC
  "${WRAPPER_BUILD_ROOT}/include"
  "${WRAPPER_ROOT}/include"
  "${EPHEMERAL_DIR}"
)
add_dependencies(flutter_wrapper_plugin flutter_assemble)

# Wrapper sources needed for the runner.
add_library(flutter_wrapper_app STATIC
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_APP}
)
apply_standard_settings(flutter_wrapper_app)
target_link_libraries(flutter_wrapper_app PUBLIC flutter)
target_include_directories(flutter_wrapper_app PUBLIC
  "${WRAPPER_BUILD_ROOT}/include"
  "${WRAPPER_ROOT}/include"
  "${EPHEMERAL_DIR}"
)
add_dependencies(flutter_wrapper_app flutter_assemble)

# === Flutter tool backend ===
# _phony_ is a non-existent file to force this command to run every time,
# since currently there's no way to get a full input/output list from the
# flutter tool.
set(PHONY_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/_phony_")
set_source_files_properties("${PHONY_OUTPUT}" PROPERTIES SYMBOLIC TRUE)
add_custom_command(
  OUTPUT ${FLUTTER_LIBRARY} ${FLUTTER_LIBRARY_HEADERS}
    ${CPP_WRAPPER_OUTPUTS_CORE} ${CPP_WRAPPER_OUTPUTS_PLUGIN}
    ${CPP_WRAPPER_OUTPUTS_APP}
    ${PHONY_OUTPUT}
  COMMAND ${CMAKE_COMMAND} -E env
    ${FLUTTER_TOOL_ENVIRONMENT}
    "${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.bat"
      ${FLUTTER_TARGET_PLATFORM} $<CONFIG>
  VERBATIM
)
add_custom_target(flutter_assemble DEPENDS
  "${FLUTTER_LIBRARY}"
  ${FLUTTER_LIBRARY_HEADERS}
  ${CPP_WRAPPER_OUTPUTS_CORE}
  ${CPP_WRAPPER_OUTPUTS_PLUGIN}
  ${CPP_WRAPPER_OUTPUTS_APP}
)

# Re-check the ephemeral directory after flutter_assemble, but only repair
# files that are missing so normal incremental builds return quickly.
add_custom_target(flutter_ensure_ephemeral_artifacts
  COMMAND ${CMAKE_COMMAND}
    -DWRAPPER_ROOT=${WRAPPER_ROOT}
    -DWRAPPER_FALLBACK_ROOT=${WRAPPER_FALLBACK_ROOT}
    -DEPHEMERAL_DIR=${EPHEMERAL_DIR}
    -DFLUTTER_ENGINE_FALLBACK_ROOT=${FLUTTER_ENGINE_FALLBACK_ROOT}
    -DPLUGIN_LINKS_DIR=${EPHEMERAL_DIR}/.plugin_symlinks
    -P ${FLUTTER_EPHEMERAL_REPAIR_SCRIPT}
  COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/flutter_ensure_ephemeral_artifacts"
  DEPENDS flutter_assemble
  VERBATIM
)

add_dependencies(flutter_wrapper_plugin flutter_ensure_ephemeral_artifacts)
add_dependencies(flutter_wrapper_app flutter_ensure_ephemeral_artifacts)
