# 1.4 Форматирование, анализ и линтеры

## 1. Формальное определение

**dart format** — встроенный автоформатёр, приводящий код к единому стилю. Реализует официальный Dart Style Guide, не допуская вариативности форматирования.

**dart analyze** — статический анализатор, выполняющий проверку типов, обнаружение ошибок, предупреждений и стилевых замечаний без запуска программы.

**Линтеры** — набор правил (lints), хранящихся в `analysis_options.yaml`, расширяющих базовый анализ дополнительными проверками.

**Уровень:** инфраструктура / качество кода.

## 2. Зачем это нужно

- **Единый стиль** — `dart format` устраняет споры о форматировании в команде. Нет конфигурации — нет дискуссий.
- **Раннее обнаружение ошибок** — анализатор находит type mismatches, null safety нарушения, unreachable code — до запуска.
- **Стандарты команды** — линтер-правила кодифицируют соглашения: «не используй `print()` в prod», «всегда указывай тип возвращаемого значения».
- **CI gate** — `dart analyze --fatal-warnings` и `dart format --set-exit-if-changed` блокируют merge при нарушениях.

## 3. Как это работает

### dart format

```bash
# Форматировать все .dart файлы рекурсивно
dart format .

# Проверить без изменений (для CI)
dart format --set-exit-if-changed .

# Указать ширину строки (по умолчанию 80)
dart format --line-length=120 .

# Форматировать конкретный файл
dart format lib/src/parser.dart

# Показать diff вместо перезаписи
dart format --output=show .
```

Формаратёр Dart — **неконфигурируемый** (в отличие от Prettier). Единственный параметр — `--line-length`. Это сделано намеренно: один стиль для всей экосистемы.

### analysis_options.yaml

```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml # Базовый набор правил

analyzer:
  # Повышение severity
  errors:
    missing_return: error # warning → error
    unused_local_variable: warning # info → warning
    todo: ignore # подавить TODO-предупреждения

  # Исключения из анализа
  exclude:
    - "**.g.dart" # Сгенерированные файлы
    - "**.freezed.dart" # Сгенерированные Freezed-файлы
    - "build/**" # Каталог сборки

  # Языковые настройки
  language:
    strict-casts: true # Запрет implicit downcast
    strict-inference: true # Требовать explicit типы при неоднозначности
    strict-raw-types: true # Запрет raw generic types

linter:
  rules:
    # Включить дополнительные правила
    - always_declare_return_types
    - avoid_print # Запретить print() — используй логгер
    - prefer_single_quotes
    - sort_constructors_first
    - unawaited_futures # Предупреждать о не-awaited Future
    - cancel_subscriptions # Предупреждать об утечке StreamSubscription


    # Отключить правило из included набора
    # prefer_final_locals: false     # (раскомментировать при необходимости)
```

### Пакеты правил

| Пакет                                | Назначение                                    | Строгость |
| ------------------------------------ | --------------------------------------------- | --------- |
| `package:lints/core.yaml`            | Минимальный набор от Dart-команды             | Низкая    |
| `package:lints/recommended.yaml`     | Рекомендуемый набор (default в `dart create`) | Средняя   |
| `package:flutter_lints/flutter.yaml` | Для Flutter-проектов                          | Средняя   |
| `package:very_good_analysis`         | От VGV (Very Good Ventures)                   | Высокая   |
| `package:pedantic`                   | Устаревший (заменён на `lints`)               | —         |

```yaml
# Для максимальной строгости (Flutter-проект):
include: package:very_good_analysis/analysis_options.yaml
```

### dart analyze

```bash
# Анализ проекта
dart analyze
# Analyzing my_app...
# info - lib/src/utils.dart:12:3 - Avoid print calls - avoid_print
# warning - lib/src/parser.dart:45:10 - Unused variable 'temp' - unused_local_variable
# error - lib/src/model.dart:8:5 - Missing return - missing_return
# 3 issues found (1 error, 1 warning, 1 info)

# CI-режим: fail на любой warning
dart analyze --fatal-warnings

# CI-режим: fail на info тоже
dart analyze --fatal-infos
```

### dart fix

```bash
# Показать доступные автоисправления
dart fix --dry-run

# Применить все исправления
dart fix --apply
# Fixed 12 issues in 5 files.
```

