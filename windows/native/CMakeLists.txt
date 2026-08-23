cmake_minimum_required(VERSION 3.14)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(flynarwhal_native_install_helper LANGUAGES CXX)
endif()

if(MSVC OR CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
  set(FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS /W4 /WX /EHsc /utf-8)
else()
  set(FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS -Wall -Wextra -Werror)
endif()

add_library(flynarwhal_install_helper_core STATIC
  "src/flynarwhal_install_helper.cpp"
  "src/flynarwhal_updater_endpoint.cpp"
  "src/flynarwhal_recovery_host.cpp"
)
target_include_directories(flynarwhal_install_helper_core PUBLIC "include")
target_compile_features(flynarwhal_install_helper_core PUBLIC cxx_std_17)
target_compile_definitions(flynarwhal_install_helper_core PRIVATE
  NOMINMAX
  WIN32_LEAN_AND_MEAN
  $<$<CONFIG:Debug>:FLYNARWHAL_NATIVE_HELPER_DEVELOPMENT_BUILD>
)
target_compile_options(flynarwhal_install_helper_core PRIVATE
  ${FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS}
)
target_link_libraries(flynarwhal_install_helper_core PRIVATE
  advapi32.lib
  bcrypt.lib
  ole32.lib
  oleaut32.lib
  shell32.lib
  taskschd.lib
  version.lib
)

add_executable(FlyNarwhalInstallHelper "src/main.cpp")
target_compile_features(FlyNarwhalInstallHelper PRIVATE cxx_std_17)
if(NOT MSVC AND NOT CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
  target_link_options(FlyNarwhalInstallHelper PRIVATE -municode)
endif()
target_compile_options(FlyNarwhalInstallHelper PRIVATE
  ${FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS}
)
target_link_libraries(FlyNarwhalInstallHelper PRIVATE flynarwhal_install_helper_core)
set_target_properties(FlyNarwhalInstallHelper PROPERTIES
  OUTPUT_NAME "FlyNarwhalInstallHelper"
)

add_executable(FlyNarwhalProtectedHelper "src/protected_helper_main.cpp")
target_compile_features(FlyNarwhalProtectedHelper PRIVATE cxx_std_17)
if(NOT MSVC AND NOT CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
  target_link_options(FlyNarwhalProtectedHelper PRIVATE -municode)
endif()
target_compile_options(FlyNarwhalProtectedHelper PRIVATE
  ${FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS}
)
target_link_libraries(FlyNarwhalProtectedHelper PRIVATE
  flynarwhal_install_helper_core
)
set_target_properties(FlyNarwhalProtectedHelper PROPERTIES
  OUTPUT_NAME "FlyNarwhalProtectedHelper"
)

add_executable(FlyNarwhalRecoveryHost
  "src/recovery_host_main.cpp"
)
target_compile_features(FlyNarwhalRecoveryHost PRIVATE cxx_std_17)
if(MSVC OR CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
  # Launched by the Task Scheduler; the Windows subsystem keeps the
  # scheduled resume from flashing a visible console window on screen.
  target_link_options(FlyNarwhalRecoveryHost PRIVATE
    /SUBSYSTEM:WINDOWS
    /ENTRY:wmainCRTStartup
  )
else()
  target_link_options(FlyNarwhalRecoveryHost PRIVATE
    -municode
    -Wl,--subsystem,windows
  )
endif()
target_compile_options(FlyNarwhalRecoveryHost PRIVATE
  ${FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS}
)
target_link_libraries(FlyNarwhalRecoveryHost PRIVATE
  flynarwhal_install_helper_core
  ole32.lib
  oleaut32.lib
  shell32.lib
)
set_target_properties(FlyNarwhalRecoveryHost PROPERTIES
  OUTPUT_NAME "FlyNarwhalRecoveryHost"
)

include(CTest)
if(BUILD_TESTING)
  add_executable(flynarwhal_install_helper_tests
    "tests/flynarwhal_install_helper_tests.cpp"
  )
  target_compile_features(flynarwhal_install_helper_tests PRIVATE cxx_std_17)
  if(NOT MSVC AND NOT CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
    target_link_options(flynarwhal_install_helper_tests PRIVATE -municode)
  endif()
  target_compile_options(flynarwhal_install_helper_tests PRIVATE
    ${FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS}
  )
  target_link_libraries(flynarwhal_install_helper_tests PRIVATE
    flynarwhal_install_helper_core
  )
  add_test(NAME flynarwhal_install_helper_tests
    COMMAND flynarwhal_install_helper_tests
  )

  add_executable(flynarwhal_install_helper_path_tests
    "tests/flynarwhal_install_helper_path_tests.cpp"
  )
  target_compile_features(flynarwhal_install_helper_path_tests PRIVATE cxx_std_17)
  if(NOT MSVC AND NOT CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
    target_link_options(flynarwhal_install_helper_path_tests PRIVATE -municode)
  endif()
  target_compile_options(flynarwhal_install_helper_path_tests PRIVATE
    ${FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS}
  )
  target_link_libraries(flynarwhal_install_helper_path_tests PRIVATE
    flynarwhal_install_helper_core
  )
  add_test(NAME flynarwhal_install_helper_path_tests
    COMMAND flynarwhal_install_helper_path_tests
  )

  add_executable(flynarwhal_updater_endpoint_tests
    "tests/flynarwhal_updater_endpoint_tests.cpp"
  )
  target_compile_features(flynarwhal_updater_endpoint_tests PRIVATE cxx_std_17)
  if(NOT MSVC AND NOT CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
    target_link_options(flynarwhal_updater_endpoint_tests PRIVATE -municode)
  endif()
  target_compile_options(flynarwhal_updater_endpoint_tests PRIVATE
    ${FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS}
  )
  target_link_libraries(flynarwhal_updater_endpoint_tests PRIVATE
    flynarwhal_install_helper_core
  )
  add_test(NAME flynarwhal_updater_endpoint_tests
    COMMAND flynarwhal_updater_endpoint_tests
  )

  add_executable(flynarwhal_recovery_host_tests
    "tests/flynarwhal_recovery_host_tests.cpp"
  )
  target_compile_features(flynarwhal_recovery_host_tests PRIVATE cxx_std_17)
  if(NOT MSVC AND NOT CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
    target_link_options(flynarwhal_recovery_host_tests PRIVATE -municode)
  endif()
  target_compile_options(flynarwhal_recovery_host_tests PRIVATE
    ${FLYNARWHAL_NATIVE_HELPER_COMPILE_OPTIONS}
  )
  target_link_libraries(flynarwhal_recovery_host_tests PRIVATE
    flynarwhal_install_helper_core
    ole32.lib
    oleaut32.lib
    shell32.lib
  )
  add_test(NAME flynarwhal_recovery_host_tests
    COMMAND flynarwhal_recovery_host_tests
  )

  add_test(NAME flynarwhal_install_helper_rejects_invalid_query
    COMMAND FlyNarwhalProtectedHelper query --transaction-id invalid
  )
  set_tests_properties(flynarwhal_install_helper_rejects_invalid_query
    PROPERTIES WILL_FAIL TRUE
  )
  add_test(NAME flynarwhal_install_helper_rejects_unsealed_option
    COMMAND FlyNarwhalProtectedHelper query --transaction-id
      123e4567-e89b-42d3-a456-426614174000 --install-dir C:\\arbitrary
  )
  set_tests_properties(flynarwhal_install_helper_rejects_unsealed_option
    PROPERTIES WILL_FAIL TRUE
  )
endif()
