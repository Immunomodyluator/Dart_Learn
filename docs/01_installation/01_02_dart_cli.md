# 1.2 Dart CLI и dartdev инструменты

## 1. Формальное определение

**Dart CLI** — единая утилита командной строки (`dart`), объединяющая все инструменты разработки: компиляцию, запуск, анализ, форматирование, тестирование и управление пакетами. С Dart 2.15+ команда `dart` является единственной точкой входа, заменяя ранее отдельные инструменты (`dartfmt`, `dartanalyzer`, `pub`, `dart2js`).

**Уровень:** инфраструктура / toolchain.

## 2. Зачем это нужно

- **Единый интерфейс** — не нужно запоминать десятки отдельных команд; всё через `dart <подкоманда>`.
- **Кроссплатформенность** — одинаковые команды на Windows, macOS и Linux.
- **Интеграция в CI/CD** — легко встроить анализ, тесты и компиляцию в пайплайн.
- **Быстрый прототип** — `dart run` запускает скрипт без предварительной сборки.

## 3. Как это работает

### Полная карта подкоманд

```
dart
├── run          ← запуск скрипта (JIT)
├── compile      ← компиляция
│   ├── exe      ← нативный исполняемый файл (AOT)
│   ├── aot-snapshot  ← AOT snapshot
│   ├── jit-snapshot  ← JIT snapshot
│   ├── js       ← компиляция в JavaScript
│   └── kernel   ← kernel snapshot (внутренний формат)
├── analyze      ← статический анализ
├── format       ← автоформатирование
├── test         ← запуск тестов
├── pub          ← менеджер пакетов
│   ├── get      ← скачать зависимости
│   ├── upgrade  ← обновить зависимости
│   ├── add      ← добавить зависимость
│   ├── remove   ← удалить зависимость
│   ├── outdated ← проверить устаревшие пакеты
│   └── publish  ← опубликовать на pub.dev
├── create       ← генерация проекта из шаблона
├── fix          ← автоматическое применение исправлений
├── doc          ← генерация документации
├── info         ← информация об окружении
└── devtools     ← запуск Dart DevTools
```

### Основные команды в деталях

#### `dart run` — запуск

```bash
# Запуск файла напрямую
dart run bin/main.dart

# Запуск по умолчанию (ищет bin/<имя_пакета>.dart)
dart run

# Передача аргументов
dart run bin/cli.dart --verbose --output=result.json

# Запуск с определением переменных окружения
dart run --define=ENV=production bin/server.dart
```

#### `dart compile` — компиляция

```bash
# Нативный исполняемый файл (самый частый сценарий)
dart compile exe bin/server.dart -o server

# JavaScript (для веб-приложений)
dart compile js lib/app.dart -o build/app.js --minify

# AOT snapshot (меньше нативного exe, но требует dart runtime)
dart compile aot-snapshot bin/tool.dart
dart run tool.aot  # запустить snapshot
```

#### `dart analyze` — статический анализ

```bash
# Анализ всего проекта
dart analyze

# Анализ с fatal-severity (для CI — fail на warning)
dart analyze --fatal-warnings --fatal-infos
```

#### `dart fix` — автоматические исправления

```bash
# Показать, что можно исправить
dart fix --dry-run

# Применить все исправления
dart fix --apply
```

## 4. Минимальный пример

```bash
# Полный цикл от создания до компиляции
dart create -t console greeter
cd greeter
dart analyze                    # проверить код
dart format .                   # отформатировать
dart test                       # запустить тесты
dart run                        # запустить (JIT)
dart compile exe bin/greeter.dart -o greeter  # скомпилировать (AOT)
./greeter                       # запустить нативный бинарник
```

## 5. Практический пример

### CLI-утилита для обработки CSV

```dart
// bin/csv_tool.dart
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Использование: csv_tool <файл.csv>');
    exit(1);
  }

  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('Файл не найден: ${args[0]}');
    exit(2);
  }

  final lines = file.readAsLinesSync();
  final header = lines.first.split(',');

  print('Колонки (${header.length}): ${header.join(" | ")}');
  print('Строк данных: ${lines.length - 1}');
}
```

```bash
# Разработка (JIT — быстрый запуск)
dart run bin/csv_tool.dart data.csv

# Продакшн (AOT — быстрый старт, standalone бинарник)
dart compile exe bin/csv_tool.dart -o csv_tool
./csv_tool data.csv
```

**Архитектурная корректность:** для CLI-утилит Dart предлагает JIT в разработке и AOT-компиляцию для распространения. Результат — единственный исполняемый файл без зависимости от установленного SDK.

## 6. Что происходит под капотом

### `dart run` внутри

```
dart run bin/main.dart
         │
         ▼
┌────────────────────┐
│  Parsing (.dart)   │  ← Лексический и синтаксический анализ
├────────────────────┤
│  Kernel AST        │  ← Промежуточное представление (Kernel IR)
├────────────────────┤
│  JIT compilation   │  ← Компиляция горячих функций в машинный код
├────────────────────┤
│  Execution on VM   │  ← Выполнение на Dart VM
└────────────────────┘
```

