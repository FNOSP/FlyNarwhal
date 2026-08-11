function(ensure_full_libmpv_windows)
  # Pin to the latest zhongfly/mpv-winbuild release. The archive SHA256 is
  # taken from that release's sha256.txt. The DLL hash is NOT pinned below:
  # it changes on every upstream release, so it is computed dynamically at
  # build time (see NEEDS_EXTRACT). If the pinned release is ever removed,
  # bump ARCHIVE_NAME/URL to the newest release and refresh ARCHIVE_SHA256
  # from its sha256.txt (one hash per architecture).
  #
  # FLUTTER_TARGET_PLATFORM is defined by the flutter tool via -D on the
  # cmake command line, so it is available at configure time.
  if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
    set(ARCHIVE_NAME "mpv-dev-aarch64-20260808-git-dd5d17d328.7z")
    set(ARCHIVE_SHA256 "edf1418d21339aa526bf6f3939f09029b637746296e69f9818a128522a16ed5b")
  else()
    set(ARCHIVE_NAME "mpv-dev-x86_64-20260808-git-dd5d17d328.7z")
    set(ARCHIVE_SHA256 "67039d30a242aff684e2c89ddc6f5a9f7270d99afe9c26db76f7da26bda63e8a")
  endif()
  set(ARCHIVE_URL  "https://github.com/zhongfly/mpv-winbuild/releases/download/2026-08-08-dd5d17d328/${ARCHIVE_NAME}")

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
    # Wrap the download in a background job guarded by both a per-request
    # timeout and a hard wall-clock timeout. A stalled GitHub connection that
    # never throws would otherwise hang the whole CMake configure step.
    execute_process(
      COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
        "Write-Host '[full_libmpv] Downloading ~30 MB ...'; $orig = '${ARCHIVE_URL}'; $out = '${OUT_NATIVE}'; $urls = @($orig, \"https://ghfast.top/$orig\", \"https://gh-proxy.com/$orig\", \"https://ghproxy.net/$orig\"); $ok = $false; foreach ($url in $urls) { Write-Host \"[full_libmpv] trying source: $url\"; if (Test-Path $out) { Remove-Item $out -Force }; $job = Start-Job -ScriptBlock { param($u, $o) $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri $u -OutFile $o -MaximumRedirection 10 -UseBasicParsing -TimeoutSec 30 } -ArgumentList $url, $out; if (Wait-Job $job -Timeout 90) { Receive-Job $job -ErrorAction SilentlyContinue | Out-Null; Remove-Job $job -Force -ErrorAction SilentlyContinue; if ((Test-Path $out) -and ((Get-Item $out).Length -gt 0)) { $size = (Get-Item $out).Length; Write-Host \"[full_libmpv] Download complete: $size bytes\"; $ok = $true; break } else { Write-Host \"[full_libmpv] source produced no file, next\" } } else { Write-Host \"[full_libmpv] source stalled >90s, killing, next\"; Stop-Job $job -ErrorAction SilentlyContinue; Remove-Job $job -Force -ErrorAction SilentlyContinue; if (Test-Path $out) { Remove-Item $out -Force } }; Start-Sleep -Seconds 1 }; if ($ok) { exit 0 } else { Write-Host '[full_libmpv] Download failed from all sources'; exit 1 }"
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
  # The DLL hash is not pinned (it changes every upstream release), so a
  # cached DLL is trusted as long as it is non-empty and the archive SHA256
  # passed above. Extraction is only re-run when the DLL is missing/empty.
  set(NEEDS_EXTRACT TRUE)
  if(EXISTS "${LIBMPV_DLL}")
    message(STATUS "[full_libmpv] Checking cached DLL...")
    file(SIZE "${LIBMPV_DLL}" DLL_SIZE)
    if(DLL_SIZE GREATER 0)
      message(STATUS "[full_libmpv] DLL cached (${DLL_SIZE} bytes)")
      set(NEEDS_EXTRACT FALSE)
    else()
      message(STATUS "[full_libmpv] Cached DLL is empty, will re-extract")
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
      file(SIZE "${LIBMPV_DLL}" DLL_SIZE)
      if(DLL_SIZE GREATER 0)
        message(STATUS "[full_libmpv] DLL extracted OK (${DLL_SIZE} bytes)")
      else()
        message(FATAL_ERROR "[full_libmpv] Extracted DLL is empty")
      endif()
    else()
      message(FATAL_ERROR "[full_libmpv] DLL not found after extraction")
    endif()
  endif()

  # On arm64 we also stage the headers, import library and DLL in the same
  # layout that media_kit_video expects, so the local override of
  # media_kit_libs_windows_video can reuse them instead of downloading again.
  if(FLUTTER_TARGET_PLATFORM STREQUAL "windows-arm64")
    set(LIBMPV_STAGING_DIR "${CMAKE_BINARY_DIR}/libmpv")
    if(NOT EXISTS "${LIBMPV_STAGING_DIR}/libmpv-2.dll" OR NOT EXISTS "${LIBMPV_STAGING_DIR}/libmpv.dll.a")
      message(STATUS "[full_libmpv] Staging arm64 libmpv for media_kit_video...")
      file(MAKE_DIRECTORY "${LIBMPV_STAGING_DIR}")
      if(EXISTS "${LIBMPV_DIR}/include")
        file(COPY "${LIBMPV_DIR}/include" DESTINATION "${LIBMPV_STAGING_DIR}")
        # media_kit_video includes <client.h>, not <mpv/client.h>, so flatten
        # the libmpv include layout from include/mpv/... to include/...
        file(TO_NATIVE_PATH "${LIBMPV_STAGING_DIR}/include" _include_native)
        execute_process(
          COMMAND powershell -NoProfile -ExecutionPolicy Bypass -Command
            "$d = '${_include_native}'; if (Test-Path (Join-Path $d 'mpv')) { Move-Item -Path (Join-Path $d 'mpv\*') -Destination $d -Force; Remove-Item -Path (Join-Path $d 'mpv') -Recurse -Force }"
          RESULT_VARIABLE _flatten_result
        )
        if(NOT _flatten_result EQUAL 0)
          message(FATAL_ERROR "[full_libmpv] Failed to flatten mpv include directory")
        endif()
      endif()
      foreach(_item IN ITEMS "${LIBMPV_DIR}/libmpv.dll.a" "${LIBMPV_DIR}/libmpv-2.dll")
        if(EXISTS "${_item}")
          file(COPY "${_item}" DESTINATION "${LIBMPV_STAGING_DIR}")
        endif()
      endforeach()
      message(STATUS "[full_libmpv] Staging complete: ${LIBMPV_STAGING_DIR}")
    endif()
  endif()

  message(STATUS "[full_libmpv] Ready: ${LIBMPV_DLL}")
  # Export for install() in parent scope
  set(FULL_LIBMPV_DLL "${LIBMPV_DLL}" PARENT_SCOPE)
endfunction()
