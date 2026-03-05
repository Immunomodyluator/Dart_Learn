# 18.1 Настройка CI (GitHub Actions и др.)

## 1. Формальное определение

**CI (Continuous Integration)** — практика автоматической сборки, анализа и тестирования кода при каждом изменении. Для Dart-проектов наиболее популярны GitHub Actions и GitLab CI.

## 2. Зачем это нужно

- **Раннее обнаружение ошибок** — тесты запускаются при каждом push.
- **Единообразие** — гарантировано одинаковое окружение для всех разработчиков.
- **Защита ветки** — PR не мержится, пока пайплайн не зелёный.
- **Документированный процесс** — конфигурация CI = спецификация требований к качеству.

## 3. GitHub Actions

### Базовый workflow

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
          sdk: stable # или '3.4.0' для фиксации версии

      - name: Install dependencies
        run: dart pub get

      - name: Check formatting
        run: dart format --set-exit-if-changed .

      - name: Analyze
        run: dart analyze --fatal-infos

      - name: Run tests
        run: dart test
```

### С покрытием кода

```yaml
- name: Run tests with coverage
  run: dart test --coverage=coverage

- name: Convert coverage to lcov
  run: dart pub global activate coverage &&
    dart pub global run coverage:format_coverage \
    --lcov --in=coverage --out=coverage/lcov.info \
    --report-on=lib

- name: Upload coverage
  uses: codecov/codecov-action@v4
  with:
    files: coverage/lcov.info
```

### Матрица версий

```yaml
strategy:
  matrix:
    sdk: [stable, beta, "3.3.0"]
    os: [ubuntu-latest, windows-latest, macos-latest]
runs-on: ${{ matrix.os }}

steps:
  - uses: actions/checkout@v4
  - uses: dart-lang/setup-dart@v1
    with:
      sdk: ${{ matrix.sdk }}
  - run: dart pub get
  - run: dart test
```

## 4. GitLab CI

```yaml
# .gitlab-ci.yml
image: dart:stable

stages:
  - test

dart_test:
  stage: test
  script:
    - dart pub get
    - dart format --set-exit-if-changed .
    - dart analyze --fatal-infos
    - dart test
  cache:
    paths:
      - .dart_tool/
      - .packages
```

## 5. Кэширование зависимостей

### GitHub Actions

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.pub-cache
    key: ${{ runner.os }}-pub-${{ hashFiles('pubspec.lock') }}
    restore-keys: |
      ${{ runner.os }}-pub-
```

### Результат — ускорение `dart pub get` с ~15-30 с до ~2-5 с.

## 6. Secrets и переменные окружения

```yaml
- name: Publish package
  run: dart pub publish --force
  env:
    PUB_TOKEN: ${{ secrets.PUB_TOKEN }}
```

> **Никогда** не коммитьте токены в репозиторий. Используйте Repository Secrets в настройках GitHub/GitLab.

## 7. Уведомления о поломках

```yaml
- name: Notify on failure
  if: failure()
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: '❌ CI failed. Please check the logs.'
      });
```

## 8. Распространённые ошибки

| Ошибка                                          | Решение                                                 |
| ----------------------------------------------- | ------------------------------------------------------- |
| `dart format` проходит локально, но падает в CI | Убедитесь в одинаковой версии SDK                       |
| Тесты тайм-аутят в CI                           | Увеличьте timeout или оптимизируйте тесты               |
| `pub get` скачивает каждый раз                  | Настройте кэш (раздел 5)                                |
| Секреты недоступны в PR от fork                 | Используйте `pull_request_target` вместо `pull_request` |

---

> **Назад:** [18.0 Обзор](18_00_overview.md) · **Далее:** [18.2 Статический анализ в CI](18_02_static_analysis_ci.md)
