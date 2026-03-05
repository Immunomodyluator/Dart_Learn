# 12.1 Структура пакета и документация

## 1. Формальное определение

**Пакет (package)** в Dart — это директория, содержащая `pubspec.yaml` и (как правило) каталог `lib/` с исходным кодом. Файл `pubspec.yaml` — единственный обязательный файл, определяющий имя, версию, зависимости и метаданные пакета.

**Структура каталогов** следует конвенциям Dart:
- `lib/` — публичный API (доступен другим пакетам).
- `lib/src/` — приватная реализация (импорт извне не рекомендуется).
- `test/` — тесты.
- `example/` — примеры использования.
- `bin/` — исполняемые файлы.

## 2. Зачем это нужно

- **Переиспользование** — выделить общий код в пакет и использовать в нескольких проектах.
- **Экосистема** — pub.dev оценивает структуру, документацию, тесты.
- **Удобство** — стандартная структура понятна всем Dart-разработчикам.
- **Документация** — `dartdoc` генерирует API-документацию из doc-комментариев.
- **Качество** — pub.dev scoring поощряет README, CHANGELOG, example, analysis.

## 3. Как это работает

### Создание пакета

```bash
# Создать library package
dart create -t package string_utils

# Создать console application
dart create -t console my_app

# Создать server application
dart create -t server-shelf my_server
```

### Полная структура пакета

```
string_utils/
├── lib/
│   ├── string_utils.dart         ← «barrel file» — точка входа
│   └── src/
│       ├── capitalize.dart       ← приватная реализация
│       ├── slug.dart
│       └── truncate.dart
├── test/
│   ├── capitalize_test.dart
│   ├── slug_test.dart
│   └── truncate_test.dart
├── example/
│   └── string_utils_example.dart
├── bin/                          ← (опционально) CLI утилиты
│   └── slugify.dart
├── doc/                          ← (опционально) дополнительная документация
│   └── api/                      ← генерируется dartdoc
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
├── CHANGELOG.md
└── LICENSE
```

### pubspec.yaml

```yaml
name: string_utils
description: >-
  A collection of string utility functions for Dart.
  Provides capitalize, slugify, truncate and more.
version: 1.0.0
homepage: https://github.com/username/string_utils
repository: https://github.com/username/string_utils
issue_tracker: https://github.com/username/string_utils/issues
documentation: https://pub.dev/documentation/string_utils/latest/

# Окружение
environment:
  sdk: ^3.0.0

# Зависимости
dependencies:
  meta: ^1.9.0

# Зависимости разработки
dev_dependencies:
  test: ^1.25.0
  lints: ^4.0.0

# Темы для поиска
topics:
  - string
  - utilities
  - text

# Скриншоты (для Flutter-пакетов)
# screenshots:
#   - description: 'Example usage'
#     path: doc/screenshots/example.png

# Для Flutter-пакетов
# flutter:
#   plugin:
#     platforms:
#       android:
#         package: com.example.string_utils
```

### Barrel file (точка входа)

```dart
// lib/string_utils.dart
// Это «barrel file» — единственный файл, который импортируют пользователи

/// String utility functions for Dart.
///
/// ```dart
/// import 'package:string_utils/string_utils.dart';
///
/// print(capitalize('hello')); // Hello
/// print(slugify('Hello World!')); // hello-world
/// ```
library;

export 'src/capitalize.dart';
export 'src/slug.dart';
export 'src/truncate.dart';
// НЕ экспортируем приватные хелперы
```

### Реализация в lib/src/

```dart
// lib/src/capitalize.dart

/// Делает первую букву строки заглавной.
///
/// Возвращает пустую строку, если [input] пуст.
///
/// ```dart
/// capitalize('hello');  // 'Hello'
/// capitalize('');       // ''
/// capitalize('A');      // 'A'
/// ```
String capitalize(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}

