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
    message(STATUS "[full_libmpv] Checking existing archive...")
    file(SIZE "${LIBMPV_ARCHIVE}" SIZE_OUT)
    file(SHA256 "${LIBMPV_ARCHIVE}" HASH_OUT)
    if(SIZE_OUT GREATER 0 AND HASH_OUT STREQUAL ARCHIVE_SHA256)
      message(STATUS "[full_libmpv] Archive cached & verified (${SIZE_OUT} bytes)")
      set(NEEDS_DOWNLOAD FALSE)
    else()
      message(STATUS "[full_libmpv] Cached archive is invalid (size=${SIZE_OUT}), will re-download")
      file(REMOVE "${LIBMPV_ARCHIVE}")
    endif()
  endif()

  if(NEEDS_DOWNLOAD)
    message(STATUS "[full_libmpv] Downloading from: ${ARCHIVE_URL}")
    file(TO_NATIVE_PATH "${LIBMPV_ARCHIVE}" OUT_NATIVE)
    execute_process(
      COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
        "Write-Host '[full_libmpv] Downloading ~30 MB ...'; $url = '${ARCHIVE_URL}'; $out = '${OUT_NATIVE}'; for ($r = 1; $r -le 3; $r++) { try { Invoke-WebRequest -Uri $url -OutFile $out -MaximumRedirection 10 -UseBasicParsing; if ((Test-Path $out) -and ((Get-Item $out).Length -gt 0)) { $size = (Get-Item $out).Length; Write-Host \"[full_libmpv] Download complete: $size bytes\"; exit 0 } } catch { if (Test-Path $out) { Remove-Item $out -Force }; if ($r -eq 3) { Write-Host \"[full_libmpv] Download failed after 3 attempts: $_\" }; Start-Sleep -Seconds 2 } }; exit 1"
      RESULT_VARIABLE DL_RESULT
      ERROR_VARIABLE DL_ERROR
    )
    if(NOT DL_RESULT EQUAL 0)
      message(FATAL_ERROR "[full_libmpv] Failed to download ${ARCHIVE_NAME}: ${DL_ERROR}")
    endif()

    message(STATUS "[full_libmpv] Verifying SHA256...")
    file(SHA256 "${LIBMPV_ARCHIVE}" HASH_AFTER)
    if(NOT HASH_AFTER STREQUAL ARCHIVE_SHA256)
      message(FATAL_ERROR "[full_libmpv] Archive SHA256 mismatch!`n  expected: ${ARCHIVE_SHA256}`n  got:      ${HASH_AFTER}")
    endif()
    message(STATUS "[full_libmpv] SHA256 verified OK")
  endif()

  # -- Extract DLL from the .7z archive -------------------------------------
  set(NEEDS_EXTRACT TRUE)
  if(EXISTS "${LIBMPV_DLL}")
    message(STATUS "[full_libmpv] Checking cached DLL...")
    file(SIZE "${LIBMPV_DLL}" DLL_SIZE)
    file(SHA256 "${LIBMPV_DLL}" DLL_HASH)
    if(DLL_SIZE GREATER 0 AND DLL_HASH STREQUAL DLL_SHA256)
      message(STATUS "[full_libmpv] DLL cached & verified (${DLL_SIZE} bytes)")
      set(NEEDS_EXTRACT FALSE)
    else()
      message(STATUS "[full_libmpv] Cached DLL is invalid, will re-extract")
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
        message(STATUS "[full_libmpv] 7z not found, downloading portable 7zr.exe (~650 KB)...")
        file(TO_NATIVE_PATH "${SEVENZ_EXE}" SEVENZ_NATIVE)
        execute_process(
          COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
            "Write-Host '[full_libmpv] Fetching 7zr.exe ...'; Invoke-WebRequest -Uri 'https://www.7-zip.org/a/7zr.exe' -OutFile '${SEVENZ_NATIVE}' -MaximumRedirection 10 -UseBasicParsing; $size = (Get-Item '${SEVENZ_NATIVE}').Length; Write-Host \"[full_libmpv] 7zr.exe downloaded: $size bytes\""
          RESULT_VARIABLE DL_7ZR_RESULT
          ERROR_VARIABLE DL_7ZR_ERROR
        )
        if(NOT DL_7ZR_RESULT EQUAL 0)
          message(FATAL_ERROR "[full_libmpv] Failed to download 7zr.exe. Install 7-Zip manually from https://www.7-zip.org/")
        endif()
      else()
        message(STATUS "[full_libmpv] Using cached 7zr.exe")
      endif()
    else()
      message(STATUS "[full_libmpv] Using 7z: ${SEVENZ_EXE}")
    endif()

    message(STATUS "[full_libmpv] Extracting libmpv-2.dll (~118 MB)...")
    file(TO_NATIVE_PATH "${LIBMPV_ARCHIVE}" SRC_NATIVE)
    file(TO_NATIVE_PATH "${LIBMPV_DIR}"     DST_NATIVE)

    execute_process(
      COMMAND "${SEVENZ_EXE}" x "${SRC_NATIVE}" -o${DST_NATIVE} -y
      RESULT_VARIABLE EXTRACT_RESULT
      OUTPUT_VARIABLE EXTRACT_OUTPUT
      ERROR_VARIABLE EXTRACT_ERROR
    )
    if(NOT EXTRACT_RESULT EQUAL 0)
      message(FATAL_ERROR "[full_libmpv] Extraction failed:`n${EXTRACT_OUTPUT}`n${EXTRACT_ERROR}")
    endif()
    message(STATUS "[full_libmpv] Extraction complete")

    if(EXISTS "${LIBMPV_DLL}")
      message(STATUS "[full_libmpv] Verifying extracted DLL SHA256...")
      file(SHA256 "${LIBMPV_DLL}" DLL_HASH)
      if(NOT DLL_HASH STREQUAL DLL_SHA256)
        message(FATAL_ERROR "[full_libmpv] Extracted DLL SHA256 mismatch!`n  expected: ${DLL_SHA256}`n  got:      ${DLL_HASH}")
      endif()
      message(STATUS "[full_libmpv] DLL verified OK")
    else()
      message(FATAL_ERROR "[full_libmpv] DLL not found after extraction")
    endif()
  endif()

  message(STATUS "[full_libmpv] Ready: ${LIBMPV_DLL}")
  # Export for install() in parent scope
  set(FULL_LIBMPV_DLL "${LIBMPV_DLL}" PARENT_SCOPE)
endfunction()
