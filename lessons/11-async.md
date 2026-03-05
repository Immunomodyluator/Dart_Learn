# Урок 11. Асинхронность и конкурентность

> Охватывает подтемы: 11.1 Future и async/await, 11.2 Streams, 11.3 Isolates, 11.4 Event loop и микротаски

---

## 1. Формальное определение

Dart — **однопоточный** язык (по умолчанию) с **event-driven** моделью конкурентности:

- **`Future<T>`** — обещание одного значения в будущем (аналог Promise)
- **`Stream<T>`** — последовательность событий во времени (аналог Observable/AsyncIterator)
- **`Isolate`** — отдельная «нить» с изолированной памятью; коммуникация только через сообщения
- **Event loop** — цикл обработки событий: microtask queue → event queue → idle

Уровень: **конкурентность, I/O**.

---

## 2. Зачем это нужно

- **Неблокирующий I/O** без тредов — сетевые запросы, файловый I/O не блокируют UI/сервер
- **Streams** для event-driven данных: WebSocket, файловые потоки, UI события
- **Isolates** для CPU-интенсивных задач: не блокируют главный поток
- **Event loop** — понимание порядка выполнения async кода, избегание deadlocks

---

## 3. Future и async/await (11.1)

```dart
import 'dart:async';

// async функция всегда возвращает Future
Future<String> fetchUser(int id) async {
  // await приостанавливает до завершения Future
  await Future.delayed(Duration(milliseconds: 100)); // имитация задержки
  return 'User#$id';
}

// Работа с Future через методы
Future<void> useFutureApi() async {
  // Последовательно
  final user1 = await fetchUser(1);
  final user2 = await fetchUser(2); // ждёт завершения fetchUser(1)

  // Параллельно — Future.wait
  final [u3, u4] = await Future.wait([fetchUser(3), fetchUser(4)]);

  // Первый выполненный
  final first = await Future.any([fetchUser(5), fetchUser(6)]);

  // С таймаутом
  try {
    final result = await fetchUser(7).timeout(Duration(seconds: 5));
  } on TimeoutException catch (e) {
    print('Timeout: ${e.duration}');
  }

  // Трансформация
  final upperName = await fetchUser(8).then((name) => name.toUpperCase());

  // Обработка ошибок
  await fetchUser(-1)
      .catchError((e) => 'default_user', test: (e) => e is RangeError)
      .whenComplete(() => print('cleanup'));
}

// Создание Future вручную
Future<int> computeAsync(int input) {
  return Future(() => input * 2); // выполняется в event queue
}

// Future.value — уже выполненный
Future<String> cachedResult() => Future.value('cached');

// Completer — ручное управление Future
Future<String> waitForSignal() {
  final completer = Completer<String>();
  
  // Кто-то снаружи может завершить
  Timer(Duration(seconds: 1), () {
    if (!completer.isCompleted) {
      completer.complete('signal received');
    }
  });
  
  return completer.future;
}

// unawaited — явно игнорируем future (чтобы lint не ругался)
import 'package:meta/meta.dart';
import 'dart:async' show unawaited;

void fireAndForget() {
  unawaited(fetchUser(99)); // сознательно не ждём
}
```

---

## 4. Streams (11.2)

