# 1.3 pub и pubspec.yaml

## 1. Формальное определение

**pub** — встроенный менеджер пакетов Dart, интегрированный в CLI как `dart pub`. Управляет зависимостями проекта, версионированием, скачиванием и кэшированием пакетов.

**pubspec.yaml** — манифест проекта в формате YAML. Определяет имя пакета, версию, зависимости, ограничения SDK и метаданные для публикации. Аналог `package.json` (Node.js), `Cargo.toml` (Rust), `build.gradle` (Java).

**Уровень:** инфраструктура / управление зависимостями.

## 2. Зачем это нужно

- **Повторное использование кода** — тысячи готовых пакетов на pub.dev (HTTP-клиенты, JSON-сериализация, утилиты).
- **Воспроизводимость сборок** — `pubspec.lock` фиксирует точные версии всех зависимостей.
- **Разделение dev/prod зависимостей** — пакеты для тестирования и генерации кода не попадают в продакшн.
- **Разрешение конфликтов** — pub автоматически находит совместимые версии при пересечении ограничений.

## 3. Как это работает

### Структура pubspec.yaml

```yaml
name: my_app # Имя пакета (snake_case)
description: Серверное приложение # Описание
version: 1.0.0 # SemVer-версия
publish_to: none # 'none' = не публиковать на pub.dev

environment:
  sdk: ^3.0.0 # Ограничение версии SDK

dependencies: # Продакшн-зависимости
  http: ^1.1.0
  path: ^1.8.0
  args: ^2.4.0

dev_dependencies: # Зависимости для разработки
  test: ^1.24.0
  lints: ^3.0.0
  mockito: ^5.4.0
  build_runner: ^2.4.0

dependency_overrides: # Принудительная версия (обход конфликтов)
  collection: 1.18.0
```

### Синтаксис версий

```yaml
dependencies:
  # Точная версия
  http: 1.1.0

  # Каретка (совместимые обновления — наиболее частый вариант)
  http: ^1.1.0          # >=1.1.0 <2.0.0

  # Диапазон
  http: '>=1.0.0 <2.0.0'

  # Любая версия (антипаттерн!)
  http: any

  # Git-зависимость
  my_utils:
    git:
      url: https://github.com/user/my_utils.git
      ref: main                    # ветка, тег или коммит

  # Локальный путь (для mono-repo)
  shared_models:
    path: ../shared_models

  # Hosted (нестандартный реестр)
  private_pkg:
    hosted: https://my-registry.example.com
    version: ^1.0.0
```

### Основные команды

```bash
# Получить зависимости (создаёт/обновляет pubspec.lock)
dart pub get

# Добавить зависимость
dart pub add http
dart pub add --dev test

# Удалить зависимость
dart pub remove http

# Обновить зависимости до последних совместимых версий
dart pub upgrade

# Принудительное обновление major-версий
dart pub upgrade --major-versions

# Показать устаревшие пакеты
dart pub outdated

# Показать дерево зависимостей
dart pub deps

# Проверить перед публикацией
dart pub publish --dry-run
```

## 4. Минимальный пример

```yaml
# pubspec.yaml
name: hello_pub
environment:
  sdk: ^3.0.0

dependencies:
  path: ^1.8.0
```

```dart
// bin/hello_pub.dart
import 'package:path/path.dart' as p;

void main() {
  final fullPath = p.join('home', 'user', 'documents', 'file.txt');
  print(fullPath); // home/user/documents/file.txt (Unix)
                   // home\user\documents\file.txt (Windows)
}
```

```bash
dart pub get    # скачать пакет path
dart run        # запустить
```

## 5. Практический пример

### HTTP-клиент с конфигурацией зависимостей

```yaml
# pubspec.yaml
name: weather_cli
version: 0.1.0
description: CLI для получения погоды
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  http: ^1.1.0 # HTTP-запросы
  args: ^2.4.0 # Парсинг CLI-аргументов
  json_annotation: ^4.8.0 # Аннотации для JSON

dev_dependencies:
  test: ^1.24.0
  lints: ^3.0.0
  json_serializable: ^6.7.0 # Генератор JSON-кода
  build_runner: ^2.4.0 # Запуск генерации
```

```dart
// bin/weather_cli.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:args/args.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('city', abbr: 'c', mandatory: true);

  final results = parser.parse(arguments);
  final city = results['city'] as String;

  // Пример: запрос к API (URL условный)
  final uri = Uri.https('api.example.com', '/weather', {'q': city});
  final response = await http.get(uri);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    print('Погода в $city: ${data["temp"]}°C');
  } else {
    print('Ошибка: ${response.statusCode}');
  }
}
```

**Архитектурная корректность:**

- `http` — в `dependencies`, так как используется в runtime.
- `json_serializable` и `build_runner` — в `dev_dependencies`, так как нужны только при генерации кода.
- `lints` — в `dev_dependencies`, так как нужен только для анализатора.
- `publish_to: none` — приложение, не библиотека, публикация не нужна.

## 6. Что происходит под капотом

### Как работает `dart pub get`

```
dart pub get
     │
     ▼
┌──────────────────────┐
│ Чтение pubspec.yaml  │
├──────────────────────┤
│ Запрос версий с       │  ← HTTP-запрос к pub.dev API
│ pub.dev / hosted      │
├──────────────────────┤
│ Version solving       │  ← Алгоритм DPLL (SAT-solver)
│ (разрешение версий)   │     находит совместимый набор
├──────────────────────┤
│ Скачивание и кэш      │  ← ~/.pub-cache/ (Linux/macOS)
│                       │     %LOCALAPPDATA%\Pub\Cache (Win)
├──────────────────────┤
│ Генерация             │
│ pubspec.lock           │  ← Зафиксированные версии
│ .dart_tool/            │  ← Внутренние метаданные
│ package_config.json    │  ← Маппинг пакетов → пути
└──────────────────────┘
```

