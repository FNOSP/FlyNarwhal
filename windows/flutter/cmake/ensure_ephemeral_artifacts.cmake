# Repair missing wrapper or runtime files without re-copying unchanged artifacts.

# Fail fast when the Flutter SDK cache is unavailable, otherwise the wrapper
# repair step can appear successful while leaving the build broken.
if (NOT EXISTS "${WRAPPER_FALLBACK_ROOT}")
  message(FATAL_ERROR "Flutter wrapper fallback root is missing: ${WRAPPER_FALLBACK_ROOT}")
endif()

if (NOT EXISTS "${FLUTTER_ENGINE_FALLBACK_ROOT}")
  message(FATAL_ERROR "Flutter engine fallback root is missing: ${FLUTTER_ENGINE_FALLBACK_ROOT}")
endif()

# Copy wrapper sources only when tool_backend leaves gaps in the ephemeral tree.
set(WRAPPER_SOURCE_FILES
  "binary_messenger_impl.h"
  "byte_buffer_streams.h"
  "core_implementations.cc"
  "engine_method_result.cc"
  "flutter_engine.cc"
  "flutter_view_controller.cc"
  "plugin_registrar.cc"
  "standard_codec.cc"
  "texture_registrar_impl.h"
)

# Validate the fallback wrapper payload before copying any files into the
# ephemeral directory.
if (NOT EXISTS "${WRAPPER_FALLBACK_ROOT}/include")
  message(FATAL_ERROR "Flutter wrapper include directory is missing: ${WRAPPER_FALLBACK_ROOT}/include")
endif()

foreach(WRAPPER_SOURCE_FILE ${WRAPPER_SOURCE_FILES})
  if (NOT EXISTS "${WRAPPER_FALLBACK_ROOT}/${WRAPPER_SOURCE_FILE}")
    message(FATAL_ERROR "Flutter wrapper fallback file is missing: ${WRAPPER_FALLBACK_ROOT}/${WRAPPER_SOURCE_FILE}")
  endif()
endforeach()

set(WRAPPER_NEEDS_REPAIR FALSE)
if (NOT EXISTS "${WRAPPER_ROOT}/include")
  set(WRAPPER_NEEDS_REPAIR TRUE)
endif()

foreach(WRAPPER_SOURCE_FILE ${WRAPPER_SOURCE_FILES})
  if (NOT EXISTS "${WRAPPER_ROOT}/${WRAPPER_SOURCE_FILE}")
    set(WRAPPER_NEEDS_REPAIR TRUE)
  endif()
endforeach()

if (WRAPPER_NEEDS_REPAIR)
  file(MAKE_DIRECTORY "${WRAPPER_ROOT}")
  file(COPY "${WRAPPER_FALLBACK_ROOT}/include" DESTINATION "${WRAPPER_ROOT}")

  foreach(WRAPPER_SOURCE_FILE ${WRAPPER_SOURCE_FILES})
    if (NOT EXISTS "${WRAPPER_ROOT}/${WRAPPER_SOURCE_FILE}")
      file(COPY "${WRAPPER_FALLBACK_ROOT}/${WRAPPER_SOURCE_FILE}" DESTINATION "${WRAPPER_ROOT}")
    endif()
  endforeach()
endif()

# Fail immediately when the wrapper repair step still leaves missing sources.
if (NOT EXISTS "${WRAPPER_ROOT}/include")
  message(FATAL_ERROR "Flutter wrapper include directory was not restored: ${WRAPPER_ROOT}/include")
endif()

foreach(WRAPPER_SOURCE_FILE ${WRAPPER_SOURCE_FILES})
  if (NOT EXISTS "${WRAPPER_ROOT}/${WRAPPER_SOURCE_FILE}")
    message(FATAL_ERROR "Flutter wrapper file was not restored: ${WRAPPER_ROOT}/${WRAPPER_SOURCE_FILE}")
  endif()
endforeach()

# Copy runtime files only when launch_app style builds leave them incomplete.
set(RUNTIME_FILES
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

# Validate the fallback runtime payload before copying any files into the
# ephemeral directory.
foreach(RUNTIME_FILE ${RUNTIME_FILES})
  if (NOT EXISTS "${FLUTTER_ENGINE_FALLBACK_ROOT}/${RUNTIME_FILE}")
    message(FATAL_ERROR "Flutter runtime fallback file is missing: ${FLUTTER_ENGINE_FALLBACK_ROOT}/${RUNTIME_FILE}")
  endif()
endforeach()

file(MAKE_DIRECTORY "${EPHEMERAL_DIR}")
foreach(RUNTIME_FILE ${RUNTIME_FILES})
  if (NOT EXISTS "${EPHEMERAL_DIR}/${RUNTIME_FILE}")
    file(COPY "${FLUTTER_ENGINE_FALLBACK_ROOT}/${RUNTIME_FILE}" DESTINATION "${EPHEMERAL_DIR}")
  endif()
endforeach()

# Fail immediately when the runtime repair step still leaves missing files.
foreach(RUNTIME_FILE ${RUNTIME_FILES})
  if (NOT EXISTS "${EPHEMERAL_DIR}/${RUNTIME_FILE}")
    message(FATAL_ERROR "Flutter runtime file was not restored: ${EPHEMERAL_DIR}/${RUNTIME_FILE}")
  endif()
endforeach()

# Warn early when plugin links are missing so the next failure is not deferred
# to generated_plugins.cmake or Visual Studio.
if (DEFINED PLUGIN_LINKS_DIR AND NOT EXISTS "${PLUGIN_LINKS_DIR}")
  message(WARNING "Flutter plugin links directory is missing and will need to be regenerated: ${PLUGIN_LINKS_DIR}")
endif()
