# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

set(FLUTTER_ENGINE_ARTIFACT_DIR_NAME "windows-x64")
if (CMAKE_BUILD_TYPE STREQUAL "Profile")
  set(FLUTTER_ENGINE_ARTIFACT_DIR_NAME "windows-x64-profile")
elseif(CMAKE_BUILD_TYPE STREQUAL "Release")
  set(FLUTTER_ENGINE_ARTIFACT_DIR_NAME "windows-x64-release")
endif()

# TODO: Move the rest of this into files in ephemeral. See
# https://github.com/flutter/flutter/issues/57146.
set(FLUTTER_ENGINE_FALLBACK_ROOT "${FLUTTER_ROOT}/bin/cache/artifacts/engine/${FLUTTER_ENGINE_ARTIFACT_DIR_NAME}")
set(WRAPPER_ROOT "${EPHEMERAL_DIR}/cpp_client_wrapper")
set(WRAPPER_FALLBACK_ROOT "${FLUTTER_ENGINE_FALLBACK_ROOT}/cpp_client_wrapper")
set(WRAPPER_BUILD_ROOT "${WRAPPER_FALLBACK_ROOT}")

# Pre-seed runtime artifacts when flutter run recreates the ephemeral tree
# without restoring the engine payload before Visual Studio starts building.
set(FLUTTER_RUNTIME_FALLBACK_FILES
  "flutter_export.h"
  "flutter_windows.h"
  "flutter_messenger.h"
  "flutter_plugin_registrar.h"
  "flutter_texture_registrar.h"
  "flutter_windows.dll"
  "flutter_windows.dll.exp"
  "flutter_windows.dll.lib"
  "flutter_windows.dll.pdb"
  "icudtl.dat"
)
file(MAKE_DIRECTORY "${EPHEMERAL_DIR}")
foreach(FLUTTER_RUNTIME_FILE ${FLUTTER_RUNTIME_FALLBACK_FILES})
  if (NOT EXISTS "${FLUTTER_ENGINE_FALLBACK_ROOT}/${FLUTTER_RUNTIME_FILE}")
    message(FATAL_ERROR "Flutter runtime fallback file is missing: ${FLUTTER_ENGINE_FALLBACK_ROOT}/${FLUTTER_RUNTIME_FILE}")
  endif()
  # Never overwrite files already staged by the flutter tool, otherwise a debug
  # engine payload would replace the mode-specific one in release builds.
  if (NOT EXISTS "${EPHEMERAL_DIR}/${FLUTTER_RUNTIME_FILE}")
    file(COPY "${FLUTTER_ENGINE_FALLBACK_ROOT}/${FLUTTER_RUNTIME_FILE}" DESTINATION "${EPHEMERAL_DIR}")
  endif()
endforeach()

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

# Multi-config generators (Visual Studio) leave CMAKE_BUILD_TYPE empty, so the
# repair step resolves the mode-specific engine payload from the build-time
# configuration instead of falling back to the debug artifact directory.
set(FLUTTER_RUNTIME_REPAIR_FALLBACK_ROOT "$<IF:$<STREQUAL:$<LOWER_CASE:$<CONFIG>>,debug>,${FLUTTER_ENGINE_FALLBACK_ROOT},$<IF:$<STREQUAL:$<LOWER_CASE:$<CONFIG>>,profile>,${FLUTTER_ROOT}/bin/cache/artifacts/engine/windows-x64-profile,${FLUTTER_ROOT}/bin/cache/artifacts/engine/windows-x64-release>>")

# === Flutter Library ===
# Use the stable engine cache for runtime headers and library references because
# flutter run may prune them from the ephemeral directory between build phases.
set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/flutter_windows.dll")
set(FLUTTER_LIBRARY_IMPORT "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_windows.dll.lib")
set(FLUTTER_RUNTIME_LIBRARY "${FLUTTER_ENGINE_FALLBACK_ROOT}/flutter_windows.dll")

