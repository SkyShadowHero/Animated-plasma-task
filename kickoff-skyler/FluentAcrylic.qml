/*
    SPDX-FileCopyrightText: 2026 The Kickoff Skyler authors

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

/**
 * A stand-in for the Windows 11 "Acrylic" material.
 *
 * Acrylic is three things stacked: a blur of what is behind the window, a
 * translucent colour cast over it, and a very fine grain. Plasma already gives
 * us the first one — Plasmoid.backgroundHints keeps DefaultBackground, which
 * makes the compositor blur behind the popup — and the theme's dialog
 * background owns the silhouette: its corners, its shadow, its 1px edge. So
 * this layer draws no border and no edge of its own: a flat wash plus the
 * grain, and the only shape it takes is the card's corner radius — taken from
 * Kirigami (which reports what the style advertises) or, when that number does
 * not match what the style actually draws, from the setting.
 *
 * The caller is responsible for handing it the card's rectangle. In Plasma the
 * page's own background item sits inside the frame margins, so
 * FullRepresentation.qml pushes it back out over the whole card with negative
 * insets.
 */
Rectangle {
    id: root

    // Whatever the active style rounds its cards with: Kirigami's units carry
    // the platform corner radius, so the wash stops where the card stops
    // instead of a few pixels either side of it. Rectangle's corners are
    // aliased at this size, so ask for antialiasing.
    //
    // Not every style reports the radius it actually draws its dialogs with —
    // Breeze's frame metrics are not the same number — so the setting can take
    // over and the value is picked by hand instead.
    readonly property bool followsThemeRadius: Plasmoid.configuration?.acrylicFollowsTheme ?? true
    readonly property int customRadius: Plasmoid.configuration?.acrylicRadius ?? 12

    radius: followsThemeRadius ? Kirigami.Units.cornerRadius : customRadius
    antialiasing: true

    // Acrylic's colour cast, tuned to keep the blur readable: the light cast
    // is a near-white wash, the dark one a lifted charcoal (pure black would
    // swallow the blur entirely).
    color: FluentStyle.dark
        ? Qt.rgba(0.13, 0.13, 0.13, 0.60)
        : Qt.rgba(0.99, 0.99, 0.99, 0.52)

    // The grain. A 64x64 8-bit grey noise tile, inlined as a data URL so the
    // applet needs no extra resource file (and therefore no build-system
    // plumbing) and the texture can never go missing at install time. It is
    // tiled at its native pitch with smoothing off, which is what gives the
    // material its "sandblasted" feel instead of a blurry gradient.
    //
    // The tile is deliberately low-contrast: every sample sits between 38% and
    // 62% grey, which is what Fluent's own noise asset looks like. A full-range
    // black-to-white tile drawn at the same opacity does not read as grain —
    // it reads as speckle, and because Qt upscales a bitmap tile by the screen
    // scale factor, those speckles end up looking like blotches. Keeping the
    // amplitude small and paying for it with a slightly higher opacity gives
    // the same "sandblasted" impression with dots the eye stops resolving.
    //
    // The tile is a plain rectangle and so are its corners: Qt clips children
    // to a rectangle, not to a rounded one. At this alpha the sliver that ends
    // up outside the card's curve is a couple of percent of grey over the
    // theme's shadow, i.e. nothing, and masking it would cost a full-screen
    // effect pass on a popup that opens on every keystroke.
    Image {
        anchors.fill: parent
        source: "data:image/png;base64,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"
        fillMode: Image.Tile
        smooth: false
        opacity: FluentStyle.dark ? 0.065 : 0.055
    }
}
