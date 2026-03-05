# 9.5 Цикл событий и микрозадачи

## 1. Формальное определение

**Event loop** — бесконечный цикл, обрабатывающий задачи из двух очередей:

1. **Microtask queue** — высокоприоритетная очередь. Обрабатывается **полностью** перед каждым событием.
2. **Event queue** — основная очередь (I/O callbacks, Timer, UI events, Future результаты из внешних источников).

```
while (true) {
  while (microtaskQueue.isNotEmpty) {
    microtaskQueue.removeFirst().execute();  // ← все microtasks ПЕРВЫМИ
  }
  if (eventQueue.isNotEmpty) {
    eventQueue.removeFirst().execute();      // ← одно событие
  }
}
```

Каждый Dart isolate имеет свой event loop.

## 2. Зачем это нужно

- **Порядок выполнения** — понимание, в какой последовательности выполняется асинхронный код.
- **Отладка** — почему `print('A')` после `await` печатается позже `print('B')`.
- **Производительность** — избежание блокировки event loop тяжёлыми синхронными операциями.
- **Корректность** — microtask'и завершаются до следующего события UI/IO.

## 3. Как это работает

### Базовый порядок выполнения

```dart
import 'dart:async';

void main() {
  print('1. Синхронный код (main)');

  // Event queue — Timer
  Timer.run(() => print('5. Timer.run (event queue)'));

  // Event queue — Future с задержкой
  Future.delayed(Duration.zero, () => print('6. Future.delayed (event queue)'));

  // Microtask queue
  scheduleMicrotask(() => print('3. scheduleMicrotask'));

  // Future.value → then = microtask
  Future.value().then((_) => print('4. Future.value().then (microtask)'));

  // Future() → вычисление через Timer (event queue), then → microtask после
  Future(() => print('7. Future() constructor (event queue)'));

  print('2. Ещё синхронный код');
}

// Порядок вывода:
// 1. Синхронный код (main)
// 2. Ещё синхронный код
// 3. scheduleMicrotask
// 4. Future.value().then (microtask)
// 5. Timer.run (event queue)
// 6. Future.delayed (event queue)
// 7. Future() constructor (event queue)
```

### Приоритет microtask над event

```dart
import 'dart:async';

void main() {
  // Event
  Timer.run(() {
    print('Event 1');
    // Microtask внутри event → выполняется ДО следующего event
    scheduleMicrotask(() => print('  Microtask inside Event 1'));
  });

  // Event
  Timer.run(() {
    print('Event 2');
  });

  // Microtask
  scheduleMicrotask(() {
    print('Microtask 1');
    // Microtask внутри microtask → тоже ДО любого event
    scheduleMicrotask(() => print('  Nested Microtask'));
  });

  scheduleMicrotask(() => print('Microtask 2'));

  print('Sync');
}

// Порядок:
// Sync
// Microtask 1
// Microtask 2
// Nested Microtask         ← вложенный microtask ДО events!
// Event 1
//   Microtask inside Event 1  ← microtask ДО Event 2
// Event 2
```

### Future и microtask / event queue

```dart
import 'dart:async';

void main() {
  // Future.value() → then → MICROTASK
  Future.value(1).then((v) => print('Future.value.then: $v'));

  // Future(() => ...) → СНАЧАЛА event (вычисление), ПОТОМ microtask (then)
  Future(() => 2).then((v) => print('Future().then: $v'));

  // Future.microtask() → MICROTASK (и вычисление, и then)
  Future.microtask(() => 3).then((v) => print('Future.microtask.then: $v'));

  // Future.delayed() → EVENT (Timer) → MICROTASK (then)
  Future.delayed(Duration.zero, () => 4).then((v) => print('Future.delayed.then: $v'));

  print('Sync');
}

// Порядок:
// Sync
// Future.value.then: 1      (microtask — value уже готов)
// Future.microtask.then: 3  (microtask)
// Future().then: 2           (event → microtask)
// Future.delayed.then: 4    (event/timer → microtask)
```

### await и event loop

