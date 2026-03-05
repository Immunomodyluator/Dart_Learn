# 9.4 Isolates и обмен сообщениями

## 1. Формальное определение

**Isolate** — изолированный поток выполнения со своей собственной **кучей памяти** (heap). Isolates не делят изменяемое состояние и общаются только через **передачу сообщений** (`SendPort` / `ReceivePort`). Это модель конкурентности Dart, альтернативная потокам с общей памятью.

```dart
// Dart 2.19+ — упрощённый API
Future<R> Isolate.run<R>(FutureOr<R> computation());

// Низкоуровневый API
Future<Isolate> Isolate.spawn<T>(
  void entryPoint(T message),
  T message,
);
```

## 2. Зачем это нужно

- **CPU-bound задачи** — парсинг JSON, шифрование, обработка изображений.
- **Не блокировать UI** — Flutter: тяжёлые вычисления в отдельном isolate.
- **Безопасность** — нет data races, нет deadlocks, нет мьютексов.
- **Параллелизм** — на многоядерных CPU isolates работают на разных ядрах.

## 3. Как это работает

### Isolate.run — простейший способ (Dart 2.19+)

```dart
import 'dart:isolate';

// Функция ДОЛЖНА быть top-level или static
int heavyComputation(int n) {
  var result = 0;
  for (var i = 0; i < n; i++) {
    result += i;
  }
  return result;
}

void main() async {
  print('Запуск...');

  // Isolate.run — запуск, ожидание результата, автоматическое завершение
  final result = await Isolate.run(() => heavyComputation(1000000000));

  print('Результат: $result');
}
```

### Isolate.run с параметрами

```dart
import 'dart:isolate';
import 'dart:convert';

// Парсинг большого JSON в отдельном isolate
Future<List<Map<String, dynamic>>> parseJsonInBackground(
    String jsonString) async {
  return await Isolate.run(() {
    // Этот код выполняется в ДРУГОМ isolate
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.cast<Map<String, dynamic>>();
  });
}

void main() async {
  // Имитация большого JSON
  final bigJson =
      jsonEncode(List.generate(1000, (i) => {'id': i, 'name': 'Item $i'}));

  final data = await parseJsonInBackground(bigJson);
  print('Распарсено ${data.length} записей');
}
```

### Isolate.spawn + SendPort / ReceivePort

```dart
import 'dart:isolate';

// Entry point для isolate — top-level функция
void workerEntryPoint(SendPort mainSendPort) {
  // Создаём порт для получения сообщений от main
  final workerReceivePort = ReceivePort();

  // Отправляем наш SendPort в main
  mainSendPort.send(workerReceivePort.sendPort);

  // Слушаем сообщения
  workerReceivePort.listen((message) {
    if (message is int) {
      // Вычисляем и отправляем результат обратно
      final result = message * message;
      mainSendPort.send(result);
    } else if (message == 'exit') {
      workerReceivePort.close();
    }
  });
}

void main() async {
  // Создаём порт для получения сообщений от worker
  final mainReceivePort = ReceivePort();

  // Запускаем isolate
  final isolate = await Isolate.spawn(
    workerEntryPoint,
    mainReceivePort.sendPort,
  );

  // Первое сообщение — SendPort worker'а
  final workerSendPort = await mainReceivePort.first as SendPort;

  // Новый ReceivePort для дальнейшего общения
  final responsePort = ReceivePort();

  // Подписываемся на ответы (нужен новый ReceivePort, т.к. .first закрыл старый)
  // Альтернатива — использовать broadcast stream

  // Упрощённый пример:
  final receivePort = ReceivePort();
  final isolate2 = await Isolate.spawn(workerEntryPoint, receivePort.sendPort);

  final broadcastStream = receivePort.asBroadcastStream();
  final sendPort = await broadcastStream.first as SendPort;

  // Отправляем задачу
  sendPort.send(7);

  // Получаем результат
  final result = await broadcastStream.first;
  print('7² = $result'); // 7² = 49

  sendPort.send('exit');
  receivePort.close();
  isolate2.kill();
}
```

### Двусторонняя связь (паттерн)

