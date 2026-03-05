# 1.1 Установка SDK и редакторов

## 1. Формальное определение

**Dart SDK** (Software Development Kit) — набор инструментов для разработки на Dart, включающий:

- Виртуальную машину Dart VM (JIT-компиляция для разработки)
- AOT-компилятор (для продакшн-сборок)
- Набор core-библиотек (`dart:core`, `dart:async`, `dart:io` и др.)
- CLI-утилиту `dart` (единая точка входа для всех инструментов)
- Менеджер пакетов `pub`

**Уровень:** инфраструктура и toolchain — не относится к синтаксису или runtime напрямую, но является обязательным условием для работы с языком.

## 2. Зачем это нужно

- **Dart не работает «из коробки»** в отличие от JavaScript (который есть в каждом браузере). Для запуска Dart-кода нужен SDK.
- **IDE-интеграция** обеспечивает автодополнение, навигацию по коду, рефакторинг, отладку и hot reload (во Flutter).
- **Единообразие среды** — SDK фиксирует версию языка, что критично для воспроизводимости сборок.

**Сценарии:**
| Сценарий | Что нужно |
|----------|-----------|
| Flutter-разработка | Flutter SDK (включает Dart SDK) |
| Серверный Dart | Dart SDK |
| CLI-утилиты | Dart SDK |
| Веб-приложения | Dart SDK + `webdev` |

## 3. Как это работает

### Установка на Windows

```powershell
# Через Chocolatey
choco install dart-sdk

# Или через winget
winget install Dart.DartSDK
```

### Установка на macOS

```bash
brew tap dart-lang/dart
brew install dart
```

### Установка на Linux

```bash
sudo apt-get update
sudo apt-get install apt-transport-https
wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/dart.gpg
echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/dart-archive/channels/stable/release latest main' | sudo tee /etc/apt/sources.list.d/dart_stable.list
sudo apt-get update
sudo apt-get install dart
```

### Проверка установки

```bash
dart --version
# Dart SDK version: 3.x.x (stable) ...
```

### Настройка VS Code

1. Установить расширение **Dart** (`Dart-Code.dart-code`)
2. Установить расширение **Flutter** (если нужен Flutter)
3. Настроить `settings.json`:

```json
{
  "dart.lineLength": 80,
  "dart.enableSdkFormatter": true,
  "editor.formatOnSave": true,
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.rulers": [80]
  }
}
```

### Настройка IntelliJ IDEA / Android Studio

1. **Plugins → Marketplace → Dart** — установить плагин
2. **File → Project Structure → SDKs** — указать путь к Dart SDK
3. Для Flutter: установить плагин Flutter (подтянет Dart автоматически)

## 4. Минимальный пример

Проверка, что SDK работает:

```dart
// файл: hello.dart
void main() {
  print('Dart SDK установлен и работает');
  print('Версия: ${Platform.version}');
}
```

```bash
dart run hello.dart
```

## 5. Практический пример

Создание проекта с нуля через CLI:

```bash
# Создать консольное приложение
dart create -t console my_app
cd my_app

# Структура проекта:
# my_app/
# ├── bin/
# │   └── my_app.dart      ← точка входа
# ├── lib/
# │   └── my_app.dart      ← библиотечный код
# ├── test/
# │   └── my_app_test.dart ← тесты
# ├── pubspec.yaml          ← манифест проекта
# ├── analysis_options.yaml ← правила анализа
# └── README.md

# Запуск
dart run

# Запуск тестов
dart test

# Анализ кода
dart analyze
```

**Почему именно эта структура?**

- `bin/` — исполняемые файлы; один `main()` на файл
- `lib/` — переиспользуемый код; импортируется через `package:my_app/`
- `test/` — конвенция Dart; `dart test` ищет файлы `*_test.dart` именно здесь
- `pubspec.yaml` — единый манифест: имя, версия, зависимости, ограничения SDK

## 6. Что происходит под капотом

### Dart SDK — это не просто компилятор

SDK содержит два основных режима исполнения:

```
                    ┌─────────────────────┐
                    │     Dart Source      │
                    │      (.dart)         │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                 ▼
      ┌──────────────┐ ┌─────────────┐ ┌───────────────┐
      │   dart run   │ │ dart compile│ │  dart compile │
      │   (JIT)      │ │   exe (AOT) │ │   js          │
      └──────────────┘ └─────────────┘ └───────────────┘
              │                │                 │
              ▼                ▼                 ▼
      Dart VM с JIT      Нативный       JavaScript
      (быстрый старт,   исполняемый    (для браузера)
       hot reload)       файл
```

- **JIT (Just-In-Time):** используется при `dart run`. Компилирует код по мере выполнения. Поддерживает hot reload. Идеален для разработки.
- **AOT (Ahead-Of-Time):** используется при `dart compile exe`. Компилирует весь код заранее в машинный код. Быстрый запуск, но нет hot reload. Для продакшн.

