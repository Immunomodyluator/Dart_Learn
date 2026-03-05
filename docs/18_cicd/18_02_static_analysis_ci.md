# 18.2 Статический анализ и правила качества в CI

## 1. Формальное определение

**Статический анализ** — проверка исходного кода без его выполнения. Dart-анализатор выявляет ошибки типов, неиспользуемые импорты, потенциальные null-проблемы и нарушения стиля. Включение анализа в CI гарантирует, что код проходит все проверки до мержа.

## 2. Зачем это нужно

- **Единый стандарт кода** — все разработчики следуют одним правилам.
- **Автоматический гейт** — PR не проходит, пока есть предупреждения.
- **Раннее обнаружение** — типовые ошибки ловятся без запуска.
- **Измеримое качество** — количество предупреждений = метрика здоровья проекта.

## 3. Настройка analysis_options.yaml

```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml
# Или строже:
# include: package:lints/core.yaml

analyzer:
  language:
    strict-casts: true # Запрет неявных приведений
    strict-inference: true # Требовать явные типы без контекста
    strict-raw-types: true # Запрет сырых дженериков
  errors:
    missing_return: error # Повышение до ошибки
    unused_import: warning
    dead_code: warning
  exclude:
    - "**.g.dart" # Сгенерированный код
    - "**.freezed.dart"
    - "build/**"

linter:
  rules:
    - prefer_final_locals
    - avoid_print
    - always_declare_return_types
    - unawaited_futures
    - prefer_const_constructors
    - sort_constructors_first
```

## 4. Пакеты линтов

| Пакет                    | Строгость | Назначение                              |
| ------------------------ | --------- | --------------------------------------- |
| `lints/core.yaml`        | Базовая   | Минимальные правила от Dart-команды     |
| `lints/recommended.yaml` | Средняя   | Рекомендуемые правила для всех проектов |
| `flutter_lints`          | Средняя   | Правила для Flutter-проектов            |
| `very_good_analysis`     | Высокая   | Строгие правила (VGV)                   |
| `pedantic`               | Высокая   | Deprecated, но часто встречается        |

```yaml
# pubspec.yaml
dev_dependencies:
  lints: ^4.0.0
  # или
  very_good_analysis: ^6.0.0
```

## 5. Команды анализа в CI

```yaml
# Базовый анализ (предупреждения не фатальны)
- run: dart analyze

# Строгий режим — даже infos ломают билд
- run: dart analyze --fatal-infos

# Проверка форматирования (не изменяет файлы, а выдаёт ошибку)
- run: dart format --set-exit-if-changed .

# Custom Lint Rules с package:custom_lint
- run: dart run custom_lint
```

### Полный шаг проверки качества

```yaml
- name: Quality Gate
  run: |
    echo "=== Formatting ==="
    dart format --set-exit-if-changed .

    echo "=== Analysis ==="
    dart analyze --fatal-infos

    echo "=== Tests ==="
    dart test --reporter=github
```

## 6. Custom Lint Rules

```yaml
# pubspec.yaml
dev_dependencies:
  custom_lint: ^0.6.0
  my_custom_lints:
    path: packages/my_custom_lints
```

```dart
// packages/my_custom_lints/lib/my_custom_lints.dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _MyLints();

class _MyLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    _AvoidMagicNumbers(),
  ];
}

class _AvoidMagicNumbers extends DartLintRule {
  _AvoidMagicNumbers() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_magic_numbers',
    problemMessage: 'Avoid magic numbers. Extract into a named constant.',
    correctionMessage: 'Create a const variable.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIntegerLiteral((node) {
      final value = node.value;
      if (value != null && value != 0 && value != 1 && value != -1) {
        reporter.atNode(node, code);
      }
    });
  }
}
```

## 7. Отчёты в PR

### GitHub Actions — встроенный reporter

```yaml
- run: dart analyze --format=github
  # Показывает аннотации прямо в PR diff
```

### Пример аннотации в PR

```
⚠ lib/src/api.dart:42:5 - avoid_print - Avoid using `print()`.
```

## 8. Метрики кода (DCM)

[Dart Code Metrics](https://dcm.dev/) — инструмент для измерения сложности:

```yaml
dev_dependencies:
  dart_code_metrics: ^5.0.0
```

```bash
dart run dart_code_metrics:metrics analyze lib
dart run dart_code_metrics:metrics check-unused-files lib
dart run dart_code_metrics:metrics check-unused-code lib
```

Метрики: цикломатическая сложность, вложенность, количество параметров, длина функции.

## 9. Распространённые ошибки

| Ошибка                                            | Решение                                                     |
| ------------------------------------------------- | ----------------------------------------------------------- |
| `--fatal-infos` слишком строг для старого проекта | Начните с `--fatal-warnings`, постепенно ужесточайте        |
| Сгенерированный код вызывает предупреждения       | Добавьте `**.g.dart` в `exclude:`                           |
| Правила конфликтуют                               | Явно отключите конфликтующие: `prefer_double_quotes: false` |
| `dart format` и IDE форматирование различаются    | Используйте одинаковую версию SDK                           |

---

> **Назад:** [18.1 Настройка CI](18_01_ci_setup.md) · **Далее:** [18.3 Контейнеризация и деплой](18_03_containerization.md)
