cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "unity_kit")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "unity_kit_plugin")

list(APPEND PLUGIN_SOURCES
  "unity_kit_plugin.cc"
)

add_library(${PLUGIN_NAME} SHARED ${PLUGIN_SOURCES})
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)

if(NOT TARGET PkgConfig::GTK)
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
endif()
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# List of absolute paths to libraries that should be bundled with the plugin.
set(unity_kit_bundled_libraries
  ""
  PARENT_SCOPE
)