### Кэш пакетов

pub хранит скачанные пакеты в глобальном кэше:

- **Linux/macOS:** `~/.pub-cache/hosted/pub.dev/`
- **Windows:** `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\`

Каждая версия пакета хранится отдельно. Проекты используют symlink/ссылки на кэш через `package_config.json`.

### package_config.json

Автогенерируемый файл в `.dart_tool/`:

```json
{
  "configVersion": 2,
  "packages": [
    {
      "name": "http",
      "rootUri": "file:///Users/dev/.pub-cache/hosted/pub.dev/http-1.1.0",
      "packageUri": "lib/",
      "languageVersion": "3.0"
    }
  ]
}
```

Dart VM читает этот файл, чтобы резолвить `import 'package:http/http.dart'`.

## 7. Производительность и ресурсы

| Операция                         | Время    | Примечание                           |
| -------------------------------- | -------- | ------------------------------------ |
| `dart pub get` (холодный)        | 2–15 сек | Зависит от количества пакетов и сети |
| `dart pub get` (тёплый, из кэша) | < 1 сек  | Всё уже скачано                      |
| `dart pub upgrade`               | 3–20 сек | Проверяет все версии на pub.dev      |
| `dart pub outdated`              | 2–5 сек  | Запрашивает latest-версии            |
| Version solving (10 deps)        | < 100 мс | SAT-solver обычно быстр              |
| Version solving (100+ deps)      | 1–5 сек  | Может быть экспоненциально сложным   |

**Оптимизации:**

- Используйте `--offline` для работы без сети (только из кэша).
- `PUB_CACHE` — переменная окружения для перемещения кэша (полезно для Docker/CI).
- В CI кэшируйте `~/.pub-cache` между сборками для ускорения.

## 8. Частые ошибки и антипаттерны

### ❌ Не коммитить pubspec.lock для приложений

```
# .gitignore — НЕПРАВИЛЬНО для приложений:
pubspec.lock

# Правило:
# Приложения: коммитить pubspec.lock (воспроизводимость)
# Библиотеки: НЕ коммитить pubspec.lock (гибкость для потребителей)
```

### ❌ Использование `any` версий

```yaml
# Плохо:
dependencies:
  http: any

# Хорошо:
dependencies:
  http: ^1.1.0
```

### ❌ dependency_overrides в продакшн-коде

```yaml
# Только для временной отладки! Убирать перед коммитом.
dependency_overrides:
  broken_package: 1.2.3
```

`dependency_overrides` обходит version solving и может привести к несовместимости.

### ❌ Dev-зависимости в dependencies

```yaml
# Плохо: build_runner нужен только при разработке
dependencies:
  build_runner: ^2.4.0

# Хорошо:
dev_dependencies:
  build_runner: ^2.4.0
```

### ❌ Слишком строгие ограничения версий

```yaml
# Плохо: блокирует обновления
dependencies:
  http: 1.1.0     # только эта версия

# Хорошо: совместимые обновления
dependencies:
  http: ^1.1.0    # >=1.1.0 <2.0.0
```

## 9. Сравнение с альтернативами

| Критерий        | dart pub       | npm (Node.js)       | cargo (Rust) | go mod (Go)      |
| --------------- | -------------- | ------------------- | ------------ | ---------------- |
| Манифест        | `pubspec.yaml` | `package.json`      | `Cargo.toml` | `go.mod`         |
| Lock-файл       | `pubspec.lock` | `package-lock.json` | `Cargo.lock` | `go.sum`         |
| Реестр          | pub.dev        | npmjs.com           | crates.io    | proxy.golang.org |
| Глобальный кэш  | ✅             | ❌ (node_modules/)  | ✅           | ✅               |
| Workspaces      | ❌ (path deps) | ✅                  | ✅           | ✅               |
| Version solving | SAT-solver     | Простой алгоритм    | SAT-solver   | MVS              |
| Скорость        | Быстро         | Средне              | Быстро       | Быстро           |

**Ключевое отличие:** pub использует глобальный кэш (как cargo), а не копирует пакеты в каждый проект (как npm с `node_modules/`). Это экономит место на диске.

## 10. Когда НЕ стоит использовать

- **`dart pub global activate`** для продакшн-инструментов — глобальные пакеты привязаны к одной версии. Для CI используйте `dart pub get` в проекте.
- **Git-зависимости для стабильных пакетов** — если пакет есть на pub.dev, используйте pub.dev. Git-зависимости не гарантируют стабильность.
- **`dart pub upgrade --major-versions`** без проверки — major-обновления могут сломать API. Делайте это осознанно.

## 11. Краткое резюме

1. **`pubspec.yaml`** — единый манифест проекта. Имя, версия, SDK-ограничения, зависимости — всё здесь.
2. **Каретка `^`** — предпочтительный синтаксис версии: `^1.2.0` = `>=1.2.0 <2.0.0`.
3. **`pubspec.lock` коммитить для приложений**, не коммитить для библиотек.
4. **dev_dependencies** — пакеты для разработки (тесты, генераторы, линтеры). Не попадают в runtime.
5. **Глобальный кэш** экономит диск: каждая версия пакета скачивается один раз.
6. **`dart pub outdated`** — первый шаг при обновлении зависимостей. Показывает текущие, совместимые и последние версии.
7. **`dart pub deps`** — быстрый способ увидеть полное дерево зависимостей и найти конфликты.

---

> **Следующий:** [1.4 Форматирование, анализ и линтеры](01_04_formatting_analysis.md)
