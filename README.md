# GoodByCopilot

GoodByCopilot is a small AutoHotkey v2 utility for managing AI web app shortcuts and a companion engine process on Windows. It provides a compact GUI, tray integration, theming, localization, hotkey setup, and persistent state through INI files.

## What it does

- Launches and manages the `CoreGBC` engine.
- Stores per-service metadata in `Core\list.ini`.
- Keeps user settings in `Core\config.ini`.
- Supports Russian and English UI text.
- Supports light, dark, and system theme modes.
- Can start with Windows and show a tray icon.
- Remembers window state and service selection.

## Project Structure

- `GoodByCopilot.ahk` - main UI and application entry point.
- `Core\CoreGBC.ahk` - engine/runtime logic.
- `Core\Config.ahk` - configuration migrations and cleanup helpers.
- `Core\Service.ahk` - engine start/stop and autostart helpers.
- `Core\Locale.ahk` - language detection.
- `Core\Theme.ahk` - theme palette and GUI styling.
- `Core\UI.ahk` - layout helpers for the interface.
- `Core\default\` - default service descriptors.
- `Core\LangPackage\` - localization files.

## Requirements

- Windows
- AutoHotkey v2.0

## Running

1. Make sure AutoHotkey v2 is installed.
2. Open `GoodByCopilot.ahk`, or run the compiled build if you have one.
3. On first launch, the app creates its runtime folders and configuration files inside `Core\`.

## Configuration Files

The application uses these runtime files and folders inside `Core\`:

- `config.ini`
- `list.ini`
- `SessionHwnd.ini`
- `HotkeyError.ini`
- `PWA\`

These files are created and updated automatically.

## Main Features

- Service list management
- Settings window
- Hotkey selection
- Tray menu
- Auto-start support
- Theme switching
- Localization
- Window handle persistence

## Service Definitions

Default service descriptors live in `Core\default\` and are stored as `.ini` and `.url` files. The app uses them to seed or restore the service list.

## Notes

- The project is intentionally Windows-specific.
- Some operations rely on process detection and window matching, so behavior can depend on the browser and service title format.
- The codebase is structured for practical use rather than as a general-purpose framework.

## Release Build

Release archives are built locally from compiled binaries.

1. Compile `GoodByCopilot.ahk` to `GoodByCopilot.exe`.
2. Compile `Core\CoreGBC.ahk` to `CoreGBC.exe`.
3. Run `scripts\build-release-local.ps1`.

The release zip includes a top-level `GoodByCopilot/` folder containing:

- `GoodByCopilot.exe`
- `Core\CoreGBC.exe`
- `Core\default\`
- `Core\LangPackage\`

---

# GoodByCopilot

GoodByCopilot - это небольшая утилита на AutoHotkey v2 для управления ярлыками AI-сервисов и сопутствующим engine-процессом в Windows. В проекте есть компактный GUI, интеграция с tray, темы оформления, локализация, настройка горячей клавиши и сохранение состояния через INI-файлы.

## Что делает проект

- Запускает и управляет движком `CoreGBC`.
- Хранит метаданные сервисов в `Core\list.ini`.
- Хранит пользовательские настройки в `Core\config.ini`.
- Поддерживает русский и английский интерфейс.
- Поддерживает светлую, тёмную и системную тему.
- Может запускаться вместе с Windows и показывать значок в tray.
- Запоминает состояние окна и выбранный сервис.

## Структура проекта

- `GoodByCopilot.ahk` - основная точка входа и GUI.
- `Core\CoreGBC.ahk` - логика движка.
- `Core\Config.ahk` - миграции конфигурации и служебные операции.
- `Core\Service.ahk` - запуск/остановка движка и автозапуск.
- `Core\Locale.ahk` - определение языка.
- `Core\Theme.ahk` - палитра и оформление GUI.
- `Core\UI.ahk` - вспомогательные функции раскладки интерфейса.
- `Core\default\` - шаблоны сервисов.
- `Core\LangPackage\` - файлы локализации.

## Требования

- Windows
- AutoHotkey v2.0

## Запуск

1. Убедитесь, что установлен AutoHotkey v2.
2. Откройте `GoodByCopilot.ahk` или запустите собранный `exe`, если он есть.
3. При первом запуске приложение создаст служебные папки и файлы внутри `Core\`.

## Файлы конфигурации

Приложение использует следующие runtime-файлы и папки внутри `Core\`:

- `config.ini`
- `list.ini`
- `SessionHwnd.ini`
- `HotkeyError.ini`
- `PWA\`

Они создаются и обновляются автоматически.

## Основные возможности

- Управление списком сервисов
- Окно настроек
- Выбор горячей клавиши
- Меню в tray
- Автозапуск
- Переключение темы
- Локализация
- Сохранение состояния окон

## Описание сервисов

Шаблоны сервисов по умолчанию лежат в `Core\default\` и представлены файлами `.ini` и `.url`. Приложение использует их для первичного заполнения или восстановления списка сервисов.

## Примечания

- Проект рассчитан только на Windows.
- Часть логики опирается на поиск процессов и сопоставление заголовков окон, поэтому поведение зависит от браузера и формата названия сервиса.
- Кодовая база сделана как прикладной инструмент, а не как универсальный framework.

## Сборка релиза

Релизный архив собирается локально из готовых бинарников.

1. Скомпилируйте `GoodByCopilot.ahk` в `GoodByCopilot.exe`.
2. Скомпилируйте `Core\CoreGBC.ahk` в `CoreGBC.exe`.
3. Запустите `scripts\build-release-local.ps1`.

В архиве релиза есть верхняя папка `GoodByCopilot/`, внутри которой лежат:

- `GoodByCopilot.exe`
- `Core\CoreGBC.exe`
- `Core\default\`
- `Core\LangPackage\`
