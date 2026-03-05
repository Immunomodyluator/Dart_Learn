# 9.1 Futures и обработка результатов

## 1. Формальное определение

**`Future<T>`** — объект, представляющий **отложенное вычисление**, результатом которого будет значение типа `T` или ошибка. Future имеет два состояния: **uncompleted** (ожидание) и **completed** (завершён с данными или ошибкой).

```dart
abstract class Future<T> {
  factory Future(FutureOr<T> computation());
  factory Future.value(FutureOr<T> value);
  factory Future.error(Object error, [StackTrace? stackTrace]);
  factory Future.delayed(Duration duration, [FutureOr<T> computation()?]);

  Future<R> then<R>(FutureOr<R> onValue(T value), {Function? onError});
  Future<T> catchError(Function onError, {bool test(Object error)?});
  Future<T> whenComplete(FutureOr<void> action());
  Future<T> timeout(Duration timeLimit, {FutureOr<T> onTimeout()?});

  static Future<List<T>> wait<T>(Iterable<Future<T>> futures);
  static Future<T> any<T>(Iterable<Future<T>> futures);
}
```

## 2. Зачем это нужно

- **Неблокирующие операции** — I/O, сеть, таймеры возвращают `Future` вместо блокировки потока.
- **Композиция** — цепочки `then`, параллельный запуск через `Future.wait`.
- **Обработка ошибок** — `catchError`, `onError`, propagation по цепочке.
- **Единый интерфейс** — любая асинхронная операция → `Future<T>`.

## 3. Как это работает

### Создание Future

```dart
void main() {
  // 1. Через конструктор (вычисление откладывается на event loop)
  final f1 = Future(() => 42);

  // 2. Уже завершённый с значением
  final f2 = Future.value('готово');

  // 3. Уже завершённый с ошибкой
  final f3 = Future<int>.error(Exception('сбой'));

  // 4. С задержкой
  final f4 = Future.delayed(
    Duration(seconds: 2),
    () => 'Через 2 секунды',
  );

  // 5. Из синхронного или асинхронного значения (FutureOr)
  FutureOr<int> maybeAsync(bool sync) {
    if (sync) return 42;         // синхронно
    return Future.value(42);     // асинхронно
  }
}
```

### then — обработка результата

```dart
void main() {
  Future.value(10)
      .then((value) => value * 2)     // 20
      .then((value) => 'Ответ: $value') // 'Ответ: 20'
      .then(print);                     // Ответ: 20

  // then возвращает новый Future
  // Каждый .then — шаг в цепочке
}
```

### then с возвратом Future (flat map)

```dart
Future<String> fetchUser(int id) =>
    Future.delayed(Duration(milliseconds: 100), () => 'User_$id');

Future<String> fetchProfile(String user) =>
    Future.delayed(Duration(milliseconds: 100), () => 'Profile($user)');

void main() {
  // then автоматически «разворачивает» возвращённый Future
  fetchUser(1)
      .then((user) => fetchProfile(user)) // Future<String>, не Future<Future<String>>
      .then((profile) => print(profile));  // Profile(User_1)
}
```

### catchError — обработка ошибок

```dart
void main() {
  Future<int>.error(FormatException('bad'))
      .then((value) => print('Значение: $value'))  // ← пропускается
      .catchError(
        (error) => print('Ошибка формата: $error'),
        test: (error) => error is FormatException,  // Ловим только FormatException
      )
      .catchError(
        (error) => print('Другая ошибка: $error'),  // Ловим всё остальное
      );
}
```

### onError в then

```dart
void main() {
  Future<int>.error(Exception('сбой'))
      .then(
        (value) => print('OK: $value'),
        onError: (error, stackTrace) {
          print('Ошибка: $error');
          // Если onError не выбрасывает — ошибка считается обработанной
        },
      );
}
```

### whenComplete — аналог finally

```dart
void main() {
  Future.value(42)
      .then((value) => print('Значение: $value'))
      .catchError((e) => print('Ошибка: $e'))
      .whenComplete(() => print('Завершено'));
  // Вызывается в любом случае: и при успехе, и при ошибке
}
```

### timeout