```dart
import 'dart:async';

// Single-subscription stream (один слушатель)
Stream<int> countDown(int from) async* {
  for (int i = from; i >= 0; i--) {
    yield i;
    await Future.delayed(Duration(seconds: 1));
  }
}

// Broadcast stream (много слушателей)
Stream<int> broadcastTimer() {
  return Stream.periodic(Duration(seconds: 1), (i) => i)
      .asBroadcastStream();
}

// StreamController — ручное создание стрима
class EventBus<E> {
  final StreamController<E> _controller = StreamController<E>.broadcast();

  Stream<E> get events => _controller.stream;

  void emit(E event) => _controller.add(event);
  void emitError(Object error) => _controller.addError(error);

  Future<void> close() => _controller.close();
}

// Работа со стримом
Future<void> useStreams() async {
  // await for — consume stream
  await for (final count in countDown(5)) {
    print(count);
  }
  
  // Трансформация стримов
  final doubledEvens = countDown(10)
      .where((n) => n.isEven)       // фильтрация
      .map((n) => n * 2)            // трансформация
      .take(3);                      // ограничение

  await for (final val in doubledEvens) {
    print(val); // 20, 16, 12
  }

  // listen — подписка
  final sub = broadcastTimer().listen(
    (data) => print('tick: $data'),
    onError: (e) => print('error: $e'),
    onDone: () => print('done'),
    cancelOnError: false,
  );

  await Future.delayed(Duration(seconds: 3));
  await sub.cancel(); // отписка

  // StreamTransformer
  final transformer = StreamTransformer<int, String>.fromHandlers(
    handleData: (data, sink) => sink.add('value: $data'),
    handleError: (e, st, sink) => sink.addError(e, st),
  );

  await for (final s in Stream.fromIterable([1, 2, 3]).transform(transformer)) {
    print(s);
  }
}

// fold, first, last, toList, length
Future<void> streamAggregation() async {
  final sum = await Stream.fromIterable([1, 2, 3, 4, 5])
      .fold<int>(0, (prev, elem) => prev + elem);
  print(sum); // 15
  
  final items = await countDown(5).toList();
  print(items); // [5, 4, 3, 2, 1, 0]
}
```

---

## 5. Isolates (11.3)

```dart
import 'dart:isolate';
import 'dart:async';

// Простейший Isolate — Isolate.run (Dart 2.19+)
// Выполняется в отдельном изоляте, возвращает Future
Future<void> useIsolateRun() async {
  final result = await Isolate.run(() {
    // CPU-интенсивная работа — не блокирует главный изолят
    return List.generate(1000000, (i) => i).reduce((a, b) => a + b);
  });
  print('Sum: $result');
}

// Долгоживущий Isolate с двусторонней коммуникацией
Future<void> longLivedIsolate() async {
  final receivePort = ReceivePort();

  final isolate = await Isolate.spawn(
    workerIsolate,
    receivePort.sendPort,
  );

  // Получаем SendPort рабочего изолята
  final workerSendPort = await receivePort.first as SendPort;

  // Отправляем задачи
  final responsePort = ReceivePort();
  workerSendPort.send([10, responsePort.sendPort]);
  final answer = await responsePort.first;
  print('Worker answered: $answer');

  isolate.kill(priority: Isolate.immediate);
  receivePort.close();
}

void workerIsolate(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort); // сообщаем свой SendPort

  receivePort.listen((message) {
    final [int input, SendPort replyTo] = message as List;
    // CPU работа
    final result = List.generate(input, (i) => i).reduce((a, b) => a + b);
    replyTo.send(result);
  });
}

// compute() — Flutter helper (удобная обёртка над Isolate.run)
// import 'package:flutter/foundation.dart';
// final result = await compute(expensiveFunction, input);

// Ограничения Isolates:
// - Нельзя передавать объекты с изменяемым состоянием напрямую
// - SendPort принимает: null, bool, int, double, String, List, Map, TransferableTypedData
// - Нет разделяемой памяти (кроме dart:ffi и TransferableTypedData)
```

---

## 6. Event loop и микротаски (11.4)

