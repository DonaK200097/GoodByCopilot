# GoodByCopilot

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
  <b>Компактная утилита для запуска и управления AI-сервисами в Windows.</b>
</p>

<p align="center">
  <a href="https://github.com/DonaK200097/GoodByCopilot/releases/latest"><b>Скачать / Download</b></a>
</p>

GoodByCopilot объединяет запуск сервисов, управление их списком, настройки интерфейса и работу фонового `CoreGBC`-движка в одном небольшом Windows-приложении.  
Программа помогает держать несколько AI-сервисов под рукой без лишних ручных действий.

## Что умеет

- Открывать и переключать AI-сервисы из единого интерфейса
- Управлять фоновым `CoreGBC`-движком
- Сохранять сервисы, настройки и состояние окна
- Работать с hotkey, tray и автозапуском
- Переключать тему и язык интерфейса

## Как это работает

1. Вы запускаете `GoodByCopilot.exe` или исходный `GoodByCopilot.ahk`.
2. Приложение читает конфигурацию из `Core\config.ini` и список сервисов из `Core\list.ini`.
3. Через `CoreGBC` оно открывает, переключает и закрывает нужный сервис.
4. Настройки, тема, хоткей и состояние окна сохраняются автоматически.

## Основные возможности

- Управление списком AI-сервисов
- Запуск и остановка фонового движка
- Быстрый выбор активного сервиса
- Настройка горячей клавиши
- Автозапуск вместе с Windows
- Значок в tray и управление окном из трея
- Светлая, тёмная и системная тема
- Русский и английский интерфейс
- Сохранение состояния окна и пользовательских настроек

## Что внутри

- `GoodByCopilot.ahk` - основная точка входа и GUI
- `Core\CoreGBC.ahk` - логика движка
- `Core\Config.ahk` - конфигурация и миграции
- `Core\Service.ahk` - запуск, остановка и автозапуск
- `Core\Locale.ahk` - определение языка интерфейса
- `Core\Theme.ahk` - оформление и палитра
- `Core\UI.ahk` - вспомогательные функции интерфейса

## Сборка релиза

Релизный архив собирается локально из скомпилированных бинарников.

1. Скомпилируйте `GoodByCopilot.ahk` в `GoodByCopilot.exe`.
2. Скомпилируйте `Core\CoreGBC.ahk` в `CoreGBC.exe`.
3. Запустите `scripts\build-release-local.ps1`.

Последний релиз всегда доступен по кнопке выше. Прямая ссылка на архив:

`https://github.com/DonaK200097/GoodByCopilot/releases/latest/download/GoodByCopilot-release.zip`

## Требования

- Windows
- AutoHotkey v2.0

## Примечание

Проект намеренно Windows-ориентированный. Часть логики завязана на процессы, окна и локальные INI-файлы, поэтому поведение зависит от браузера и формата заголовков сервисов.