`dart fix` применяет «quick fixes» — автоматические трансформации кода для устранения lint-предупреждений и миграции deprecated API.

## 4. Минимальный пример

До форматирования:

```dart
void main(){var x=42;if(x>0){print('positive: $x');}else{print('non-positive');}}
```

После `dart format`:

```dart
void main() {
  var x = 42;
  if (x > 0) {
    print('positive: $x');
  } else {
    print('non-positive');
  }
}
```

Форматёр автоматически расставляет отступы, пробелы, переносы строк.

## 5. Практический пример

### Настройка проекта с полным анализом

```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    missing_return: error
    unused_import: warning
    todo: ignore
  exclude:
    - "**.g.dart"
    - "**.freezed.dart"

linter:
  rules:
    - always_declare_return_types
    - annotate_overrides
    - avoid_print
    - cancel_subscriptions
    - close_sinks
    - prefer_single_quotes
    - unawaited_futures
```

```dart
// lib/src/user_service.dart
import 'dart:developer' as developer;

class UserService {
  final List<String> _users = [];

  // ✅ Тип возвращаемого значения указан (always_declare_return_types)
  // ✅ Одинарные кавычки (prefer_single_quotes)
  void addUser(String name) {
    _users.add(name);
    // ✅ Используется developer.log вместо print (avoid_print)
    developer.log('User added: $name', name: 'UserService');
  }

  List<String> getUsers() => List.unmodifiable(_users);
}
```

```bash
# CI-скрипт
dart format --set-exit-if-changed .    # Формат: fail если не отформатировано
dart analyze --fatal-warnings          # Анализ: fail на warnings
dart test                              # Тесты
```

**Архитектурная корректность:** `analysis_options.yaml` хранится в корне проекта и коммитится в VCS. Все разработчики и CI используют одни правила — нет расхождений.

## 6. Что происходит под капотом

### dart format

```
Исходный код (.dart)
       │
       ▼
┌──────────────┐
│   Lexer      │  ← Токенизация (без парсинга AST)
├──────────────┤
│   Parser     │  ← Построение CST (Concrete Syntax Tree)
├──────────────┤
│   Formatter  │  ← Алгоритм «best-effort line splitting»
│   Engine     │     Жадная стратегия с backtracking
├──────────────┤
│   Output     │  ← Перезапись файла
└──────────────┘
```

Форматёр работает на уровне **CST** (конкретное синтаксическое дерево), а не AST (абстрактное). Это значит, что он сохраняет комментарии и пробелы между токенами, не теряя информацию.

Алгоритм разбиения строк:

1. Попытаться уместить выражение в одну строку.
2. Если не влезает в `line-length` — разбить по «точкам разделения» (аргументы, операторы, `=>`) нажадного алгоритма.
3. Trailing comma в конце списка аргументов **форсирует** многострочное форматирование.

### dart analyze

```
Исходный код (.dart)
       │
       ▼
┌──────────────────┐
│  CFE (Parser)    │  ← Парсинг → Kernel IR
├──────────────────┤
│  Type Inference  │  ← Вывод типов, проверка sound null safety
├──────────────────┤
│  Error Reporter  │  ← Ошибки компиляции (errors)
├──────────────────┤
│  Lint Engine     │  ← Применение правил из analysis_options.yaml
│  (AST Visitor)   │     Каждый lint — visitor, обходящий AST
├──────────────────┤
│  Diagnostics     │  ← Отчет: errors, warnings, infos
└──────────────────┘
```

Анализатор работает **инкрементально** — при изменении одного файла пересчитывает только затронутые части. В IDE (VS Code/IntelliJ) анализ запускается непрерывно в фоне через **Analysis Server** — отдельный long-running процесс.

## 7. Производительность и ресурсы

| Операция                         | Скорость  | RAM        |
| -------------------------------- | --------- | ---------- |
| `dart format` (1 файл)           | < 10 мс   | ~20 MB     |
| `dart format .` (1000 файлов)    | 1–3 сек   | ~50 MB     |
| `dart analyze` (холодный старт)  | 3–10 сек  | ~200 MB    |
| `dart analyze` (инкрементальный) | < 1 сек   | —          |
| Analysis Server (фоновый, IDE)   | постоянно | 150–500 MB |

