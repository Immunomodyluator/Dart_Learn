# Урок 18. Производительность и профилирование

> Охватывает подтемы: 18.1 DevTools профилирование, 18.2 Оптимизация аллокаций, 18.3 Async bottlenecks, 18.4 Сборщик мусора

---

## 1. Формальное определение

Производительность Dart-приложения определяется:

- **CPU time** — время выполнения кода (горячие пути, алгоритмы)
- **Memory** — количество и живое время объектов; давление на GC
- **Latency** — задержки event loop, блокирующий код в async контексте
- **Throughput** — количество операций в единицу времени

**Инструменты**: Dart DevTools (профилировщик CPU, memory, timeline), `dart compile` флаги, benchmark_harness.

---

## 2. DevTools профилирование (18.1)

```bash
# Запуск с Observatory/DevTools
dart --observe bin/server.dart
# или с автоматическим открытием:
dart run --observe bin/server.dart

# Для Flutter
flutter run --profile  # профиль-режим (без debug overhead, без AOT оптимизаций)
flutter run --release  # release (полный AOT)
```

### CPU Профилировщик программно

```dart
import 'dart:developer';

void profileHotPath() {
  // Начало CPU профилирования
  UserTag('hot_path').makeCurrent();
  
  // Маркеры на timeline
  Timeline.startSync('MyOperation');
  
  expensiveComputation();
  
  Timeline.finishSync();
}

// Измерение времени
void benchmark() {
  final sw = Stopwatch()..start();
  
  for (int i = 0; i < 1000000; i++) {
    doWork(i);
  }
  
  sw.stop();
  print('Time: ${sw.elapsedMicroseconds}μs');
  print('Per op: ${sw.elapsedMicroseconds / 1000000}μs');
}
```

### package:benchmark_harness

```dart
import 'package:benchmark_harness/benchmark_harness.dart';

class ListBenchmark extends BenchmarkBase {
  ListBenchmark() : super('List<int> creation');
  
  @override
  void run() {
    // Этот код измеряется
    final list = List<int>.generate(1000, (i) => i);
    doNotOptimizeAway(list);
  }
  
  // setup() и teardown() — вне измерений
}

void main() {
  ListBenchmark().report();
  // Output: List<int> creation(RunTime): 12.3 us.
}
```

---

## 3. Оптимизация аллокаций (18.2)

### const — compile-time constants

```dart
// BAD: создаёт новый объект при каждом вызове
Widget build() {
  return Padding(
    padding: EdgeInsets.all(16.0), // новый объект
    child: Text('Hello'),          // новый объект
  );
}

// GOOD: один объект в пуле констант
const kPadding = EdgeInsets.all(16.0);
Widget build() {
  return const Padding(
    padding: kPadding,
    child: Text('Hello'), // const виджет → не пересоздаётся
  );
}
```

### Reuse объектов вместо создания новых

```dart
// BAD: новый List в каждой итерации
List<String> processItems(List<int> items) {
  return items.map((i) => 'item_$i').toList(); // OK если нужна List
}

// GOOD для горячего пути: reuse буфера
class Processor {
  final List<String> _buffer = [];
  
  List<String> processItems(List<int> items) {
    _buffer.clear();
    for (final i in items) {
      _buffer.add('item_$i');
    }
    return List.unmodifiable(_buffer); // или передавать _buffer напрямую
  }
}
```

### Lazy collections (Iterable vs List)

```dart
// BAD: создаёт промежуточные списки
final result = items
    .map(transform)    // List<>
    .where(filter)     // List<>
    .take(10)          // List<>
    .toList();

// GOOD: lazy chain — промежуточные объекты не создаются
final result = items
    .map(transform)    // lazy Iterable
    .where(filter)     // lazy Iterable
    .take(10)          // lazy Iterable
    .toList();         // материализуется ОДИН раз здесь
// Разница: map/where на Iterable ленивы; .toList() фиксирует
```

### Avoid boxing/unboxing