```dart
void main() async {
  print('1');

  // await Future.value() → завершается «мгновенно», но await
  // приостанавливает функцию до следующего microtask tick
  await Future.value();
  print('3'); // ПОСЛЕ microtask tick

  print('4');

  await Future(() {}); // Приостановка до event tick
  print('6');
}

// Если добавить параллельный код:
void main2() {
  print('A');
  asyncWork();
  print('B');
}

Future<void> asyncWork() async {
  print('C');
  await Future.value(); // Приостановка
  print('D'); // После microtask
}

// Порядок:
// A
// C
// B   ← main2 продолжается, пока asyncWork ждёт
// D   ← asyncWork возобновляется
```

### Блокировка event loop

```dart
import 'dart:async';

void main() {
  // Timer должен сработать через 0 мс
  Timer.run(() => print('Timer сработал'));

  // НО: синхронная блокировка event loop
  print('Начало тяжёлой работы...');
  var sum = 0;
  for (var i = 0; i < 1000000000; i++) {
    sum += i;
  }
  print('Конец работы: $sum');

  // Timer сработает только ПОСЛЕ синхронного кода
  // В Flutter: UI зависнет на это время!
}

// Порядок:
// Начало тяжёлой работы...
// Конец работы: 499999999500000000   ← может занять секунды
// Timer сработал                      ← только после завершения sync кода
```

### scheduleMicrotask vs Future.microtask

```dart
import 'dart:async';

void main() {
  // scheduleMicrotask — напрямую в microtask queue
  scheduleMicrotask(() => print('scheduleMicrotask'));

  // Future.microtask — создаёт Future, планирует в microtask queue
  Future.microtask(() {
    print('Future.microtask');
    return 42;
  }).then((v) => print('  результат: $v'));

  // Разница: Future.microtask может вернуть значение и поддерживает then/catchError
  // scheduleMicrotask — fire-and-forget

  print('Sync');
}

// Порядок:
// Sync
// scheduleMicrotask
// Future.microtask
//   результат: 42
```

### Zone и microtasks

```dart
import 'dart:async';

void main() {
  // Zone — контекст выполнения (перехват ошибок, scheduling)
  runZonedGuarded(() {
    // Ошибки в microtask'ах перехватываются Zone
    scheduleMicrotask(() {
      throw Exception('Ошибка в microtask');
    });

    Future(() {
      throw Exception('Ошибка в event');
    });
  }, (error, stackTrace) {
    print('Zone поймала: $error');
  });
}
```

### Визуализация порядка

```dart
import 'dart:async';

void main() {
  print('═══ Старт main() ═══');

  // Microtask queue
  scheduleMicrotask(() => print('│ MT-1'));
  Future.value().then((_) => print('│ MT-2 (Future.value.then)'));
  Future.microtask(() => print('│ MT-3 (Future.microtask)'));

  // Event queue
  Timer.run(() => print('│ EV-1 (Timer.run)'));
  Future(() => print('│ EV-2 (Future())'));
  Timer(Duration.zero, () => print('│ EV-3 (Timer(0))'));

  // Вложенные
  scheduleMicrotask(() {
    print('│ MT-4');
    scheduleMicrotask(() => print('│   MT-4.1 (вложенный)'));
    Timer.run(() => print('│   EV-4.1 (Timer в microtask)'));
  });

  Timer.run(() {
    print('│ EV-5');
    scheduleMicrotask(() => print('│   MT-5.1 (microtask в event)'));
  });

  print('═══ Конец main() ═══');
}

// Вывод:
// ═══ Старт main() ═══
// ═══ Конец main() ═══
// │ MT-1
// │ MT-2 (Future.value.then)
// │ MT-3 (Future.microtask)
// │ MT-4
// │   MT-4.1 (вложенный)     ← microtask из microtask = ещё microtask!
// │ EV-1 (Timer.run)
// │ EV-2 (Future())
// │ EV-3 (Timer(0))
// │   EV-4.1 (Timer в microtask)
// │ EV-5
// │   MT-5.1 (microtask в event)  ← microtask ДО следующего event
```

## 4. Минимальный пример

```dart
import 'dart:async';

void main() {
  Future.value().then((_) => print('2. Microtask'));
  Timer.run(() => print('3. Event'));
  print('1. Sync');
}

// 1. Sync
// 2. Microtask
// 3. Event
```

## 5. Практический пример

### Batch processing без блокировки UI

