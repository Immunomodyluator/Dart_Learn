# 9.3 Streams и реактивные последовательности

## 1. Формальное определение

**`Stream<T>`** — асинхронная последовательность значений типа `T`, доставляемых во времени. В отличие от `Future<T>` (одно значение), `Stream` может выдавать **0..N значений** и завершаться нормально или ошибкой.

Два вида:

- **Single-subscription** — один слушатель; default для большинства потоков (File I/O, HTTP response body).
- **Broadcast** — множество слушателей; события вроде кликов, WebSocket.

```dart
abstract class Stream<T> {
  StreamSubscription<T> listen(
    void onData(T event)?,
    {Function? onError, void onDone()?, bool? cancelOnError}
  );

  Stream<T> where(bool test(T event));
  Stream<S> map<S>(S convert(T event));
  Future<T> get first;
  Future<T> get last;
  Future<List<T>> toList();
  // ... 40+ методов
}
```

## 2. Зачем это нужно

- **Реактивные данные** — бесконечные потоки (WebSocket, датчики, таймеры).
- **Lazy evaluation** — данные вычисляются по мере запроса.
- **Back-pressure** — подписчик контролирует паузу/возобновление.
- **Трансформации** — `map`, `where`, `expand`, `debounce` — функциональный стиль.

## 3. Как это работает

### Создание Stream

```dart
import 'dart:async';

void main() {
  // 1. Stream.fromIterable — из готовой коллекции
  final s1 = Stream.fromIterable([1, 2, 3, 4, 5]);

  // 2. Stream.periodic — периодические значения
  final s2 = Stream.periodic(
    Duration(seconds: 1),
    (count) => count, // 0, 1, 2, 3, ...
  ).take(5); // Берём первые 5

  // 3. Stream.value — одно значение
  final s3 = Stream.value(42);

  // 4. Stream.error — ошибка
  final s4 = Stream<int>.error(Exception('ошибка'));

  // 5. Stream.empty — пустой поток
  final s5 = Stream<int>.empty();

  // 6. Stream.fromFuture — обёртка над Future
  final s6 = Stream.fromFuture(Future.value('hello'));

  // 7. Stream.fromFutures — несколько Future
  final s7 = Stream.fromFutures([
    Future.delayed(Duration(seconds: 2), () => 'B'),
    Future.delayed(Duration(seconds: 1), () => 'A'),
  ]); // Порядок: кто завершится первым → A, B
}
```

### async\* и yield — генератор

```dart
Stream<int> fibonacci(int count) async* {
  int a = 0, b = 1;
  for (var i = 0; i < count; i++) {
    yield a; // Отправляет значение подписчику
    final next = a + b;
    a = b;
    b = next;
  }
}

// yield* — делегирование другому Stream
Stream<int> twoSequences() async* {
  yield* Stream.fromIterable([1, 2, 3]);
  yield* Stream.fromIterable([10, 20, 30]);
  // Результат: 1, 2, 3, 10, 20, 30
}

void main() async {
  await for (final n in fibonacci(8)) {
    print(n); // 0, 1, 1, 2, 3, 5, 8, 13
  }
}
```

### listen — подписка

```dart
void main() {
  final stream = Stream.fromIterable([1, 2, 3]);

  final subscription = stream.listen(
    (data) => print('Данные: $data'),
    onError: (error) => print('Ошибка: $error'),
    onDone: () => print('Поток завершён'),
    cancelOnError: false, // Продолжать при ошибках
  );

  // Управление подпиской
  // subscription.pause();
  // subscription.resume();
  // subscription.cancel();
}
```

### await for — итерация

```dart
void main() async {
  final stream = Stream.periodic(
    Duration(milliseconds: 200),
    (i) => i,
  ).take(5);

  // await for — последовательное чтение
  await for (final value in stream) {
    print('Получено: $value');
  }
  print('Поток завершён');
}
```

### Трансформации

```dart
void main() async {
  final numbers = Stream.fromIterable([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

  // where — фильтрация
  // map — преобразование
  // take — ограничение количества
  final result = numbers
      .where((n) => n.isEven)       // 2, 4, 6, 8, 10
      .map((n) => n * n)            // 4, 16, 36, 64, 100
      .take(3);                      // 4, 16, 36

  await for (final n in result) {
    print(n); // 4, 16, 36
  }
}
```

### Полезные методы Stream

