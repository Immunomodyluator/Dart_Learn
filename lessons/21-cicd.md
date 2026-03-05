# Урок 21. CI/CD и развёртывание

> Охватывает подтемы: 21.1 GitHub Actions, 21.2 `dart analyze` в pipeline, 21.3 Docker, 21.4 Авто-публикация пакетов

---

## 1. Формальное определение

CI/CD (Continuous Integration / Continuous Deployment) — автоматизированный pipeline:
- **CI**: при каждом коммите запускаются тесты, линтер, анализ кода
- **CD**: при успешном CI автоматически деплоится или публикуется артефакт

Dart предоставляет:
- `dart analyze` — статический анализ (встроен, бесплатно)
- `dart test` — тесты
- `dart format --output=none --set-exit-if-changed` — проверка форматирования
- `dart compile exe` — сборка в нативный бинарник

---

## 2. GitHub Actions: базовый CI (21.1, 21.2)

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    name: "Dart ${{ matrix.dart-version }} on ${{ matrix.os }}"
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        dart-version: [stable, beta]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Dart
        uses: dart-lang/setup-dart@v1
        with:
          sdk: ${{ matrix.dart-version }}

      - name: Print Dart version
        run: dart --version

      - name: Install dependencies
        run: dart pub get

      # Проверка форматирования
      - name: Check formatting
        run: dart format --output=none --set-exit-if-changed .

      # Статический анализ — максимально строго
      - name: Analyze
        run: dart analyze --fatal-infos --fatal-warnings

      # Запуск тестов с покрытием
      - name: Run tests
        run: dart test --coverage=coverage

      # Генерация отчёта покрытия
      - name: Generate coverage report
        run: |
          dart pub global activate coverage
          dart pub global run coverage:format_coverage \
            --packages=.dart_tool/package_config.json \
            --report-on=lib \
            --lcov \
            -i coverage \
            -o coverage/lcov.info

      # Загрузка покрытия в Codecov
      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: coverage/lcov.info
          fail_ci_if_error: true
```

### Более продвинутый CI с кэшированием

```yaml
# .github/workflows/ci.yml
jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      # Кэш pub зависимостей
      - name: Cache pub dependencies
        uses: actions/cache@v4
        with:
          path: |
            ~/.pub-cache
            .dart_tool
          key: pub-${{ hashFiles('pubspec.lock') }}
          restore-keys: pub-

      - run: dart pub get

      # Кэш build_runner артефактов
      - name: Cache build outputs
        uses: actions/cache@v4
        with:
          path: .dart_tool/build
          key: build-${{ hashFiles('lib/**/*.dart') }}-${{ hashFiles('pubspec.lock') }}
          restore-keys: build-

      # Генерация кода (если нужно)
      - name: Generate code
        run: dart run build_runner build --delete-conflicting-outputs

      - run: dart format --output=none --set-exit-if-changed .
      - run: dart analyze --fatal-infos
      - run: dart test
```

---

## 3. Docker (21.3)

### Многоэтапный Dockerfile для Dart сервера

```dockerfile
# Dockerfile
# Этап 1: сборка нативного бинарника
FROM dart:stable AS builder

WORKDIR /app

# Копируем только pubspec сначала (кэш Docker слоёв)
COPY pubspec.* ./
RUN dart pub get

# Копируем исходный код
COPY . .

# Убеждаемся, что зависимости актуальны
RUN dart pub get --offline

# Компилируем в нативный AOT бинарник
RUN dart compile exe bin/server.dart -o bin/server

# ==============================================
# Этап 2: минимальный runtime образ
FROM scratch AS runtime

# Dart AOT бинарники могут работать на scratch
# (включает системный libc, нужен debian-slim или alpine если dart:io)
FROM debian:bookworm-slim AS runtime

# Только то, что нужно для запуска
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копируем только скомпилированный бинарник
COPY --from=builder /app/bin/server .

# Если есть статические ресурсы
COPY --from=builder /app/web ./web

# Непривилегированный пользователь
RUN useradd --no-create-home --shell /bin/false appuser
USER appuser

EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["./server"]
```

```bash
# Сборка и запуск
docker build -t my-dart-server .
docker run -p 8080:8080 -e PORT=8080 my-dart-server

# Размер образа: ~20-50 MB (против ~800MB для JVM)
docker images my-dart-server
```

### docker-compose для локальной разработки

```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build:
      context: .
      target: builder   # dev режим: JIT, горячая перезагрузка
    volumes:
      - .:/app          # монтируем исходники
    command: dart run --observe bin/server.dart
    ports:
      - "8080:8080"
      - "8181:8181"     # Observatory/DevTools
    environment:
      - PORT=8080
      - DATABASE_URL=postgres://user:pass@db:5432/mydb
    depends_on:
      - db

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: mydb
    volumes:
      - pg_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

volumes:
  pg_data:
```

```dockerfile
# Dockerfile с dev target
FROM dart:stable AS builder
WORKDIR /app
COPY pubspec.* ./
RUN dart pub get
COPY . .
# dev: used by docker-compose (JIT, can hot-reload with restart)
# prod: copies final binary
FROM dart:stable AS dev
WORKDIR /app
COPY --from=builder /app .
EXPOSE 8080 8181

