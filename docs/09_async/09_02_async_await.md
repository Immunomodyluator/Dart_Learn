# 9.2 async / await

## 1. Формальное определение

**`async`** — модификатор функции, превращающий её возвращаемый тип в `Future<T>`. Внутри `async`-функции доступен оператор **`await`**, который приостанавливает выполнение до завершения `Future`, не блокируя event loop.

```dart
// Синтаксис
Future<T> functionName() async {
  T result = await someFuture;
  return result;  // Автоматически оборачивается в Future<T>
}
```

`async` / `await` — синтаксический сахар поверх `Future.then()`, делающий асинхронный код линейным и читаемым.

## 2. Зачем это нужно

- **Читаемость** — плоский код вместо вложенных `.then()`.
- **Обработка ошибок** — обычный `try/catch` вместо `.catchError()`.
- **Отладка** — понятные стек-трейсы, работа breakpoints.
- **Контроль потока** — `if`, `for`, `while` с `await` внутри.

## 3. Как это работает

### Базовый async / await

```dart
// Без async/await (callback hell)
void loadDataOld() {
  fetchUser()
      .then((user) => fetchProfile(user))
      .then((profile) => fetchPosts(profile))
      .then((posts) => print(posts))
      .catchError((e) => print('Ошибка: $e'));
}

// С async/await — линейный код
Future<void> loadData() async {
  try {
    final user = await fetchUser();
    final profile = await fetchProfile(user);
    final posts = await fetchPosts(profile);
    print(posts);
  } catch (e) {
    print('Ошибка: $e');
  }
}

Future<String> fetchUser() async =>
    Future.delayed(Duration(milliseconds: 100), () => 'User');
Future<String> fetchProfile(String user) async =>
    Future.delayed(Duration(milliseconds: 100), () => 'Profile($user)');
Future<List<String>> fetchPosts(String profile) async =>
    Future.delayed(Duration(milliseconds: 100), () => ['Post 1', 'Post 2']);
```

### Возвращаемые типы

```dart
// Future<int> — возвращает int
Future<int> getAge() async {
  return 25; // Автоматически → Future.value(25)
}

// Future<void> — ничего не возвращает
Future<void> log(String msg) async {
  await Future.delayed(Duration(milliseconds: 10));
  print(msg);
}

// Можно вернуть Future напрямую — не двойная обёртка
Future<int> doubled() async {
  return await getAge(); // ← await не обязателен, но допустим
}

// Без await — тоже работает
Future<int> doubled2() async {
  return getAge(); // Dart «разворачивает» Future автоматически
}
```

### try / catch / finally с await

```dart
Future<String> riskyOperation() async {
  await Future.delayed(Duration(milliseconds: 100));
  throw FormatException('Неверный формат');
}

Future<void> main() async {
  try {
    final result = await riskyOperation();
    print('Результат: $result');
  } on FormatException catch (e) {
    print('Ошибка формата: $e');
  } on TimeoutException catch (e) {
    print('Таймаут: $e');
  } catch (e, stackTrace) {
    print('Неизвестная ошибка: $e');
    print('Stack trace: $stackTrace');
  } finally {
    print('Очистка ресурсов');
  }
}
```

### await в циклах

```dart
Future<void> processSequentially(List<String> urls) async {
  // Последовательная обработка — каждый await ждёт предыдущий
  for (final url in urls) {
    final data = await fetch(url);
    print('Загружено: $data');
  }
}

Future<void> processParallel(List<String> urls) async {
  // ✅ Параллельная обработка — Future.wait
  final futures = urls.map(fetch);
  final results = await Future.wait(futures);
  for (final data in results) {
    print('Загружено: $data');
  }
}

Future<String> fetch(String url) =>
    Future.delayed(Duration(milliseconds: 200), () => 'data($url)');
```

### await в условиях

