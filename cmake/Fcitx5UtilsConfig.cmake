set(Fcitx5Utils_FOUND TRUE)

# dependent projects usually use
# "${FCITX_INSTALL_CMAKECONFIG_DIR}/Fcitx5Utils/Fcitx5CompilerSettings.cmake"
# to locate Fcitx5CompilerSettings
set(FCITX_INSTALL_CMAKECONFIG_DIR "${CMAKE_CURRENT_LIST_DIR}")

# mimic fcitx5/src/lib/fcitx-utils/Fcitx5UtilsConfig.cmake.in
include("${CMAKE_CURRENT_LIST_DIR}/Fcitx5Utils/Fcitx5Macros.cmake")

# Unify addons with fcitx5.
set(FCITX_INSTALL_LOCALEDIR "/usr/local/share/locale")
