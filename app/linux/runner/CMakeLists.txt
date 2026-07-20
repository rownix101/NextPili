cmake_minimum_required(VERSION 3.13)
# C required for wayland-scanner private-code (.c) stubs.
project(runner LANGUAGES C CXX)

# --- Wayland ext-background-effect-v1 (compositor real-time blur) ---
find_package(PkgConfig REQUIRED)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
pkg_check_modules(WAYLAND_PROTOCOLS wayland-protocols)
pkg_get_variable(WAYLAND_PROTOCOLS_DIR wayland-protocols pkgdatadir)
if(NOT WAYLAND_PROTOCOLS_DIR)
  set(WAYLAND_PROTOCOLS_DIR "/usr/share/wayland-protocols")
endif()
set(EXT_BG_EFFECT_XML
  "${WAYLAND_PROTOCOLS_DIR}/staging/ext-background-effect/ext-background-effect-v1.xml")
if(NOT EXISTS "${EXT_BG_EFFECT_XML}")
  message(FATAL_ERROR
    "ext-background-effect-v1.xml not found at ${EXT_BG_EFFECT_XML}. "
    "Install wayland-protocols ≥ staging that includes ext-background-effect.")
endif()

set(PROTOCOL_GEN_DIR "${CMAKE_CURRENT_BINARY_DIR}/protocol")
file(MAKE_DIRECTORY "${PROTOCOL_GEN_DIR}")
set(EXT_BG_EFFECT_CLIENT_H
  "${PROTOCOL_GEN_DIR}/ext-background-effect-v1-client-protocol.h")
set(EXT_BG_EFFECT_CLIENT_C
  "${PROTOCOL_GEN_DIR}/ext-background-effect-v1-protocol.c")

add_custom_command(
  OUTPUT "${EXT_BG_EFFECT_CLIENT_H}"
  COMMAND "${WAYLAND_SCANNER}" client-header
          "${EXT_BG_EFFECT_XML}" "${EXT_BG_EFFECT_CLIENT_H}"
  DEPENDS "${EXT_BG_EFFECT_XML}"
  COMMENT "wayland-scanner client-header ext-background-effect-v1"
  VERBATIM)
add_custom_command(
  OUTPUT "${EXT_BG_EFFECT_CLIENT_C}"
  COMMAND "${WAYLAND_SCANNER}" private-code
          "${EXT_BG_EFFECT_XML}" "${EXT_BG_EFFECT_CLIENT_C}"
  DEPENDS "${EXT_BG_EFFECT_XML}"
  COMMENT "wayland-scanner private-code ext-background-effect-v1"
  VERBATIM)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "desktop_compositor_blur.cc"
  "${EXT_BG_EFFECT_CLIENT_C}"
  "${EXT_BG_EFFECT_CLIENT_H}"
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
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::WAYLAND_CLIENT)

# X11 KWin blur atom fallback.
pkg_check_modules(NEXTPILI_X11 IMPORTED_TARGET x11)
if(TARGET PkgConfig::NEXTPILI_X11)
  target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::NEXTPILI_X11)
endif()

target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_SOURCE_DIR}"
  "${PROTOCOL_GEN_DIR}")
