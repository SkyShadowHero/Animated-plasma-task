%global debug_package %{nil}

Name:           plasma6-applets-animated-taskmanager
Version:        1.1.6
Release:        1%{?dist}
Summary:        Forked KDE Plasma 6 plasmoids with press / entry / minimize animations

License:        GPL-2.0-or-later
URL:            https://github.com/SkyShadowHero/Animated-plasma-task
Source0:        https://github.com/SkyShadowHero/Animated-plasma-task/archive/refs/tags/1.1.6.tar.gz

BuildArch:      x86_64

BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  gcc-c++
BuildRequires:  cmake(Qt6Core)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6Quick)
BuildRequires:  cmake(KF6I18n)
BuildRequires:  cmake(KF6Notifications)
BuildRequires:  cmake(KF6Service)
BuildRequires:  cmake(KF6WindowSystem)
BuildRequires:  cmake(KF6Config)
BuildRequires:  cmake(KF6KIO)
BuildRequires:  cmake(Plasma)
BuildRequires:  cmake(PlasmaActivities)
BuildRequires:  cmake(PlasmaActivitiesStats)
BuildRequires:  cmake(KSysGuard)
BuildRequires:  cmake(LibNotificationManager)
BuildRequires:  cmake(KF6ItemModels)
BuildRequires:  gettext

Requires:       plasma-workspace
Requires:       hicolor-icon-theme

%description
A set of forked KDE Plasma 6 plasmoids that bring Windows/macOS-like
animations to the taskbar and the application launcher:

* Icons-Only Task Manager (SkyAnimation) — org.kde.plasma.icontasks.skyler
* Task Manager (SkyAnimation) — org.kde.plasma.taskmanager.skyler
* Application Launcher (SkyAnimation) — org.kde.plasma.kickoff.skyler

Features include press scale, entry slide-in, minimize bounce,
exit slide-out, reappear pop-up, hover animation, icon scaling,
5-speed animation settings and custom decorations.

%prep
%autosetup -n Animated-plasma-task-%{version} -p1

%build
%cmake
%cmake_build

%install
%cmake_install

# upstream installs the .pot template straight into /usr/share/locale
rm -f %{buildroot}%{_datadir}/locale/*.pot

%find_lang plasma_applet_org.kde.plasma.taskmanager.skyler || true
%find_lang plasma_applet_org.kde.plasma.kickoff.skyler || true
%find_lang plasma_applet_org.kde.plasma.icontasks.skyler || true

%files -f plasma_applet_org.kde.plasma.taskmanager.skyler.lang -f plasma_applet_org.kde.plasma.kickoff.skyler.lang -f plasma_applet_org.kde.plasma.icontasks.skyler.lang
%doc README.md READMECN.md
%{_libdir}/qt6/plugins/*
%{_datadir}/plasma/plasmoids/*

%changelog
* Mon Nov 23 2026 KairikiFedora <13278297951@sina.cn> - 1.1.6-1
- Update to 1.1.6

* Fri Nov 20 2026 KairikiFedora <13278297951@sina.cn> - 1.1.3-2
- Update translate

* Sun Nov 08 2026 KairikiFedora <13278297951@sina.cn> - 1.1.3-1
- Update translate

* Sat Nov 07 2026 KairikiFedora <13278297951@sina.cn> - 1.1.2-1
- Update to 1.1.2

* Sun Sep 06 2026 KairikiFedora <13278297951@sina.cn> - 1.1.1-3
- fix: translations for kickoff-skyler and taskmanager-skyler

* Sun Sep 06 2026 KairikiFedora <13278297951@sina.cn> - 1.1.1-2
- Push to Stable

* Sun Sep 06 2026 KairikiFedora <13278297951@sina.cn> - 1.1.1-1
- Initial package