```dart
void main() async {
  try {
    final result = await Future.delayed(
      Duration(seconds: 5),
      () => 'Долгая операция',
    ).timeout(
      Duration(seconds: 2),
      onTimeout: () => 'Таймаут!', // Fallback-значение
    );
    print(result); // Таймаут!
  } on TimeoutException catch (e) {
    // Без onTimeout — бросает TimeoutException
    print('Превышено время ожидания: $e');
  }
}
```

### Future.wait — параллельное выполнение

```dart
Future<String> loadConfig() =>
    Future.delayed(Duration(seconds: 1), () => 'config');
Future<String> loadUser() =>
    Future.delayed(Duration(seconds: 1), () => 'user');
Future<String> loadTheme() =>
    Future.delayed(Duration(seconds: 1), () => 'theme');

void main() async {
  final stopwatch = Stopwatch()..start();

  // Все три выполняются ПАРАЛЛЕЛЬНО
  final results = await Future.wait([
    loadConfig(),
    loadUser(),
    loadTheme(),
  ]);

  print(results);               // [config, user, theme]
  print('${stopwatch.elapsed}'); // ~1 секунда, НЕ 3!

  // Если любой Future завершится ошибкой — весь wait завершится ошибкой
  // eagerError: true — ошибка сразу, не ждёт остальных
}
```

### Future.wait с eagerError и cleanUp

```dart
void main() async {
  try {
    await Future.wait(
      [
        Future.value(1),
        Future<int>.error(Exception('сбой')),
        Future.value(3),
      ],
      eagerError: true,  // Не ждать остальных при первой ошибке
      cleanUp: (value) {
        // Вызывается для уже успешно завершённых Future
        print('Очистка: $value');
      },
    );
  } catch (e) {
    print('Ошибка: $e'); // Ошибка: Exception: сбой
  }
}
```

### Future.any — первый завершившийся

```dart
void main() async {
  final result = await Future.any([
    Future.delayed(Duration(seconds: 3), () => 'медленный'),
    Future.delayed(Duration(seconds: 1), () => 'быстрый'),
    Future.delayed(Duration(seconds: 2), () => 'средний'),
  ]);

  print(result); // быстрый
  // Остальные Future НЕ отменяются — Dart Future не cancelable
}
```

### Future.forEach — последовательная итерация

```dart
void main() async {
  final urls = ['url1', 'url2', 'url3'];

  await Future.forEach<String>(urls, (url) async {
    // Каждый вызов ждёт завершения предыдущего
    await Future.delayed(Duration(milliseconds: 500));
    print('Загружен: $url');
  });
  // url1, url2, url3 — строго последовательно
}
```

### FutureOr<T> — синхронный или асинхронный результат

```dart
import 'dart:async';

// FutureOr<T> = T | Future<T>
// Позволяет функции возвращать результат синхронно ИЛИ асинхронно

FutureOr<int> cachedFetch(Map<String, int> cache, String key) {
  if (cache.containsKey(key)) {
    return cache[key]!;  // Синхронно — без Future
  }
  return Future.delayed(
    Duration(milliseconds: 100),
    () {
      cache[key] = 42;
      return 42;         // Асинхронно
    },
  );
}

void main() async {
  final cache = <String, int>{};

  // Первый вызов — async
  final v1 = await cachedFetch(cache, 'key');
  print(v1); // 42

  // Второй вызов — sync (из кеша), но await тоже работает
  final v2 = await cachedFetch(cache, 'key');
  print(v2); // 42
}
```

### Completer — ручное управление Future

```dart
import 'dart:async';

class TaskQueue {
  final _queue = <Completer<String>>[];

  Future<String> enqueue(String task) {
    final completer = Completer<String>();
    _queue.add(completer);
    print('Задача "$task" в очереди');
    return completer.future; // Возвращаем Future, который завершим позже
  }

  void processNext(String result) {
    if (_queue.isEmpty) return;
    final completer = _queue.removeAt(0);
    completer.complete(result); // Завершаем Future вручную
  }

  void failNext(Object error) {
    if (_queue.isEmpty) return;
    final completer = _queue.removeAt(0);
    completer.completeError(error); // Завершаем с ошибкой
  }
}

void main() async {
  final queue = TaskQueue();

  // Кто-то ждёт результат
  final future = queue.enqueue('обработать данные');

  // Кто-то завершает задачу
  queue.processNext('результат');

  print(await future); // результат
}
```

