function(ensure_full_libmpv_windows)
  set(ARCHIVE_NAME "mpv-dev-x86_64-20260706-git-c8c7d91a8e.7z")
  set(ARCHIVE_URL  "https://github.com/zhongfly/mpv-winbuild/releases/download/2026-07-06-c8c7d91a8e/${ARCHIVE_NAME}")
  set(ARCHIVE_SHA256 "81beeb603d42162fcee96fdaadea2d564282563a054db93431a755d43a2f53c3")
  set(DLL_SHA256 "b7ce1d6145dd86be99b3eb04cd4307d484f22f1b957104c0c437b14999451bd2")

  set(LIBMPV_DIR     "${CMAKE_BINARY_DIR}/full_libmpv")
  set(LIBMPV_ARCHIVE "${LIBMPV_DIR}/${ARCHIVE_NAME}")
  set(LIBMPV_DLL     "${LIBMPV_DIR}/libmpv-2.dll")

  file(MAKE_DIRECTORY "${LIBMPV_DIR}")

  # -- Validate or download the .7z archive ----------------------------------
  set(NEEDS_DOWNLOAD TRUE)
  if(EXISTS "${LIBMPV_ARCHIVE}")
    file(SIZE "${LIBMPV_ARCHIVE}" SIZE_OUT)
    file(SHA256 "${LIBMPV_ARCHIVE}" HASH_OUT)
    if(SIZE_OUT GREATER 0 AND HASH_OUT STREQUAL ARCHIVE_SHA256)
      set(NEEDS_DOWNLOAD FALSE)
    else()
      file(REMOVE "${LIBMPV_ARCHIVE}")
    endif()
  endif()

  if(NEEDS_DOWNLOAD)
    message(STATUS "Downloading full libmpv (required for PGS/HDMV subtitle support)...")
    file(TO_NATIVE_PATH "${LIBMPV_ARCHIVE}" OUT_NATIVE)
    execute_process(
      COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
        "$ProgressPreference = 'SilentlyContinue'; $url = '${ARCHIVE_URL}'; $out = '${OUT_NATIVE}'; for ($r = 1; $r -le 3; $r++) { try { Invoke-WebRequest -Uri $url -OutFile $out -MaximumRedirection 10 -UseBasicParsing; if ((Test-Path $out) -and ((Get-Item $out).Length -gt 0)) { exit 0 } } catch { if (Test-Path $out) { Remove-Item $out -Force }; if ($r -eq 3) { throw }; Start-Sleep -Seconds 1 } }; exit 1"
      RESULT_VARIABLE DL_RESULT
      ERROR_VARIABLE DL_ERROR
    )
    if(NOT DL_RESULT EQUAL 0)
      message(FATAL_ERROR "Failed to download ${ARCHIVE_NAME}: ${DL_ERROR}")
    endif()

    file(SHA256 "${LIBMPV_ARCHIVE}" HASH_AFTER)
    if(NOT HASH_AFTER STREQUAL ARCHIVE_SHA256)
      message(FATAL_ERROR "${ARCHIVE_NAME} SHA256 mismatch")
    endif()
  endif()

  # -- Extract DLL from the .7z archive -------------------------------------
  set(NEEDS_EXTRACT TRUE)
  if(EXISTS "${LIBMPV_DLL}")
    file(SIZE "${LIBMPV_DLL}" DLL_SIZE)
    file(SHA256 "${LIBMPV_DLL}" DLL_HASH)
    if(DLL_SIZE GREATER 0 AND DLL_HASH STREQUAL DLL_SHA256)
      set(NEEDS_EXTRACT FALSE)
    endif()
  endif()

  if(NEEDS_EXTRACT)
    # Locate a 7z capable extractor
    find_program(SEVENZ_EXE NAMES 7z 7za 7zr)
    if(NOT SEVENZ_EXE)
      foreach(TRY
          "C:/Program Files/7-Zip/7z.exe"
          "C:/Program Files (x86)/7-Zip/7z.exe"
        )
        if(EXISTS "${TRY}")
          set(SEVENZ_EXE "${TRY}")
          break()
        endif()
      endforeach()
    endif()

    # Fallback: download portable 7zr.exe (~650 KB) on demand
    if(NOT SEVENZ_EXE)
      set(SEVENZ_EXE "${LIBMPV_DIR}/7zr.exe")
      if(NOT EXISTS "${SEVENZ_EXE}")
        message(STATUS "Downloading portable 7zr.exe...")
        file(TO_NATIVE_PATH "${SEVENZ_EXE}" SEVENZ_NATIVE)
        execute_process(
          COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
            "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri 'https://www.7-zip.org/a/7zr.exe' -OutFile '${SEVENZ_NATIVE}' -MaximumRedirection 10 -UseBasicParsing; if (-not (Test-Path '${SEVENZ_NATIVE}') -or (Get-Item '${SEVENZ_NATIVE}').Length -eq 0) { exit 1 }"
          RESULT_VARIABLE DL_7ZR_RESULT
          ERROR_VARIABLE DL_7ZR_ERROR
        )
        if(NOT DL_7ZR_RESULT EQUAL 0)
          message(FATAL_ERROR "Failed to download 7zr.exe. Install 7-Zip manually from https://www.7-zip.org/")
        endif()
      endif()
    endif()

    message(STATUS "Extracting full libmpv-2.dll...")
    file(TO_NATIVE_PATH "${LIBMPV_ARCHIVE}" SRC_NATIVE)
    file(TO_NATIVE_PATH "${LIBMPV_DIR}"     DST_NATIVE)

    execute_process(
      COMMAND "${SEVENZ_EXE}" x "${SRC_NATIVE}" -o${DST_NATIVE} -y -bso0 -bsp0
      RESULT_VARIABLE EXTRACT_RESULT
      ERROR_VARIABLE EXTRACT_ERROR
    )
    if(NOT EXTRACT_RESULT EQUAL 0)
      message(FATAL_ERROR "Failed to extract libmpv archive: ${EXTRACT_ERROR}")
    endif()

    if(EXISTS "${LIBMPV_DLL}")
      file(SHA256 "${LIBMPV_DLL}" DLL_HASH)
      if(NOT DLL_HASH STREQUAL DLL_SHA256)
        message(FATAL_ERROR "Extracted libmpv-2.dll SHA256 mismatch")
      endif()
    else()
      message(FATAL_ERROR "libmpv-2.dll not found after extraction")
    endif()
  endif()

  # Export for install() in parent scope
  set(FULL_LIBMPV_DLL "${LIBMPV_DLL}" PARENT_SCOPE)
endfunction()