```dart
// BAD: int boxing в typed data
List<int> numbers = List.generate(1000000, (i) => i); // boxed ints

// GOOD: unboxed typed data
import 'dart:typed_data';
Int32List numbers = Int32List.fromList(List.generate(1000000, (i) => i));
// В 2-4+ раза меньше памяти; лучшая cache locality
```

---

## 4. Async bottlenecks (18.3)

### Избегайте await в узком цикле

```dart
// BAD: N*RTT задержки
Future<List<User>> loadAllUsers(List<String> ids) async {
  final users = <User>[];
  for (final id in ids) {
    users.add(await fetchUser(id)); // каждый запрос ждёт предыдущего
  }
  return users;
}

// GOOD: параллельно
Future<List<User>> loadAllUsers(List<String> ids) =>
    Future.wait(ids.map(fetchUser)); // все запросы одновременно
```

### Батчинг

```dart
// Слишком много параллельных запросов → перегрузка сервера
// ХОРОШО: батчи по N запросов
Future<List<T>> batchedFetch<T>(
  List<String> ids,
  Future<T> Function(String) fetcher, {
  int batchSize = 10,
}) async {
  final results = <T>[];
  
  for (int i = 0; i < ids.length; i += batchSize) {
    final batch = ids.sublist(i, (i + batchSize).clamp(0, ids.length));
    results.addAll(await Future.wait(batch.map(fetcher)));
  }
  
  return results;
}
```

### CPU в async — Isolate

```dart
// BAD: блокируем event loop
Future<Map<String, dynamic>> parseHugeJson(String json) async {
  return jsonDecode(json); // sync CPU, блокирует event loop!
}

// GOOD: в отдельном Isolate
Future<Map<String, dynamic>> parseHugeJson(String json) =>
    Isolate.run(() => jsonDecode(json) as Map<String, dynamic>);
```

### Избегайте synchronous I/O

```dart
// BAD: блокирует event loop на I/O
String readConfig() {
  return File('config.json').readAsStringSync(); // блокирующий!
}

// GOOD
Future<String> readConfig() =>
    File('config.json').readAsString();
```

---

## 5. Garbage Collector Dart (18.4)

Dart VM использует **generational GC**:

```
Young generation (new space):
  ├── Nursery: новые объекты живут здесь
  └── Semi-space: выжившие копируются
  
Old generation (old space):
  └── Долгоживущие объекты (промотируются из new space)
```

### GC стратегии

- **Scavenger** (minor GC): быстрый, собирает new space; ~1ms
- **Mark-Sweep-Compact** (major GC): полная сборка; ~10-100ms
- **Incremental GC**: разбитый на маленькие шаги для Flutter

### Влияние на GC

```dart
// Снизить давление на GC:

// 1. Immutable objects — GC знает они не изменятся
const config = AppConfig(host: 'localhost', port: 8080);

// 2. Object pools — reuse вместо create/destroy
class ObjectPool<T> {
  final Queue<T> _pool = Queue();
  final T Function() _factory;
  final void Function(T) _reset;
  
  ObjectPool({required T Function() factory, required void Function(T) reset})
      : _factory = factory, _reset = reset;
  
  T acquire() => _pool.isNotEmpty ? _pool.removeFirst() : _factory();
  
  void release(T obj) {
    _reset(obj);
    _pool.addLast(obj);
  }
}

// 3. Избегайте closures в горячих путях (захватывают переменные)
// BAD — closure создаётся в каждой итерации
items.forEach((item) { process(item); }); // OK в большинстве случаев

// 4. StringBuilder для строк
final sb = StringBuffer();
for (final chunk in chunks) sb.write(chunk);
final result = sb.toString(); // одна аллокация вместо N
```

---

## 6. Практический пример: профилирование сервера