```dart
import 'dart:async';
import 'dart:isolate';

/// Worker isolate с двусторонней связью
class IsolateWorker {
  late final Isolate _isolate;
  late final SendPort _sendPort;
  final _receivePort = ReceivePort();
  final _responses = <int, Completer<dynamic>>{};
  var _nextId = 0;

  Future<void> start() async {
    _isolate = await Isolate.spawn(_workerMain, _receivePort.sendPort);

    final stream = _receivePort.asBroadcastStream();
    _sendPort = await stream.first as SendPort;

    // Слушаем ответы
    stream.listen((message) {
      if (message is Map) {
        final id = message['id'] as int;
        final result = message['result'];
        _responses[id]?.complete(result);
        _responses.remove(id);
      }
    });
  }

  /// Отправить задачу и получить результат
  Future<dynamic> compute(String task, dynamic data) {
    final id = _nextId++;
    final completer = Completer<dynamic>();
    _responses[id] = completer;
    _sendPort.send({'id': id, 'task': task, 'data': data});
    return completer.future;
  }

  void dispose() {
    _receivePort.close();
    _isolate.kill();
  }

  static void _workerMain(SendPort mainSendPort) {
    final workerPort = ReceivePort();
    mainSendPort.send(workerPort.sendPort);

    workerPort.listen((message) {
      if (message is Map) {
        final id = message['id'];
        final task = message['task'] as String;
        final data = message['data'];

        dynamic result;
        switch (task) {
          case 'square':
            result = (data as int) * data;
          case 'uppercase':
            result = (data as String).toUpperCase();
          default:
            result = 'Unknown task: $task';
        }

        mainSendPort.send({'id': id, 'result': result});
      }
    });
  }
}

void main() async {
  final worker = IsolateWorker();
  await worker.start();

  final sq = await worker.compute('square', 42);
  print('42² = $sq'); // 42² = 1764

  final upper = await worker.compute('uppercase', 'hello');
  print('upper = $upper'); // upper = HELLO

  worker.dispose();
}
```

### Что можно передавать между Isolates

```dart
import 'dart:isolate';

// ✅ Передаваемые (sendable) типы:
// - null, bool, int, double, String
// - SendPort, Capability
// - List, Map, Set (если элементы sendable)
// - TypedData (Uint8List и т.д.)
// - Int32x4, Float32x4, Float64x2 (SIMD)
// - TransferableTypedData (zero-copy)

// ❌ НЕ переменные:
// - Closure (замыкания с captured state)
// - Объект с SendPort в nested scope (иногда)
// - Socket, File handle и другие system resources

void main() async {
  // Передача сложных данных
  final result = await Isolate.run(() {
    final data = {
      'users': [
        {'name': 'Alice', 'age': 30},
        {'name': 'Bob', 'age': 25},
      ],
      'count': 2,
      'active': true,
    };
    return data;
  });

  print(result); // {users: [{name: Alice, age: 30}, ...], count: 2, active: true}
}
```

### TransferableTypedData — zero-copy

```dart
import 'dart:isolate';
import 'dart:typed_data';

void main() async {
  // Создаём большой массив данных
  final largeData = Uint8List(10 * 1024 * 1024); // 10 MB
  for (var i = 0; i < largeData.length; i++) {
    largeData[i] = i % 256;
  }

  // TransferableTypedData — передаёт без копирования
  final transferable = TransferableTypedData.fromList([largeData]);

  // После передачи — исходный больше НЕ доступен
  final result = await Isolate.run(() {
    final data = transferable.materialize().asUint8List();
    // Обработка...
    return data.length;
  });

  print('Обработано: $result байт');
}
```

### Isolate.exit — быстрый возврат без копирования

```dart
import 'dart:isolate';

void main() async {
  final receivePort = ReceivePort();

  await Isolate.spawn((sendPort) {
    // Вместо sendPort.send(bigData) — используем Isolate.exit
    // Данные передаются БЕЗ КОПИРОВАНИЯ
    final bigResult = List.generate(1000000, (i) => i);
    Isolate.exit(sendPort, bigResult);
    // Код после Isolate.exit НЕ выполняется
  }, receivePort.sendPort);

  final result = await receivePort.first as List<int>;
  print('Получено ${result.length} элементов');
  receivePort.close();
}
```

### Пул Isolates

```dart
import 'dart:async';
import 'dart:isolate';

/// Простой пул isolates для параллельных задач
class IsolatePool {
  final int size;
  final _queue = <_Task>[];
  var _activeCount = 0;

  IsolatePool({this.size = 4});

  /// Добавить задачу в пул
  Future<R> run<R>(R Function() computation) {
    final completer = Completer<R>();
    _queue.add(_Task(() async => completer.complete(await Isolate.run(computation))));
    _processQueue();
    return completer.future;
  }

  void _processQueue() {
    while (_activeCount < size && _queue.isNotEmpty) {
      _activeCount++;
      final task = _queue.removeAt(0);
      task.execute().whenComplete(() {
        _activeCount--;
        _processQueue();
      });
    }
  }
}

class _Task {
  final Future<void> Function() execute;
  _Task(this.execute);
}

void main() async {
  final pool = IsolatePool(size: 3);

  // Запускаем 6 задач, max 3 параллельно
  final futures = <Future<int>>[];
  for (var i = 0; i < 6; i++) {
    final n = i;
    futures.add(pool.run(() {
      // Имитация тяжёлой работы
      var sum = 0;
      for (var j = 0; j < 100000000; j++) sum += j % (n + 1);
      return sum;
    }));
  }

  final results = await Future.wait(futures);
  print('Результаты: $results');
}
```

