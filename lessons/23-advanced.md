# Урок 23. Переход к продвинутым темам

> Охватывает подтемы: 23.1 AOT/JIT — глубокое погружение, 23.2 Вклад в OSS Dart, 23.3 Портфельные проекты

---

## 1. Формальное определение

Dart поддерживает несколько моделей компиляции и выполнения:

| Режим                   | Команда                     | Когда используется                              |
| ----------------------- | --------------------------- | ----------------------------------------------- |
| **JIT** (Just-In-Time)  | `dart run`                  | Разработка: быстрый запуск, hot reload          |
| **AOT** (Ahead-Of-Time) | `dart compile exe`          | Продакшн: быстрый старт, max производительность |
| **JIT snapshot**        | `dart compile jit-snapshot` | Тесты: JIT, но пропускает парсинг               |
| **AOT snapshot**        | `dart compile aot-snapshot` | AOT, запускается через `dartaotruntime`         |
| **Wasm**                | `dart compile wasm`         | Браузер: sandbox + near-native perf             |
| **JS**                  | `dart compile js`           | Браузер: совместимость, дерево трясения         |
| **kernel**              | `dart compile kernel`       | Kernel binary (.dill) — независимый от CPU      |

---

## 2. AOT vs JIT — глубокое погружение (23.1)

### JIT компиляция

```text
Dart source code
    ↓ (parse)
AST (Abstract Syntax Tree)
    ↓ (compile)
Kernel IR (.dill bytecode)
    ↓ (загрузка в VM)
Unoptimized Machine Code  ← выполняется немедленно
    ↓ (профилировщик замечает "горячие" пути, ~100 вызовов)
Optimized Machine Code    ← генерируется фоново JIT-компилятором
    ↓ (деоптимизация при нарушении предположений)
Unoptimized code again    ← если предположение оказалось неверным
```

**Ключевые JIT оптимизации:**

- **Inline кэш (IC)** — запоминает типы аргументов в конкретных call-site для быстрой диспетчеризации
- **Type feedback** — JIT предполагает конкретные мономорфные типы; может деоптимизировать при полиморфизме
- **Speculative inlining** — встраивает малые функции на основе профиля

```dart
// JIT оптимизирует ЭТО эффективно (нет кода, но VM использует профиль)
// После ~1000 вызовов calculate(int, int) → оптимизирует для int
// Если вдруг вызвать с double → деоптимизация и переком
num calculate(num a, num b) => a + b;

void hotLoop() {
  var sum = 0;
  for (var i = 0; i < 1000000; i++) {
    sum += calculate(i, i + 1); // JIT специализирует для int
  }
  print(sum);
}
```

### AOT компиляция

```text
Dart source
    ↓ (frontend)
Kernel IR
    ↓ (TFA — Type Flow Analysis)
Strongly typed, devirtualized IR
    ↓ (backend: gen_snapshot)
Machine code (ELF/Mach-O/PE)
    ↓ (linker + tree shaking)
Executable binary
```

**Ключевые AOT техники:**

- **Tree shaking** — удаляем весь код, на который нет ссылок (в т.ч. flutter widgets, dart:core methods)
- **TFA (Type Flow Analysis)** — межпроцедурный анализ типов; девиртуализация вызовов
- **Global transformations** — оптимизации на уровне всей программы (недоступно в JIT)
- **`@pragma('vm:prefer-inline')`** — подсказка компилятору

```dart
// Подсказки компилятору
@pragma('vm:prefer-inline')
int fastAdd(int a, int b) => a + b;   // всегда инлайнится в AOT

@pragma('vm:never-inline')
void heavyOperation() { /* не инлайнится даже в горячем пути */ }

@pragma('vm:entry-point')
class MyClass {
  @pragma('vm:entry-point')
  void myMethod() { /* не удаляется tree shaking даже без явных Dart ссылок */ }
}
// Нужен при reflection/FFI callback где TFA не видит использований
```

### Сравнение производительности

```dart
// benchmark_harness для измерения
import 'package:benchmark_harness/benchmark_harness.dart';

class ListBenchmark extends BenchmarkBase {
  const ListBenchmark() : super('ListBenchmark');

  static final _list = List.generate(1000, (i) => i);

  @override
  void run() {
    var sum = 0;
    for (final item in _list) {  // for-in: итератор
      sum += item;
    }
  }
}

class IndexedListBenchmark extends BenchmarkBase {
  const IndexedListBenchmark() : super('IndexedListBenchmark');

  static final _list = List.generate(1000, (i) => i);

  @override
  void run() {
    var sum = 0;
    final len = _list.length;
    for (var i = 0; i < len; i++) { // индексированный — быстрее в AOT на ~15%
      sum += _list[i];
    }
  }
}

void main() {
  const ListBenchmark().report();
  const IndexedListBenchmark().report();
}
```

### Снапшоты

