cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# === Full libmpv bundling =================================================
# Run after the runner executable is linked, on every build type. Skips
# itself when the build host has a system libmpv.so.2 (so CI's apt-installed
# path stays the fast path). Otherwise downloads a self-contained closure
# from the Ubuntu 24.04 apt pool into a project-local cache and asks the
# bundler to copy the .so files into the binary's runtime directory.
# See linux/cmake/ensure_full_libmpv.cmake for the actual implementation.
#
# Note: this must live in the same directory scope as the target (`fly_narwhal`
# is created above), because add_custom_command(TARGET ... POST_BUILD) is
# rejected otherwise. Flutter's hot reload (`r`/`R`) only pushes a new Dart
# kernel and does not relink the ELF, so this hook only fires on actual C++
# rebuilds.
add_custom_command(
  TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND}
    -DFLY_NARWHAL_FETCH_FULL_LIBMPV=${FLY_NARWHAL_FETCH_FULL_LIBMPV}
    -DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}
    -DCMAKE_SOURCE_DIR=${CMAKE_SOURCE_DIR}
    -DCMAKE_BINARY_DIR=${CMAKE_BINARY_DIR}
    -P "${CMAKE_CURRENT_SOURCE_DIR}/../cmake/ensure_full_libmpv.cmake"
  COMMENT "Bundling full libmpv (downloads from Ubuntu apt pool if needed)"
  VERBATIM
)