```dart
Future<void> conditionalLoad() async {
  final config = await loadConfig();

  // await внутри if — обычный поток управления
  if (config['featureEnabled'] == true) {
    final data = await fetchFeatureData();
    print('Feature: $data');
  } else {
    print('Feature отключена');
  }

  // await в тернарном операторе
  final result = config['useCache'] == true
      ? await loadFromCache()
      : await loadFromNetwork();
  print(result);
}

Future<Map<String, dynamic>> loadConfig() async => {'featureEnabled': true, 'useCache': false};
Future<String> fetchFeatureData() async => 'feature_data';
Future<String> loadFromCache() async => 'cached';
Future<String> loadFromNetwork() async => 'network';
```

### Множественный await и деструктуризация

```dart
Future<void> main() async {
  // Последовательный await (медленно, если независимы)
  final a = await fetchA();
  final b = await fetchB();

  // ✅ Параллельный запуск + деструктуризация (Dart 3)
  final (x, y) = await (fetchA(), fetchB()).wait;
  // .wait на Record из Future — параллельное выполнение (package:async)

  // Через Future.wait
  final [p, q] = await Future.wait([fetchA(), fetchB()]);
  print('$p, $q');
}

Future<int> fetchA() => Future.delayed(Duration(seconds: 1), () => 1);
Future<int> fetchB() => Future.delayed(Duration(seconds: 1), () => 2);
```

### async\* и yield — генераторы (синтаксис для Stream)

```dart
// async* — возвращает Stream<T>
Stream<int> countDown(int from) async* {
  for (var i = from; i >= 0; i--) {
    await Future.delayed(Duration(milliseconds: 500));
    yield i; // Отправляет значение в Stream
  }
}

// yield* — делегирует другому Stream
Stream<int> fullSequence() async* {
  yield* countDown(3); // 3, 2, 1, 0
  yield* countDown(2); // 2, 1, 0
}

void main() async {
  // await for — итерация по Stream
  await for (final n in countDown(3)) {
    print(n); // 3, 2, 1, 0
  }
}
```

### sync\* и yield — синхронные генераторы

```dart
// sync* — возвращает Iterable<T>
Iterable<int> range(int start, int end) sync* {
  for (var i = start; i < end; i++) {
    yield i; // Ленивая генерация
  }
}

// yield* — делегирует другому Iterable
Iterable<int> pyramid(int n) sync* {
  yield* range(1, n + 1);   // 1..n
  yield n;                    // n
  yield* range(1, n).toList().reversed; // n-1..1
}

void main() {
  for (final n in range(0, 5)) {
    print(n); // 0, 1, 2, 3, 4
  }
}
```

### Отложенная инициализация с late и async

```dart
class Service {
  late final Future<String> _config = _loadConfig();

  Future<String> _loadConfig() async {
    await Future.delayed(Duration(milliseconds: 100));
    return 'loaded_config';
  }

  Future<void> doWork() async {
    // Первый вызов — загрузка; последующие — кеш
    final config = await _config;
    print('Работаю с: $config');
  }
}

void main() async {
  final service = Service();
  await service.doWork(); // Загрузка
  await service.doWork(); // Кеш (повторно _loadConfig НЕ вызывается)
}
```

## 4. Минимальный пример

```dart
Future<String> greet(String name) async {
  await Future.delayed(Duration(seconds: 1));
  return 'Привет, $name!';
}

void main() async {
  final message = await greet('Алексей');
  print(message); // Привет, Алексей!
}
```

## 5. Практический пример

### Пошаговый pipeline с retry и logging