```dart
import 'dart:async';

void demonstrateEventLoop() {
  print('1: sync start');

  // Микротаска — выполняется ПЕРЕД следующим событием event queue
  scheduleMicrotask(() => print('3: microtask'));

  // Future.value/Future.microtask — микротаска
  Future.microtask(() => print('4: Future.microtask'));

  // Future() — event queue (следующий тик)
  Future(() => print('5: Future event'));

  // await создаёт continuation как микротаску
  asyncFunc();

  print('2: sync end');
}

Future<void> asyncFunc() async {
  // До первого await — выполняется синхронно
  print('2.5: before await');
  
  await Future.value(1); // continuation планируется как микротаска

  // После await — в следующей микротаске
  print('6: after await in asyncFunc');
}

// Вывод: 1, 2, 2.5, 3, 4, 6, 5
// (микротаски выполняются до event queue)

// Порядок очередей:
// [sync code] → [microtask queue (empty)] → [event queue]
//                      ↑ повторяется пока не пусто

void eventLoopPitfall() async {
  // НЕ делайте так — это заблокирует event loop:
  // while (true) { /* CPU работа */ } // бесконечный цикл в main isolate

  // Вместо этого:
  // 1. Использовать compute/Isolate.run для CPU
  // 2. Разбить на чанки через scheduleMicrotask или Timer
}

// Zone — контекст выполнения async кода
void useZones() {
  runZonedGuarded(
    () async {
      throw Exception('test error');
    },
    (error, stack) {
      print('Caught in zone: $error');
    },
  );
}
```

---

## 7. Минимальный пример

```dart
// Типичный паттерн: параллельная загрузка данных
Future<Map<String, dynamic>> loadDashboard(String userId) async {
  final [profile, posts, notifications] = await Future.wait([
    fetchProfile(userId),
    fetchPosts(userId),
    fetchNotifications(userId),
  ]);
  
  return {
    'profile': profile,
    'posts': posts,
    'notifications': notifications,
  };
}

Future<Map<String, dynamic>> fetchProfile(String id) async {
  await Future.delayed(Duration(milliseconds: 100));
  return {'id': id, 'name': 'Alice'};
}

Future<List<String>> fetchPosts(String id) async {
  await Future.delayed(Duration(milliseconds: 150));
  return ['Post 1', 'Post 2'];
}

Future<int> fetchNotifications(String id) async {
  await Future.delayed(Duration(milliseconds: 50));
  return 5;
}

void main() async {
  final dashboard = await loadDashboard('user_1');
  print(dashboard);
  // Время выполнения: ~150ms (параллельно), не 300ms (последовательно)
}
```

---

## 8. Практический пример: стриминговый чат

```dart
import 'dart:async';

class ChatService {
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  
  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  
  // Имитация WebSocket подключения
  Future<void> connect(String url) async {
    _connectionController.add(true);
    
    // Симуляция входящих сообщений
    Stream.periodic(Duration(seconds: 2), (i) => i)
        .take(10)
        .listen((i) {
          _messageController.add(ChatMessage(
            id: i.toString(),
            text: 'Message $i',
            sender: 'Bot',
            timestamp: DateTime.now(),
          ));
        });
  }

  Future<void> send(String text) async {
    await Future.delayed(Duration(milliseconds: 50)); // имитация отправки
    _messageController.add(ChatMessage(
      id: 'sent_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      sender: 'Me',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> dispose() async {
    await _messageController.close();
    await _connectionController.close();
  }
}

class ChatMessage {
  final String id, text, sender;
  final DateTime timestamp;
  const ChatMessage({
    required this.id, required this.text,
    required this.sender, required this.timestamp,
  });
}

void main() async {
  final service = ChatService();
  
  // Подписка
  service.messages
      .where((m) => m.sender != 'Me')
      .listen((m) => print('[${m.sender}] ${m.text}'));
  
  await service.connect('ws://localhost:8080');
  await service.send('Hello!');
  
  await Future.delayed(Duration(seconds: 5));
  await service.dispose();
}
```

---

## 9. Под капотом

### Dart VM: Event loop implementation

Dart VM поддерживает две очереди:
1. **Microtask queue** — `scheduleMicrotask`, Future completions, await
2. **Event queue** — Timer, I/O, user input, `Future()`

```
┌─────────────────────────────────┐
│        Dart Isolate             │
│  ┌──────────────────────┐       │
│  │    Microtask Queue   │ ◄─ await, scheduleMicrotask
│  └──────────┬───────────┘       │
│             │ (drain completely) │
│  ┌──────────▼───────────┐       │
│  │     Event Queue      │ ◄─ Timer, I/O, sendPort
│  └──────────────────────┘       │
└─────────────────────────────────┘
```