**Нюансы:**

- Analysis Server в IDE потребляет значительную память (150–500 MB). Для слабых машин — отключите анализ в неиспользуемых workspace.
- `dart format` работает параллельно на нескольких ядрах, скорость масштабируется.
- Для mono-repo с 10000+ файлов используйте `dart analyze lib/` (анализ подмножества).

## 8. Частые ошибки и антипаттерны

### ❌ Trailing comma забыт

```dart
// Без trailing comma — однострочное форматирование:
Widget build(BuildContext context) {
  return Container(padding: EdgeInsets.all(8), child: Text('Hello'));
}

// С trailing comma — многострочное (читабельнее):
Widget build(BuildContext context) {
  return Container(
    padding: EdgeInsets.all(8),
    child: Text('Hello'),  // ← trailing comma
  );
}
```

### ❌ Подавление всех warning через ignore

```dart
// Плохо: замолчать все предупреждения
// ignore_for_file: type=lint

// Хорошо: подавить конкретный lint с обоснованием
// ignore: avoid_print — debug output, удалить перед prod
print(debugInfo);
```

### ❌ Не исключить сгенерированные файлы

```yaml
# Без этого анализатор засыпет ошибками из .g.dart файлов
analyzer:
  exclude:
    - "**.g.dart"
    - "**.freezed.dart"
```

### ❌ Конфликт IDE-форматёра и dart format

Если в VS Code включен и **Prettier**, и **Dart** для `.dart` файлов — результаты конфликтуют. Убедитесь:

```json
{
  "[dart]": {
    "editor.defaultFormatter": "Dart-Code.dart-code"
  }
}
```

## 9. Сравнение с альтернативами

| Критерий               | dart format/analyze     | ESLint + Prettier (JS/TS) | ktlint (Kotlin) | gofmt + go vet   |
| ---------------------- | ----------------------- | ------------------------- | --------------- | ---------------- |
| Конфигурация форматёра | ❌ (только line-length) | ✅ (десятки опций)        | ✅ (умеренно)   | ❌               |
| Встроен в SDK          | ✅                      | ❌                        | ❌              | ✅               |
| Автофикс               | ✅ (`dart fix`)         | ✅ (`eslint --fix`)       | ✅              | ❌               |
| Скорость анализатора   | Быстро                  | Средне                    | Быстро          | Быстро           |
| Custom rules           | ✅ (через пакеты)       | ✅ (плагины)              | ✅ (ruleset)    | ✅ (go/analysis) |

**Философия Dart** совпадает с Go: один неконфигурируемый форматёр = нулевые дискуссии о стиле. В отличие от экосистемы JS/TS, где Prettier имеет десятки опций и каждый проект форматирует по-своему.

## 10. Когда НЕ стоит использовать

- **Не отключайте `dart format`** для «особого форматирования» — если форматёр ломает визуальную структуру, скорее всего, код слишком сложен и нуждается в рефакторинге.
- **Не создавайте свои lint-правила** для тривиальных стилистических предпочтений — используйте существующие пакеты (`lints`, `very_good_analysis`).
- **Не используйте `strict-casts: true`** в начале миграции на null safety — это добавит сотни ошибок в legacy-код. Включайте постепенно.

## 11. Краткое резюме

1. **`dart format`** — безальтернативный форматёр. Одна конфигурация — нулевые споры. Trailing comma управляет многострочностью.
2. **`dart analyze`** — статический анализатор с инкрементальным режимом. Работает через Analysis Server в IDE.
3. **`analysis_options.yaml`** — един для проекта, коммитится в VCS. `include: package:lints/recommended.yaml` — минимальный стандарт.
4. **`strict-casts`, `strict-inference`, `strict-raw-types`** — три флага для максимальной типобезопасности.
5. **`dart fix --apply`** — автоматическое исправление lint-нарушений и deprecated API.
6. **В CI:** `dart format --set-exit-if-changed . && dart analyze --fatal-warnings` — обязательный gate.
7. **Исключайте `**.g.dart`\*\* из анализа — сгенерированный код не должен проверяться лишними правилами.

---

> **Назад:** [Обзор раздела](01_00_overview.md) · **Далее:** [2. Основы синтаксиса](../02_syntax_basics/02_00_overview.md)