```dart
import 'dart:math';

/// Имитация обработки данных с пошаговым pipeline
class DataPipeline {
  final _random = Random();

  /// Этап 1: Загрузка сырых данных
  Future<List<String>> fetchRawData() async {
    print('📥 Загрузка данных...');
    await Future.delayed(Duration(milliseconds: 300));
    return ['  Alice,30 ', 'Bob,25', ' Carol,35 ', '', 'Dave,28'];
  }

  /// Этап 2: Очистка данных
  Future<List<String>> cleanData(List<String> raw) async {
    print('🧹 Очистка данных...');
    await Future.delayed(Duration(milliseconds: 100));
    return raw
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Этап 3: Парсинг
  Future<List<({String name, int age})>> parse(List<String> clean) async {
    print('🔄 Парсинг...');
    await Future.delayed(Duration(milliseconds: 100));

    return clean.map((line) {
      final parts = line.split(',');
      if (parts.length != 2) throw FormatException('Неверный формат: $line');
      return (name: parts[0].trim(), age: int.parse(parts[1].trim()));
    }).toList();
  }

  /// Этап 4: Валидация
  Future<List<({String name, int age})>> validate(
      List<({String name, int age})> records) async {
    print('✅ Валидация...');
    await Future.delayed(Duration(milliseconds: 100));
    return records.where((r) => r.age >= 18 && r.age <= 100).toList();
  }

  /// Retry-обёртка
  Future<T> withRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        print('⚠️ Попытка $attempt/$maxAttempts не удалась: $e');
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(delay * attempt); // Exponential backoff
      }
    }
    throw StateError('Unreachable');
  }

  /// Полный pipeline
  Future<void> run() async {
    final stopwatch = Stopwatch()..start();

    try {
      final raw = await withRetry(fetchRawData);
      final clean = await cleanData(raw);
      final parsed = await parse(clean);
      final valid = await validate(parsed);

      print('\n📊 Результат (${valid.length} записей):');
      for (final r in valid) {
        print('   ${r.name}, возраст: ${r.age}');
      }
    } catch (e) {
      print('❌ Pipeline failed: $e');
    } finally {
      print('\n⏱ Время: ${stopwatch.elapsed}');
    }
  }
}

void main() async {
  await DataPipeline().run();
}

// Вывод:
// 📥 Загрузка данных...
// 🧹 Очистка данных...
// 🔄 Парсинг...
// ✅ Валидация...
//
// 📊 Результат (4 записей):
//    Alice, возраст: 30
//    Bob, возраст: 25
//    Carol, возраст: 35
//    Dave, возраст: 28
//
// ⏱ Время: 0:00:00.600xxx
```

## 6. Что происходит под капотом

```
Future<int> example() async {
  print('A');
  final x = await Future.value(1);
  print('B');
  final y = await Future.value(2);
  print('C');
  return x + y;
}

Компилятор трансформирует в state machine:

  example() {
    state = 0;
    completer = Completer<int>();

    void step() {
      switch (state) {
        case 0:
          print('A');
          Future.value(1).then((result) {
            x = result;
            state = 1;
            scheduleMicrotask(step);
          });
          break;
        case 1:
          print('B');
          Future.value(2).then((result) {
            y = result;
            state = 2;
            scheduleMicrotask(step);
          });
          break;
        case 2:
          print('C');
          completer.complete(x + y);
          break;
      }
    }

    scheduleMicrotask(step);
    return completer.future;
  }

Каждый await → точка приостановки:
  1. Сохраняется состояние (state machine)
  2. Подписка на Future через .then()
  3. Когда Future завершается → переход к следующему state
  4. Всё происходит в том же потоке (main isolate)

async-функция НЕ создаёт новый поток!
Она просто «паркует» выполнение и регистрирует callback.
```

## 7. Производительность и ресурсы

| Аспект                       | Стоимость                             |
| ---------------------------- | ------------------------------------- |
| `async` функция              | Создание state machine + Completer    |
| `await Future.value(x)`      | Один microtask tick (не моментально!) |
| `await` в цикле (N итераций) | N microtask ticks                     |
| `return x` из async          | Future.value(x) + microtask           |
| `Future.wait(N)`             | Параллельно, один tick после всех     |

**Рекомендации:**

- Не оборачивайте в `async` то, что можно вернуть напрямую.
- `await` даже для `Future.value` — это один tick; в hot paths используйте `FutureOr`.
- Параллельные задачи → `Future.wait`, не последовательные `await`.

