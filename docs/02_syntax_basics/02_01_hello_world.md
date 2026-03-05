# 2.1 Hello World и структура программы

## 1. Формальное определение

Каждая Dart-программа начинается с функции `main()` — единственной обязательной точки входа. Dart — **объектно-ориентированный язык**, в котором всё является объектом, включая числа, функции и `null`. Программа состоит из `.dart`-файлов, организованных в библиотеки и пакеты.

**Уровень:** синтаксис / структура программы.

## 2. Зачем это нужно

- **Единая точка входа** (`main()`) — чётко определяет, откуда начинается выполнение. Нет неявных инициализаций.
- **Модульность** — код разбивается на файлы, файлы объединяются в библиотеки, библиотеки — в пакеты.
- **Top-level функции и переменные** — не нужно создавать класс ради одной функции (в отличие от Java).

## 3. Как это работает

### Минимальная программа

```dart
void main() {
  print('Hello, Dart!');
}
```

- `void` — функция ничего не возвращает.
- `main()` — точка входа. Вызывается Dart VM автоматически.
- `print()` — top-level функция из `dart:core` (импортируется неявно).

### main() с аргументами командной строки

```dart
void main(List<String> args) {
  if (args.isNotEmpty) {
    print('Привет, ${args[0]}!');
  } else {
    print('Привет, мир!');
  }
}
```

```bash
dart run bin/hello.dart Ivan
# Привет, Ivan!
```

### Структура файла

```dart
// 1. Библиотечная директива (опционально, редко используется)
library my_library;

// 2. Импорты
import 'dart:io';                       // Стандартные библиотеки
import 'dart:async';
import 'package:http/http.dart' as http; // Внешние пакеты
import 'src/utils.dart';                // Локальные файлы

// 3. Части библиотеки (устаревший подход)
// part 'src/helper.dart';

// 4. Top-level переменные
final version = '1.0.0';

// 5. Top-level функции
String greet(String name) => 'Привет, $name!';

// 6. Классы / enums / typedefs / extensions
class App {
  void run() => print('Запуск...');
}

// 7. Точка входа
void main() {
  print(greet('Dart'));
  App().run();
}
```

### Система импортов

```dart
// Импорт стандартной библиотеки
import 'dart:math';

// Импорт пакета
import 'package:path/path.dart';

// Импорт с алиасом (избежание конфликтов имён)
import 'package:http/http.dart' as http;

// Импорт только определённых символов
import 'dart:math' show pi, sqrt;

// Импорт всего, кроме определённых символов
import 'dart:math' hide Random;

// Условный импорт (платформо-зависимый)
import 'src/stub.dart'
    if (dart.library.io) 'src/io_impl.dart'
    if (dart.library.html) 'src/web_impl.dart';
```

### Структура проекта

```
my_app/
├── bin/
│   └── my_app.dart          ← main() для исполняемого приложения
├── lib/
│   ├── my_app.dart           ← «barrel file» — реэкспорт публичного API
│   └── src/                  ← Приватная реализация
│       ├── parser.dart
│       └── utils.dart
├── test/
│   └── parser_test.dart
├── pubspec.yaml
└── analysis_options.yaml
```

**Конвенции:**

- `lib/src/` — приватная реализация. Файлы внутри не должны импортироваться напрямую извне пакета.
- `lib/my_app.dart` — публичный API. Реэкспортирует нужные символы из `src/`.
- `bin/` — исполняемые файлы. Каждый файл — отдельный исполняемый скрипт.

## 4. Минимальный пример

```dart
// bin/main.dart
import 'package:my_app/my_app.dart';

void main() {
  final result = add(2, 3);
  print('2 + 3 = $result');
}
```

```dart
// lib/my_app.dart
export 'src/math.dart';
```

```dart
// lib/src/math.dart
int add(int a, int b) => a + b;
```

## 5. Практический пример

### CLI-приложение с модульной структурой

```dart
// bin/todo.dart
import 'dart:io';
import 'package:todo_app/todo_app.dart';

void main(List<String> args) {
  final store = TodoStore();

  if (args.isEmpty) {
    print('Команды: add <текст> | list | done <id>');
    exit(1);
  }

  switch (args[0]) {
    case 'add':
      final text = args.skip(1).join(' ');
      store.add(text);
      print('Добавлено: $text');
    case 'list':
      for (final todo in store.all) {
        final status = todo.done ? '✓' : '○';
        print('[$status] ${todo.id}: ${todo.text}');
      }
    case 'done':
      store.complete(int.parse(args[1]));
      print('Выполнено: ${args[1]}');
    default:
      print('Неизвестная команда: ${args[0]}');
  }
}
```

```dart
// lib/todo_app.dart
export 'src/todo_store.dart';
export 'src/todo.dart';
```

```dart
// lib/src/todo.dart
class Todo {
  final int id;
  final String text;
  bool done;

  Todo({required this.id, required this.text, this.done = false});
}
```

```dart
// lib/src/todo_store.dart
import 'todo.dart';

class TodoStore {
  final List<Todo> _todos = [];
  int _nextId = 1;

  void add(String text) {
    _todos.add(Todo(id: _nextId++, text: text));
  }

  void complete(int id) {
    _todos.firstWhere((t) => t.id == id).done = true;
  }

  List<Todo> get all => List.unmodifiable(_todos);
}
```

**Архитектурная корректность:**

- Бизнес-логика (`TodoStore`) отделена от CLI-интерфейса (`bin/todo.dart`).
- `lib/todo_app.dart` — barrel file, контролирующий публичный API.
- Приватная реализация в `lib/src/` — не импортируется напрямую потребителями пакета.

