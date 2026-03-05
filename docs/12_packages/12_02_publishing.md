# 12.2 Публикация на pub.dev

## 1. Формальное определение

**pub.dev** — официальный репозиторий пакетов Dart и Flutter. Публикация — это процесс загрузки версии пакета на pub.dev, после чего он становится доступен другим разработчикам через `dart pub get`.

Публикация является **необратимой**: загруженную версию нельзя удалить, можно только пометить как `retracted` (отозванную) или выпустить новую версию.

## 2. Зачем это нужно

- **Распространение** — любой разработчик может добавить ваш пакет одной строкой в `pubspec.yaml`.
- **Скоринг** — pub.dev оценивает качество пакета (pub points), что мотивирует поддерживать высокие стандарты.
- **Документация** — pub.dev автоматически генерирует API-документацию из doc-комментариев.
- **Обнаруживаемость** — пакеты индексируются, имеют рейтинг и отзывы.
- **Верифицированные издатели** — организации могут подтвердить владение доменом.

## 3. Как это работает

### Предварительная проверка

Перед публикацией пакет должен соответствовать требованиям:

```bash
# Проверка без фактической публикации
dart pub publish --dry-run
```

Типичные ошибки, которые `--dry-run` обнаруживает:

```
Package validation found the following errors:
* Your pubspec.yaml must have a "homepage" or "repository" field.
* Your package description is too short (must be 60-180 characters).
* Missing a LICENSE file.
* Missing a README.md file.
```

### Минимальный pubspec.yaml для публикации

```yaml
name: string_utils
description: >-
  A lightweight collection of string utility functions
  including capitalize, slugify, truncate and padding.
version: 1.0.0
repository: https://github.com/username/string_utils

environment:
  sdk: ^3.0.0
```

### Чек-лист перед публикацией

```
✅ pubspec.yaml
   ├── name — уникальное имя (snake_case)
   ├── description — 60-180 символов
   ├── version — корректная SemVer версия
   ├── repository / homepage — URL репозитория
   └── environment.sdk — ограничение SDK

✅ Файлы
   ├── README.md — описание, примеры, бейджи
   ├── CHANGELOG.md — история изменений
   ├── LICENSE — лицензия (BSD-3, MIT и т.д.)
   ├── example/ — рабочий пример
   └── analysis_options.yaml — настройки линтера

✅ Качество
   ├── dart analyze — 0 ошибок и предупреждений
   ├── dart format — весь код отформатирован
   ├── dart test — все тесты проходят
   └── dartdoc — doc-комментарии на экспортируемых API
```

### Процесс публикации

```bash
# 1. Авторизация (выполняется один раз)
dart pub login

# 2. Проверка
dart pub publish --dry-run

# 3. Публикация
dart pub publish

# Подтверждение в консоли:
# Publishing string_utils 1.0.0 to https://pub.dev
# |-- LICENSE
# |-- CHANGELOG.md
# |-- README.md
# |-- lib/string_utils.dart
# |-- lib/src/capitalize.dart
# |-- pubspec.yaml
# |-- example/string_utils_example.dart
# Looks great! Are you ready to upload? (y/n)
```

### Верифицированные издатели (Verified Publishers)

```
┌────────────────────────────────────────────────────┐
│  Verified Publisher                                 │
│                                                    │
│  1. Создать организацию на pub.dev                 │
│  2. Подтвердить владение доменом (DNS TXT запись)   │
│  3. Привязать пакеты к организации                 │
│                                                    │
│  Пакет от «tools.example.com» ✓ получает           │
│  повышенное доверие и отображает значок             │
└────────────────────────────────────────────────────┘
```

```bash
# Передача пакета верифицированному издателю
dart pub uploader add publisher@example.com
```

## 4. Pub Points — система скоринга

pub.dev оценивает пакет по 160 баллов (pub points):

```
┌─────────────────────────────────────────────────────────────┐
│  Категория               │ Макс. баллы │ Что оценивается    │
├──────────────────────────┼─────────────┼────────────────────┤
│  Follow Dart conventions │     30      │ Форматирование,    │
│                          │             │ analysis_options   │
├──────────────────────────┼─────────────┼────────────────────┤
│  Provide documentation   │     20      │ README, example,   │
│                          │             │ API docs           │
├──────────────────────────┼─────────────┼────────────────────┤
│  Platform support        │     20      │ Поддержка платформ │
│                          │             │ (native, js, wasm) │
├──────────────────────────┼─────────────┼────────────────────┤
│  Pass static analysis    │     50      │ dart analyze,      │
│                          │             │ 0 ошибок           │
├──────────────────────────┼─────────────┼────────────────────┤
│  Support up-to-date      │     20      │ Совместимость с    │
│  dependencies            │             │ последним Dart SDK │
├──────────────────────────┼─────────────┼────────────────────┤
│  Sound null safety       │     20      │ Полная поддержка   │
│                          │             │ null safety        │
├──────────────────────────┼─────────────┼────────────────────┤
│                          │ Итого: 160  │                    │
└──────────────────────────┴─────────────┴────────────────────┘
```