- **Kernel IR** — промежуточное представление, генерируемое фронтендом компилятора (Common Front End, CFE). Хранится как `.dill` файл.
- **JIT** компилирует функции при первом вызове, затем оптимизирует «горячие» пути.
- **Snapshots** позволяют сохранить скомпилированное состояние, пропустив этап парсинга при следующем запуске.

### `dart compile exe` внутри

```
dart compile exe bin/main.dart
         │
         ▼
┌────────────────────┐
│  Kernel IR (.dill) │  ← CFE генерирует IR
├────────────────────┤
│  AOT Compiler      │  ← Tree shaking, type flow analysis
├────────────────────┤
│  Machine code       │  ← Генерация нативного кода
├────────────────────┤
│  ELF / PE binary   │  ← Упаковка с мини-рантаймом Dart
└────────────────────┘
```

Результат — самодостаточный бинарный файл размером 5–15 MB (включает урезанный Dart runtime).

## 7. Производительность и ресурсы

| Операция                        | Типичное время | Примечание                     |
| ------------------------------- | -------------- | ------------------------------ |
| `dart run` (холодный старт)     | 200–500 мс     | Включает парсинг и JIT         |
| `dart run` (тёплый, snapshot)   | 50–100 мс      | Использует cached kernel       |
| `dart compile exe`              | 5–30 сек       | Зависит от объёма кода         |
| `dart analyze` (средний проект) | 1–5 сек        | Инкрементальный анализ быстрее |
| `dart format .` (100 файлов)    | < 1 сек        | Очень быстрый                  |
| `dart test` (100 unit-тестов)   | 2–10 сек       | Зависит от изоляции            |

**Оптимизации:**

- Используйте `--enable-experiment` только при явной необходимости — экспериментальные фичи могут замедлить компиляцию.
- `dart compile exe` с `--verbosity=error` ускоряет CI (меньше логов).
- Размер AOT-бинарника можно уменьшить на 20–40% через `--target-os` (убирает поддержку чуждых платформ).

## 8. Частые ошибки и антипаттерны

### ❌ Использование `dart run` в продакшн

```bash
# Плохо: JIT-накладные расходы при каждом запуске
dart run bin/server.dart  # на продакшн-сервере

# Хорошо: AOT-компиляция
dart compile exe bin/server.dart -o server
./server
```

### ❌ Забытый `dart pub get` после клонирования

```
Error: Could not resolve the package 'my_dependency'
```

**Решение:** `dart pub get` нужно запускать после клонирования репозитория или изменения `pubspec.yaml`.

### ❌ `dart format` без привязки к CI

Форматирование «на глазок» приводит к бесконечным diff-ам. Добавьте в CI:

```bash
dart format --set-exit-if-changed .
```

### ❌ Игнорирование `dart fix`

`dart fix --apply` автоматически обновляет deprecated API-вызовы. Многие разработчики не знают об этом инструменте и правят вручную.

## 9. Сравнение с альтернативами

| Возможность    | `dart` CLI         | `go` CLI   | `cargo` (Rust)          | `dotnet` CLI       |
| -------------- | ------------------ | ---------- | ----------------------- | ------------------ |
| Запуск скрипта | `dart run`         | `go run`   | `cargo run`             | `dotnet run`       |
| Компиляция     | `dart compile exe` | `go build` | `cargo build --release` | `dotnet publish`   |
| Тесты          | `dart test`        | `go test`  | `cargo test`            | `dotnet test`      |
| Форматирование | `dart format`      | `gofmt`    | `rustfmt`               | `dotnet format`    |
| Анализ         | `dart analyze`     | `go vet`   | `cargo clippy`          | `dotnet analyzers` |
| Пакеты         | `dart pub`         | `go mod`   | `cargo`                 | `dotnet nuget`     |
| Документация   | `dart doc`         | `go doc`   | `cargo doc`             | ❌                 |
| Автофиксы      | `dart fix`         | ❌         | `cargo fix`             | ❌                 |

Dart CLI ближе всего к `cargo` по полноте и к `go` по минимализму.

## 10. Когда НЕ стоит использовать

- **`dart compile exe` для скриптов, запускаемых раз в день** — JIT-запуск быстрее в разработке, оверхед компиляции не окупается.
- **`dart compile js` для серверного кода** — JS-compilation предназначен только для браузерного окружения.
- **`dart run` для профилирования** — замеры на JIT не отражают AOT-производительность. Для бенчмарков используйте `dart compile exe`.

## 11. Краткое резюме

1. **`dart` — единственная команда**, которую нужно знать. Все инструменты — подкоманды.
2. **`dart run`** = JIT, для разработки. **`dart compile exe`** = AOT, для продакшн.
3. **`dart analyze` + `dart format`** — обязательный минимум в CI/CD пайплайне.
4. **`dart fix --apply`** автоматически обновляет код при миграции между версиями.
5. **`dart create`** генерирует проект с правильной структурой — шаблоны `console`, `package`, `server-shelf`, `web`.
6. **AOT-бинарник** — самодостаточный файл 5–15 MB, не требует установленного SDK на целевой машине.
7. **`dart info`** — быстрый способ проверить окружение (версия SDK, платформа, каналы).

---

> **Следующий:** [1.3 pub и pubspec.yaml](01_03_pub_pubspec.md)