## 8. Частые ошибки и антипаттерны

### ❌ Лишний async/await

```dart
// ❌ Обёртка ничего не добавляет
Future<int> bad() async {
  return await compute(); // Лишний await
}

// ✅ Передаём Future напрямую
Future<int> good() {
  return compute(); // Без async — нет overhead
}

// ⚠️ Исключение: если нужен try/catch, async обязателен
Future<int> withErrorHandling() async {
  try {
    return await compute();
  } catch (e) {
    return -1; // Fallback
  }
}

Future<int> compute() => Future.value(42);
```

### ❌ async void — потеря ошибок

```dart
// ❌ async void — ошибки теряются, нельзя await
async void badHandler() {
  throw Exception('Потеряна!');
}

// ✅ Возвращайте Future<void>
Future<void> goodHandler() async {
  throw Exception('Можно поймать');
}

void main() async {
  badHandler(); // ❌ Exception не поймать!

  try {
    await goodHandler(); // ✅ Ловим
  } catch (e) {
    print(e);
  }
}
```

### ❌ await в цикле вместо параллельного запуска

```dart
// ❌ Медленно: 5 последовательных запросов
Future<void> slow() async {
  for (final id in [1, 2, 3, 4, 5]) {
    await processItem(id); // Ждёт каждый
  }
}

// ✅ Быстро: 5 параллельных запросов
Future<void> fast() async {
  await Future.wait(
    [1, 2, 3, 4, 5].map(processItem),
  );
}

Future<void> processItem(int id) =>
    Future.delayed(Duration(seconds: 1), () => print('Done $id'));
```

### ❌ Забыли await

```dart
Future<void> save(String data) async {
  await Future.delayed(Duration(milliseconds: 100));
  print('Saved: $data');
}

void main() async {
  save('important'); // ❌ Без await — может не выполниться до выхода!
  print('Done');     // Печатается ДО save

  // ✅
  await save('important');
  print('Done');
}
```

## 9. Сравнение с альтернативами

| Подход             | Читаемость     | Error handling | Отладка           | Когда             |
| ------------------ | -------------- | -------------- | ----------------- | ----------------- |
| `async/await`      | ✅ Линейный    | try/catch      | ✅ Стек-трейсы    | По умолчанию      |
| `.then()` chain    | ⚠️ Вложенность | .catchError    | ⚠️ Неясные трейсы | Простые цепочки   |
| `Completer`        | ⚠️ Ручное      | Ручное         | ✅                | Мосты, legacy API |
| `sync*` / `async*` | ✅             | try/catch      | ✅                | Генераторы        |

## 10. Когда НЕ стоит использовать

- **Чисто синхронный код** — `async` добавляет overhead; не оборачивайте `int add(int a, int b)` в `async`.
- **Горячие пути** — каждый `await` = один microtask tick; для высокочастотных вычислений это заметно.
- **`async void`** — почти всегда ошибка; используйте `Future<void>`.
- **Одноуровневая цепочка** — простой `future.then(print)` может быть проще `await`.

## 11. Краткое резюме

1. **`async`** — превращает функцию в возвращающую `Future<T>`.
2. **`await`** — приостанавливает до завершения Future, не блокируя поток.
3. **try/catch** — работает с `await` для обработки асинхронных ошибок.
4. **`async*` + `yield`** — создаёт `Stream<T>` (асинхронный генератор).
5. **`sync*` + `yield`** — создаёт `Iterable<T>` (синхронный генератор).
6. **Под капотом** — state machine с microtask scheduling.
7. **Не `async void`** — используйте `Future<void>`.
8. **Параллельность** — `Future.wait` вместо последовательных `await`.

---

> **Назад:** [9.1 Futures и обработка результатов](09_01_futures.md) · **Далее:** [9.3 Streams и реактивные последовательности](09_03_streams.md)