## 4. Минимальный пример

```dart
import 'dart:isolate';

void main() async {
  final result = await Isolate.run(() {
    // Этот код выполняется в отдельном isolate
    return 'Привет из изолята!';
  });

  print(result); // Привет из изолята!
}
```

## 5. Практический пример

### Параллельная обработка файлового лога

```dart
import 'dart:isolate';
import 'dart:convert';

/// Запись лога
class LogEntry {
  final DateTime timestamp;
  final String level;
  final String message;

  LogEntry(this.timestamp, this.level, this.message);

  @override
  String toString() => '[$level] $timestamp: $message';
}

/// Статистика лога
class LogStats {
  final int totalLines;
  final int errors;
  final int warnings;
  final int infos;
  final String? firstError;

  LogStats({
    required this.totalLines,
    required this.errors,
    required this.warnings,
    required this.infos,
    this.firstError,
  });

  @override
  String toString() => 'LogStats(total: $totalLines, '
      'errors: $errors, warnings: $warnings, infos: $infos, '
      'firstError: $firstError)';
}

/// Парсинг и анализ лога в отдельном isolate
Future<LogStats> analyzeLog(String rawLog) async {
  return await Isolate.run(() {
    final lines = LineSplitter.split(rawLog).toList();
    var errors = 0;
    var warnings = 0;
    var infos = 0;
    String? firstError;

    for (final line in lines) {
      if (line.contains('[ERROR]')) {
        errors++;
        firstError ??= line;
      } else if (line.contains('[WARN]')) {
        warnings++;
      } else if (line.contains('[INFO]')) {
        infos++;
      }
    }

    return LogStats(
      totalLines: lines.length,
      errors: errors,
      warnings: warnings,
      infos: infos,
      firstError: firstError,
    );
  });
}

/// Параллельный анализ нескольких логов
Future<List<LogStats>> analyzeMultipleLogs(List<String> logs) async {
  return await Future.wait(
    logs.map((log) => analyzeLog(log)),
  );
}

void main() async {
  // Генерация тестового лога
  final log = StringBuffer();
  final levels = ['INFO', 'INFO', 'INFO', 'WARN', 'ERROR'];
  for (var i = 0; i < 10000; i++) {
    final level = levels[i % levels.length];
    log.writeln('2026-03-05T10:00:${(i % 60).toString().padLeft(2, '0')} '
        '[$level] Сообщение #$i');
  }

  final stopwatch = Stopwatch()..start();

  // Разбиваем на «файлы» и анализируем параллельно
  final allLines = log.toString();
  final chunkSize = allLines.length ~/ 3;
  final chunks = [
    allLines.substring(0, chunkSize),
    allLines.substring(chunkSize, chunkSize * 2),
    allLines.substring(chunkSize * 2),
  ];

  final results = await analyzeMultipleLogs(chunks);

  stopwatch.stop();

  // Объединяем результаты
  var totalErrors = 0, totalWarnings = 0, totalInfos = 0, totalLines = 0;
  for (final r in results) {
    totalErrors += r.errors;
    totalWarnings += r.warnings;
    totalInfos += r.infos;
    totalLines += r.totalLines;
  }

  print('Анализ завершён за ${stopwatch.elapsedMilliseconds} мс');
  print('Всего строк: $totalLines');
  print('Ошибки: $totalErrors');
  print('Предупреждения: $totalWarnings');
  print('Информация: $totalInfos');
  print('Первая ошибка: ${results.first.firstError}');
}
```

## 6. Что происходит под капотом

```
Isolate.run(() => heavyWork()):

1. Dart VM создаёт новый Isolate:
   - Выделяет отдельную кучу (heap)
   - Создаёт свой event loop
   - НЕ делит память с main isolate

2. Компилирует/загружает код в новый isolate

3. Создаёт ReceivePort в main, SendPort в worker

4. Serialization:
   - Замыкание (closure) → сериализация параметров
   - Простые типы → копирование
   - Isolate.exit → transfer ownership (zero-copy)

5. Worker выполняет вычисление в своём потоке ОС

6. Результат → сериализация → SendPort → ReceivePort

7. Worker isolate уничтожается (heap освобождается)

Ограничения:
  - Нельзя делить mutable state
  - Нельзя передавать closures с захваченным состоянием
  - Создание isolate ~5-50мс (startup cost)
  - Сериализация/десериализация данных — копирование

MultIcore:
  Main isolate → OS thread (core 1)
  Worker isolate → OS thread (core 2)
  Worker isolate → OS thread (core 3)
  ...

  Настоящий параллелизм на CPU!
```