```bash
# JIT snapshot — всключает JIT код, пропускает парсинг
dart compile jit-snapshot bin/server.dart -o server.jitsnap
dart run server.jitsnap    # быстрее первого запуска на ~30-50%

# AOT snapshot (без embedded runtime)
dart compile aot-snapshot bin/server.dart -o server.aot
dartaotruntime server.aot  # нужен dartaotruntime в PATH

# Exe (содержит dartaotruntime) — самодостаточный
dart compile exe bin/server.dart -o server
./server  # никаких зависимостей Dart SDK
```

### Анализ размера AOT бинарника

```bash
# Посмотреть дерево символов (gen_snapshot dump)
dart compile exe bin/app.dart \
  -o app \
  --save-debugging-info=debug-info.json \
  --snapshot-kind=app-aot-elf

# DevTools → App Size tool:
dart devtools
# Открываем дерево зависимостей и видим что занимает место

# Ручной dump (Linux)
nm --size-sort app | tail -50  # топ-50 символов по размеру
```

---

## 3. Вклад в OSS Dart (23.2)

### Экосистема open source Dart

- **dart-lang/sdk** — VM, компилятор, core libraries; C++ + Dart
- **dart-lang/pub** — package manager; написан на Dart
- **dart-lang/lints** — официальный линтер rules; легко контрибьютить
- **dart-lang/test** — test framework
- **flutter/flutter** — Flutter SDK
- **pub.dev** — registry; написан на Dart (открытый исходник: dart-lang/pub-dev)

### Workflow контрибьюции в dart-lang

```bash
# 1. Fork на GitHub
# 2. Клон
git clone https://github.com/YOUR_USERNAME/lints.git
cd lints
git remote add upstream https://github.com/dart-lang/lints.git

# 3. Настройка
dart pub get

# 4. Ветка для исправления
git checkout -b fix/issue-123-prefer-final-locals

# 5. Делаем изменения, пишем тесты
# 6. Проверяем
dart analyze
dart test
dart format .

# 7. CLA / DCO подпись (для dart-lang)
# dart-lang использует CLA (Contributor License Agreement)
# Нужно подписать один раз на https://cla.developers.google.com

# 8. Коммит
git commit -m "fix: Correct prefer_final_locals to handle pattern declarations (fixes #123)"
# Формат: type: Description (#issue)
# types: fix, feat, refactor, docs, test, style, chore

# 9. Push и PR
git push origin fix/issue-123-prefer-final-locals
# GitHub: New Pull Request → base: dart-lang/lints:main
```

### Как найти хорошие первые задачи

```text
GitHub → dart-lang/sdk → Issues → label:good-first-issue
GitHub → dart-lang/lints → Issues → label:help wanted
GitHub → flutter/flutter → Issues → label:good first contribution

Полезные типы задач для начинающих:
- fix: опечатки в документации (merged быстро)
- improvement: примеры в API docs
- test: добавить edge case тесты
- fix: обработка ошибки в конкретном пакете
```

### Написание и публикация собственного пакета

```text
my_dart_package/
├── lib/
│   ├── my_dart_package.dart     # главный export
│   └── src/
│       ├── feature_a.dart
│       └── feature_b.dart
├── bin/
│   └── cli.dart                 # если есть CLI
├── example/
│   └── main.dart                # рабочий пример
├── test/
│   └── my_dart_package_test.dart
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── publish.yml
├── CHANGELOG.md                 # следуй keepachangelog.com
├── README.md                    # badges, quickstart, API overview
├── LICENSE
└── pubspec.yaml
```

```yaml
# pubspec.yaml хорошего пакета
name: my_dart_package
description: A brief description of what this package does.
version: 0.1.0
repository: https://github.com/yourname/my_dart_package
issue_tracker: https://github.com/yourname/my_dart_package/issues
documentation: https://pub.dev/documentation/my_dart_package

environment:
  sdk: ^3.0.0

dependencies:
  # минимально необходимые зависимости
  meta: ^1.9.0

dev_dependencies:
  lints: ^3.0.0
  test: ^1.24.0
```

---

## 4. Портфельные проекты (23.3)

### Проект 1: CLI инструмент

```text
Идея: dart_diff_tool — сравнение JSON/YAML файлов
├── Показывает структурный diff (не строковый)
├── Подсветка изменений в терминале (package:ansi)
├── Выходной формат: human-readable, JSON patch, Markdown
└── Цель: демонстрация CLI, алгоритмов, тестирования

Технологии:
- package:args — парсинг CLI
- package:yaml — парсинг YAML
- dart:convert — JSON
- package:path — работа с путями
- package:test + mocktail — тестирование
```

```dart
// bin/dart_diff.dart — примерная точка входа
import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag('json-patch', help: 'Output as JSON Patch (RFC 6902)')
    ..addFlag('no-color', help: 'Disable color output')
    ..addOption('format', allowed: ['human', 'json', 'md'], defaultsTo: 'human');

  final results = parser.parse(args);

  if (results.rest.length != 2) {
    stderr.writeln('Usage: dart_diff <file1> <file2>');
    exit(1);
  }

  final file1 = _readFile(results.rest[0]);
  final file2 = _readFile(results.rest[1]);

  final diff = computeDiff(file1, file2);

  if (diff.isEmpty) {
    print('Files are identical');
    exit(0);
  }

  formatAndPrint(diff, results['format'] as String, !results['no-color'] as bool);
  exit(1);  // diff нашёл различия
}

dynamic _readFile(String path) {
  final content = File(path).readAsStringSync();
  if (path.endsWith('.yaml') || path.endsWith('.yml')) {
    return loadYaml(content);
  }
  return jsonDecode(content);
}
```