### Где хранится SDK

- Windows: `C:\tools\dart-sdk\` или `C:\src\flutter\bin\cache\dart-sdk\`
- macOS: `/usr/local/opt/dart/libexec/`
- Linux: `/usr/lib/dart/`

SDK содержит:

- `bin/dart` — единственный исполняемый файл (заменяет устаревшие `dart2js`, `dartfmt`, `dartanalyzer`)
- `lib/` — core-библиотеки (скомпилированные snapshots)
- `include/` — заголовки для FFI-интеграции

## 7. Производительность и ресурсы

| Характеристика                  | Значение                                  |
| ------------------------------- | ----------------------------------------- |
| Размер SDK                      | ~500 MB (standalone), ~2 GB (Flutter SDK) |
| Время холодного старта (JIT)    | ~200–500 мс                               |
| Время холодного старта (AOT)    | ~5–50 мс                                  |
| Потребление RAM (пустой проект) | ~30–50 MB                                 |

**Рекомендации:**

- Для CI/CD используйте Docker-образы `dart:stable` (~300 MB) вместо полной установки
- Если диск ограничен — не устанавливайте Flutter SDK, если нужен только серверный Dart
- VS Code потребляет значительно меньше RAM, чем IntelliJ IDEA (~300 MB vs ~1.5 GB)

## 8. Частые ошибки и антипаттерны

### ❌ Не добавлен в PATH

```
'dart' is not recognized as an internal or external command
```

**Решение:** убедиться, что `<dart-sdk>/bin` добавлен в переменную `PATH`.

### ❌ Использование устаревших инструментов

```bash
# Устарело (Dart 2.x):
dartfmt .
dartanalyzer .
pub get

# Актуально (Dart 3.x):
dart format .
dart analyze
dart pub get
```

### ❌ Flutter SDK вместо Dart SDK для серверных проектов

Flutter SDK включает Dart, но тянет за собой ~2 GB зависимостей (Android SDK, Platform tools). Для чистого серверного Dart используйте standalone Dart SDK.

### ❌ Игнорирование `analysis_options.yaml`

Проект без настроенного анализатора — это проект без статической проверки. Всегда используйте хотя бы `package:lints/recommended.yaml`.

## 9. Сравнение с альтернативами

| Критерий               | Dart SDK             | Node.js (npm)         | JDK (Java/Kotlin)         | Go toolchain       |
| ---------------------- | -------------------- | --------------------- | ------------------------- | ------------------ |
| Единый CLI             | `dart` (всё в одном) | `node`, `npm`, `npx`  | `java`, `javac`, `gradle` | `go` (всё в одном) |
| Встроенный форматтер   | ✅ `dart format`     | ❌ (нужен Prettier)   | ❌ (нужен IDE/plugin)     | ✅ `go fmt`        |
| Встроенный анализатор  | ✅ `dart analyze`    | ❌ (нужен ESLint)     | ✅ (javac warnings)       | ✅ `go vet`        |
| Встроенный тест-раннер | ✅ `dart test`       | ❌ (нужен Jest/Mocha) | ❌ (нужен JUnit)          | ✅ `go test`       |
| Скорость установки     | Быстро (~1 мин)      | Быстро                | Медленно (JDK + Gradle)   | Быстро             |

**Dart ближе всего к Go** по философии toolchain: один CLI, встроенные инструменты, минимум конфигурации.

## 10. Когда НЕ стоит использовать

- **Если проект уже завязан на JVM-экосистему** — Java/Kotlin SDK имеет несравнимо большую экосистему библиотек для enterprise.
- **Если не планируется Flutter и нужен только веб** — Node.js/TypeScript имеет более зрелую экосистему для серверного и клиентского веба.
- **Если нужен системный язык** — Dart не заменяет C/C++/Rust для низкоуровневой разработки.
- **Если команда не знает Dart и нет мотивации изучать** — язык достаточно нишевый вне Flutter-мира.

## 11. Краткое резюме

1. **Dart SDK** — единственное, что нужно для начала: компилятор, VM, пакетный менеджер и утилиты в одном пакете.
2. **Один CLI `dart`** заменяет десятки отдельных инструментов: форматирование, анализ, тесты, компиляция.
3. **JIT для разработки, AOT для продакшн** — две модели компиляции для разных задач.
4. **VS Code + Dart-плагин** — оптимальный выбор по соотношению функциональность/потребление ресурсов.
5. **`dart create`** генерирует проект с правильной структурой — не создавайте структуру вручную.
6. **Всегда настраивайте `analysis_options.yaml`** — статический анализ ловит ошибки до запуска программы.
7. **Философия toolchain Dart** ближе к Go, чем к Java или Node.js: минимум конфигурации, максимум встроенных инструментов.

---

> **Следующий:** [1.2 Dart CLI и dartdev инструменты](01_02_dart_cli.md)