/// Делает первую букву каждого слова заглавной.
///
/// ```dart
/// capitalizeWords('hello world');  // 'Hello World'
/// ```
String capitalizeWords(String input) {
  return input.split(' ').map(capitalize).join(' ');
}
```

```dart
// lib/src/slug.dart

/// Преобразует строку в URL-slug.
///
/// Заменяет пробелы и спецсимволы на `-`,
/// переводит в нижний регистр.
///
/// ```dart
/// slugify('Hello World!');  // 'hello-world'
/// slugify('Привет Мир');    // 'привет-мир'
/// ```
String slugify(String input, {String separator = '-'}) {
  return input
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .replaceAll(RegExp(r'[\s_]+'), separator);
}
```

```dart
// lib/src/truncate.dart

/// Обрезает строку до [maxLength] символов.
///
/// Если строка длиннее [maxLength], добавляет [ellipsis] в конце.
///
/// ```dart
/// truncate('Hello World', 5);          // 'Hello...'
/// truncate('Hi', 10);                  // 'Hi'
/// truncate('Hello', 3, ellipsis: '…'); // 'Hel…'
/// ```
String truncate(String input, int maxLength, {String ellipsis = '...'}) {
  if (maxLength < 0) throw ArgumentError('maxLength must be non-negative');
  if (input.length <= maxLength) return input;
  return '${input.substring(0, maxLength)}$ellipsis';
}
```

### Doc-комментарии (dartdoc)

```dart
/// Форматирование документации в Dart:
///
/// ## Markdown поддерживается
///
/// Можно использовать **жирный**, *курсив*, `код`.
///
/// ### Ссылки на другие элементы
///
/// Используйте [capitalize] для ссылки на функцию в этом файле.
/// Или [String.isEmpty] для ссылки на stdlib.
///
/// ### Примеры кода
///
/// ```dart
/// final result = myFunction('hello');
/// print(result); // HELLO
/// ```
///
/// ### Списки
///
/// - Элемент 1
/// - Элемент 2
///   - Вложенный
///
/// ### Параметры
///
/// Описывайте параметры в тексте комментария,
/// упоминая их как [paramName].
String myFunction(String input) => input.toUpperCase();
```

### README.md

```markdown
# string_utils

A collection of string utility functions for Dart.

## Features

- `capitalize` — capitalize first letter
- `capitalizeWords` — capitalize each word
- `slugify` — convert to URL slug
- `truncate` — truncate with ellipsis

## Getting started

```yaml
dependencies:
  string_utils: ^1.0.0
```

## Usage

```dart
import 'package:string_utils/string_utils.dart';

// Capitalize
print(capitalize('hello'));       // Hello
print(capitalizeWords('hi all')); // Hi All

// Slugify
print(slugify('Hello World!')); // hello-world

// Truncate
print(truncate('Long text here', 8)); // Long tex...
```

## Additional information

