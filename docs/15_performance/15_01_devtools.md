# 15.1 Профайлинг с DevTools

## 1. Формальное определение

**Dart DevTools** — набор инструментов для отладки и профилирования Dart- и Flutter-приложений. Включает CPU profiler, memory profiler, network inspector, timeline и другие инструменты, доступные через веб-интерфейс.

## 2. Зачем это нужно

- **Измерять** — нельзя оптимизировать то, что не измерено.
- **Находить горячие точки** — какие функции потребляют больше всего CPU.
- **Обнаруживать утечки памяти** — объекты, которые не освобождаются GC.
- **Визуализировать** — timeline показывает поведение приложения во времени.

## 3. Запуск DevTools

```bash
# Для standalone Dart-приложения
dart run --observe main.dart
# Выводит: Observatory listening on http://127.0.0.1:8181/...

# Открыть DevTools
dart devtools

# Для Flutter
flutter run --profile
# DevTools URL выводится в консоли
```

### Запуск из VS Code

```
1. Запустить приложение в debug-режиме
2. Command Palette → "Dart: Open DevTools"
3. Или кликнуть на ссылку в Debug Console
```

## 4. CPU Profiler

### Запись профиля

```dart
// Для точечного профилирования используйте Stopwatch
void main() {
  final sw = Stopwatch()..start();

  heavyComputation();

  sw.stop();
  print('Elapsed: ${sw.elapsedMilliseconds} ms');
}
```

### Анализ в DevTools

```
┌──────────── CPU Profiler ─────────────────────────┐
│                                                    │
│  1. Вкладка "CPU Profiler"                        │
│  2. Нажать "Record" → выполнить операцию          │
│  3. Нажать "Stop"                                 │
│                                                    │
│  Представления:                                    │
│  ├── Call Tree — дерево вызовов (top-down)         │
│  ├── Bottom Up — от «листьев» к корню              │
│  ├── Method Table — все методы с %-CPU             │
│  └── Flame Chart — визуализация стека             │
│                                                    │
│  Flame Chart:                                      │
│  ┌────────────────────────────────────────┐         │
│  │ main()                                 │         │
│  │ ├── parseData()     ████████░░░  72%   │         │
│  │ │   └── regex()     ██████░░░░  55%   │         │
│  │ └── renderUI()      ██░░░░░░░░  18%   │         │
│  └────────────────────────────────────────┘         │
│                                                    │
└────────────────────────────────────────────────────┘
```

### Программное профилирование

```dart
import 'dart:developer';

void profiledFunction() {
  // Создание timeline event
  Timeline.startSync('myOperation');

  // ... тяжёлая операция ...

  Timeline.finishSync();
}

// Или через timelineTask для async
void asyncProfiled() async {
  final task = TimelineTask();
  task.start('fetchData');

  await fetchFromApi();

  task.finish();
}
```

## 5. Memory Profiler

### Основные метрики

```
┌──────────── Memory Overview ──────────────────────┐
│                                                    │
│  Dart Heap Used:    12.4 MB                       │
│  Dart Heap Total:   24.0 MB                       │
│  External:           3.2 MB                       │
│  RSS:              48.0 MB                        │
│                                                    │
│  Heap Graph (время →)                             │
│        ╱╲                                         │
│  ────╱    ╲───╱╲──────  ← GC снижает peak        │
│                   ╲╱                              │
│                                                    │
└────────────────────────────────────────────────────┘
```

### Snapshot и утечки

```
1. Сделать Heap Snapshot (кнопка "Snapshot")
2. Выполнить операцию, которая должна освободить память
3. Сделать ещё один Snapshot
4. Сравнить — объекты, оставшиеся после операции = потенциальная утечка
```

### Программное отслеживание

```dart
import 'dart:developer';

void checkMemory() {
  // Принудительный GC (только в debug/profile)
  // Через DevTools или VM service

  // Аллокационный трейсинг
  debugger(); // Остановка для снятия snapshot
}
```

## 6. Бенчмаркинг

```dart
// Простой бенчмарк
void benchmark(String name, void Function() fn, {int iterations = 100000}) {
  // Прогрев — JIT-компилятор оптимизирует горячий код
  for (var i = 0; i < 1000; i++) fn();

  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) fn();
  sw.stop();

  final usPerOp = sw.elapsedMicroseconds / iterations;
  print('$name: ${usPerOp.toStringAsFixed(2)} µs/op');
}

void main() {
  final list = List.generate(10000, (i) => i);

  benchmark('List.contains', () => list.contains(9999));
  benchmark('Set.contains', () => Set.of(list).contains(9999));

  // Сравнение строковой конкатенации
  benchmark('String +', () {
    var s = '';
    for (var i = 0; i < 100; i++) s += 'a';
  });

  benchmark('StringBuffer', () {
    final sb = StringBuffer();
    for (var i = 0; i < 100; i++) sb.write('a');
    sb.toString();
  });
}
```

### Пакет benchmark_harness

```dart
import 'package:benchmark_harness/benchmark_harness.dart';

class ListSortBenchmark extends BenchmarkBase {
  ListSortBenchmark() : super('ListSort');

  late List<int> data;

  @override
  void setup() {
    data = List.generate(10000, (i) => 10000 - i);
  }

  @override
  void run() {
    final copy = List.of(data);
    copy.sort();
  }
}

void main() {
  ListSortBenchmark().report();
  // ListSort(RunTime): 452.32 us.
}
```

## 7. Полезные команды

```bash
# Запуск с Observatory
dart run --observe main.dart

# Компиляция в profile-режиме (Flutter)
flutter run --profile

# Открыть DevTools
dart devtools

# Запуск с включённым assertion (debug)
dart run --enable-asserts main.dart

# AOT-компиляция для production-бенчмарков
dart compile exe main.dart -o main
./main
```

## 8. Распространённые ошибки

### ❌ Оптимизация без профилирования

```dart
// Плохо — «оптимизируем» наугад
// «Наверное, эта строка медленная...»

// Хорошо — сначала профилируем
// 1. Запустить CPU profiler
// 2. Найти реальную горячую точку
// 3. Оптимизировать конкретную функцию
// 4. Проверить, что стало быстрее
```

### ❌ Бенчмарк без прогрева

```dart
// Плохо — первые вызовы включают JIT-компиляцию
final sw = Stopwatch()..start();
result = compute();
print(sw.elapsedMicroseconds);

// Хорошо — прогреваем, потом измеряем
for (var i = 0; i < 1000; i++) compute(); // warmup
final sw = Stopwatch()..start();
for (var i = 0; i < 10000; i++) compute();
print(sw.elapsedMicroseconds ~/ 10000);
```

---

> **Назад:** [15.0 Обзор](15_00_overview.md) · **Далее:** [15.2 Оптимизация аллокаций](15_02_allocations.md)
