# This file is a part of media_kit (https://github.com/media-kit/media-kit).
#
# Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
# All rights reserved.
# Use of this source code is governed by MIT license that can be found in the LICENSE file.

cmake_minimum_required(VERSION 3.14)

# This option is read by the other packages which are part of package:media_kit.
option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

set(PROJECT_NAME "media_kit_libs_windows_video")
project(${PROJECT_NAME} LANGUAGES CXX)

# Deal with MSVC incompatiblity
add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

# ------------------------------------------------------------------------------
function(download_and_verify url md5 locationForArchive)
  # Check if the archive exists.
  if(EXISTS "${locationForArchive}")
    file(MD5 "${locationForArchive}" ARCHIVE_MD5)

    # If MD5 doesn't match, delete the archive to download again.
    if(NOT md5 STREQUAL ARCHIVE_MD5)
      file(REMOVE "${locationForArchive}")
      message(STATUS "MD5 mismatch. File deleted.")
    endif()
  endif()

  # Download the archive if it doesn't exist.
  if(NOT EXISTS "${locationForArchive}")
    message(STATUS "Downloading archive from ${url}...")
    file(DOWNLOAD "${url}" "${locationForArchive}")
    message(STATUS "Downloaded archive to ${locationForArchive}.")

    # Verify MD5 of the newly downloaded file.
    file(MD5 "${locationForArchive}" ARCHIVE_MD5)

    if(md5 STREQUAL ARCHIVE_MD5)
      message(STATUS "${locationForArchive} Verification successful.")
    else()
      message(FATAL_ERROR "${locationForArchive} Integrity check failed, please try to re-build project again.")
    endif()
  endif()
endfunction()

function(copy_local_archive_and_verify src md5 locationForArchive)
  # Copy a bundled local archive into the build tree, then verify its MD5.
  # CMake's file(DOWNLOAD) does not reliably handle file:// URLs, so we use a
  # normal file copy for local assets and validate the checksum afterwards.
  if(EXISTS "${locationForArchive}")
    file(MD5 "${locationForArchive}" ARCHIVE_MD5)
    if(NOT md5 STREQUAL ARCHIVE_MD5)
      file(REMOVE "${locationForArchive}")
      message(STATUS "MD5 mismatch. Local copy deleted.")
    endif()
  endif()

  if(NOT EXISTS "${locationForArchive}")
    message(STATUS "Copying bundled archive from ${src}...")
    configure_file("${src}" "${locationForArchive}" COPYONLY)
    message(STATUS "Copied bundled archive to ${locationForArchive}.")

    file(MD5 "${locationForArchive}" ARCHIVE_MD5)
    if(md5 STREQUAL ARCHIVE_MD5)
      message(STATUS "${locationForArchive} Verification successful.")
    else()
      message(FATAL_ERROR "${locationForArchive} Integrity check failed, please try to re-build project again.")
    endif()
  endif()
endfunction()

function(check_directory_exists_and_not_empty dir result_var)
  # Check if the directory exists
  if(EXISTS "${dir}")
    # Check if the directory is not empty
    file(GLOB dir_contents "${dir}/*")

    if(dir_contents)
      set(${result_var} TRUE PARENT_SCOPE)
    else()
      set(${result_var} FALSE PARENT_SCOPE)
      message(STATUS "Directory ${dir} exists but is empty!")
    endif()
  else()
    set(${result_var} FALSE PARENT_SCOPE)
    message(STATUS "Directory ${dir} does not exist!")
  endif()
endfunction()

# ------------------------------------------------------------------------------
# Architecture-specific prebuilt libraries.
# Flutter passes FLUTTER_TARGET_PLATFORM=windows-arm64 for Windows ARM64.
if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  message(STATUS "media_kit_libs_windows_video: using ARM64 prebuilt libraries")

  # full_libmpv.cmake (called from the project's windows/CMakeLists.txt before
  # plugins are configured) already downloads and stages libmpv for arm64, so
  # reuse it here instead of fetching it a second time.
  set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")
  set(LIBMPV_SRC_VALID TRUE)

  # ANGLE archive assembled from MSYS2 clangarm64 packages and bundled inside
  # this local override. Use a local copy instead of file(DOWNLOAD), which can
  # produce an empty file for file:// URLs. The assets/ directory lives next to
  # this windows/ directory, so reference it through the parent of
  # CMAKE_CURRENT_SOURCE_DIR.
  set(ANGLE "ANGLE-arm64.tar.gz")
  set(ANGLE_LOCAL "${CMAKE_CURRENT_SOURCE_DIR}/../assets/${ANGLE}")
  set(ANGLE_MD5 "b802623416c8c81772e212ddd715cbdd")
