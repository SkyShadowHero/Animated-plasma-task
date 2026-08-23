add_definitions(-DTRANSLATION_DOMAIN=\"plasma_applet_org.kde.plasma.taskmanager.skyler\")

plasma_add_applet(org.kde.plasma.taskmanager.skyler
    QML_SOURCES
        qml/AudioStream.qml
        qml/ConfigAppearance.qml
        qml/ConfigBehavior.qml
        qml/config.qml
        qml/ContextMenu.qml
        qml/GroupDialog.qml
        qml/GroupExpanderOverlay.qml
        qml/main.qml
        qml/MouseHandler.qml
        qml/PipeWireThumbnail.qml
        qml/PlayerController.qml
        qml/PulseAudio.qml
        qml/ScrollableTextWrapper.qml
        qml/TaskBadgeOverlay.qml
        qml/TaskList.qml
        qml/TaskProgressOverlay.qml
        qml/Task.qml
        qml/ToolTipDelegate.qml
        qml/ToolTipInstance.qml
        qml/ToolTipWindowMouseArea.qml
        qml/code/LayoutMetrics.js
        qml/code/TaskTools.js
    CPP_SOURCES
        backend.cpp
        smartlauncherbackend.cpp
        smartlauncheritem.cpp
    RESOURCES
        main.xml
    GENERATE_APPLET_CLASS
)

kconfig_add_kcfg_files(org.kde.plasma.taskmanager.skyler ${CMAKE_CURRENT_SOURCE_DIR}/kactivitymanagerd_plugins_settings.kcfgc)

include(ECMQtDeclareLoggingCategory)
ecm_qt_declare_logging_category(org.kde.plasma.taskmanager.skyler
    HEADER log_settings_skyler.h
    IDENTIFIER TASKMANAGER_SKYLER_DEBUG
    CATEGORY_NAME org.kde.plasma.taskmanager.skyler)

# Ensure generated headers (kcfg, logging) are found
target_include_directories(org.kde.plasma.taskmanager.skyler PRIVATE ${CMAKE_CURRENT_BINARY_DIR})

target_link_libraries(org.kde.plasma.taskmanager.skyler PRIVATE
    Qt::Core
    Qt::Qml
    Qt::Quick
    Plasma::Activities
    Plasma::ActivitiesStats
    KF6::ConfigGui
    KF6::I18n
    KF6::KIOCore
    KF6::KIOGui
    KF6::KIOFileWidgets
    KF6::Notifications
    Plasma::Plasma
    KSysGuard::ProcessCore
    KF6::Service
    KF6::WindowSystem
    PW::LibNotificationManager
)

# ── Install the QML as a KPackage ─────────────────────
# This plasmoid is used in two ways:
#   1. Standalone: "Task Manager (SkyAnimation)" —
#      org.kde.plasma.taskmanager.skyler loads its QML from the
#      embedded resources of the plugin built above (ecm_add_qml_module),
#      and the KPackage below provides the metadata the applet loader
#      needs to resolve the plugin (KPackageStructure + KPlugin.Id).
#   2. As the root path of "Icons-Only Task Manager (SkyAnimation)" —
#      org.kde.plasma.icontasks.skyler redirects here via
#      X-Plasma-RootPath, so this package must also be installed as a
#      KPackage for the redirect to resolve.
# The directory also contains C++ sources, so a plain
# plasma_install_package() would copy build artifacts into the package;
# install only the runtime files instead.
install(
    DIRECTORY qml/
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/plasma/plasmoids/org.kde.plasma.taskmanager.skyler"
    FILES_MATCHING
    PATTERN "*.qml"
    PATTERN "*.js"
)
install(
    FILES metadata.json main.xml
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/plasma/plasmoids/org.kde.plasma.taskmanager.skyler"
)

# ── Install translations ──────────────────────────────
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
    DIRECTORY po/
    DESTINATION "${CMAKE_INSTALL_PREFIX}/share/locale"
    FILES_MATCHING
    PATTERN "*.mo"
    PATTERN "*.pot"
)
