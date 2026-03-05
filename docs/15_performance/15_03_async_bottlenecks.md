# 15.3 Асинхронные узкие места

## 1. Формальное определение

**Асинхронное узкое место** — ситуация, когда event loop блокируется долгой синхронной операцией, или асинхронные задачи выполняются последовательно вместо параллельного, или ресурсы ожидаются неэффективно.

## 2. Зачем это нужно

- **Отзывчивость** — блокировка event loop замораживает UI и останавливает обработку запросов.
- **Пропускная способность** — параллельное выполнение независимых задач ускоряет обработку.
- **Масштабируемость** — правильная асинхронность позволяет серверу обрабатывать тысячи соединений.

## 3. Типичные проблемы и решения

### Блокировка event loop

```dart
// ❌ Плохо — синхронная тяжёлая операция блокирует event loop
void handleRequest(HttpRequest request) {
  final result = computeHeavyTask();  // 500 мс CPU-bound
  request.response.write(result);     // Все остальные запросы ждут!
}

// ✅ Хорошо — вынести в Isolate
Future<void> handleRequest(HttpRequest request) async {
  final result = await Isolate.run(() => computeHeavyTask());
  request.response.write(result);
}
```

### Последовательные независимые запросы

```dart
// ❌ Плохо — запросы выполняются последовательно
Future<Dashboard> loadDashboard() async {
  final user = await fetchUser();         // 200 мс
  final orders = await fetchOrders();     // 300 мс
  final notifications = await fetchNotifications(); // 150 мс
  // Итого: ~650 мс

  return Dashboard(user, orders, notifications);
}

// ✅ Хорошо — параллельное выполнение
Future<Dashboard> loadDashboard() async {
  final results = await Future.wait([
    fetchUser(),
    fetchOrders(),
    fetchNotifications(),
  ]);
  // Итого: ~300 мс (максимальный из трёх)

  return Dashboard(results[0], results[1], results[2]);
}

// ✅ Ещё лучше — с типизацией через Record (Dart 3)
Future<Dashboard> loadDashboard() async {
  final (user, orders, notifications) = await (
    fetchUser(),
    fetchOrders(),
    fetchNotifications(),
  ).wait;

  return Dashboard(user, orders, notifications);
}
```

### Unthrottled обработка потоков

```dart
// ❌ Плохо — обрабатываем все события без ограничения
Stream<Result> processAll(Stream<Event> events) async* {
  await for (final event in events) {
    yield await heavyProcess(event);  // Может захлебнуться
  }
}

// ✅ Хорошо — ограничение параллельных операций
Stream<Result> processAll(
  Stream<Event> events, {
  int maxConcurrency = 5,
}) {
  final controller = StreamController<Result>();
  var active = 0;
  final queue = <Event>[];

  void processNext() async {
    if (queue.isEmpty || active >= maxConcurrency) return;
    active++;
    final event = queue.removeAt(0);
    try {
      final result = await heavyProcess(event);
      controller.add(result);
    } catch (e) {
      controller.addError(e);
    } finally {
      active--;
      processNext();
    }
  }

  events.listen(
    (event) { queue.add(event); processNext(); },
    onDone: () async {
      // Ждём завершения всех активных задач
      while (active > 0) await Future.delayed(Duration(milliseconds: 10));
      controller.close();
    },
  );

  return controller.stream;
}
```

### Timer drift и microtask starvation

```dart
// ❌ Плохо — длинная цепочка microtask'ов не даёт обработать timer'ы
void badLoop() {
  for (var i = 0; i < 1000000; i++) {
    scheduleMicrotask(() {
      // Эти microtask'ы выполнятся ВСЕ до любого timer/IO callback
    });
  }
}

// ✅ Хорошо — разбивка через Future() (timer queue)
Future<void> processInChunks(List<int> items) async {
  const chunkSize = 1000;
  for (var i = 0; i < items.length; i += chunkSize) {
    final chunk = items.skip(i).take(chunkSize);
    for (final item in chunk) {
      process(item);
    }
    // Отдать контроль event loop
    await Future.delayed(Duration.zero);
  }
}
```

## 4. Паттерн: Debounce и Throttle

```dart
// Debounce — выполнить только после паузы
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() => _timer?.cancel();
}

// Throttle — не чаще чем раз в N мс
class Throttler {
  final Duration interval;
  DateTime _lastCall = DateTime(0);

  Throttler({required this.interval});

  void call(void Function() action) {
    final now = DateTime.now();
    if (now.difference(_lastCall) >= interval) {
      _lastCall = now;
      action();
    }
  }
}

// Использование
final debouncer = Debouncer(delay: Duration(milliseconds: 300));
searchField.onChange.listen((_) {
  debouncer.call(() => performSearch(searchField.value));
});
```

## 5. Когда использовать Isolate

```
┌──────────── Isolate vs Event Loop ────────────────┐
│                                                    │
│  Event Loop (async/await) — для:                   │
│  ├── I/O операции (HTTP, файлы, БД)               │
│  ├── Timer'ы и периодические задачи               │
│  └── Лёгкие вычисления (< 16 мс)                  │
│                                                    │
│  Isolate.run() — для:                              │
│  ├── Парсинг большого JSON (> 1 МБ)               │
│  ├── Обработка изображений                        │
│  ├── Криптография                                 │
│  ├── Сортировка больших массивов                   │
│  └── Любой CPU-bound код > 16 мс                   │
│                                                    │
└────────────────────────────────────────────────────┘
```

```dart
// Простое правило: если Stopwatch показывает > 16 мс → Isolate
Future<List<Item>> parseItems(String jsonStr) async {
  return await Isolate.run(() {
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => Item.fromJson(e)).toList();
  });
}
```

## 6. Распространённые ошибки

### ❌ await в цикле для независимых задач

```dart
// Плохо — 10 секунд (10 × 1с)
for (final url in urls) {
  await download(url);
}

// Хорошо — ~1 секунда (параллельно)
await Future.wait(urls.map(download));
```

### ❌ Игнорирование ошибок в Future.wait

```dart
// Если одна задача упадёт — Future.wait выбросит первую ошибку
// и отменит ожидание остальных
try {
  await Future.wait([task1(), task2(), task3()]);
} catch (e) {
  // Обработать ошибку
  // Но task2 и task3 продолжат выполняться!
}

// Если нужны все результаты (даже ошибочные):
await Future.wait([task1(), task2(), task3()], eagerError: false);
```

---

> **Назад:** [15.2 Оптимизация аллокаций](15_02_allocations.md) · **Далее:** [15.4 Память и GC](15_04_gc.md)