## 6. Что происходит под капотом

### От main() до выполнения

```
dart run bin/main.dart
         │
         ▼
┌────────────────────────┐
│ 1. Загрузка SDK        │  ← dart:core, dart:async и т.д.
│    snapshots            │     (предкомпилированные)
├────────────────────────┤
│ 2. Резолв импортов     │  ← package_config.json → пути к пакетам
├────────────────────────┤
│ 3. CFE → Kernel IR     │  ← Парсинг всех .dart файлов
│                        │     в промежуточное представление
├────────────────────────┤
│ 4. JIT-компиляция      │  ← main() компилируется первой
│    main()              │
├────────────────────────┤
│ 5. Выполнение          │  ← Event loop запускается
│                        │     main() выполняется
├────────────────────────┤
│ 6. Завершение          │  ← Event loop пуст → процесс завершается
└────────────────────────┘
```

### Всё — объект

В Dart **всё является объектом**, включая:

- Числа: `42` — экземпляр `int`, который extends `num`, который extends `Object`
- Функции: `main` — экземпляр `Function`
- `null` — единственный экземпляр `Null`
- Типы: `int` — экземпляр `Type`

Иерархия типов:

```
       Object?
      /       \
  Object      Null
  /    \
int   String   ...
```

`Object?` — top type (включает null). `Object` — top non-nullable type. `Never` — bottom type (нет экземпляров).

## 7. Производительность и ресурсы

| Аспект                           | Значение                                                    |
| -------------------------------- | ----------------------------------------------------------- |
| Время парсинга `main()` (JIT)    | < 5 мс                                                      |
| Время инициализации Dart VM      | ~100–200 мс                                                 |
| Overhead от top-level переменных | Минимален (lazy init)                                       |
| Импорт неиспользуемого файла     | Увеличивает время компиляции, но tree-shaker удалит при AOT |

- **Top-level переменные** инициализируются лениво — при первом обращении. Это значит, что `final version = computeVersion()` не вызовет `computeVersion()` пока `version` не будет прочитан.
- **Tree shaking** при AOT-компиляции удаляет неиспользуемый код. Неиспользуемые импорты увеличивают время компиляции, но не размер бинарника.

## 8. Частые ошибки и антипаттерны

### ❌ Несколько main() в одном пакете без понимания

```
bin/
├── server.dart     ← main() для сервера
└── migrate.dart    ← main() для миграции
```

Это нормально! Каждый файл в `bin/` — отдельный executable. Но запускать нужно явно:

```bash
dart run bin/server.dart
dart run bin/migrate.dart
```

### ❌ Импорт из lib/src/ извне пакета

```dart
// Плохо: зависимость от внутренней структуры
import 'package:other_pkg/src/internal.dart';

// Хорошо: использовать публичный API
import 'package:other_pkg/other_pkg.dart';
```

### ❌ Циклические импорты

```dart
// a.dart
import 'b.dart';  // b.dart импортирует a.dart → цикл!
```

Dart разрешает циклические импорты, но они усложняют понимание кода. Решение: выделить общий код в третий файл.

### ❌ Top-level mutable state

```dart
// Плохо: глобальное мутабельное состояние
var counter = 0;
void increment() => counter++;

// Лучше: инкапсулировать в класс
class Counter {
  int _value = 0;
  int get value => _value;
  void increment() => _value++;
}
```

## 9. Сравнение с альтернативами

| Аспект               | Dart                 | Java                                     | Kotlin               | TypeScript          |
| -------------------- | -------------------- | ---------------------------------------- | -------------------- | ------------------- |
| Точка входа          | `void main()`        | `public static void main(String[] args)` | `fun main()`         | нет (модуль)        |
| Top-level функции    | ✅                   | ❌ (только в классе)                     | ✅                   | ✅                  |
| Top-level переменные | ✅ (lazy)            | ❌                                       | ✅                   | ✅                  |
| Обязательный класс   | ❌                   | ✅                                       | ❌                   | ❌                  |
| Модульная система    | `import` / `library` | `import` / `package`                     | `import` / `package` | `import` / `export` |
| Приватность          | `_prefix` (файл)     | `private` (класс)                        | `private` (класс)    | `private` / `#`     |

**Dart ближе к Kotlin и TypeScript:** top-level функции, минимум церемоний, но со строгой типизацией.

## 10. Когда НЕ стоит использовать

- **Top-level переменные для dependency injection** — усложняет тестирование. Используйте конструкторы.
- **`library` директива для каждого файла** — устаревший подход. Используйте только если нужна аннотация на уровне библиотеки.
- **`part` / `part of`** — устаревший механизм. Используйте обычные `import` / `export`.

## 11. Краткое резюме

1. **`void main()`** — единственная обязательная точка входа в Dart-программу.
2. **Всё — объект**: числа, строки, функции, `null` — всё наследует от `Object?`.
3. **Top-level функции и переменные** — не нужно оборачивать всё в класс (в отличие от Java).
4. **`lib/src/`** — приватная реализация; `lib/package.dart` — публичный API (barrel file).
5. **Приватность** определяется символом `_` в начале имени — на уровне библиотеки (файла).
6. **Импорты** поддерживают `show`, `hide`, `as`, условный импорт и deferred loading.
7. **Top-level переменные** инициализируются лениво — при первом обращении, а не при импорте.

---

> **Следующий:** [2.2 Объявление переменных](02_02_variables.md)