See the [API documentation](https://pub.dev/documentation/string_utils/latest/)
for detailed reference.

File issues on [GitHub](https://github.com/username/string_utils/issues).
```

### CHANGELOG.md

```markdown
## 1.0.0

- Initial release
- Added `capitalize` and `capitalizeWords`
- Added `slugify` with custom separator
- Added `truncate` with custom ellipsis

## 0.2.0

- **Breaking:** Renamed `toSlug` to `slugify`
- Added `separator` parameter to `slugify`
- Improved Unicode handling

## 0.1.0

- Initial beta release
- Basic `capitalize` and `toSlug` functions
```

### analysis_options.yaml

```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml

# Для пакетов на pub.dev рекомендуется:
# include: package:lints/core.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

  exclude:
    - '**.g.dart'
    - '**.freezed.dart'

linter:
  rules:
    - public_member_api_docs  # Требовать doc-комментарии
    - sort_constructors_first
    - prefer_single_quotes
```

### Пример (example/)

```dart
// example/string_utils_example.dart
import 'package:string_utils/string_utils.dart';

void main() {
  // Capitalize
  print(capitalize('hello'));                    // Hello
  print(capitalizeWords('hello world'));          // Hello World

  // Slugify
  print(slugify('Hello World!'));                 // hello-world
  print(slugify('Dart is great', separator: '_')); // dart_is_great

  // Truncate
  print(truncate('Very long text here', 8));     // Very lon...
  print(truncate('Short', 10));                  // Short
}
```

### Генерация API-документации

```bash
# Генерация HTML-документации
dart doc .

# Результат в doc/api/
# Открыть:
# start doc/api/index.html  (Windows)
```

## 4. Минимальный пример

```yaml
# pubspec.yaml
name: my_utils
version: 0.1.0
environment:
  sdk: ^3.0.0
```

```dart
// lib/my_utils.dart
String greet(String name) => 'Привет, $name!';
```

## 5. Практический пример

### Полноценный пакет с тестами и примерами

```dart
// lib/src/result.dart

/// Тип Result для обработки ошибок без исключений.
///
/// Вдохновлён Result из Rust и Either из fp-ts.
///
/// ```dart
/// final result = Result.ok(42);
/// final value = result.when(
///   ok: (v) => 'Got: $v',
///   err: (e) => 'Error: $e',
/// );
/// ```
sealed class Result<T, E> {
  const Result._();

  /// Создаёт успешный результат.
  const factory Result.ok(T value) = Ok<T, E>;

  /// Создаёт ошибочный результат.
  const factory Result.err(E error) = Err<T, E>;

  /// Pattern matching по результату.
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  });

  /// `true` если результат успешный.
  bool get isOk;

  /// `true` если результат ошибочный.
  bool get isErr;
}

/// Успешный результат.
final class Ok<T, E> extends Result<T, E> {
  /// Значение.
  final T value;
  const Ok(this.value) : super._();

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) => ok(value);

  @override
  bool get isOk => true;

  @override
  bool get isErr => false;
}

/// Ошибочный результат.
final class Err<T, E> extends Result<T, E> {
  /// Ошибка.
  final E error;
  const Err(this.error) : super._();

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) => err(error);

  @override
  bool get isOk => false;

  @override
  bool get isErr => true;
}
```

```dart
// test/result_test.dart
import 'package:test/test.dart';
// import 'package:my_package/src/result.dart';

// (Result, Ok, Err определены выше)

void main() {
  group('Result', () {
    test('Ok содержит значение', () {
      const result = Ok<int, String>(42);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.value, 42);
    });

    test('Err содержит ошибку', () {
      const result = Err<int, String>('fail');
      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.error, 'fail');
    });

    test('when вызывает правильный callback', () {
      final ok = Result<int, String>.ok(42);
      final err = Result<int, String>.err('nope');

      expect(ok.when(ok: (v) => v * 2, err: (_) => -1), 84);
      expect(err.when(ok: (v) => v * 2, err: (e) => -1), -1);
    });
  });
}
```

## 6. Что происходит под капотом

```
import 'package:string_utils/string_utils.dart';

1. Dart ищет пакет string_utils:
   → .dart_tool/package_config.json → путь к lib/
   → Может быть: ~/.pub-cache/hosted/pub.dev/string_utils-1.0.0/lib/

2. Загружает lib/string_utils.dart (barrel file)
   → export 'src/capitalize.dart';
   → export 'src/slug.dart';
   → export 'src/truncate.dart';

3. Все экспортированные символы доступны:
   capitalize('hello')  → ищет в capitalize.dart
   slugify('hello')     → ищет в slug.dart

lib/src/ — конвенция приватности:
  ├── lib/my_pkg.dart      ← Публичный (export)
  ├── lib/src/impl.dart    ← Приватный (НЕ export)
  └── import 'package:my_pkg/src/impl.dart' ← Работает технически,
                                               но нарушает конвенцию.
                                               Линтер предупредит!

