cmake_minimum_required(VERSION 3.20)
project(SkylerPlasmaTaskManager VERSION 1.0.6)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# ── KDE ECM ──────────────────────────────────────────
find_package(ECM REQUIRED CONFIG)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} ${ECM_KDE_MODULE_DIR})

# KDE install dirs are auto-detected by ECM (KDEInstallDirs).
# Do not override them here; the distro multiarch path
# (e.g. x86_64-linux-gnu/qt6/plugins) is the correct default.

# Plasma macros set LIBRARY_OUTPUT_DIRECTORY based on CMAKE_LIBRARY_OUTPUT_DIRECTORY
if(NOT DEFINED CMAKE_LIBRARY_OUTPUT_DIRECTORY)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
endif()

# ── Qt ───────────────────────────────────────────────
find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)

# ── KF6 (separate packages for cleaner dependency management) ──
find_package(KF6 REQUIRED COMPONENTS I18n Notifications Service WindowSystem)
find_package(KF6Config REQUIRED)    # → KF6::ConfigGui
find_package(KF6KIO REQUIRED)       # → KF6::KIOCore KF6::KIOGui KF6::KIOFileWidgets
find_package(Plasma REQUIRED)       # → Plasma::Plasma (standalone, not under KF6)

# ── Plasma extras ────────────────────────────────────
find_package(PlasmaActivities REQUIRED)       # → Plasma::Activities
find_package(PlasmaActivitiesStats REQUIRED)   # → Plasma::ActivitiesStats
find_package(KSysGuard REQUIRED)               # → KSysGuard::ProcessCore
find_package(LibNotificationManager REQUIRED)  # → PW::LibNotificationManager

# ── Build ────────────────────────────────────────────
add_subdirectory(taskmanager-skyler)
add_subdirectory(kickoff-skyler)

# ── Install taskmanager QML as KPackage ──────────────
# icontasks-skyler uses X-Plasma-RootPath to redirect to taskmanager-skyler,
# so taskmanager-skyler needs its QML files installed as a KPackage too.
install(
    DIRECTORY taskmanager-skyler/qml/
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/plasma/plasmoids/org.kde.plasma.taskmanager.skyler"
    FILES_MATCHING
    PATTERN "*.qml"
    PATTERN "*.js"
)
install(
    FILES taskmanager-skyler/metadata.json taskmanager-skyler/main.xml
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/plasma/plasmoids/org.kde.plasma.taskmanager.skyler"
)

# ── Install wrapper packages ─────────────────────────
plasma_install_package(icontasks-skyler org.kde.plasma.icontasks.skyler)
plasma_install_package(kickoff-skyler org.kde.plasma.kickoff.skyler)

# ── Install taskmanager-skyler translations ───────────
# taskmanager-skyler now uses its own TRANSLATION_DOMAIN
# (plasma_applet_org.kde.plasma.taskmanager.skyler).
# Remove old symlinks first — CMake's install(DIRECTORY) won't overwrite them.
install(CODE "
    set(DOMAIN plasma_applet_org.kde.plasma.taskmanager.skyler)
    file(GLOB OLD_LINKS /usr/share/locale/*/LC_MESSAGES/\${DOMAIN}.mo)
    foreach(LINK \${OLD_LINKS})
        if(IS_SYMLINK \"\${LINK}\")
            file(REMOVE \"\${LINK}\")
        endif()
    endforeach()
")
install(
    DIRECTORY taskmanager-skyler/po/
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/locale"
    FILES_MATCHING
    PATTERN "*.mo"
    PATTERN "*.pot"
)

# ── icontasks-skyler → taskmanager-skyler translation ─
install(CODE "
    set(SKYLER_DOMAIN plasma_applet_org.kde.plasma.taskmanager.skyler)
    set(ICON_DOMAIN   plasma_applet_org.kde.plasma.icontasks.skyler)
    file(GLOB LOCALE_DIRS /usr/share/locale/*/LC_MESSAGES)
    foreach(LOCALE_DIR \${LOCALE_DIRS})
        set(MO_FILE \"\${LOCALE_DIR}/\${SKYLER_DOMAIN}.mo\")
        if(EXISTS \"\${MO_FILE}\")
            get_filename_component(PARENT \"\${LOCALE_DIR}\" DIRECTORY)
            get_filename_component(LOCALE \"\${PARENT}\" NAME)
            set(TARGET \"\$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/locale/\${LOCALE}/LC_MESSAGES/\${ICON_DOMAIN}.mo\")
            file(MAKE_DIRECTORY \"\$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/locale/\${LOCALE}/LC_MESSAGES\")
            execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink
                \"\${SKYLER_DOMAIN}.mo\" \"\${TARGET}\")
        endif()
    endforeach()
")

# ── Reuse original kickoff translations ─────────────
install(CODE "
    set(ORIG_DOMAIN plasma_applet_org.kde.plasma.kickoff)
    set(SKYLER_DOMAIN plasma_applet_org.kde.plasma.kickoff.skyler)
    file(GLOB LOCALE_DIRS /usr/share/locale/*/LC_MESSAGES)
    foreach(LOCALE_DIR \${LOCALE_DIRS})
        set(ORIG_MO \"\${LOCALE_DIR}/\${ORIG_DOMAIN}.mo\")
        if(EXISTS \"\${ORIG_MO}\")
            get_filename_component(LOCALE_PARENT_DIR \"\${LOCALE_DIR}\" DIRECTORY)
            get_filename_component(LOCALE_NAME \"\${LOCALE_PARENT_DIR}\" NAME)
            set(TARGET_LOCALE_DIR \"\$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/locale/\${LOCALE_NAME}/LC_MESSAGES\")
            file(MAKE_DIRECTORY \"\${TARGET_LOCALE_DIR}\")
            execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink
                \"\${ORIG_DOMAIN}.mo\"
                \"\${TARGET_LOCALE_DIR}/\${SKYLER_DOMAIN}.mo\")
        endif()
    endforeach()
")

# ── Uninstall ────────────────────────────────────────
if(NOT TARGET uninstall)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
        @ONLY)
    add_custom_target(uninstall
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
endif()

# ── Status ───────────────────────────────────────────
message(STATUS "")
message(STATUS "Skyler Plasma Task Manager ${PROJECT_VERSION}")
message(STATUS "  Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  Plugin ID:      org.kde.plasma.icontasks.skyler")
message(STATUS "")
