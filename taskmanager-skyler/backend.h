/*
    SPDX-FileCopyrightText: 2013-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <KConfigWatcher>

#include <QColor>
#include <QObject>
#include <QRect>

#include <netwm.h>
#include <qqmlregistration.h>
#include <qwindowdefs.h>

#include "kactivitymanagerd_plugins_settings.h"

class QAction;
class QActionGroup;
class QQuickItem;
class QQuickWindow;
class QJsonArray;

namespace KActivities
{
class Consumer;
}

class Backend : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    // The user's KDE accent color from kdeglobals [General] AccentColor.
    // PlasmaCore.Theme.highlightColor is not exposed as a Q_PROPERTY and
    // Plasmoid.accentColor is walled off from the user setting, so read it
    // directly here and expose it with change notification.
    Q_PROPERTY(QColor accentColor READ accentColor NOTIFY accentColorChanged)

public:
    enum MiddleClickAction {
        None = 0,
        Close,
        NewInstance,
        ToggleMinimized,
        ToggleGrouping,
        BringToCurrentDesktop,
    };

    Q_ENUM(MiddleClickAction)

    explicit Backend(QObject *parent = nullptr);
    ~Backend() override;

    Q_INVOKABLE QVariantList jumpListActions(const QUrl &launcherUrl, QObject *parent);
    Q_INVOKABLE QVariantList placesActions(const QUrl &launcherUrl, bool showAllPlaces, QObject *parent);
    Q_INVOKABLE QVariantList recentDocumentActions(const QUrl &launcherUrl, QObject *parent);
    Q_INVOKABLE void setActionGroup(QAction *action) const;

    Q_INVOKABLE QRect globalRect(QQuickItem *item) const;

    Q_INVOKABLE bool isApplication(const QUrl &url) const;

    Q_INVOKABLE qint64 parentPid(qint64 pid) const;

    QColor accentColor() const;

    Q_INVOKABLE static QUrl tryDecodeApplicationsUrl(const QUrl &launcherUrl);
    Q_INVOKABLE static QStringList applicationCategories(const QUrl &launcherUrl);

Q_SIGNALS:
    void addLauncher(const QUrl &url) const;

    void showAllPlaces();

    void accentColorChanged();

private Q_SLOTS:
    void handleRecentDocumentAction() const;

private:
    QVariantList systemSettingsActions(QObject *parent) const;

    QActionGroup *m_actionGroup = nullptr;
    KActivities::Consumer *m_activitiesConsumer = nullptr;

    KActivityManagerdPluginsSettings m_activityManagerPluginsSettings;
    KConfigWatcher::Ptr m_activityManagerPluginsSettingsWatcher;
    KConfigWatcher::Ptr m_accentColorWatcher;
};
