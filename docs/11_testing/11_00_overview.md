# 11. Тестирование — обзор

## О чём этот раздел

Тестирование в Dart — это не опциональная роскошь, а встроенная в экосистему практика.
SDK поставляется с пакетом `test`, а `dart test` работает «из коробки».

## Уровни тестирования

```
┌──────────────────────────────────────────────────────┐
│                    E2E / Integration                 │  Медленные,
│               (всё приложение целиком)               │  хрупкие,
├──────────────────────────────────────────────────────┤  но реалистичные
│              Integration tests                       │
│         (несколько компонентов вместе)                │
├──────────────────────────────────────────────────────┤
│                  Unit tests                          │  Быстрые,
│          (одна функция / класс)                      │  стабильные,
└──────────────────────────────────────────────────────┘  изолированные
```

| Уровень     | Скорость  | Изоляция  | Хрупкость | Инструмент                            |
| ----------- | --------- | --------- | --------- | ------------------------------------- |
| Unit        | ⚡ мс     | Полная    | Низкая    | `package:test`                        |
| Integration | ⏱ секунды | Частичная | Средняя   | `package:test` + реальные зависимости |
| E2E         | 🐢 минуты | Нет       | Высокая   | `package:integration_test` (Flutter)  |

## Структура проекта с тестами

```
my_project/
├── lib/
│   ├── src/
│   │   ├── calculator.dart
│   │   └── user_service.dart
│   └── my_project.dart
├── test/
│   ├── calculator_test.dart       ← unit-тест
│   ├── user_service_test.dart     ← unit-тест с mock
│   └── integration/
│       └── api_test.dart          ← интеграционный
├── pubspec.yaml
└── analysis_options.yaml
```

## Минимальный пример

```yaml
# pubspec.yaml
dev_dependencies:
  test: ^1.25.0
```

```dart
// lib/src/calculator.dart
int add(int a, int b) => a + b;

// test/calculator_test.dart
import 'package:test/test.dart';
import 'package:my_project/src/calculator.dart';

void main() {
  test('add складывает два числа', () {
    expect(add(2, 3), equals(5));
  });
}
```

```bash
dart test
# ✅ All tests passed!
```

## Ключевые пакеты

| Пакет                      | Назначение                            |
| -------------------------- | ------------------------------------- |
| `test`                     | Фреймворк для unit/integration тестов |
| `mockito` + `build_runner` | Генерация mock-объектов               |
| `fake_async`               | Контроль таймеров и Future в тестах   |
| `coverage`                 | Сбор данных покрытия                  |
| `test_process`             | Тестирование CLI-процессов            |

## Содержание раздела

| Подраздел                                                     | Тема                                           |
| ------------------------------------------------------------- | ---------------------------------------------- |
| [11.1 Unit-тесты](11_01_unit_tests.md)                        | Структура тестов, матчеры, группы, async-тесты |
| [11.2 Mocking и stubbing](11_02_mocking.md)                   | mockito, ручные fake, stubbing зависимостей    |
| [11.3 Интеграционные и E2E тесты](11_03_integration_tests.md) | Тестирование взаимодействия компонентов        |
| [11.4 Покрытие кода и CI](11_04_coverage_ci.md)               | coverage, CI-pipeline, best practices          |

---

> **Назад:** [10.4 Логирование и мониторинг ошибок](../10_error_handling/10_04_logging.md) · **Далее:** [11.1 Unit-тесты с пакетом test](11_01_unit_tests.md)