```dart
import 'dart:developer';
import 'dart:io';
import 'dart:convert';

class MetricsMiddleware {
  final Map<String, List<int>> _durations = {};
  
  Future<void> measure(String name, Future<void> Function() fn) async {
    final sw = Stopwatch()..start();
    Timeline.startSync(name, arguments: {'type': 'http_handler'});
    
    try {
      await fn();
    } finally {
      sw.stop();
      Timeline.finishSync();
      
      _durations.putIfAbsent(name, () => [])
          .add(sw.elapsedMicroseconds);
    }
  }
  
  Map<String, dynamic> getStats() {
    return {
      for (final entry in _durations.entries)
        entry.key: {
          'count': entry.value.length,
          'avg_us': entry.value.isEmpty ? 0 :
              entry.value.reduce((a, b) => a + b) ~/ entry.value.length,
          'max_us': entry.value.isEmpty ? 0 :
              entry.value.reduce((a, b) => a > b ? a : b),
        }
    };
  }
}

void main() async {
  final metrics = MetricsMiddleware();
  final server = await HttpServer.bind('localhost', 8080);
  
  await for (final request in server) {
    await metrics.measure('handle_${request.method}_${request.uri.path}', () async {
      // handle request
      request.response
        ..statusCode = 200
        ..write(jsonEncode({'status': 'ok'}));
      await request.response.close();
    });
  }
}
```

---

## 7. Под капотом: AOT оптимизации

```dart
// Dart AOT применяет:
// 1. Tree shaking — удаляет неиспользуемый код
// 2. Inlining — встраивает маленькие функции
// 3. Devirtualization — статическая диспетчеризация для final классов
// 4. Type specialization — конкретные реализации для частых типов

// @pragma('vm:prefer-inline') — подсказка компилятору
@pragma('vm:prefer-inline')
int add(int a, int b) => a + b;

// @pragma('vm:never-inline') — запрет инлайнинга
@pragma('vm:never-inline')
void expensiveDebugLog(String message) {
  // Не инлайним чтобы не раздувать код
}
```

---

## 8. Производительность: чеклист

```
Memory:
├── ✓ const для неизменяемых объектов
├── ✓ final для полей
├── ✓ Int32List/Float64List вместо List<int>/List<double>
├── ✓ StringBuffer вместо + в цикле
└── ✓ Не создавать промежуточные коллекции в pipeline

CPU:
├── ✓ Lazy Iterable chain вместо промежуточных List
├── ✓ CPU-intensive → Isolate.run
└── ✓ Избегайте reflection (dart:mirrors)

Async:
├── ✓ Future.wait вместо await в цикле
├── ✓ Батчинг для массовых запросов
└── ✓ Нет sync I/O в async коде

AOT:
├── ✓ Используйте final/const классы
├── ✓ Избегайте dynamic typed code
└── ✓ Нет reflection → хороший tree shaking
```

---

## 9. Частые ошибки

**1. Не используете профилировщик:**
```dart
// Не угадывайте где проблема — измеряйте!
// dart --observe bin/app.dart → открыть DevTools → CPU Profile
```

**2. Преждевременная оптимизация:**
```dart
// Сначала нужна корректность, потом профилирование, потом оптимизация
// "Premature optimization is the root of all evil" — Donald Knuth
```

**3. Забыть что Dart числа boxed в коллекциях:**
```dart
List<int> a = []; // boxed integers — медленнее для числовых вычислений
Int64List b = Int64List(0); // unboxed → быстрее для числовых задач
```

---

## 10. Краткое резюме

1. **Измеряйте, не угадывайте**: Dart DevTools CPU профайлер → найти горячие пути
2. **`const`** — compile-time константы без аллокации при каждом вызове
3. **Lazy Iterable** pipeline — нет промежуточных List; `.toList()` только в конце
4. **`Typed Data`** (`Int32List`, `Float64List`) значительно быстрее `List<int>` для числовых задач
5. **CPU в async** → `Isolate.run` — не блокирует event loop
6. **`Future.wait`** вместо последовательных `await` во циклах
7. **GC давление** снижается: const/immutable объекты, object pools, StringBuffer
8. **Sync I/O** блокирует весь event loop — никогда в production async коде
