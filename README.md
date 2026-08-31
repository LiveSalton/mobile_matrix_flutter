# Mobile Matrix — macOS Android Device Control & ADB Workspace

Mobile Matrix is a Flutter desktop workspace for controlling Android devices from macOS. It brings ADB device management, real-time Android screen mirroring, keyboard and touch input, clipboard sync, screenshots, device tools, and an embedded STF Lite runtime into one local control console.

[简体中文](README-ZH.md) · [Download the latest macOS release](https://github.com/LiveSalton/mobile_matrix_flutter/releases/latest) · [View releases](https://github.com/LiveSalton/mobile_matrix_flutter/releases)

## Features

- **Android device control** — discover authorized ADB devices and switch between connected devices.
- **Screen mirroring** — view a live Android display through the bundled STF Lite and minicap runtime.
- **Keyboard and touch input** — send text, taps, swipes, hardware keys, and navigation actions to the device.
- **Clipboard sync** — move text between the Mac clipboard and the Android device.
- **Screenshot copy** — capture the current device screen and copy it to the system clipboard.
- **ADB tools** — run shell commands and query system version, display resolution, network information, and other device details.
- **Device workflows** — install and manage APKs, read installed applications, open system settings, and configure developer options.
- **Desktop control surface** — use a responsive multi-panel dashboard with Chinese and English UI resources.

## Download

### macOS

The current published package targets **Apple Silicon (arm64)**:

- [Mobile-Matrix-macos-arm64.zip](https://github.com/LiveSalton/mobile_matrix_flutter/releases/download/v1.0.0/Mobile-Matrix-macos-arm64.zip)

The archive contains `Mobile Matrix.app` and the bundled STF Lite runtime. The current release is distributed with ad hoc signing. macOS may show a security prompt the first time it is opened; use the system privacy settings to explicitly allow the app when appropriate.

### Windows and Linux

The repository contains Flutter desktop platform directories, but an official Windows or Linux distributable has not been published or validated yet. Do not treat those directories as a ready-to-share release.

### Android

Mobile Matrix is a desktop host for controlling Android devices. This repository does not currently publish a separate Android client application.

## Requirements

- A Mac with Apple Silicon for the current release.
- An Android phone or tablet with **Developer options** and **USB debugging** enabled.
- A USB connection and an authorized ADB connection.
- Approve the computer's RSA debugging prompt on the Android device when it appears.

## Use the release package

1. Download the macOS arm64 archive from the release page.
2. Extract `Mobile Matrix.app` and move it to a suitable local applications folder.
3. Connect an Android device with USB debugging enabled.
4. Open the app and approve the ADB authorization prompt on the device.
5. Select the device from the device selector to start controlling it.

## Development

This is a Flutter desktop project. To run it locally:

```bash
flutter pub get
flutter run -d macos
```

To inspect the project on other desktop targets, use the corresponding Flutter device target only after verifying its platform-specific runtime and bundled STF Lite resources.

## Architecture notes

The desktop UI communicates with Android through ADB. Screen streaming and input are provided by the local STF Lite integration and its bundled runtime resources. Platform-specific code remains behind the Flutter desktop application boundary so that unsupported platform capabilities are not presented as working features.

## Project status

The macOS arm64 release is available on GitHub. Feature behavior still depends on the Android device, ADB authorization, and the local STF Lite runtime. Bug reports and reproducible device-specific cases are welcome in [GitHub Issues](https://github.com/LiveSalton/mobile_matrix_flutter/issues).

For the Chinese version, see [README-ZH.md](README-ZH.md).

## License

See the repository license and third-party notices before redistributing the application bundle.
