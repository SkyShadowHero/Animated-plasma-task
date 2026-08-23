set_source_files_properties(KickoffSingleton.qml ActionMenu.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

plasma_add_applet(org.kde.plasma.kickoff.skyler
QML_SOURCES
    config.qml
    main.xml
    AbstractKickoffItemDelegate.qml
    ActionMenu.qml
    ApplicationsPage.qml
    BasePage.qml
    ConfigGeneral.qml
    DropAreaGridView.qml
    DropAreaListView.qml
    EmptyPage.qml
    Footer.qml
    FullRepresentation.qml
    Header.qml
    HorizontalStackView.qml
    KickoffDropArea.qml
    KickoffGridDelegate.qml
    KickoffGridView.qml
    KickoffListDelegate.qml
    KickoffListView.qml
    KickoffSingleton.qml
    LeaveButtons.qml
    ListOfGridsView.qml
    ListOfGridsViewDelegate.qml
    NormalPage.qml
    PlacesPage.qml
    SectionView.qml
    VerticalStackView.qml
    main.qml
RESOURCES
    main.xml
GENERATE_APPLET_CLASS
)

ecm_target_qml_sources(org.kde.plasma.kickoff.skyler SOURCES code/tools.js PATH code)

# ── Plugin embedded metadata (no KPlugin.Id) ──────────
# See taskmanager-skyler/CMakeLists.txt: the generated plugin source embeds
# "metadata.json" (resolved by moc relative to the build dir); the KPackage
# keeps KPlugin.Id in metadata.json, but the embedded variant must not contain
# it or KPluginFactory warns that the plugin "explicitly states an 'Id'".
configure_file(plugin-metadata.json ${CMAKE_CURRENT_BINARY_DIR}/metadata.json COPYONLY)