```dart
import 'dart:async';

/// Обработка большого массива данных порциями,
/// не блокируя event loop
class BatchProcessor<T, R> {
  final int batchSize;
  final R Function(T) transform;

  BatchProcessor({this.batchSize = 100, required this.transform});

  /// Обрабатывает items порциями, позволяя event loop
  /// обрабатывать события между порциями
  Stream<R> process(List<T> items) async* {
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, items.length);
      final batch = items.sublist(i, end);

      // Обрабатываем порцию
      for (final item in batch) {
        yield transform(item);
      }

      // Отдаём управление event loop через Future.delayed(Duration.zero)
      // Это позволяет UI обновиться / обработать другие события
      if (end < items.length) {
        await Future.delayed(Duration.zero);
        // Эквивалентно одному обороту event loop
      }
    }
  }
}

/// Индикатор прогресса (работает благодаря yield между порциями)
void progressIndicator(int current, int total) {
  final percent = (current / total * 100).toStringAsFixed(1);
  print('  Прогресс: $percent% ($current/$total)');
}

void main() async {
  final items = List.generate(1000, (i) => i);
  final processor = BatchProcessor<int, String>(
    batchSize: 200,
    transform: (n) {
      // «Тяжёлая» обработка
      var sum = 0;
      for (var i = 0; i < 10000; i++) sum += i;
      return 'Элемент $n (sum=$sum)';
    },
  );

  // Таймер — проверяем, что event loop не заблокирован
  var ticks = 0;
  final timer = Timer.periodic(Duration(milliseconds: 100), (_) {
    ticks++;
    print('  ⏱ Event loop tick #$ticks (event queue работает!)');
  });

  print('Начинаем обработку 1000 элементов...');
  var count = 0;
  await for (final result in processor.process(items)) {
    count++;
    if (count % 200 == 0) {
      progressIndicator(count, items.length);
    }
  }
  print('Обработано: $count элементов');

  timer.cancel();
}

// Примерный вывод:
// Начинаем обработку 1000 элементов...
//   Прогресс: 20.0% (200/1000)
//   ⏱ Event loop tick #1 (event queue работает!)
//   Прогресс: 40.0% (400/1000)
//   ⏱ Event loop tick #2 (event queue работает!)
//   ...
// Обработано: 1000 элементов
```

## 6. Что происходит под капотом

```
Dart VM Event Loop (один isolate):

┌─────────────────────────────────────────┐
│               main() запуск              │
│  → выполняет синхронный код              │
│  → регистрирует callbacks в очереди      │
│  → main() завершается                    │
└─────────────────┬───────────────────────┘
                  ▼
┌─────────────────────────────────────────┐
│            EVENT LOOP                    │
│                                          │
│  loop:                                   │
│    ┌─ Microtask Queue ──────────────┐   │
│    │ MT-1  MT-2  MT-3  ...          │   │
│    │ (все до единого обрабатываются │   │
│    │  ПЕРЕД каждым event)           │   │
│    └────────────────────────────────┘   │
│              ↓ (пустой?)                 │
│    ┌─ Event Queue ──────────────────┐   │
│    │ EV-1: Timer callback           │   │
│    │ EV-2: I/O ready                │   │
│    │ EV-3: UI event                 │   │
│    │ EV-4: Future() computation     │   │
│    │ (берём ОДНО событие)           │   │
│    └────────────────────────────────┘   │
│              ↓                           │
│    goto loop;                            │
│                                          │
│  Если обе очереди пусты +                │
│  нет активных портов/таймеров →         │
│  программа завершается                   │
└──────────────────────────────────────────┘

Источники microtasks:
  - scheduleMicrotask()
  - Future.value().then(...)  → then на completed Future
  - Future.microtask(...)
  - Completer.complete()  → then-callbacks
  - async/await resume  → после await

Источники events:
  - Timer / Timer.periodic
  - Future(() => ...)  → конструктор с вычислением
  - Future.delayed(...)
  - I/O operations (File, Socket, HttpClient)
  - ReceivePort.listen  → сообщения от isolates
  - Stream events (от StreamController.add)
```

## 7. Производительность и ресурсы

