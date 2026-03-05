# 11.4 Покрытие кода и CI-интеграция

## 1. Формальное определение

**Покрытие кода (code coverage)** — метрика, показывающая, какой процент исходного кода исполняется во время тестов. Основные виды:

- **Line coverage** — доля строк, выполненных хотя бы раз.
- **Branch coverage** — доля ветвлений (if/else, switch), через которые прошли тесты.
- **Function coverage** — доля вызванных функций/методов.

**CI (Continuous Integration)** — практика автоматического запуска тестов при каждом коммите/pull request для раннего обнаружения регрессий.

## 2. Зачем это нужно

- **Метрика качества** — видеть, какой код не покрыт тестами.
- **Обнаружение мёртвого кода** — непокрытый код может быть невостребованным.
- **Уверенность при рефакторинге** — высокое покрытие = меньше риска.
- **Автоматизация** — CI ловит ошибки до code review.
- **Стандарты** — минимальный порог покрытия как gate для merge.

## 3. Как это работает

### Сбор покрытия

```bash
# Запуск тестов с покрытием
dart test --coverage=coverage

# Результат: coverage/
#   test/  ← папка с .json файлами покрытия (LCOV-подобный формат)

# Конвертация в LCOV формат (нужен пакет coverage)
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --report-on=lib
```

### Просмотр отчёта

```bash
# Установка lcov (Linux/macOS)
# sudo apt install lcov  (Ubuntu)
# brew install lcov       (macOS)

# Генерация HTML-отчёта
genhtml coverage/lcov.info -o coverage/html

# Открытие в браузере
# open coverage/html/index.html  (macOS)
# start coverage/html/index.html (Windows)
```

### Структура LCOV

```
SF:lib/src/calculator.dart
DA:1,1     ← строка 1 выполнена 1 раз
DA:2,1
DA:3,5     ← строка 3 выполнена 5 раз
DA:5,0     ← строка 5 не выполнена!
LF:4       ← всего 4 строк
LH:3       ← покрыто 3 строки
end_of_record
```

### Пример кода и его покрытие

```dart
// lib/src/validator.dart
class Validator {
  bool isValidEmail(String email) {
    if (email.isEmpty) return false;            // L3: покрыта
    if (!email.contains('@')) return false;      // L4: покрыта
    final parts = email.split('@');             // L5: покрыта
    if (parts.length != 2) return false;        // L6: покрыта
    if (parts[1].isEmpty) return false;         // L7: покрыта
    return true;                                // L8: покрыта
  }

  bool isStrongPassword(String password) {
    if (password.length < 8) return false;      // L11: покрыта
    if (!password.contains(RegExp(r'[A-Z]')))   // L12: НЕ покрыта!
      return false;
    if (!password.contains(RegExp(r'[0-9]')))
      return false;
    return true;
  }
}
```

```dart
// test/validator_test.dart
import 'package:test/test.dart';
// import 'package:my_app/src/validator.dart';

class Validator {
  bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    if (!email.contains('@')) return false;
    final parts = email.split('@');
    if (parts.length != 2) return false;
    if (parts[1].isEmpty) return false;
    return true;
  }

  bool isStrongPassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }
}

void main() {
  final validator = Validator();

  group('isValidEmail', () {
    test('пустая строка → false', () {
      expect(validator.isValidEmail(''), isFalse);
    });

    test('без @ → false', () {
      expect(validator.isValidEmail('noat'), isFalse);
    });

    test('валидный email → true', () {
      expect(validator.isValidEmail('user@mail.com'), isTrue);
    });

    test('@ без домена → false', () {
      expect(validator.isValidEmail('user@'), isFalse);
    });
  });

  // Без тестов для isStrongPassword — покрытие < 100%
  group('isStrongPassword', () {
    test('короткий пароль → false', () {
      expect(validator.isStrongPassword('Ab1'), isFalse);
    });

    test('сильный пароль → true', () {
      expect(validator.isStrongPassword('Abcdef1!'), isTrue);
    });

    test('без заглавных → false', () {
      expect(validator.isStrongPassword('abcdef12'), isFalse);
    });

    test('без цифр → false', () {
      expect(validator.isStrongPassword('Abcdefgh'), isFalse);
    });
  });
}
```

### GitHub Actions CI

```yaml
# .github/workflows/dart.yml
name: Dart CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Install dependencies
        run: dart pub get

      - name: Analyze
        run: dart analyze --fatal-infos

      - name: Format check
        run: dart format --set-exit-if-changed .

      - name: Run tests
        run: dart test

      - name: Run tests with coverage
        run: |
          dart test --coverage=coverage
          dart pub global activate coverage
          dart pub global run coverage:format_coverage \
            --lcov \
            --in=coverage \
            --out=coverage/lcov.info \
            --report-on=lib

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info
```