else()
  message(STATUS "media_kit_libs_windows_video: using x86_64 prebuilt libraries")

  # libmpv archive containing the pre-built shared libraries & headers.
  set(LIBMPV "mpv-dev-x86_64-20230924-git-652a1dd.7z")
  set(LIBMPV_URL "https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/${LIBMPV}")
  set(LIBMPV_MD5 "a832ef24b3a6ff97cd2560b5b9d04cd8")

  # ANGLE archive containing the pre-built shared libraries & headers.
  set(ANGLE "ANGLE.7z")
  set(ANGLE_URL "https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/${ANGLE}")
  set(ANGLE_MD5 "e866f13e8d552348058afaafe869b1ed")
endif()

# Download location of the libmpv archive.
set(LIBMPV_ARCHIVE "${CMAKE_BINARY_DIR}/${LIBMPV}")
if(NOT DEFINED LIBMPV_SRC)
  set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")
endif()

if(NOT DEFINED LIBMPV_SRC_VALID)
  download_and_verify(
    ${LIBMPV_URL}
    ${LIBMPV_MD5}
    ${LIBMPV_ARCHIVE}
  )

  check_directory_exists_and_not_empty(${LIBMPV_SRC} LIBMPV_SRC_VALID)

  # Extract the libmpv archive.
  if(NOT LIBMPV_SRC_VALID)
    message(STATUS "Extracting ${LIBMPV}...")
    make_directory("${LIBMPV_SRC}")
    add_custom_target("${PROJECT_NAME}_LIBMPV_EXTRACT" ALL)
    add_custom_command(
      TARGET "${PROJECT_NAME}_LIBMPV_EXTRACT"
      COMMAND "${CMAKE_COMMAND}" -E tar xzf "\"${LIBMPV_ARCHIVE}\""
      COMMAND xcopy "\"${LIBMPV_SRC}/include/mpv\"" "\"${LIBMPV_SRC}/mpv\"" /E /H /C /I
      COMMAND rmdir "\"${LIBMPV_SRC}/include\"" /S /Q
      COMMAND ren "\"${LIBMPV_SRC}/mpv\"" "\"include\""
      WORKING_DIRECTORY "${LIBMPV_SRC}"
    )
  endif()
endif()

# ------------------------------------------------------------------------------

# Download location of the ANGLE archive.
set(ANGLE_ARCHIVE "${CMAKE_BINARY_DIR}/${ANGLE}")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")

if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  copy_local_archive_and_verify(
    ${ANGLE_LOCAL}
    ${ANGLE_MD5}
    ${ANGLE_ARCHIVE}
  )
else()
  download_and_verify(
    ${ANGLE_URL}
    ${ANGLE_MD5}
    ${ANGLE_ARCHIVE}
  )
endif()
check_directory_exists_and_not_empty(${ANGLE_SRC} ANGLE_SRC_VALID)

# Extract the ANGLE archive.
if(NOT ANGLE_SRC_VALID)
  message(STATUS "Extracting ${ANGLE}...")
  make_directory("${ANGLE_SRC}")
  add_custom_target("${PROJECT_NAME}_ANGLE_EXTRACT" ALL)
  add_custom_command(
    TARGET "${PROJECT_NAME}_ANGLE_EXTRACT"
    COMMAND "${CMAKE_COMMAND}" -E tar xzf "\"${ANGLE_ARCHIVE}\""
    WORKING_DIRECTORY "${ANGLE_SRC}"
  )
endif()

# ------------------------------------------------------------------------------
set(PLUGIN_NAME "media_kit_libs_windows_video_plugin")

add_library(
  ${PLUGIN_NAME} SHARED
  "include/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h"
  "media_kit_libs_windows_video_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(
  ${PLUGIN_NAME}
  PROPERTIES
  CXX_VISIBILITY_PRESET
  hidden
)
target_compile_definitions(
  ${PLUGIN_NAME}
  PRIVATE
  FLUTTER_PLUGIN_IMPL
)

target_include_directories(
  ${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(
  ${PLUGIN_NAME}
  PRIVATE
  flutter
  flutter_wrapper_plugin
)

set(_media_kit_bundled_libs
  "${LIBMPV_SRC}/libmpv-2.dll"
)
if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
  # The MSYS2 arm64 ANGLE package only ships libEGL/libGLESv2; the other
  # extras in the x86_64 archive are not available (and not needed) on arm64.
  list(APPEND _media_kit_bundled_libs
    "${ANGLE_SRC}/libEGL.dll"
    "${ANGLE_SRC}/libGLESv2.dll"
  )
else()
  list(APPEND _media_kit_bundled_libs
    "${ANGLE_SRC}/d3dcompiler_47.dll"
    "${ANGLE_SRC}/libEGL.dll"
    "${ANGLE_SRC}/libGLESv2.dll"
    "${ANGLE_SRC}/vk_swiftshader.dll"
    "${ANGLE_SRC}/vulkan-1.dll"
    "${ANGLE_SRC}/zlib.dll"
  )
endif()

set(
  media_kit_libs_windows_video_bundled_libraries
  ${_media_kit_bundled_libs}
  PARENT_SCOPE
)
