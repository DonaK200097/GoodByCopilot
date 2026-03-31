# GoodByCopilot — Lightweight AI assistant launcher

<p align="center">
  <img src="https://img.shields.io/badge/AutoHotkey-v2-9cf?style=for-the-badge" alt="AutoHotkey v2" />
  <img src="https://img.shields.io/badge/Platform-Windows-0078d4?style=for-the-badge" alt="Windows" />
  <img src="https://img.shields.io/badge/Release-latest-00c853?style=for-the-badge" alt="Latest release" />
</p>

<p align="center">
  <a href="./README.md"><b>English</b></a> ·
  <a href="./README.ru.md"><b>Русский</b></a>
</p>

<p align="center">
  <b>A compact Windows tool for launching and managing AI services.</b>
</p>

<p align="center">
  <a href="https://github.com/DonaK200097/GoodByCopilot/releases/latest"><b>Download</b></a>
</p>

GoodByCopilot brings service launching, service list management, interface settings, and the background `CoreGBC` engine into one small Windows app.  
It is designed to keep multiple AI services close at hand without extra manual steps.

## What it does

- Opens and switches AI services from a single interface
- Controls the background `CoreGBC` engine
- Persists services, settings, and window state
- Supports hotkey, tray, and auto-start
- Switches theme and interface language

## How it works

1. You start `GoodByCopilot.exe` or the source `GoodByCopilot.ahk`.
2. The app reads configuration from `Core\config.ini` and services from `Core\list.ini`.
3. `CoreGBC` launches, switches, and closes the selected service.
4. Theme, hotkey, and window state are saved automatically.

## Highlights

- Service list management
- Background engine control
- Quick active-service switching
- Hotkey configuration
- Auto-start with Windows
- Tray icon and tray-based control
- Light, dark, and system themes
- Russian and English UI
- Persistent window state and user settings

## What's inside

- `GoodByCopilot.ahk` - main entry point and UI
- `Core\CoreGBC.ahk` - engine logic
- `Core\Config.ahk` - configuration and migration helpers
- `Core\Service.ahk` - engine start/stop and auto-start helpers
- `Core\Locale.ahk` - interface language detection
- `Core\Theme.ahk` - palette and styling
- `Core\UI.ahk` - UI layout helpers

## Release build

Release archives are built locally from compiled binaries.

1. Compile `GoodByCopilot.ahk` to `GoodByCopilot.exe`.
2. Compile `Core\CoreGBC.ahk` to `CoreGBC.exe`.
3. Run `scripts\build-release-local.ps1`.

The latest release is always available from the button above. Direct archive link:

`https://github.com/DonaK200097/GoodByCopilot/releases/latest/download/GoodByCopilot-release.zip`

## Requirements

- Windows
- AutoHotkey v2.0

## Note

This project is intentionally Windows-only. Some logic depends on processes, windows, and local INI files, so behavior can vary with the browser and service title format.

