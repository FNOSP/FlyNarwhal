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
  bcrypt.lib
  shell32.lib
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
  add_test(NAME flynarwhal_install_helper_rejects_invalid_query
    COMMAND FlyNarwhalInstallHelper query --transaction-id invalid
  )
  set_tests_properties(flynarwhal_install_helper_rejects_invalid_query
    PROPERTIES WILL_FAIL TRUE
  )
  add_test(NAME flynarwhal_install_helper_rejects_unsealed_option
    COMMAND FlyNarwhalInstallHelper query --transaction-id
      123e4567-e89b-42d3-a456-426614174000 --install-dir C:\\arbitrary
  )
  set_tests_properties(flynarwhal_install_helper_rejects_unsealed_option
    PROPERTIES WILL_FAIL TRUE
  )
endif()