```dart
void main() async {
  final s = Stream.fromIterable([3, 1, 4, 1, 5, 9, 2, 6]);

  // Аккумуляторы
  print(await s.length);                    // 8
  // Нужно пересоздать — single-subscription!
  print(await Stream.fromIterable([3, 1, 4]).first); // 3
  print(await Stream.fromIterable([3, 1, 4]).last);  // 4
  print(await Stream.fromIterable([3, 1, 4]).toList()); // [3, 1, 4]

  // fold / reduce
  final sum = await Stream.fromIterable([1, 2, 3, 4, 5])
      .fold<int>(0, (prev, elem) => prev + elem);
  print(sum); // 15

  // any / every
  final hasEven = await Stream.fromIterable([1, 2, 3]).any((n) => n.isEven);
  print(hasEven); // true

  // distinct — убирает дубликаты подряд
  final distinct = Stream.fromIterable([1, 1, 2, 2, 3, 1]).distinct();
  print(await distinct.toList()); // [1, 2, 3, 1]

  // expand — flatMap
  final expanded = Stream.fromIterable([1, 2, 3])
      .expand((n) => [n, n * 10]); // 1, 10, 2, 20, 3, 30
  print(await expanded.toList());

  // asyncMap — map с асинхронным преобразованием
  final delayed = Stream.fromIterable([1, 2, 3])
      .asyncMap((n) => Future.delayed(Duration(milliseconds: 100), () => n * 2));
  print(await delayed.toList()); // [2, 4, 6]

  // asyncExpand — flatMap с асинхронным преобразованием
  final asyncExpanded = Stream.fromIterable([1, 2])
      .asyncExpand((n) => Stream.fromIterable([n, n * 10]));
  print(await asyncExpanded.toList()); // [1, 10, 2, 20]
}
```

### Single-subscription vs Broadcast

```dart
import 'dart:async';

void main() async {
  // === SINGLE-SUBSCRIPTION ===
  final single = Stream.fromIterable([1, 2, 3]);
  single.listen((d) => print('A: $d'));
  // single.listen((d) => print('B: $d')); // ❌ StateError!

  // === BROADCAST ===
  final controller = StreamController<int>.broadcast();
  final broadcast = controller.stream;

  // Несколько подписчиков — OK
  broadcast.listen((d) => print('Sub1: $d'));
  broadcast.listen((d) => print('Sub2: $d'));

  controller.add(1);
  controller.add(2);
  await controller.close();

  // Преобразование single → broadcast
  final broadcastFromSingle = Stream.fromIterable([1, 2, 3]).asBroadcastStream();
  broadcastFromSingle.listen((d) => print('X: $d'));
  broadcastFromSingle.listen((d) => print('Y: $d'));
}
```

### StreamController — создание потоков

```dart
import 'dart:async';

void main() async {
  // Single-subscription controller
  final controller = StreamController<String>();

  // Подписка
  controller.stream.listen(
    (data) => print('Получено: $data'),
    onDone: () => print('Закрыт'),
  );

  // Добавление данных
  controller.add('Hello');
  controller.add('World');

  // sink — альтернативный способ добавления
  controller.sink.add('через sink');

  // Добавление ошибки
  controller.addError(Exception('ой'));

  // Закрытие
  await controller.close();

  // controller.add('ещё'); // ❌ StateError: closed
}
```

### StreamController с onListen / onCancel

```dart
import 'dart:async';

StreamController<int> createTimerStream() {
  Timer? timer;
  var count = 0;

  late StreamController<int> controller;
  controller = StreamController<int>(
    onListen: () {
      // Начинаем генерировать, когда есть подписчик
      print('Подписчик появился — старт');
      timer = Timer.periodic(Duration(seconds: 1), (_) {
        controller.add(count++);
      });
    },
    onPause: () {
      print('Пауза');
      timer?.cancel();
    },
    onResume: () {
      print('Возобновление');
      timer = Timer.periodic(Duration(seconds: 1), (_) {
        controller.add(count++);
      });
    },
    onCancel: () {
      print('Отписка — стоп');
      timer?.cancel();
    },
  );

  return controller;
}

void main() async {
  final controller = createTimerStream();
  final sub = controller.stream.listen((n) => print('tick: $n'));

  await Future.delayed(Duration(seconds: 3));
  sub.pause();
  await Future.delayed(Duration(seconds: 2));
  sub.resume();
  await Future.delayed(Duration(seconds: 2));
  await sub.cancel();
  await controller.close();
}
```

### StreamTransformer