pubspec.yaml → dart pub get:
  1. Читает dependencies
  2. Разрешает версии (SAT solver)
  3. Скачивает в ~/.pub-cache/
  4. Генерирует .dart_tool/package_config.json
  5. Генерирует pubspec.lock (точные версии)
```

## 7. Производительность и ресурсы

| Аспект | Стоимость |
|--------|-----------|
| `dart pub get` (первый раз) | 2–10 сек (скачивание) |
| `dart pub get` (из кэша) | < 1 сек |
| `dart doc` | 5–30 сек (в зависимости от объёма) |
| Barrel file с 50 exports | Negligible runtime cost |
| Tree shaking (AOT) | Неиспользуемый код удаляется |

**Рекомендации:**
- `pubspec.lock` — коммитьте для applications, не коммитьте для libraries.
- Минимизируйте число зависимостей — каждая увеличивает граф.
- Используйте `show` / `hide` для ограничения импортов.

## 8. Частые ошибки и антипаттерны

### ❌ Импорт из `lib/src/`

```dart
// ❌ Нарушение конвенции — приватная реализация
// import 'package:string_utils/src/internal_helper.dart';

// ✅ Импорт через barrel file
// import 'package:string_utils/string_utils.dart';
```

### ❌ Нет barrel file

```dart
// ❌ Пользователь вынужден знать внутреннюю структуру
// import 'package:my_pkg/src/a.dart';
// import 'package:my_pkg/src/b.dart';
// import 'package:my_pkg/src/c.dart';

// ✅ Один импорт
// import 'package:my_pkg/my_pkg.dart';
```

### ❌ Без описания в pubspec.yaml

```yaml
# ❌ pub.dev понизит score
name: my_pkg
version: 1.0.0

# ✅
name: my_pkg
description: A useful package that does X and Y.
version: 1.0.0
```

### ❌ LICENSE отсутствует

```
# ❌ Без лицензии — юридически пользователи не имеют права использовать код
# Всегда добавляйте LICENSE (BSD-3, MIT, Apache 2.0)
```

## 9. Сравнение с альтернативами

| Экосистема | Файл манифеста | Реестр | Команда |
|-----------|----------------|--------|---------|
| Dart | `pubspec.yaml` | pub.dev | `dart pub` |
| Node.js | `package.json` | npm | `npm` / `yarn` |
| Python | `pyproject.toml` | PyPI | `pip` |
| Rust | `Cargo.toml` | crates.io | `cargo` |
| Go | `go.mod` | proxy.golang.org | `go` |

**Dart отличается:**
- YAML формат (как Rust's TOML, но другой).
- pub scoring — автоматическая оценка качества.
- Единый инструмент `dart pub` для всего: get, publish, outdated.

## 10. Когда НЕ стоит использовать

- **Внутренний код** — если код используется только в одном проекте, пакет избыточен.
- **Слишком мелкий пакет** — одна функция = пакет → «left-pad problem».
- **Секретный код** — pub.dev публичен; для приватных пакетов используйте git-зависимости или приватный pub server.

## 11. Краткое резюме

1. **`pubspec.yaml`** — имя, версия, описание, зависимости.
2. **`lib/`** — публичный API; `lib/src/` — приватная реализация.
3. **Barrel file** — `lib/my_pkg.dart` с `export` — единая точка импорта.
4. **`README.md`** — описание, Getting Started, Usage.
5. **`CHANGELOG.md`** — история версий (важно для pub.dev score).
6. **`example/`** — рабочий пример использования пакета.
7. **`dart doc`** — генерация API-документации из `///` комментариев.
8. **`analysis_options.yaml`** — настройки линтера; `public_member_api_docs` для пакетов.

---

> **Назад:** [12.0 Публикация и управление пакетами — обзор](12_00_overview.md) · **Далее:** [12.2 Публикация на pub.dev](12_02_publishing.md)
