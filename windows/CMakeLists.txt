# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(fly_narwhal LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "fly_narwhal")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Suppress deprecated experimental coroutine errors from transitive Windows plugins.
add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)

# Serialize MSVC PDB writes for plugin targets built in parallel.
add_compile_options(/FS)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  # Serialize PDB writes to avoid MSVC C1041 during parallel wrapper builds.
  target_compile_options(${TARGET} PRIVATE /FS)
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
  # Suppress deprecated experimental coroutine warnings in MSVC
  target_compile_definitions(${TARGET} PRIVATE "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

function(ENSURE_VERIFIED_WINDOWS_ARCHIVE ARCHIVE_NAME ARCHIVE_URL ARCHIVE_MD5)
  set(ARCHIVE_PATH "${CMAKE_BINARY_DIR}/${ARCHIVE_NAME}")
  set(ARCHIVE_NEEDS_DOWNLOAD TRUE)

  # Drop stale or empty archives so plugin CMake files don't fail on corrupt
  # cached downloads left behind by previous configure attempts.
  if (EXISTS "${ARCHIVE_PATH}")
    file(SIZE "${ARCHIVE_PATH}" ARCHIVE_SIZE)
    file(MD5 "${ARCHIVE_PATH}" ARCHIVE_HASH)
    if (ARCHIVE_SIZE GREATER 0 AND ARCHIVE_HASH STREQUAL ARCHIVE_MD5)
      set(ARCHIVE_NEEDS_DOWNLOAD FALSE)
    else()
      file(REMOVE "${ARCHIVE_PATH}")
    endif()
  endif()

  # Pre-download large third-party archives with PowerShell because CMake's
  # file(DOWNLOAD) has intermittently produced zero-byte files in this setup.
  if (ARCHIVE_NEEDS_DOWNLOAD)
    file(TO_NATIVE_PATH "${ARCHIVE_PATH}" ARCHIVE_PATH_NATIVE)
    execute_process(
      COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
        "$ProgressPreference = 'SilentlyContinue'; $url = '${ARCHIVE_URL}'; $out = '${ARCHIVE_PATH_NATIVE}'; for ($i = 1; $i -le 3; $i++) { try { Invoke-WebRequest -Uri $url -OutFile $out -MaximumRedirection 10 -UseBasicParsing; if ((Test-Path $out) -and ((Get-Item $out).Length -gt 0)) { exit 0 } } catch { if (Test-Path $out) { Remove-Item $out -Force }; if ($i -eq 3) { throw }; Start-Sleep -Seconds 1 }; if (Test-Path $out) { Remove-Item $out -Force }; Start-Sleep -Seconds 1 }; exit 1"
      RESULT_VARIABLE ARCHIVE_DOWNLOAD_RESULT
      ERROR_VARIABLE ARCHIVE_DOWNLOAD_ERROR
    )
    if (NOT ARCHIVE_DOWNLOAD_RESULT EQUAL 0)
      message(FATAL_ERROR "Failed to pre-download ${ARCHIVE_NAME}: ${ARCHIVE_DOWNLOAD_ERROR}")
    endif()
  endif()

  if (NOT EXISTS "${ARCHIVE_PATH}")
    message(FATAL_ERROR "Verified archive is missing after download: ${ARCHIVE_PATH}")
  endif()

  file(SIZE "${ARCHIVE_PATH}" ARCHIVE_SIZE)
  if (ARCHIVE_SIZE EQUAL 0)
    message(FATAL_ERROR "Verified archive is empty after download: ${ARCHIVE_PATH}")
  endif()

  file(MD5 "${ARCHIVE_PATH}" ARCHIVE_HASH)
  if (NOT ARCHIVE_HASH STREQUAL ARCHIVE_MD5)
    message(FATAL_ERROR
      "Verified archive checksum mismatch for ${ARCHIVE_NAME}: expected ${ARCHIVE_MD5}, got ${ARCHIVE_HASH}"
    )
  endif()
endfunction()

# Full libmpv download module (for PGS/HDMV bitmap subtitle support)
include(cmake/full_libmpv.cmake)

# Normalize Windows plugin links before including generated plugin rules.
if (WIN32)
  # Pre-seed archives downloaded by media_kit so plugin configure steps do not
  # get stuck on zero-byte caches produced by file(DOWNLOAD).

  # -------------------------------------------------------------------------
  # Download & extract full libmpv for bitmap subtitle (PGS/HDMV/SUP) support.
  # The extracted DLL overrides media_kit's stripped build during install.
  # -------------------------------------------------------------------------
  ensure_full_libmpv_windows()
#   ensure_verified_windows_archive(
#     "mpv-dev-x86_64-20230924-git-652a1dd.7z"
#     "https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z"
#     "a832ef24b3a6ff97cd2560b5b9d04cd8"
#   )
#   ensure_verified_windows_archive(
#     "ANGLE.7z"
#     "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z"
#     "e866f13e8d552348058afaafe869b1ed"
#   )

  set(FLUTTER_PLUGIN_DEPENDENCIES_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../.flutter-plugins-dependencies")
  set(FLUTTER_PLUGIN_LINKS_DIR "${FLUTTER_MANAGED_DIR}/ephemeral/.plugin_symlinks")
  set(FLUTTER_PLUGIN_LINKS_STAMP "${FLUTTER_MANAGED_DIR}/ephemeral/.plugin_symlinks.stamp")
  if (EXISTS "${FLUTTER_PLUGIN_DEPENDENCIES_FILE}")
    file(SHA256 "${FLUTTER_PLUGIN_DEPENDENCIES_FILE}" FLUTTER_PLUGIN_DEPENDENCIES_HASH)
    set(FLUTTER_PLUGIN_LINKS_NEED_SYNC TRUE)

    # Skip the plugin junction repair only when both the dependency hash and
    # the generated junction tree are still intact.
    if (EXISTS "${FLUTTER_PLUGIN_LINKS_DIR}" AND EXISTS "${FLUTTER_PLUGIN_LINKS_STAMP}")
      file(READ "${FLUTTER_PLUGIN_LINKS_STAMP}" FLUTTER_PLUGIN_LINKS_STAMP_VALUE)
      string(STRIP "${FLUTTER_PLUGIN_LINKS_STAMP_VALUE}" FLUTTER_PLUGIN_LINKS_STAMP_VALUE)
      if (FLUTTER_PLUGIN_LINKS_STAMP_VALUE STREQUAL FLUTTER_PLUGIN_DEPENDENCIES_HASH)
        set(FLUTTER_PLUGIN_LINKS_NEED_SYNC FALSE)
      endif()
    endif()

    # Rebuild the junction tree when the stamp is stale or any plugin link is
    # missing, even if the dependency hash has not changed.
    if (NOT FLUTTER_PLUGIN_LINKS_NEED_SYNC)
      file(TO_NATIVE_PATH "${FLUTTER_PLUGIN_DEPENDENCIES_FILE}" FLUTTER_PLUGIN_DEPENDENCIES_NATIVE)
      file(TO_NATIVE_PATH "${FLUTTER_PLUGIN_LINKS_DIR}" FLUTTER_PLUGIN_LINKS_NATIVE)
      execute_process(
        COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
          "$deps = Get-Content '${FLUTTER_PLUGIN_DEPENDENCIES_NATIVE}' -Raw | ConvertFrom-Json; $base = '${FLUTTER_PLUGIN_LINKS_NATIVE}'; if (-not (Test-Path $base)) { exit 3 }; foreach ($plugin in $deps.plugins.windows) { $target = $plugin.path.TrimEnd('\\'); $targetWindows = Join-Path $target 'windows'; if (-not (Test-Path $targetWindows)) { continue }; $windowsLink = Join-Path (Join-Path $base $plugin.name) 'windows'; if (-not (Test-Path $windowsLink)) { exit 4 } }"
        RESULT_VARIABLE FLUTTER_PLUGIN_LINK_INTEGRITY_RESULT
        ERROR_VARIABLE FLUTTER_PLUGIN_LINK_INTEGRITY_ERROR
      )
      if (NOT FLUTTER_PLUGIN_LINK_INTEGRITY_RESULT EQUAL 0)
        set(FLUTTER_PLUGIN_LINKS_NEED_SYNC TRUE)
      endif()
    endif()

    if (FLUTTER_PLUGIN_LINKS_NEED_SYNC)
      file(TO_NATIVE_PATH "${FLUTTER_PLUGIN_DEPENDENCIES_FILE}" FLUTTER_PLUGIN_DEPENDENCIES_NATIVE)
      file(TO_NATIVE_PATH "${FLUTTER_PLUGIN_LINKS_DIR}" FLUTTER_PLUGIN_LINKS_NATIVE)
      execute_process(
        COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
          "$deps = Get-Content '${FLUTTER_PLUGIN_DEPENDENCIES_NATIVE}' -Raw | ConvertFrom-Json; $base = '${FLUTTER_PLUGIN_LINKS_NATIVE}'; New-Item -ItemType Directory -Force -Path $base | Out-Null; foreach ($plugin in $deps.plugins.windows) { $name = $plugin.name; $target = $plugin.path.TrimEnd('\\'); $targetWindows = Join-Path $target 'windows'; if (-not (Test-Path $targetWindows)) { continue }; $link = Join-Path $base $name; $windowsLink = Join-Path $link 'windows'; if (Test-Path $windowsLink) { continue }; if (Test-Path $link) { Remove-Item $link -Force -Recurse }; New-Item -ItemType Junction -Path $link -Target $target | Out-Null }"
        RESULT_VARIABLE FLUTTER_PLUGIN_LINK_RESULT
        ERROR_VARIABLE FLUTTER_PLUGIN_LINK_ERROR
      )
      if (NOT FLUTTER_PLUGIN_LINK_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to normalize Windows plugin links: ${FLUTTER_PLUGIN_LINK_ERROR}")
      endif()
      file(WRITE "${FLUTTER_PLUGIN_LINKS_STAMP}" "${FLUTTER_PLUGIN_DEPENDENCIES_HASH}\n")
    endif()
  endif()
endif()

add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
# Default CMP0175 for third-party plugins that still pass unsupported DEPENDS
# to add_custom_command(TARGET ...), such as webview_windows 0.4.0.
set(CMAKE_POLICY_DEFAULT_CMP0175 OLD)
include(flutter/generated_plugins.cmake)

if(MSVC AND TARGET flutter_inappwebview_windows_plugin)
  # Suppress noisy warnings from the WebView2 SDK and plugin conversion code.
  target_compile_options(flutter_inappwebview_windows_plugin PRIVATE /utf-8 /wd4458 /wd4244 /wd4819)
endif()

unset(CMAKE_POLICY_DEFAULT_CMP0175)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_INSTALL_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_INSTALL_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Override the stripped libmpv-2.dll bundled by media_kit with a full-featured
# build that supports bitmap subtitles (PGS/HDMV/SUP). This install rule runs
# after the plugin's, so it replaces the stripped DLL in the bundle.
install(FILES "${FULL_LIBMPV_DLL}"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)