```dart
import 'dart:async';

/// Трансформер: буферизация по N элементов
StreamTransformer<T, List<T>> bufferCount<T>(int count) {
  return StreamTransformer.fromHandlers(
    handleData: (data, sink) {
      // Используем зону для хранения буфера — упрощённо
    },
  );
}

/// Трансформер через bind
class DoubleTransformer extends StreamTransformerBase<int, int> {
  @override
  Stream<int> bind(Stream<int> stream) {
    return stream.map((n) => n * 2);
  }
}

/// Debounce через StreamTransformer.fromHandlers
StreamTransformer<T, T> debounce<T>(Duration duration) {
  Timer? timer;
  return StreamTransformer.fromHandlers(
    handleData: (data, sink) {
      timer?.cancel();
      timer = Timer(duration, () => sink.add(data));
    },
    handleDone: (sink) {
      timer?.cancel();
      sink.close();
    },
  );
}

void main() async {
  // Использование трансформера
  final stream = Stream.fromIterable([1, 2, 3, 4, 5]);
  final doubled = stream.transform(DoubleTransformer());
  print(await doubled.toList()); // [2, 4, 6, 8, 10]
}
```

## 4. Минимальный пример

```dart
import 'dart:async';

void main() async {
  final controller = StreamController<String>();

  controller.stream.listen((msg) => print('Сообщение: $msg'));

  controller.add('Привет');
  controller.add('Мир');

  await controller.close();
}
```

## 5. Практический пример

### Реактивный поиск с debounce

```dart
import 'dart:async';

/// Имитация поисковой функции
Future<List<String>> search(String query) async {
  await Future.delayed(Duration(milliseconds: 200)); // Имитация API
  final allItems = ['Dart', 'Flutter', 'Darling', 'Dashboard', 'Data', 'Flow'];
  return allItems
      .where((item) => item.toLowerCase().contains(query.toLowerCase()))
      .toList();
}

/// Контроллер реактивного поиска
class SearchController {
  final _queryController = StreamController<String>();
  late final Stream<List<String>> results;

  SearchController() {
    results = _queryController.stream
        .distinct()                             // Игнорируем дубликаты
        .transform(_debounce(Duration(milliseconds: 300))) // Debounce
        .asyncMap((query) async {               // Поиск
          if (query.isEmpty) return <String>[];
          print('🔍 Ищем: "$query"');
          return search(query);
        });
  }

  void updateQuery(String query) {
    _queryController.add(query);
  }

  Future<void> dispose() async {
    await _queryController.close();
  }

  /// Debounce-трансформер
  StreamTransformer<T, T> _debounce<T>(Duration duration) {
    Timer? timer;
    return StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        timer?.cancel();
        timer = Timer(duration, () => sink.add(data));
      },
      handleDone: (sink) {
        timer?.cancel();
        sink.close();
      },
    );
  }
}

void main() async {
  final controller = SearchController();

  // Подписка на результаты
  final sub = controller.results.listen((results) {
    print('   Результаты: $results');
  });

  // Имитация ввода пользователя (быстрые нажатия)
  controller.updateQuery('D');
  await Future.delayed(Duration(milliseconds: 100));
  controller.updateQuery('Da');
  await Future.delayed(Duration(milliseconds: 100));
  controller.updateQuery('Dar');
  await Future.delayed(Duration(milliseconds: 100));
  controller.updateQuery('Dart');

  // Ждём debounce + поиск
  await Future.delayed(Duration(seconds: 1));

  // Только ПОСЛЕДНИЙ запрос «Dart» отправляется
  // 🔍 Ищем: "Dart"
  //    Результаты: [Dart]

  await sub.cancel();
  await controller.dispose();
}
```

## 6. Что происходит под капотом

```
Stream.fromIterable([1, 2, 3]).listen(print);

Внутренний механизм:
  1. Создаётся _IterableStream(iterable)
  2. .listen() → создаётся StreamSubscription
  3. Subscription планирует microtask для первого элемента
  4. Microtask: вызывает onData(1), планирует следующий
  5. Microtask: вызывает onData(2), планирует следующий
  6. Microtask: вызывает onData(3), вызывает onDone()

StreamController.add(data):
  1. Проверяет: есть подписчик? Если нет → буферизация (или отброс для broadcast)
  2. Проверяет: подписчик на паузе? Если да → буфер
  3. Планирует microtask: вызвать onData(data)

Pause / Resume / Cancel:
  - pause() → устанавливает флаг; данные буферизуются
  - resume() → сбрасывает флаг; буфер отправляется
  - cancel() → подписчик отписывается; controller.onCancel()

Broadcast vs Single:
  Single: один _BufferingStreamSubscription, буфер
  Broadcast: _BroadcastStreamController, список подписчиков
             нет буферизации! Если нет подписчиков — данные теряются
```