FROM debian:bookworm-slim AS prod
WORKDIR /app
RUN dart pub get
COPY . .
RUN dart compile exe bin/server.dart -o bin/server
EXPOSE 8080
ENTRYPOINT ["./bin/server"]
```

---

## 4. Автоматическая публикация пакетов (21.4)

### Ручная публикация

```yaml
# .github/workflows/publish.yml
name: Publish to pub.dev

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'   # v1.2.3

jobs:
  publish:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Install dependencies
        run: dart pub get

      - name: Run tests
        run: dart test

      - name: Verify publish readiness
        run: dart pub publish --dry-run

      - name: Publish to pub.dev
        uses: dart-lang/pub-dev-action@v2
        with:
          action: publish
          # OIDC публикация (не нужен токен/пароль!)
          # Требует настройки pub.dev: automated-publishing
```

### OIDC-публикация (рекомендуется — без хранения секретов)

```yaml
# .github/workflows/publish.yml
name: Publish

on:
  push:
    tags: ['v*']

permissions:
  id-token: write   # Обязательно для OIDC!
  contents: read

jobs:
  publish:
    runs-on: ubuntu-latest
    environment:
      name: pub.dev      # защищённое окружение для публикации

    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub get
      - run: dart test
      - run: dart pub publish --force   # --force для неинтерактивного режима
```

> **Настройка OIDC на pub.dev**: Account → Automated publishing → Добавить GitHub repository + branch/tag pattern. После этого никаких паролей и токенов хранить не нужно.

---

## 5. Полный релизный pipeline

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  # 1. CI
  test:
    uses: ./.github/workflows/ci.yml    # переиспользуем

  # 2. Сборка бинарников для разных платформ
  build:
    needs: test
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            artifact: my-tool-linux-amd64
            compile_target: bin/cli.dart
          - os: windows-latest
            artifact: my-tool-windows-amd64.exe
            compile_target: bin/cli.dart
          - os: macos-latest
            artifact: my-tool-macos-amd64
            compile_target: bin/cli.dart

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub get
      - name: Build
        run: dart compile exe ${{ matrix.compile_target }} -o ${{ matrix.artifact }}
      - uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact }}
          path: ${{ matrix.artifact }}

  # 3. GitHub Release
  release:
    needs: build
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - uses: actions/download-artifact@v4
        with:
          path: artifacts
          merge-multiple: true

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: artifacts/*
          generate_release_notes: true

  # 4. Публикация на pub.dev
  publish:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
      - run: dart pub get
      - run: dart pub publish --force
```

---

## 6. Качество кода: `analysis_options.yaml`

```yaml
# analysis_options.yaml — максимально строгий режим
include: package:lints/recommended.yaml   # или flutter_lints для Flutter

analyzer:
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false
  errors:
    # Превращаем предупреждения в ошибки
    missing_required_param: error
    missing_return: error
    dead_code: warning
    unused_import: warning
    unused_local_variable: warning

linter:
  rules:
    # Dart style guide
    - always_declare_return_types
    - always_put_required_named_parameters_first
    - avoid_dynamic_calls
    - avoid_print              # используй logger
    - avoid_slow_async_io      # избегай File.readAsStringSync()
    - cancel_subscriptions
    - close_sinks
    - directives_ordering
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_final_locals
    - use_string_buffers
    - unawaited_futures
    # Отключаем слишком строгие
    - always_specify_types: false
```

---

## 7. Под капотом

- **`dart analyze`** — запускает Dart Analysis Server в бессерверном режиме; анализ происходит без JVM, быстро (~1-2s для среднего пакета)
- **`--fatal-infos`** — даже `INFO`-уровень нарушений (suggestion) ломает сборку, очень строго
- **AOT compile в CI** — `dart compile exe` встроен в SDK, не нужны внешние тулчейны
- **OIDC** — GitHub получает temporary credential от pub.dev через OpenID Connect без хранения секретов

---

## 8. Частые ошибки

```yaml
# ❌ Нет кэша зависимостей
- run: dart pub get

# ✅ С кэшем (ускорение на 30-60s)
- uses: actions/cache@v4
  with:
    path: ~/.pub-cache
    key: pub-${{ hashFiles('pubspec.lock') }}
- run: dart pub get

# ❌ Dart version float (ломается при обновлении)
sdk: latest

# ✅ Зафиксировать версию
sdk: stable    # или конкретный: '3.x'

# ❌ Публикация с паролем в CI (секрет, который может утечь)
PUB_CREDENTIALS_FILE: ${{ secrets.PUB_CREDENTIALS }}

# ✅ OIDC (никаких секретов)
permissions:
  id-token: write
```

---

## 9. Краткое резюме

1. **`dart analyze --fatal-infos`** — статический анализ как hard-fail; превращает предупреждения в ошибки сборки
2. **`dart format --set-exit-if-changed`** — проверка стиля без исправления в CI
3. **GitHub Actions matrix** — тестирование на нескольких ОС и версиях SDK
4. **Многоэтапный Dockerfile**: builder (`dart:stable`) → runtime (`debian:slim`), бинарник 20-50 MB
5. **OIDC публикация** — автоматическая публикация без хранения токенов; настраивается на pub.dev
6. **Кэширование** `~/.pub-cache` и `.dart_tool/build` ускоряет CI на 40-70%
7. **`docker-compose`** с `target: builder` — разработка с live-reload; продакшн — AOT нативный бинарник
