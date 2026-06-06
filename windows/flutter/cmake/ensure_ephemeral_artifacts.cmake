# Repair missing wrapper or runtime files without re-copying unchanged artifacts.

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

# Copy runtime files only when launch_app style builds leave them incomplete.
set(RUNTIME_FILES
  "flutter_export.h"
  "flutter_windows.h"
  "flutter_messenger.h"
  "flutter_plugin_registrar.h"
  "flutter_texture_registrar.h"
  "flutter_windows.dll"
  "flutter_windows.dll.lib"
  "icudtl.dat"
)

file(MAKE_DIRECTORY "${EPHEMERAL_DIR}")
foreach(RUNTIME_FILE ${RUNTIME_FILES})
  if (NOT EXISTS "${EPHEMERAL_DIR}/${RUNTIME_FILE}")
    file(COPY "${FLUTTER_ENGINE_FALLBACK_ROOT}/${RUNTIME_FILE}" DESTINATION "${EPHEMERAL_DIR}")
  endif()
endforeach()