| Аспект                     | Стоимость                            |
| -------------------------- | ------------------------------------ |
| `scheduleMicrotask()`      | ~1 мкс (очень дёшево)                |
| `Future.value().then()`    | ~2 мкс (создание Future + microtask) |
| `Timer.run()` / `Future()` | ~10-50 мкс (планирование event)      |
| Один оборот event loop     | Зависит от содержимого очередей      |
| Блокировка > 16 мс         | Пропуск кадра в Flutter (60 fps)     |

**Рекомендации:**

- Синхронная работа в event handler < 16 мс (Flutter) или < 100 мс (server).
- Разбивайте тяжёлую работу на порции через `Future.delayed(Duration.zero)`.
- Microtask starvation: бесконечные microtasks не дадут обработать events.
- CPU-bound > 100 мс → отправляйте в Isolate.

## 8. Частые ошибки и антипаттерны

### ❌ Блокировка event loop синхронной работой

```dart
void main() async {
  // ❌ UI / другие events заблокированы
  final result = heavySync(); // 2 секунды синхронно
  print(result);

  // ✅ Вынести в isolate
  // final result = await Isolate.run(() => heavySync());
}

int heavySync() {
  var sum = 0;
  for (var i = 0; i < 1000000000; i++) sum += i;
  return sum;
}
```

### ❌ Microtask starvation

```dart
import 'dart:async';

void main() {
  Timer.run(() => print('Event — НИКОГДА не выполнится!'));

  // ❌ Бесконечный цикл microtask'ов — events голодают
  void loop() {
    scheduleMicrotask(() {
      // print('microtask');
      loop(); // Рекурсивно планирует следующий microtask
    });
  }
  // loop(); // ← НЕ делайте так!

  // ✅ Если нужен periodic — используйте Timer.periodic
}
```

### ❌ Путаница в порядке выполнения

```dart
void main() async {
  var value = 'начальное';

  Future.value().then((_) {
    value = 'из microtask';
  });

  // ❌ Ожидание: value уже изменился
  print(value); // 'начальное'! Microtask ещё НЕ выполнился

  // ✅ После await — microtask выполнился
  await Future.value();
  print(value); // 'из microtask'
}
```

## 9. Сравнение с альтернативами

| Аспект      | Dart Event Loop       | JavaScript Event Loop | Go Runtime             | Java Threads      |
| ----------- | --------------------- | --------------------- | ---------------------- | ----------------- |
| Очереди     | Microtask + Event     | Micro + Macro         | Run queue + park       | Thread pool       |
| Приоритет   | Microtask > Event     | Promise > setTimeout  | goroutine              | Thread priority   |
| Блокировка  | Один поток застревает | Один поток застывает  | goroutine не блокирует | Поток блокируется |
| Параллелизм | Isolate               | Web Worker            | goroutine (M:N)        | OS thread         |
| Планировщик | Однопоточный          | Однопоточный          | Preemptive M:N         | OS                |

## 10. Когда НЕ стоит использовать

- **`scheduleMicrotask` для обычного кода** — используйте `Future.value().then()` или `await`.
- **Microtask для длительных операций** — блокирует event queue; используйте Timer или Isolate.
- **Рекурсивные microtasks** — приводят к starvation; используйте `Timer.run()`.
- **Ручное управление event loop** — Dart абстрагирует его; в 99% случаев достаточно `async/await`.

## 11. Краткое резюме

1. **Event loop** — бесконечный цикл: microtask queue → event queue.
2. **Microtask queue** — высокий приоритет; обрабатывается **полностью** перед каждым event.
3. **Event queue** — Timer, I/O, `Future()`, UI events; по одному за раз.
4. **`scheduleMicrotask()`** — напрямую в microtask queue.
5. **`Future.value().then()`** — then на завершённый Future = microtask.
6. **`Future(() => ...)`** — вычисление в event queue, then в microtask.
7. **Блокировка** — синхронный код > 16 мс замораживает UI.
8. **Starvation** — бесконечные microtasks не дают events выполниться.
9. **`await`** — приостанавливает функцию, не блокирует event loop.

---

> **Назад:** [9.4 Isolates и обмен сообщениями](09_04_isolates.md) · **Далее:** [10.0 Обработка ошибок — обзор](../10_error_handling/10_00_overview.md)