### GitLab CI

```yaml
# .gitlab-ci.yml
image: dart:stable

stages:
  - analyze
  - test

analyze:
  stage: analyze
  script:
    - dart pub get
    - dart analyze --fatal-infos
    - dart format --set-exit-if-changed .

test:
  stage: test
  script:
    - dart pub get
    - dart test --coverage=coverage
    - dart pub global activate coverage
    - dart pub global run coverage:format_coverage
      --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/lcov.info
  coverage: '/lines\.*: (\d+\.\d+)%/'
```

### Минимальный порог покрытия (coverage gate)

```bash
#!/bin/bash
# scripts/check_coverage.sh

MIN_COVERAGE=80

# Собираем покрытие
dart test --coverage=coverage
dart pub global run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info --report-on=lib

# Считаем процент
TOTAL_LINES=$(grep -c "^DA:" coverage/lcov.info)
HIT_LINES=$(grep "^DA:" coverage/lcov.info | grep -cv ",0$")
COVERAGE=$((HIT_LINES * 100 / TOTAL_LINES))

echo "Coverage: $COVERAGE% ($HIT_LINES / $TOTAL_LINES lines)"

if [ "$COVERAGE" -lt "$MIN_COVERAGE" ]; then
  echo "❌ Coverage $COVERAGE% < minimum $MIN_COVERAGE%"
  exit 1
fi

echo "✅ Coverage $COVERAGE% >= $MIN_COVERAGE%"
```

### Конфигурация dart_test.yaml

```yaml
# dart_test.yaml

# Платформы для запуска
platforms: [vm]

# Таймауты по умолчанию
timeout: 30s

# Теги
tags:
  integration:
    timeout: 2m
  slow:
    skip: true # Пропускать по умолчанию

# Путь к тестам
paths: [test]

# Параллельность
concurrency: 4

# Retry упавших тестов
retry: 1
```

### Полезные команды `dart test`

```bash
# Запуск всех тестов
dart test

# Конкретный файл
dart test test/calculator_test.dart

# Конкретный тест по имени
dart test --name "складывает"

# Только с определённым тегом
dart test --tags integration

# Исключить тег
dart test --exclude-tags slow

# Параллельность
dart test --concurrency=8

# С покрытием
dart test --coverage=coverage

# Verbose вывод
dart test --reporter expanded

# JSON-отчёт (для CI)
dart test --reporter json > test-results.json

# Запуск на конкретной платформе
dart test --platform vm
dart test --platform chrome  # Для web-тестов
```

## 4. Минимальный пример

```bash
# 1. Запустить тесты
dart test

# 2. Собрать покрытие
dart test --coverage=coverage

# 3. Сформировать отчёт
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

## 5. Практический пример

### Полная настройка CI для Dart-проекта

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

env:
  MIN_COVERAGE: 80

jobs:
  # ── Статический анализ ──
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - run: dart pub get
      - run: dart analyze --fatal-infos
      - run: dart format --set-exit-if-changed .

  # ── Unit тесты ──
  unit-tests:
    runs-on: ubuntu-latest
    needs: analyze
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - run: dart pub get

      - name: Run unit tests with coverage
        run: |
          dart test --coverage=coverage --exclude-tags integration
          dart pub global activate coverage
          dart pub global run coverage:format_coverage \
            --lcov --in=coverage --out=coverage/lcov.info --report-on=lib

      - name: Check coverage threshold
        run: |
          TOTAL=$(grep -c "^DA:" coverage/lcov.info || echo 0)
          HIT=$(grep "^DA:" coverage/lcov.info | grep -cv ",0$" || echo 0)
          PCT=$((HIT * 100 / (TOTAL > 0 ? TOTAL : 1)))
          echo "Coverage: $PCT%"
          if [ "$PCT" -lt "$MIN_COVERAGE" ]; then
            echo "::error::Coverage $PCT% < $MIN_COVERAGE%"
            exit 1
          fi

      - uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info

  # ── Интеграционные тесты ──
  integration-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - run: dart pub get
      - run: dart test --tags integration --reporter expanded

  # ── Матрица платформ ──
  cross-platform:
    runs-on: ${{ matrix.os }}
    needs: analyze
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        sdk: [stable, beta]
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: ${{ matrix.sdk }}
      - run: dart pub get
      - run: dart test
```

## 6. Что происходит под капотом