### Проект 2: REST API сервер

```text
Идея: task_tracker_api — REST API для управления задачами
├── CRUD для tasks, projects, users
├── JWT аутентификация
├── PostgreSQL через package:postgres
├── OpenAPI документация
└── Цель: демонстрация архитектуры, безопасности, DB

Структура:
lib/
├── domain/
│   ├── entities/ (Task, Project, User)
│   └── repositories/ (интерфейсы)
├── data/
│   ├── repositories/ (PostgreSQL реализация)
│   └── mappers/
├── application/
│   └── services/ (TaskService, AuthService)
└── infrastructure/
    ├── routes/
    ├── middleware/
    └── config/
bin/
└── server.dart
```

### Проект 3: Dart пакет

```text
Идея: result_dart — монада Result<T, E> для обработки ошибок
├── sealed Ok<T> / Err<E> классы
├── map / flatMap / fold / recover методы
├── async версии
├── расширения для Future<Result<T,E>>
└── Цель: пакет с >90% покрытием тестов, pub.dev score 130/140+

Метрики хорошего пакета на pub.dev:
- pub points: 130+/140 (описание, тесты, API docs, dartdoc, platforms, null safety)
- Likes: зависят от продвижения
- Popularity: трафик = реклама в блогах, Twitter/X, Reddit
```

---

## 5. Что изучать дальше

```dart
// Дерево тем для углублённого изучения

// 1. VM internals
// - Сборка мусора: Scavenger + Mark-Sweep-Compact
// - Write barriers
// - Объектная модель (header word, class table)
// - Источник: dart-lang/sdk/runtime/vm/

// 2. Компилятор
// - CFG (Control Flow Graph) в Dart IR
// - SSA форма (Static Single Assignment)
// - Range analysis, type propagation
// - dart-lang/sdk/pkg/compiler/

// 3. Concurrency (планы Dart team)
// - Structured concurrency (ответ на проблемы с Isolates)
// - Shared memory objects (experimental)

// 4. Wasm
// - dart compile wasm
// - browser support table
// - WasmGC (Garbage Collected Wasm)

// 5. Dart for Data Science (emerging)
// - package:ml_algo
// - package:ml_dataframe
// - package:tensors

// 6. Flutter advanced
// - Custom render objects
// - Fragment shaders
// - Platform views

// Ресурсы
// - dart.dev/guides — официальная документация
// - dart.dev/articles — deep dive статьи от команды Dart
// - pub.dev/documentation — API docs всех пакетов
// - github.com/dart-lang — исходники всех официальных пакетов
// - medium.com/dartlang — блог команды Dart
// - dartweekly.com — дайджест новостей
```

---

## 6. Dart development workflow

```bash
# Полный рабочий цикл экспертного Dart разработчика

# Новый проект
dart create -t package my_project  # или: -t console, -t web, -t server-shelf
cd my_project

# Разработка
dart run bin/main.dart          # JIT, быстрый запуск
dart run --observe              # с Observatory (DevTools)
dart run build_runner watch     # watch mode для codegen

# Качество кода
dart analyze                    # статический анализ
dart format .                   # форматирование
dart test                       # тесты
dart test --coverage=coverage   # с покрытием
dart pub global run coverage:format_coverage --lcov -i coverage -o coverage/lcov.info

# Продакшн
dart compile exe bin/server.dart  # нативный бинарник
dart compile js web/main.dart     # JavaScript bundle

# Публикация
dart pub publish --dry-run      # проверка без публикации
dart pub publish                # публикация на pub.dev

# DevTools (профилировщик, отладчик)
dart devtools                   # открывает браузер UI
dart run --observe=0 bin/app.dart  # позволяет подключить DevTools

# Полезные глобальные инструменты
dart pub global activate dart_style      # форматтер
dart pub global activate coverage        # coverage tools
dart pub global activate dartdoc         # генератор документации
dart pub global activate stagehand       # шаблоны проектов
dart pub global activate pana            # проверка качества пакета (как pub.dev)
```

---

## 7. Краткое резюме

1. **JIT** оптимизирует код во время выполнения по профилю; **AOT** использует глобальный TFA и tree shaking — лучший старт и пиковая производительность
2. **`@pragma('vm:prefer-inline')`** и **`vm:entry-point`** — тонкие подсказки AOT компилятору
3. **Dart compile exe** = AOT + embedded runtime; самодостаточный бинарник 5-30 MB
4. **Вклад в OSS**: good-first-issue → fork → CLA → PR; начни с документации или тестов
5. **Портфель** должен включать: CLI инструмент, REST сервер, опубликованный пакет на pub.dev
6. **pana** — локальная симуляция pub.dev score; target 130+/140 до публикации
7. **Дальнейший путь**: VM internals, Wasm, structured concurrency, Flutter custom rendering