## 5. Пример полного жизненного цикла

### Подготовка README.md

````markdown
# string_utils

[![pub package](https://img.shields.io/pub/v/string_utils.svg)](https://pub.dev/packages/string_utils)
[![CI](https://github.com/username/string_utils/actions/workflows/ci.yml/badge.svg)](https://github.com/username/string_utils/actions)

A lightweight collection of string utility functions for Dart.

## Features

- `capitalize()` — capitalize the first letter
- `slugify()` — convert to URL-friendly slug
- `truncate()` — truncate with ellipsis

## Getting started

```bash
dart pub add string_utils
```
````

## Usage

```dart
import 'package:string_utils/string_utils.dart';

void main() {
  print('hello world'.capitalize());  // Hello world
  print('Hello World!'.slugify());    // hello-world
  print('Long text...'.truncate(8));  // Long tex…
}
```

## Additional information

See the [API documentation](https://pub.dev/documentation/string_utils/latest/)
for detailed information about all available functions.

````

### Подготовка CHANGELOG.md

```markdown
## 1.0.0

- Initial release
- Added `capitalize()` extension method
- Added `slugify()` for URL-friendly strings
- Added `truncate()` with configurable ellipsis

## 0.1.0-dev

- Pre-release with basic API
````

### Подготовка example/

```dart
// example/string_utils_example.dart
import 'package:string_utils/string_utils.dart';

void main() {
  // Capitalize
  final greeting = 'hello world'.capitalize();
  print(greeting); // Hello world

  // Slugify
  final slug = 'My Blog Post Title!'.slugify();
  print(slug); // my-blog-post-title

  // Truncate
  final short = 'A very long piece of text'.truncate(10);
  print(short); // A very lon…
}
```

## 6. Отзыв версии (Retraction)

Если в опубликованной версии обнаружена критическая ошибка:

```bash
# Отозвать конкретную версию
dart pub retract --version 1.0.0 --message "Critical bug in slugify"

# При dart pub get пользователи увидят:
# string_utils 1.0.0 (retracted)
# Consider upgrading to a newer version.
```

```dart
// В pubspec.yaml можно указать retracted версии:
// (это делается автоматически при retract через CLI)
```

Отзыв **не удаляет** версию, но:

- Новые проекты не получат её по умолчанию.
- Существующие `pubspec.lock` продолжат работать.
- В UI pub.dev версия помечается предупреждением.

## 7. Файл .pubignore

Аналог `.gitignore` для публикации — исключает файлы из пакета:

```
# .pubignore
# Не публикуем тестовые данные и CI-конфигурации
test/fixtures/
.github/
*.g.dart
coverage/
doc/api/
```

Если `.pubignore` отсутствует, используется `.gitignore`. Если `.pubignore` есть — `.gitignore` игнорируется при публикации.

## 8. Распространённые ошибки

### ❌ Публикация без проверки

```bash
# Плохо — сразу публикуем
dart pub publish

# Хорошо — сначала проверяем
dart pub publish --dry-run
dart analyze
dart test
dart pub publish
```

### ❌ Слишком широкие зависимости

```yaml
# Плохо — любая версия
dependencies:
  http: any

# Хорошо — ограниченный диапазон
dependencies:
  http: ^1.2.0
```

### ❌ Отсутствие example/

```
# pub.dev снижает очки за отсутствие рабочего примера.
# Пример обязательно должен компилироваться и запускаться.
```

### ❌ Забытый экспорт

```dart
// lib/string_utils.dart
// Плохо — забыли экспортировать новый файл
export 'src/capitalize.dart';
// export 'src/slug.dart';  ← забыли!

// Хорошо — все публичные API экспортированы
export 'src/capitalize.dart';
export 'src/slug.dart';
export 'src/truncate.dart';
```

## 9. Автоматизация публикации

```yaml
# .github/workflows/publish.yml
name: Publish to pub.dev

on:
  push:
    tags:
      - "v*"

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      id-token: write # Для OIDC-аутентификации
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - name: Install dependencies
        run: dart pub get

      - name: Verify formatting
        run: dart format --output=none --set-exit-if-changed .

      - name: Analyze
        run: dart analyze --fatal-infos

      - name: Run tests
        run: dart test

      - name: Publish
        run: dart pub publish --force
```

## 10. Полезные команды

```bash
# Проверка перед публикацией
dart pub publish --dry-run

# Публикация без подтверждения (для CI)
dart pub publish --force

# Отзыв версии
dart pub retract --version <версия>

# Просмотр загруженных версий
# (через веб-интерфейс pub.dev)

# Авторизация
dart pub login

# Выход
dart pub logout

# Информация о пакете
dart pub info <package_name>
```

---

> **Назад:** [12.1 Структура пакета](12_01_package_structure.md) · **Далее:** [12.3 Семантическое версионирование](12_03_semver.md)