## 4. Минимальный пример

```dart
void main() {
  final future = Future.delayed(
    Duration(seconds: 1),
    () => 'Готово!',
  );

  future.then((value) => print(value)); // Готово!

  print('Ждём...'); // Печатается ПЕРВЫМ!
}
```

## 5. Практический пример

### Параллельная загрузка данных с fallback и timeout

```dart
import 'dart:async';

typedef JsonMap = Map<String, dynamic>;

/// Имитация API-клиента
class ApiClient {
  final String baseUrl;
  final Duration defaultTimeout;

  ApiClient(this.baseUrl, {this.defaultTimeout = const Duration(seconds: 5)});

  Future<JsonMap> get(String path) async {
    print('  GET $baseUrl$path ...');
    // Имитация сетевого запроса
    await Future.delayed(Duration(milliseconds: 300));

    return switch (path) {
      '/user'     => {'id': 1, 'name': 'Алексей'},
      '/settings' => {'theme': 'dark', 'lang': 'ru'},
      '/stats'    => {'visits': 1024, 'rating': 4.8},
      _           => throw Exception('404: $path'),
    };
  }
}

/// Загрузка данных для дашборда
Future<JsonMap> loadDashboard(ApiClient api) async {
  try {
    // Параллельная загрузка трёх ресурсов с общим timeout
    final results = await Future.wait([
      api.get('/user'),
      api.get('/settings'),
      api.get('/stats'),
    ]).timeout(api.defaultTimeout);

    return {
      'user': results[0],
      'settings': results[1],
      'stats': results[2],
      'loadedAt': DateTime.now().toIso8601String(),
    };
  } on TimeoutException {
    // Fallback — минимальные данные
    return {
      'user': {'name': 'Гость'},
      'settings': {'theme': 'light', 'lang': 'ru'},
      'stats': null,
      'loadedAt': DateTime.now().toIso8601String(),
      'partial': true,
    };
  }
}

void main() async {
  final api = ApiClient('https://api.example.com');

  final dashboard = await loadDashboard(api);

  print('\nДашборд:');
  dashboard.forEach((key, value) => print('  $key: $value'));
}

// Вывод:
//   GET https://api.example.com/user ...
//   GET https://api.example.com/settings ...
//   GET https://api.example.com/stats ...
//
// Дашборд:
//   user: {id: 1, name: Алексей}
//   settings: {theme: dark, lang: ru}
//   stats: {visits: 1024, rating: 4.8}
//   loadedAt: 2026-03-05T10:00:00.000
```

## 6. Что происходит под капотом

```
Future.delayed(Duration(seconds: 1), () => 42)
  .then((v) => v * 2)
  .then(print);

Timeline:
  t=0ms:  Future.delayed → регистрирует Timer в event queue
          .then(v * 2) → подписывается на результат Future
          .then(print) → подписывается на результат предыдущего

  t=0ms:  main() завершается → event loop начинает обработку

  Event Loop:
    ┌─ Microtask queue: (пусто)
    │
    └─ Event queue:
         [Timer(1000ms, () => 42)]
         ...другие события...

  t=1000ms: Timer срабатывает
    → Future завершается с 42
    → Планирует microtask: вызвать then-callback

    Microtask queue:
      [() => 42 * 2]        → выполняется → результат 84
      [() => print(84)]     → выполняется → печатает 84

Ключевое:
  - then-callback выполняется как MICROTASK (приоритетнее событий)
  - Future — НЕ thread, НЕ coroutine, а chainable callback
  - Completer позволяет создать Future и завершить его вручную
  - Future НЕЛЬЗЯ отменить (нет cancel())
```

## 7. Производительность и ресурсы

| Аспект              | Стоимость                            |
| ------------------- | ------------------------------------ |
| `Future.value(x)`   | Минимальная — completion в microtask |
| `Future(() => ...)` | Один event loop tick                 |
| `Future.delayed(d)` | Timer + один tick                    |
| `.then(...)`        | Подписка + microtask при completion  |
| `Future.wait(N)`    | N параллельных + один результат      |
| `Completer`         | Один объект + Future                 |