```
dart test --coverage=coverage

1. Компилирует тесты с инструментацией (coverage probes)
2. Запускает код → каждая строка регистрирует hit
3. Записывает hit-map в coverage/ (JSON формат Dart)

coverage:format_coverage --lcov

4. Читает JSON hit-map
5. Маппит на исходные строки через source maps
6. Генерирует LCOV формат:
   SF:lib/src/calculator.dart
   DA:1,1    (строка 1, выполнена 1 раз)
   DA:2,0    (строка 2, не выполнена)
   LF:2      (всего строк)
   LH:1      (покрыто строк)

genhtml / codecov

7. Парсит LCOV → визуальный отчёт (HTML или веб-дашборд)

CI pipeline flow:
  push → trigger → checkout → install → analyze → test → coverage → gate → report
  ❌ Любой шаг упал → pipeline failed → PR не merge-ится
```

## 7. Производительность и ресурсы

| Аспект                     | Стоимость                        |
| -------------------------- | -------------------------------- |
| `dart test` (без coverage) | Базовая скорость                 |
| `dart test --coverage`     | +10–30% времени (инструментация) |
| `format_coverage`          | 1–5 сек (зависит от объёма)      |
| `genhtml`                  | < 1 сек                          |
| CI (GitHub Actions)        | ~1–3 мин для среднего проекта    |

**Рекомендации:**

- Coverage только в CI, не при каждом локальном запуске.
- Используйте `--concurrency` для ускорения.
- Кэшируйте `dart pub get` в CI (`actions/cache`).

## 8. Частые ошибки и антипаттерны

### ❌ Гонка за 100% покрытием

```dart
// ❌ Тест ради покрытия — не проверяет ничего полезного
test('toString', () {
  expect(MyClass().toString(), isNotNull);
});

// ✅ Тестируйте поведение, а не строки кода
// 80–90% покрытия — здоровый уровень
```

### ❌ Нет coverage gate в CI

```yaml
# ❌ Покрытие падает незаметно
# - run: dart test --coverage=coverage
# ...и всё, никто не проверяет процент

# ✅ Установите минимальный порог
# и ломайте pipeline при снижении
```

### ❌ Покрытие = качество

```dart
// ❌ 100% coverage, 0% пользы
test('add works', () {
  add(1, 2); // Вызов без assert!
});

// ✅ Coverage + meaningful assertions
test('add works', () {
  expect(add(1, 2), equals(3));
  expect(add(-1, 1), equals(0));
});

int add(int a, int b) => a + b;
```

### ❌ Не кэшируют зависимости в CI

```yaml
# ❌ dart pub get каждый раз скачивает всё заново (30+ сек)

# ✅ Добавьте кэш
# - uses: actions/cache@v4
#   with:
#     path: ~/.pub-cache
#     key: ${{ runner.os }}-pub-${{ hashFiles('pubspec.lock') }}
```

## 9. Сравнение с альтернативами

| Инструмент покрытия    | Язык   | Формат      | Особенности         |
| ---------------------- | ------ | ----------- | ------------------- |
| `dart test --coverage` | Dart   | JSON → LCOV | Встроен в SDK       |
| JaCoCo                 | Java   | XML/HTML    | Интеграция с Gradle |
| Istanbul/nyc           | JS     | LCOV/JSON   | Встроен в Jest      |
| coverage.py            | Python | XML/HTML    | Via pytest-cov      |
| gcov/lcov              | C/C++  | LCOV        | Нативный            |

| CI-платформа   | Бесплатно для OSS | Dart-поддержка         |
| -------------- | ----------------- | ---------------------- |
| GitHub Actions | Да                | `dart-lang/setup-dart` |
| GitLab CI      | Да                | Docker `dart:stable`   |
| Codemagic      | Да (Flutter)      | Нативная               |
| CircleCI       | Да (limited)      | Docker images          |

## 10. Когда НЕ стоит использовать

- **Прототипы** — покрытие тормозит быструю итерацию.
- **Скрипты** — одноразовый код не требует CI pipeline.
- **100% как цель** — гонка за цифрой ведёт к бесполезным тестам.
- **Сгенерированный код** — исключите `*.g.dart`, `*.freezed.dart` из coverage.

## 11. Краткое резюме

1. **`dart test --coverage=coverage`** — собирает данные покрытия при запуске тестов.
2. **`coverage:format_coverage`** — конвертирует в LCOV формат.
3. **Порог** — 80–90% line coverage — здоровый уровень.
4. **CI** — `dart analyze` → `dart format` → `dart test` → coverage gate.
5. **GitHub Actions** — `dart-lang/setup-dart` + `codecov/codecov-action`.
6. **Кэш** — `actions/cache` для `~/.pub-cache` ускоряет pipeline.
7. **Теги** — `--tags integration` для раздельного запуска уровней тестов.
8. **Покрытие ≠ качество** — важны meaningful assertions, а не % строк.

---

> **Назад:** [11.3 Интеграционные и E2E тесты](11_03_integration_tests.md) · **Далее:** [12.0 Публикация и управление пакетами — обзор](../12_packages/12_00_overview.md)