## 7. Производительность и ресурсы

| Аспект                   | Стоимость                 |
| ------------------------ | ------------------------- |
| `Stream.fromIterable(N)` | N microtasks              |
| `StreamController.add()` | 1 microtask per event     |
| `.where()` / `.map()`    | Обёртка → 1 доп. вызов    |
| `.transform()`           | Зависит от трансформера   |
| `.asBroadcastStream()`   | Дополнительный controller |
| `await for`              | Подписка + pause/resume   |

**Рекомендации:**

- Не создавайте Stream для 1 значения — используйте `Future`.
- `StreamController` требует `close()` — иначе утечка памяти.
- Broadcast без подписчиков теряет данные — учитывайте.
- Цепочки трансформаций создают обёртки; для сложных пайплайнов — используйте `StreamTransformer`.

## 8. Частые ошибки и антипаттерны

### ❌ Повторная подписка на single-subscription stream

```dart
void main() {
  final stream = Stream.fromIterable([1, 2, 3]);
  stream.listen(print);       // ✅
  // stream.listen(print);    // ❌ StateError: Stream already listened to

  // ✅ Решение: asBroadcastStream()
  final broadcast = Stream.fromIterable([1, 2, 3]).asBroadcastStream();
  broadcast.listen(print);    // ✅
  broadcast.listen(print);    // ✅
}
```

### ❌ Забыли закрыть StreamController

```dart
class MyWidget {
  final _controller = StreamController<String>();

  // ❌ Утечка памяти — controller не закрыт
  void dispose() {
    // _controller.close(); // Забыли!
  }
}

// ✅ Всегда закрывайте
class MyWidgetFixed {
  final _controller = StreamController<String>();

  Future<void> dispose() async {
    await _controller.close();
  }
}
```

### ❌ Забыли отменить подписку

```dart
void main() async {
  final stream = Stream.periodic(Duration(seconds: 1), (i) => i);
  final sub = stream.listen(print);

  await Future.delayed(Duration(seconds: 3));
  // ❌ sub продолжает слушать, даже если не нужно

  // ✅ Отменяем
  await sub.cancel();
}
```

### ❌ Broadcast stream без подписчиков

```dart
void main() async {
  final controller = StreamController<int>.broadcast();

  // Данные отправляются ДО подписки → ТЕРЯЮТСЯ
  controller.add(1);
  controller.add(2);

  controller.stream.listen((d) => print('Got: $d'));

  controller.add(3); // ✅ Это получено
  await controller.close();
  // Выведет только: Got: 3
}
```

## 9. Сравнение с альтернативами

| Аспект        | Stream            | Future | Iterable | RxDart |
| ------------- | ----------------- | ------ | -------- | ------ |
| Значений      | 0..N              | 1      | 0..N     | 0..N   |
| Async         | ✅                | ✅     | ❌       | ✅     |
| Lazy          | ✅                | ❌     | ✅       | ✅     |
| Back-pressure | ✅ (pause/resume) | N/A    | N/A      | ✅     |
| Cancel        | ✅ (subscription) | ❌     | N/A      | ✅     |
| Операторы     | ~40               | ~10    | ~50      | ~100+  |

## 10. Когда НЕ стоит использовать

- **Одно значение** — используйте `Future<T>`.
- **Синхронная коллекция** — используйте `Iterable<T>` или `List<T>`.
- **Сложные реактивные пайплайны** — рассмотрите `package:rxdart` (throttle, combineLatest, etc.).
- **Конечный набор данных** — `Stream.fromIterable` проигрывает `Iterable` по overhead.
- **CPU-intensive** — Stream не создаёт новый поток; для CPU-задач нужны Isolates.

## 11. Краткое резюме

1. **`Stream<T>`** — асинхронная последовательность 0..N значений.
2. **Single-subscription** — один слушатель; **broadcast** — множество.
3. **`async*` + `yield`** — генератор потока.
4. **`listen()`** — подписка с `onData`, `onError`, `onDone`.
5. **`await for`** — итерация по потоку.
6. **`StreamController`** — ручное создание и управление потоком.
7. **Трансформации** — `map`, `where`, `expand`, `asyncMap`, `transform`.
8. **Back-pressure** — `pause()` / `resume()` на подписке.
9. **Закрывайте** — `controller.close()` и `subscription.cancel()` предотвращают утечки.

---

> **Назад:** [9.2 async / await](09_02_async_await.md) · **Далее:** [9.4 Isolates и обмен сообщениями](09_04_isolates.md)
