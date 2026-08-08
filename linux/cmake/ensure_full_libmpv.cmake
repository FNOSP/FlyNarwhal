# Bundling helper for the full libmpv (PGS/HDMV SUP support) on every Linux
# build type. Called by linux/CMakeLists.txt as a POST_BUILD step via
# `add_custom_command(POST_BUILD ... -P ensure_full_libmpv.cmake)`.
#
# Behavior:
#   1. If the build host has a system libmpv.so.2 (CI / Ubuntu dev box with
#      `apt-get install mpv libmpv-dev`), skip the download and let the
#      bundler walk the system paths.
#   2. Otherwise, run `scripts/linux/fetch_full_libmpv.dart` to populate
#      build/linux/libmpv_cache/<arch>/root from the Ubuntu 24.04 apt pool.
#   3. Run `scripts/linux/bundle_full_libmpv.dart` against BOTH the runtime
#      output directory (used by `flutter run`) and the install bundle (used
#      by `flutter build`), passing the downloaded scratch dir through
#      LIBMPV_EXTRA_SEARCH_ROOTS so NEEDED entries resolve.
#
# Why a separate script (instead of inlining the function in
# linux/CMakeLists.txt)?
#   - The POST_BUILD hook has to be expressed as a single CMake invocation
#     so add_custom_command can serialize it; the in-function version would
#     only run at configure time, not at every build.

cmake_minimum_required(VERSION 3.13)

# CMake re-invokes this script with the variables the parent needs. Pull
# them from the command line so the script is fully self-describing.
if(NOT DEFINED FLY_NARWHAL_FETCH_FULL_LIBMPV)
  message(FATAL_ERROR "FLY_NARWHAL_FETCH_FULL_LIBMPV not defined")
endif()

if(NOT FLY_NARWHAL_FETCH_FULL_LIBMPV)
  message(STATUS "[full_libmpv] FLY_NARWHAL_FETCH_FULL_LIBMPV=OFF, skipping")
  return()
endif()

set(projectRoot "${CMAKE_SOURCE_DIR}/..")
set(binaryName "fly_narwhal")

if(CMAKE_SYSTEM_PROCESSOR MATCHES "(aarch64|arm64)")
  set(archDir "aarch64")
else()
  set(archDir "x86_64")
endif()

set(runtimeDir "${CMAKE_BINARY_DIR}/intermediates_do_not_run")
set(bundleDir "${CMAKE_BINARY_DIR}/bundle")
set(cacheDir "${projectRoot}/build/linux/libmpv_cache/${archDir}")
set(extraRoot "${cacheDir}/root")
# The downloaded .so files live under <scratch>/root/usr/lib/<arch>-linux-gnu
# (the .deb data layout). Point the bundler's extra search roots at that
# directory so both libmpv discovery and NEEDED resolution hit it.
set(extraLibDir "${extraRoot}/usr/lib/${archDir}-linux-gnu")

set(systemLibmpvX86 "/usr/lib/x86_64-linux-gnu/libmpv.so.2")
set(systemLibmpvArm "/usr/lib/aarch64-linux-gnu/libmpv.so.2")

# Pass the project root + arch to the Dart fetch via env-style args.
set(fetchArgs
  "dart"
  "run"
  "${projectRoot}/scripts/linux/fetch_full_libmpv.dart"
  "${cacheDir}"
  "${archDir}"
)

if(EXISTS "${systemLibmpvX86}" OR EXISTS "${systemLibmpvArm}")
  message(STATUS "[full_libmpv] system libmpv found, skipping download")
  set(extraSearchRootsArg "")
else()
  message(STATUS
    "[full_libmpv] no system libmpv, fetching from Ubuntu apt pool into ${cacheDir}")
  file(MAKE_DIRECTORY "${cacheDir}")
  execute_process(
    COMMAND ${fetchArgs}
    WORKING_DIRECTORY "${projectRoot}"
    RESULT_VARIABLE fetchResult
    OUTPUT_VARIABLE fetchOutput
    ERROR_VARIABLE fetchError
  )
  if(NOT fetchResult EQUAL 0)
    message(WARNING
      "[full_libmpv] fetch failed (exit ${fetchResult}); "
      "PGS/HDMV subtitle playback may be unavailable\n"
      "stderr: ${fetchError}")
    return()
  endif()
  if(fetchOutput)
    message(STATUS "${fetchOutput}")
  endif()
  set(extraSearchRootsArg "LIBMPV_EXTRA_SEARCH_ROOTS=${extraLibDir}")
endif()

# Run the bundler against each output location. The bundler is idempotent
# (skips files that already exist in the destination), so calling it twice
# in the same build is fine.
foreach(libDir IN LISTS runtimeDir bundleDir)
  if(NOT EXISTS "${libDir}")
    continue()
  endif()
  message(STATUS "[full_libmpv] bundling closure into ${libDir}")
  # The libmpv source is the extra-root scratch dir when we downloaded it
  # (the system /usr/lib/<arch>-linux-gnu may not exist on the host), or the
  # system path when the host already has libmpv installed.
  if(extraSearchRootsArg)
    set(bundleSourceArg "${extraLibDir}")
  else()
    set(bundleSourceArg "/usr/lib/${archDir}-linux-gnu")
  endif()
  if(extraSearchRootsArg)
    set(bundleCommand
      ${CMAKE_COMMAND} -E env ${extraSearchRootsArg}
      dart run
        "${projectRoot}/scripts/linux/bundle_full_libmpv.dart"
        "${libDir}"
        "${bundleSourceArg}"
    )
  else()
    set(bundleCommand
      dart run
        "${projectRoot}/scripts/linux/bundle_full_libmpv.dart"
        "${libDir}"
        "${bundleSourceArg}"
    )
  endif()
  execute_process(
    COMMAND ${bundleCommand}
    WORKING_DIRECTORY "${projectRoot}"
    RESULT_VARIABLE bundleResult
    OUTPUT_VARIABLE bundleOutput
    ERROR_VARIABLE bundleError
  )
  if(NOT bundleResult EQUAL 0)
    message(WARNING
      "[full_libmpv] bundle failed for ${libDir} (exit ${bundleResult})\n"
      "stderr: ${bundleError}")
  elseif(bundleOutput)
    message(STATUS "${bundleOutput}")
  endif()
endforeach()

message(STATUS "[full_libmpv] done")