### async/await компиляция

`async/await` — синтаксический сахар над `Future.then()` + state machine:

```dart
// Оригинал:
Future<int> compute() async {
  final x = await getValue();
  return x + 1;
}

// Примерный эквивалент:
Future<int> compute() {
  return getValue().then((x) => x + 1);
}
```

---

## 10. Производительность

- **`Future.wait`** vs последовательные await — параллельно может быть в N раз быстрее для независимых операций
- **Isolates** имеют overhead на старт (~5-10ms) — для коротких задач не выгодно
- **Stream** с broadcast — overhead на синхронизацию слушателей; предпочитайте single-subscription где возможно
- **`scheduleMicrotask`** приоритетнее event queue — злоупотребление может задержать обработку событий
- **`await` в цикле** vs `Future.wait` — последнее параллельно, первое последовательно

---

## 11. Частые ошибки

**1. Забыть `await`:**
```dart
// НЕВЕРНО — Future не ожидается, ошибки теряются
void bad() async {
  fetchUser(1); // fire-and-forget без unawaited()
}

// ВЕРНО
void good() async {
  await fetchUser(1);
  // или явно:
  unawaited(fetchUser(1)); // сознательное игнорирование
}
```

**2. Последовательные await вместо Future.wait:**
```dart
// МЕДЛЕННО: 300ms
final a = await fetchA(); // 100ms
final b = await fetchB(); // 100ms
final c = await fetchC(); // 100ms

// БЫСТРО: 100ms (параллельно)
final [a, b, c] = await Future.wait([fetchA(), fetchB(), fetchC()]);
```

**3. Не закрывать StreamController:**
```dart
// Утечка памяти — StreamController.close() никогда не вызывается
class Service {
  final _ctrl = StreamController<int>();
  void dispose() { _ctrl.close(); } // ВСЕГДА вызывать dispose
}
```

**4. Блокирующий код в async функции:**
```dart
Future<void> bad() async {
  // Это БЛОКИРУЕТ event loop — не делайте так!
  final result = jsonDecode(hugeJsonString); // sync CPU работа
}

// Для CPU-интенсивного кода — Isolate.run
Future<Map> good(String json) => Isolate.run(() => jsonDecode(json));
```

---

## 12. Сравнение с другими языками

| Аспект | Dart | JavaScript | Kotlin | Go |
|---|---|---|---|---|
| Async primitive | Future | Promise | Coroutine/Deferred | goroutine + channel |
| Await syntax | `await` | `await` | `suspend fun` | implicit (goroutines) |
| Streams | Stream | Observable/AsyncIterator | Flow | channel |
| Parallelism | Isolates | Workers | Threads | goroutines |
| Shared memory | НЕТ между isolates | Shared через SharedArrayBuffer | Да, с locks | Да, с locks |

---

## 13. Когда НЕ использовать

- **`async` для синхронного кода** — лишний overhead, если нет await
- **Isolate для коротких задач (<1ms)** — overhead запуска больше выигрыша
- **Broadcast stream для одного слушателя** — используйте single-subscription
- **`scheduleMicrotask` для задержки** — используйте `Future.delayed` или `Timer`

---

## 14. Краткое резюме

1. **Dart однопоточный** внутри изолята; concurrency через event loop, не через threads
2. **`Future<T>`** — одно значение асинхронно; `Stream<T>` — последовательность
3. **`await`** не блокирует поток — передаёт управление event loop
4. **`Future.wait`** для параллельных независимых операций быстрее последовательных await
5. **Microtask queue** имеет приоритет над event queue — вызывается до следующего события
6. **Isolates** — единственный способ параллельного выполнения в Dart; нет shared memory
7. **`Isolate.run`** (Dart 2.19+) — простейший способ для CPU-задач; `Isolate.spawn` для долгоживущих
8. **Всегда закрывать StreamController** во избежание утечек памяти