# Prefer a stable runtime source for install because flutter run may recreate
# the ephemeral directory without repopulating runtime files before INSTALL.
set(FLUTTER_INSTALL_RUNTIME_ROOT "${EPHEMERAL_DIR}")
if (NOT EXISTS "${EPHEMERAL_DIR}/flutter_windows.dll" OR NOT EXISTS "${EPHEMERAL_DIR}/icudtl.dat")
  #region debug-point flutter-install-runtime-fallback
  message(STATUS "Flutter install runtime fallback enabled: ${FLUTTER_ENGINE_FALLBACK_ROOT}")
  #endregion
  set(FLUTTER_INSTALL_RUNTIME_ROOT "${FLUTTER_ENGINE_FALLBACK_ROOT}")
endif()
set(FLUTTER_INSTALL_LIBRARY "${FLUTTER_INSTALL_RUNTIME_ROOT}/flutter_windows.dll")
set(FLUTTER_INSTALL_ICU_DATA_FILE "${FLUTTER_INSTALL_RUNTIME_ROOT}/icudtl.dat")

# Published to parent scope for install step.
set(FLUTTER_LIBRARY ${FLUTTER_LIBRARY} PARENT_SCOPE)
set(FLUTTER_ROOT "${FLUTTER_ROOT}" PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)
set(FLUTTER_INSTALL_LIBRARY "${FLUTTER_INSTALL_LIBRARY}" PARENT_SCOPE)
set(FLUTTER_INSTALL_ICU_DATA_FILE "${FLUTTER_INSTALL_ICU_DATA_FILE}" PARENT_SCOPE)
set(PROJECT_BUILD_DIR "${PROJECT_DIR}/build/" PARENT_SCOPE)
set(AOT_LIBRARY "${PROJECT_DIR}/build/windows/app.so" PARENT_SCOPE)

list(APPEND FLUTTER_LIBRARY_HEADERS
  "flutter_export.h"
  "flutter_windows.h"
  "flutter_messenger.h"
  "flutter_plugin_registrar.h"
  "flutter_texture_registrar.h"
)
set(FLUTTER_RUNTIME_HEADERS ${FLUTTER_LIBRARY_HEADERS})
list(TRANSFORM FLUTTER_LIBRARY_HEADERS PREPEND "${EPHEMERAL_DIR}/")
list(TRANSFORM FLUTTER_RUNTIME_HEADERS PREPEND "${FLUTTER_ENGINE_FALLBACK_ROOT}/")
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
# Invoke the Flutter tool backend directly as a target because Visual Studio's
# output-based custom command graph can deadlock on synthetic file rules.
add_custom_target(flutter_assemble
  # Run tool_backend from the project root so Flutter can resolve .dart_tool
  # and other generated inputs using the same working directory as flutter CLI.
  COMMAND ${CMAKE_COMMAND} -E chdir "${PROJECT_DIR}"
    ${CMAKE_COMMAND} -E env
      ${FLUTTER_TOOL_ENVIRONMENT}
      "${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.bat"
        ${FLUTTER_TARGET_PLATFORM} $<CONFIG>
  VERBATIM
)

# Re-check the ephemeral directory after flutter_assemble, but only repair
# files that are missing so normal incremental builds return quickly.
add_custom_target(flutter_ensure_ephemeral_artifacts
  COMMAND ${CMAKE_COMMAND}
    -DWRAPPER_ROOT=${WRAPPER_ROOT}
    -DWRAPPER_FALLBACK_ROOT=${WRAPPER_FALLBACK_ROOT}
    -DEPHEMERAL_DIR=${EPHEMERAL_DIR}
    -DFLUTTER_ENGINE_FALLBACK_ROOT=${FLUTTER_ENGINE_FALLBACK_ROOT}
    -DRUNTIME_FALLBACK_ROOT=${FLUTTER_RUNTIME_REPAIR_FALLBACK_ROOT}
    -DPLUGIN_LINKS_DIR=${EPHEMERAL_DIR}/.plugin_symlinks
    -P ${FLUTTER_EPHEMERAL_REPAIR_SCRIPT}
  COMMAND ${CMAKE_COMMAND} -E touch "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/flutter_ensure_ephemeral_artifacts"
  DEPENDS flutter_assemble
  VERBATIM
)

add_dependencies(flutter_wrapper_plugin flutter_ensure_ephemeral_artifacts)
add_dependencies(flutter_wrapper_app flutter_ensure_ephemeral_artifacts)