## 7. Производительность и ресурсы

| Аспект                    | Стоимость                |
| ------------------------- | ------------------------ |
| Создание Isolate          | ~5–50 мс (VM startup)    |
| Передача данных (copy)    | O(n) — размер данных     |
| `Isolate.exit` (transfer) | O(1) — zero-copy         |
| `TransferableTypedData`   | O(1) — zero-copy         |
| Уничтожение isolate       | Быстро (GC heap)         |
| Пул isolates              | Амортизация startup cost |

**Рекомендации:**

- Используйте `Isolate.run` для задач > 16 мс (один кадр в Flutter).
- Не создавайте isolate для мелких операций — overhead > пользы.
- Для частых задач — пул isolates или persistent worker.
- `Isolate.exit` — быстрее `SendPort.send` для больших данных.

## 8. Частые ошибки и антипаттерны

### ❌ Передача closure с captured state

```dart
void main() async {
  var counter = 0;

  // ❌ closure захватывает counter из main isolate
  // final result = await Isolate.run(() {
  //   counter++; // ❌ Это КОПИЯ counter, main не обновится
  //   return counter;
  // });

  // ✅ Передавайте данные как аргументы
  final result = await Isolate.run(() => 42);
  counter = result;
}
```

### ❌ Isolate для мелких задач

```dart
void main() async {
  // ❌ Isolate для тривиальной операции — overhead > пользы
  final sum = await Isolate.run(() => 2 + 2);

  // ✅ Просто синхронно
  final sum2 = 2 + 2;
}
```

### ❌ Забыли закрыть ReceivePort

```dart
void main() async {
  final port = ReceivePort();
  await Isolate.spawn(worker, port.sendPort);

  final result = await port.first;
  // ❌ port не закрыт → программа может не завершиться

  // ✅ Закрываем
  port.close();
}

void worker(SendPort port) {
  port.send('done');
}
```

### ❌ Попытка передать non-sendable объект

```dart
import 'dart:io';

void main() async {
  // final socket = await Socket.connect('example.com', 80);
  // ❌ Нельзя передать Socket в другой isolate
  // await Isolate.run(() => socket.write('hello'));

  // ✅ Передавайте данные, не ресурсы
  // Сетевые операции — в том же isolate, где создан Socket
}
```

## 9. Сравнение с альтернативами

| Аспект       | Isolate    | Thread (Java/C++)     | Web Worker  | Go goroutine     |
| ------------ | ---------- | --------------------- | ----------- | ---------------- |
| Общая память | ❌         | ✅                    | ❌          | Shared (с mutex) |
| Общение      | Сообщения  | Shared memory + locks | postMessage | Channels         |
| Data races   | Невозможны | Возможны              | Невозможны  | Возможны         |
| Startup cost | ~5-50 мс   | ~1 мс                 | ~10-100 мс  | ~1 мкс           |
| Lightweight  | Средне     | Средне                | Средне      | Очень            |
| Cancel       | `kill()`   | interrupt             | terminate   | Context cancel   |

## 10. Когда НЕ стоит использовать

- **I/O-bound задачи** — `Future` / `async-await` достаточно; I/O уже неблокирующий.
- **Мелкие вычисления** — startup cost isolate > само вычисление.
- **Много общего состояния** — постоянная сериализация/десериализация замедлит.
- **Простые приложения** — в консольных скриптах isolates обычно не нужны.

## 11. Краткое резюме

1. **Isolate** — изолированный поток со своей кучей и event loop.
2. **`Isolate.run()`** — самый простой способ: запуск, результат, авто-завершение.
3. **`Isolate.spawn()`** — низкоуровневый API с `SendPort` / `ReceivePort`.
4. **Общение через сообщения** — нет общей памяти, нет data races.
5. **Передаваемые типы** — примитивы, коллекции, `SendPort`, `TypedData`.
6. **`Isolate.exit()`** — zero-copy возврат результата.
7. **Startup cost** — ~5-50 мс; используйте пул для частых задач.
8. **Реальный параллелизм** — каждый isolate на своём ядре CPU.

---

> **Назад:** [9.3 Streams и реактивные последовательности](09_03_streams.md) · **Далее:** [9.5 Цикл событий и микрозадачи](09_05_event_loop.md)