**Рекомендации:**

- `Future.wait` для параллельных запросов — быстрее последовательных `await`.
- `FutureOr<T>` для кеша — экономит event loop tick при синхронном возврате.
- Не создавайте Future внутри tight loops — overhead на scheduling.

## 8. Частые ошибки и антипаттерны

### ❌ Забытый await / неиспользованный Future

```dart
void main() {
  // ❌ Future создаётся, но никто не ждёт и не обрабатывает
  Future.delayed(Duration(seconds: 1), () => print('done'));
  print('exit'); // Программа может завершиться ДО выполнения Future

  // ✅ Используйте await или .then
  // await Future.delayed(...);
}
```

### ❌ Последовательный await вместо Future.wait

```dart
void main() async {
  // ❌ Последовательно: ~3 секунды
  final a = await loadA(); // 1 сек
  final b = await loadB(); // 1 сек
  final c = await loadC(); // 1 сек

  // ✅ Параллельно: ~1 секунда
  final [a2, b2, c2] = await Future.wait([loadA(), loadB(), loadC()]);
}

Future<int> loadA() => Future.delayed(Duration(seconds: 1), () => 1);
Future<int> loadB() => Future.delayed(Duration(seconds: 1), () => 2);
Future<int> loadC() => Future.delayed(Duration(seconds: 1), () => 3);
```

### ❌ Ошибка не обработана

```dart
void main() {
  // ❌ Unhandled Future error → crash
  Future<int>.error(Exception('oops'));

  // ✅ Обработайте ошибку
  Future<int>.error(Exception('oops')).catchError((e) => print(e));
}
```

### ❌ Completer.complete() дважды

```dart
void main() {
  final c = Completer<int>();
  c.complete(1);
  // c.complete(2); // ❌ StateError: Future already completed

  // ✅ Проверяйте c.isCompleted
  if (!c.isCompleted) c.complete(2);
}
```

## 9. Сравнение с альтернативами

| Аспект              | Future                | Stream            | Isolate.run | sync                 |
| ------------------- | --------------------- | ----------------- | ----------- | -------------------- |
| Количество значений | 1                     | 0..N              | 1           | 1                    |
| Блокирует поток     | ❌                    | ❌                | ❌          | ✅                   |
| Cancelable          | ❌                    | ✅ (subscription) | ❌          | N/A                  |
| Параллелизм         | Кооперативный         | Кооперативный     | Настоящий   | Нет                  |
| Когда               | Одноразовый результат | Поток данных      | CPU-задача  | Мгновенный результат |

## 10. Когда НЕ стоит использовать

- **Синхронные вычисления** — `Future(() => 2 + 2)` → просто `2 + 2`.
- **Поток данных** — для 0..N значений используйте `Stream`.
- **CPU-bound задачи** — Future не создаёт новый поток; используйте `Isolate.run`.
- **Отменяемые операции** — Future нельзя отменить; используйте `CancelableOperation` из `package:async`.
- **Fire-and-forget без ErrorHandler** — необработанная ошибка в Future крашит приложение.

## 11. Краткое резюме

1. **`Future<T>`** — одноразовый контейнер для отложенного значения или ошибки.
2. **`.then()`** — цепочка обработки; автоматически разворачивает вложенные Future.
3. **`.catchError()`** — перехват ошибок в цепочке; аналог `catch` для Future.
4. **`.whenComplete()`** — аналог `finally`; вызывается при любом исходе.
5. **`Future.wait()`** — параллельное выполнение N Future, результат — `List<T>`.
6. **`Future.any()`** — первый завершившийся из списка.
7. **`Completer`** — ручное создание и управление Future.
8. **`FutureOr<T>`** — тип, допускающий и синхронный `T`, и `Future<T>`.
9. **Future нельзя отменить** — это фундаментальное ограничение.

---

> **Назад:** [9.0 Асинхронность — обзор](09_00_overview.md) · **Далее:** [9.2 async / await](09_02_async_await.md)
