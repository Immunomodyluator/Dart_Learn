# Урок 15. Публикация и управление пакетами

> Охватывает подтемы: 15.1 Структура пакета, 15.2 pub.dev и pubspec.yaml, 15.3 Версионирование, 15.4 Dependency conflicts

---

## 1. Формальное определение

**Dart package** — переиспользуемый юнит кода, опубликованный на [pub.dev](https://pub.dev) или размещённый локально/на git. Экосистема управляется инструментом `dart pub`.

- **`pubspec.yaml`** — манифест пакета: имя, версия, зависимости
- **SemVer** (Semantic Versioning) — `MAJOR.MINOR.PATCH`
- **Constraint solving** — `dart pub get` находит совместимый набор версий для всех зависимостей
- **`pubspec.lock`** — зафиксированные версии зависимостей (должен быть в git для приложений)

---

## 2. Структура пакета (15.1)

```
my_package/
├── lib/                    # Публичный API
│   ├── my_package.dart     # Главный export файл
│   └── src/                # Приватная реализация
│       ├── utils.dart
│       └── models.dart
├── bin/                    # Исполняемые файлы (CLI tools)
│   └── my_tool.dart
├── test/                   # Тесты
│   └── my_package_test.dart
├── example/                # Примеры использования
│   └── main.dart
├── doc/                    # Документация (опционально)
├── CHANGELOG.md            # История версий
├── README.md               # Описание пакета
├── LICENSE                 # Лицензия (обязательно для публикации)
├── pubspec.yaml            # Манифест
└── pubspec.lock            # Зафиксированные версии
```

```dart
// lib/my_package.dart — re-export публичного API
library my_package;

export 'src/models.dart';
export 'src/utils.dart' show formatDate, parseDate; // только нужное
// src/ не экспортируем напрямую — это приватная реализация
```

---

## 3. pubspec.yaml в деталях (15.2)

```yaml
name: my_awesome_package
description: A concise description of what the package does. Keep it under 180 chars.
version: 1.2.3
homepage: https://github.com/username/my_awesome_package
repository: https://github.com/username/my_awesome_package
issue_tracker: https://github.com/username/my_awesome_package/issues

# Минимальная версия Dart SDK
environment:
  sdk: '>=3.0.0 <4.0.0'

# Зависимости для production кода
dependencies:
  http: ^1.2.0          # ^1.2.0 = >=1.2.0 <2.0.0
  meta: ^1.11.0
  intl: '>=0.19.0 <1.0.0'  # явный диапазон

# Зависимости только для разработки (не включаются в пакет)
dev_dependencies:
  test: ^1.25.0
  mockito: ^5.4.0
  build_runner: ^2.4.0
  lints: ^3.0.0

# Переопределение версии (осторожно!)
dependency_overrides:
  some_package: 1.0.5   # замораживает конкретную версию

# Исполняемые файлы для dart pub global activate
executables:
  my_tool: main         # dart run my_tool → bin/main.dart
  another_tool:         # bin/another_tool.dart

# Flutter специфика (если Flutter пакет)
flutter:
  plugin:
    platforms:
      android:
        package: com.example.my_package
        pluginClass: MyPlugin
```

---

## 4. Управление зависимостями

```bash
# Установить зависимости из pubspec.yaml
dart pub get

# Обновить до последних совместимых версий
dart pub upgrade

# Обновить конкретный пакет
dart pub upgrade http

# Обновить до последних версий ДАЖЕ если minor/major
dart pub upgrade --major-versions

# Добавить зависимость и обновить pubspec.yaml
dart pub add http
dart pub add --dev test mockito

# Удалить зависимость
dart pub remove old_package

# Посмотреть дерево зависимостей
dart pub deps

# Проверить устаревшие зависимости
dart pub outdated

# Глобальная установка CLI инструмента
dart pub global activate dart_style
dart pub global run dart_style:format .
```

---

## 5. Версионирование SemVer (15.3)

```
MAJOR.MINOR.PATCH[-pre+build]
  │      │     │
  │      │     └─ Исправления: обратно совместимые баг-фиксы
  │      └─────── Новая функциональность: обратно совместимо
  └────────────── Breaking changes: несовместимые изменения API
```

```yaml
# Синтаксис constraints:
http: ^1.2.3      # caret: >=1.2.3 <2.0.0 (рекомендуется для >1.0.0)
http: ^0.13.4     # caret для 0.x: >=0.13.4 <0.14.0 (осторожно!)
http: '>=1.0.0 <3.0.0'  # явный диапазон
http: '1.2.3'     # точная версия (нежелательно — блокирует обновления)
http: any         # любая (крайне нежелательно)
```

### CHANGELOG.md — правильный формат

```markdown
## 2.0.0

Breaking changes:
- Removed deprecated `fetchLegacy()` method
- `Config` constructor requires `timeout` parameter

New features:
- Added `Config.withDefaults()` factory
- Support for retry policies

Bug fixes:
- Fixed memory leak in connection pool

## 1.2.1

Bug fixes:
- Fixed null safety issue in parser (#42)

## 1.2.0

New features:
- Added `batchFetch()` method
```

---

## 6. Dependency conflicts (15.4)

```bash
# Симптом конфликта:
# Because package_a >=1.0.0 depends on shared_lib ^1.0.0 and
# package_b >=2.0.0 depends on shared_lib ^2.0.0,
# package_a >=1.0.0 is incompatible with package_b >=2.0.0.

# Диагностика:
dart pub deps --style=compact
dart pub outdated --transitive
```

```yaml
# Решение 1: dependency_overrides (временное, с осторожностью)
dependency_overrides:
  shared_lib: ^2.0.0  # форсируем версию; может сломать package_a

# Решение 2: ограничить версию проблемного пакета
dependencies:
  package_a: '>=1.0.0 <2.0.0'  # версия совместимая с shared_lib ^1.0.0

# Решение 3: conditional import для несовместимых платформ
# import 'package:some_pkg/io.dart'
#   if (dart.library.html) 'package:some_pkg/web.dart';
```

---

## 7. Публикация на pub.dev

```bash
# 1. Проверка перед публикацией
dart pub publish --dry-run

# Контрольный список pub.dev:
# ✓ LICENSE файл
# ✓ README.md с примером использования
# ✓ CHANGELOG.md
# ✓ analysis_options.yaml (рекомендуется lints/core)
# ✓ Документация публичного API (///)
# ✓ dart analyze без ошибок и предупреждений
# ✓ dart format --output=none --set-exit-if-changed .  (проверка форматирования)
# ✓ dart test (все тесты проходят)

# 2. Публикация
dart pub publish
# Потребует Google аккаунт (OAuth)

# Автоматизация через GitHub Actions
```

```yaml
# .github/workflows/publish.yml
name: Publish to pub.dev

on:
  push:
    tags: ['v*']  # при создании тага v1.2.3

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # для OIDC
    
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - name: Install dependencies
        run: dart pub get
      - name: Test
        run: dart test
      - name: Publish
        run: dart pub publish --force  # OIDC аутентификация без интерактива
```

---

## 8. Документация публичного API

```dart
/// Клиент для работы с REST API.
///
/// Пример использования:
/// ```dart
/// final client = ApiClient(baseUrl: 'https://api.example.com');
/// final user = await client.getUser('123');
/// ```
///
/// Не забудьте вызвать [dispose] когда клиент больше не нужен.
class ApiClient {
  final String baseUrl;

  /// Создаёт клиент с заданным [baseUrl].
  ///
  /// [timeout] — таймаут на запрос (по умолчанию 30 секунд).
  ///
  /// Throws [ArgumentError] если [baseUrl] пустой.
  ApiClient({required this.baseUrl, Duration timeout = const Duration(seconds: 30)});

  /// Получить пользователя по [id].
  ///
  /// Возвращает [User] если найден.
  /// Throws [NotFoundException] если пользователь не найден.
  /// Throws [NetworkException] при проблемах с сетью.
  Future<User> getUser(String id) async { /* ... */ }

  /// Освобождает ресурсы клиента.
  void dispose() { /* ... */ }
}
```

```bash
# Генерация документации
dart pub global activate dartdoc
dartdoc
# Документация в doc/api/
```

---

## 9. Path и git зависимости

```yaml
dependencies:
  # Локальная зависимость (для разработки)
  my_local_package:
    path: ../my_local_package

  # Git зависимость
  my_git_package:
    git:
      url: https://github.com/username/my_git_package.git
      ref: main       # ветка, тег или SHA
      path: packages/core  # если пакет в поддиректории

  # Hosted на альтернативном pub сервере
  my_enterprise_package:
    hosted:
      name: my_enterprise_package
      url: https://pub.enterprise.com
    version: ^1.0.0
```

---

## 10. Под капотом

### Алгоритм constraint solving

`dart pub get` использует **DPLL-based SAT solver** (pubgrub algorithm):
1. Берёт constraints для всех зависимостей
2. Ищет пересечение совместимых версий
3. Resolves transitive deps рекурсивно
4. Сохраняет результат в `pubspec.lock`

### pub.dev инфраструктура

- Пакеты загружаются как `.tar.gz` архивы
- Верификация публикации через Google OAuth / OIDC
- Кэш: `~/.pub-cache/` — загруженные пакеты

---

## 11. Частые ошибки

**1. `pubspec.lock` не в git (для приложений):**
```bash
# Для ПРИЛОЖЕНИЙ — lock файл в git (воспроизводимые билды)
# Для ПАКЕТОВ (библиотек) — lock файл НЕ в git (тестируем с разными версиями)
```

**2. `any` или слишком широкий constraint:**
```yaml
# ПЛОХО — любая версия, включая будущие breaking
http: any

# ХОРОШО
http: ^1.2.0
```

**3. dev_dependencies в dependencies:**
```yaml
# ПЛОХО — test попадёт в транзитивные зависимости пакета
dependencies:
  test: ^1.25.0  # только нужен для разработки!

# ХОРОШО
dev_dependencies:
  test: ^1.25.0
```

---

## 12. Краткое резюме

1. **Структура пакета**: `lib/` (публичное) + `lib/src/` (приватное) + `test/` + `pubspec.yaml`
2. **`pubspec.lock`**: в git для приложений, не в git для библиотек
3. **SemVer**: `^1.2.0` = `>=1.2.0 <2.0.0`; breaking changes → major bump
4. **`dart pub outdated`** для мониторинга устаревших зависимостей
5. **`dependency_overrides`** — временное решение конфликтов; может нарушить совместимость
6. **Перед публикацией**: LICENSE + README + CHANGELOG + `dart analyze` + `dart test`
7. **OIDC автопубликация** через GitHub Actions без хранения секретных токенов
