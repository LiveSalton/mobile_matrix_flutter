# GitHub discoverability guide

## Scope

This document defines the public positioning and search vocabulary for the Mobile Matrix GitHub repository. It is a GitHub repository SEO guide, not a Google Play listing or an App Store listing.

The project currently publishes a macOS Apple Silicon desktop release. Android is the controlled device, not a separately published Mobile Matrix client. Windows and Linux platform directories exist in the Flutter project, but there is no validated public package for those platforms yet.

## Canonical positioning

> Mobile Matrix is a Flutter desktop workspace for controlling Android devices from macOS with ADB, real-time screen mirroring, keyboard and touch input, clipboard sync, screenshots, device tools, and STF Lite.

Use this message as the source of truth for the repository description, README opening, release notes, and future documentation. Keep the product name as **Mobile Matrix** and retain the repository URL `LiveSalton/mobile_matrix_flutter` to avoid breaking existing links.

## Keyword clusters

Use these terms where they describe the surrounding content naturally. Do not repeat them mechanically or add capabilities that are not implemented.

| Cluster | Terms | Best placement |
| --- | --- | --- |
| Product category | Flutter desktop app, Android device control, device management workspace | Repository description, README opening |
| Connectivity | ADB, Android Debug Bridge, authorized Android device, USB debugging | Requirements, setup, troubleshooting |
| Screen and input | Android screen mirroring, live device display, keyboard input, touch input, swipe control | Feature list, usage guide |
| Productivity | clipboard sync, screenshot copy, device tools, ADB shell | Feature list, release notes |
| Runtime | STF Lite, minicap, local screen streaming | Architecture notes, troubleshooting |
| Testing and operations | mobile testing, Android QA, multi-device control, APK management | README feature context, future guides |
| Platform | macOS, Apple Silicon, arm64, desktop Android controller | Download section, repository metadata |

## Placement rules

1. Keep the primary product category and platform in the repository description.
2. Put the most important product and feature terms in the first README paragraph.
3. Use feature-specific headings and short explanations instead of a keyword-only block.
4. Mention the downloadable artifact with its exact platform and architecture.
5. Repeat important terms only when the surrounding explanation adds information.
6. Keep Chinese explanations after the English overview so both audiences can scan the page quickly.
7. Link to releases, issues, and setup details so search visitors can take a useful next step.

## Repository metadata

Recommended description:

> Flutter desktop workspace for Android device control, ADB management, screen mirroring, keyboard and touch input, clipboard sync, screenshots, and STF Lite.

Recommended Topics:

`flutter` · `macos` · `android` · `adb` · `android-device-manager` · `android-device-control` · `screen-mirroring` · `mobile-testing` · `multi-device` · `stf` · `stf-lite` · `clipboard-sync` · `keyboard-input` · `device-management`

Topics should remain limited to terms that describe the current repository. Remove a topic if the corresponding capability is removed or becomes misleading.

## Release naming

Use a stable, searchable release title and an explicit artifact name:

- Release title: `Mobile Matrix v<version> — macOS arm64`
- Artifact: `Mobile-Matrix-macos-arm64.zip`

Each release should briefly state the supported platform, architecture, signing status, runtime prerequisites, and the main user-visible changes. Do not label an unvalidated Windows or Linux build as official.

## Measurement

After each meaningful README or metadata update, inspect GitHub repository insights rather than inventing search targets:

- **Traffic**: repository views, unique visitors, clones, and referrers.
- **Releases**: asset download counts and release-page visits.
- **Issues and discussions**: questions that reveal the terms users actually use.

Compare periods consistently and treat traffic changes as directional evidence, not proof that a single keyword caused the change.

## Claims to avoid

- Do not describe Mobile Matrix as a Google Play or App Store listing.
- Do not claim an Android client is available.
- Do not claim Windows or Linux packages are ready for distribution without a validated release artifact.
- Do not call the app a full STF server stack; the current project embeds and uses STF Lite runtime components locally.
- Do not promise support for every Android device, Android version, or ADB networking mode without a reproduced test case.
- Do not add unrelated popular keywords merely to increase impressions.
