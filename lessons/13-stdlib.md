# Урок 13. Стандартная библиотека Dart

> Охватывает подтемы: 13.1 dart:core, 13.2 dart:collection, 13.3 dart:convert, 13.4 dart:math, 13.5 dart:io, 13.6 dart:async (утилиты)

---

## 1. Формальное определение

**Стандартная библиотека Dart** — набор встроенных пакетов (`dart:*`) доступных без pub зависимостей:

- **`dart:core`** — импортируется автоматически; `String`, `List`, `Map`, `DateTime`, `RegExp`, `Uri`
- **`dart:collection`** — расширенные коллекции: `LinkedHashMap`, `SplayTreeMap`, `Queue`, `ListQueue`
- **`dart:convert`** — кодирование/декодирование: JSON, UTF-8, Base64, Latin1
- **`dart:math`** — математические функции и константы
- **`dart:io`** — файловый I/O, сокеты, HTTP (только для VM, не для Web)
- **`dart:async`** — расширенные async утилиты: `StreamController`, `Completer`, `Zone`, `scheduleMicrotask`

Уровень: **API, утилиты**.

---

## 2. dart:core — базовые типы (13.1)

```dart
// String — immutable, UTF-16
String s = 'Hello, Dart!';
s.length;           // символы (code units), не bytes
s.runes.length;     // Unicode code points
s[0];               // 'H' — код-юнит, не code point!
s.substring(0, 5);  // 'Hello'
s.contains('Dart'); // true
s.replaceAll('l', 'L'); // 'HeLLo, Dart!'
s.split(', ');      // ['Hello', 'Dart!']
s.trim();           // убирает пробелы по краям
s.padLeft(15, '*'); // '***Hello, Dart!'
s.toLowerCase();    // 'hello, dart!'
s.startsWith('He'); // true

// String.fromCharCodes, codeUnitAt — низкоуровневый доступ
String emoji = '😀';
print(emoji.length);          // 2 (это surrogate pair в UTF-16)
print(emoji.runes.length);    // 1 (один code point)

// Многострочные строки
String multi = '''
  Line 1
  Line 2
''';

// RegExp
final email = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
print(email.hasMatch('user@example.com'));  // true
final allNumbers = RegExp(r'\d+').allMatches('a1b23c456');
print(allNumbers.map((m) => m.group(0)).toList()); // [1, 23, 456]

// num, int, double
int.parse('42');               // 42
int.tryParse('abc');           // null (не бросает)
double.parse('3.14');          // 3.14
42.toRadixString(16);          // '2a' (hex)
255.toRadixString(2);          // '11111111' (binary)
(3.7).round();                 // 4
(3.7).floor();                 // 3
(3.7).ceil();                  // 4
(3.7).truncate();              // 3

// DateTime — immutable
final now = DateTime.now();
final specific = DateTime(2024, 3, 15, 10, 30);
final utc = DateTime.utc(2024, 1, 1);
final parsed = DateTime.parse('2024-03-15T10:30:00Z');

specific.year;    // 2024
specific.month;   // 3
specific.day;     // 15
specific.weekday; // DateTime.friday = 5

final tomorrow = now.add(Duration(days: 1));
final diff = tomorrow.difference(now); // Duration(days: 1)
diff.inHours;   // 24
diff.inMinutes; // 1440
now.isBefore(tomorrow); // true
now.isAfter(specific);  // depends

// Comparing
specific.compareTo(utc); // отрицательное если раньше

// Duration
final d = Duration(days: 1, hours: 2, minutes: 30);
d.inSeconds;           // 95400
d.toString();          // '1:02:30.000000'
```

---

## 3. dart:collection (13.2)

```dart
import 'dart:collection';

// LinkedHashMap — стандартный Map в Dart (iteration порядок = insertion порядок)
final map = LinkedHashMap<String, int>();
map['b'] = 2; map['a'] = 1; map['c'] = 3;
print(map.keys.toList()); // [b, a, c] — порядок вставки

// SplayTreeMap — сортированный Map (O(log n) все операции)
final sorted = SplayTreeMap<String, int>((a, b) => a.compareTo(b));
sorted['banana'] = 2; sorted['apple'] = 1; sorted['cherry'] = 3;
print(sorted.keys.toList()); // [apple, banana, cherry]

// HashMap — нет гарантий порядка, быстрее LinkedHashMap
final hash = HashMap<String, int>();

// Queue — двусторонняя очередь
final queue = Queue<int>();
queue.addLast(1);   // enqueue
queue.addFirst(0);  // prepend
queue.removeFirst(); // dequeue: 0
queue.removeLast();  // 1

// ListQueue — Queue на основе списка (более эффективна для большинства операций)
final lq = ListQueue<String>();
lq.add('a'); lq.add('b'); lq.add('c');
lq.first;   // 'a'
lq.last;    // 'c'

// SplayTreeSet — отсортированный Set
final treeSet = SplayTreeSet<int>()..addAll([5, 3, 1, 4, 2]);
print(treeSet.toList()); // [1, 2, 3, 4, 5]

// UnmodifiableListView — read-only обёртка
final mutableList = [1, 2, 3];
final readOnly = UnmodifiableListView(mutableList);
// readOnly.add(4); // UnsupportedError

// ListBase, MapBase, SetBase — для кастомных коллекций
class FruitList extends ListBase<String> {
  final List<String> _inner = [];
  @override int get length => _inner.length;
  @override set length(int l) => _inner.length = l;
  @override String operator [](int i) => _inner[i];
  @override void operator []=(int i, String v) => _inner[i] = v;
}
```

---

## 4. dart:convert (13.3)

```dart
import 'dart:convert';

// JSON
final Map<String, dynamic> data = {'name': 'Alice', 'age': 30, 'tags': ['dart', 'flutter']};
final jsonString = jsonEncode(data);    // '{"name":"Alice","age":30,"tags":["dart","flutter"]}'
final decoded = jsonDecode(jsonString); // Map<String, dynamic>

// pretty print
const encoder = JsonEncoder.withIndent('  ');
print(encoder.convert(data));

// JsonCodec для стриминга больших JSON
final sink = StringBuffer();
JsonEncoder().startChunkedConversion(StringConversionSink.fromStringSink(sink))
    .addSlice(jsonString, 0, jsonString.length, true);

// UTF-8
final List<int> bytes = utf8.encode('Hello, Мир!');
final back = utf8.decode(bytes);
// Безопасное декодирование
final safe = utf8.decode(bytes, allowMalformed: true);

// Base64
final encoded = base64.encode(utf8.encode('Hello'));  // 'SGVsbG8='
final decoded64 = utf8.decode(base64.decode('SGVsbG8=')); // 'Hello'

// base64Url — для URL-safe (заменяет +/= на -_.)
final urlSafe = base64Url.encode(bytes);

// Latin1
final latin1Bytes = latin1.encode('Caf\xe9'); // 'Café'
final latin1String = latin1.decode([67, 97, 102, 233]); // 'Café'

// Codec pipeline — цепочка кодеков
final zipEncoder = utf8.fuse(base64); // UTF-8 → Base64
final result2 = zipEncoder.encode('Hello, World!');
final restored = zipEncoder.decode(result2);
```

---

## 5. dart:math (13.4)

```dart
import 'dart:math';

// Константы
print(pi);    // 3.141592653589793
print(e);     // 2.718281828459045
print(ln2);   // 0.6931471805599453
print(sqrt2); // 1.4142135623730951

// Функции
sqrt(16);         // 4.0
pow(2, 10);       // 1024.0
log(e);           // 1.0 (натуральный логарифм)
sin(pi / 2);      // 1.0
cos(pi);          // -1.0
tan(pi / 4);      // ~1.0
asin(1.0);        // pi/2
atan2(1, 1);      // pi/4

min(3, 5);        // 3
max(3, 5);        // 5
(3.7).abs();      // 3.7
(-3.7).abs();     // 3.7

// Случайные числа
final random = Random();
random.nextInt(10);      // [0, 10)
random.nextDouble();     // [0.0, 1.0)
random.nextBool();       // true или false

// Криптографически стойкий RNG
final secureRandom = Random.secure();
final key = List.generate(32, (_) => secureRandom.nextInt(256));

// Point
final p1 = Point(0, 0);
final p2 = Point(3, 4);
print(p1.distanceTo(p2)); // 5.0
print(p1.squaredDistanceTo(p2)); // 25
```

---

## 6. dart:io (13.5)

```dart
import 'dart:io';

// Файловая система
Future<void> fileOperations() async {
  // Чтение файла
  final file = File('data.txt');
  if (await file.exists()) {
    final content = await file.readAsString();
    final lines = await file.readAsLines();
    final bytes = await file.readAsBytes();
  }

  // Запись файла
  await file.writeAsString('Hello, Dart!');
  await file.writeAsBytes([72, 101, 108, 108, 111]);
  await file.writeAsString('\nMore content', mode: FileMode.append);

  // Стриминговые операции (для больших файлов)
  final stream = file.openRead();
  await for (final chunk in stream) {
    // chunk: List<int>
    process(chunk);
  }

  // IOSink для записи потоками
  final sink = file.openWrite();
  sink.write('Line 1\n');
  sink.write('Line 2\n');
  await sink.flush();
  await sink.close();

  // Директории
  final dir = Directory('data');
  await dir.create(recursive: true);
  
  await for (final entity in dir.list(recursive: true)) {
    if (entity is File) {
      print('File: ${entity.path}');
    } else if (entity is Directory) {
      print('Dir: ${entity.path}');
    }
  }
}

// HTTP сервер
Future<void> httpServer() async {
  final server = await HttpServer.bind('localhost', 8080);
  print('Server on port 8080');
  
  await for (final request in server) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('{"status": "ok"}')
      ..close();
  }
}

// HTTP клиент
Future<void> httpClient() async {
  final client = HttpClient();
  
  final request = await client.getUrl(Uri.parse('https://api.example.com/data'));
  final response = await request.close();
  
  if (response.statusCode == 200) {
    final body = await response.transform(utf8.decoder).join();
    final data = jsonDecode(body);
  }
  
  client.close();
}

// Environment variables
final dbUrl = Platform.environment['DATABASE_URL'] ?? 'postgres://localhost/mydb';
print(Platform.operatingSystem); // 'windows', 'linux', 'macos'
print(Platform.numberOfProcessors);
print(Directory.current.path);

// stdin/stdout
stdout.writeln('Enter your name:');
final name = stdin.readLineSync(encoding: utf8);
stderr.writeln('Error occurred'); // stderr отдельно
```

---

## 7. dart:async расширенные утилиты (13.6)

```dart
import 'dart:async';

// Timer
final timer = Timer(Duration(seconds: 5), () => print('fired once'));
// Отменить до срабатывания:
timer.cancel();

// Periodic timer
final periodic = Timer.periodic(Duration(milliseconds: 500), (t) {
  print('tick ${t.tick}');
  if (t.tick >= 5) t.cancel();
});

// StreamController
final controller = StreamController<String>();
final stream = controller.stream.asBroadcastStream();

// Добавление данных
controller.add('event1');
controller.addError(Exception('something went wrong'));
await controller.close();

// Completer — ручной Future
final completer = Completer<int>();
Future.delayed(Duration(seconds: 1), () => completer.complete(42));
print(await completer.future); // 42

// scheduleMicrotask — приоритетное выполнение
scheduleMicrotask(() => print('This runs before next event queue item'));

// Zone — контекст выполнения
final zone = Zone.current.fork(
  specification: ZoneSpecification(
    print: (_, __, ___, message) {
      // Перехватываем все print в этой zone
      Zone.root.print('[$message]');
    },
  ),
);

zone.run(() {
  print('Hello'); // выведет '[Hello]'
});
```

---

## 8. Практический пример: CLI инструмент

```dart
import 'dart:io';
import 'dart:convert';
import 'dart:math';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: tool <command> [options]');
    exit(1);
  }

  switch (args[0]) {
    case 'hash':
      if (args.length < 2) {
        stderr.writeln('Usage: tool hash <text>');
        exit(1);
      }
      final text = args[1];
      final bytes = utf8.encode(text);
      final encoded = base64.encode(bytes);
      stdout.writeln('Base64: $encoded');

    case 'random':
      final count = args.length > 1 ? int.tryParse(args[1]) ?? 10 : 10;
      final rand = Random.secure();
      final bytes2 = List.generate(count, (_) => rand.nextInt(256));
      stdout.writeln('Random bytes: ${bytes2.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    case 'json-format':
      if (args.length < 2) {
        stderr.writeln('Pipe JSON or provide path');
        exit(1);
      }
      final file = File(args[1]);
      if (!await file.exists()) {
        stderr.writeln('File not found: ${args[1]}');
        exit(1);
      }
      final content = await file.readAsString();
      try {
        final data = jsonDecode(content);
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(data));
      } on FormatException catch (e) {
        stderr.writeln('Invalid JSON: ${e.message}');
        exit(1);
      }

    default:
      stderr.writeln('Unknown command: ${args[0]}');
      exit(1);
  }
}
```

---

## 9. Под капотом

- **`dart:core`** компилируется как native код — `String`, `List` имеют оптимизированные VM representation
- **`dart:io`** — тонкая обёртка над нативными syscall через Dart native extensions
- **`dart:convert`** UTF-8 decoder использует оптимизированные SIMD инструкции в AOT
- **`dart:math`** `Random()` — Mersenne Twister; `Random.secure()` — `/dev/urandom` на POSIX, CryptGenRandom на Windows

---

## 10. Производительность

- **`File.readAsBytes()`** быстрее `readAsString()` — нет UTF-8 decode
- **Стриминг файлов** (`file.openRead()`) — O(1) память для любых файлов vs O(N) для `readAsBytes()`
- **`jsonEncode` большого объекта** — рассмотрите стриминговый encode для >10MB
- **`StringBuffer`** для конкатенации строк вместо `+` в цикле — O(N) vs O(N²)

```dart
// МЕДЛЕННО: O(N²) из-за копирования строк
String buildBad(List<String> parts) {
  String result = '';
  for (final p in parts) result += p;
  return result;
}

// БЫСТРО: O(N)
String buildGood(List<String> parts) => parts.join();
// или
String buildBuffer(List<String> parts) {
  final sb = StringBuffer();
  for (final p in parts) sb.write(p);
  return sb.toString();
}
```

---

## 11. Частые ошибки

**1. `dart:io` в Flutter Web:**
```dart
// ОШИБКА — dart:io недоступен на web
import 'dart:io';
void main() => File('test.txt').readAsStringSync(); // failed on web

// Используйте package:http, package:file, или conditional imports
```

**2. Синхронный I/O в production:**
```dart
// ПЛОХО — блокирует event loop
final content = File('data.txt').readAsStringSync();

// ХОРОШО — асинхронно
final content = await File('data.txt').readAsString();
```

**3. Незакрытый HttpClient:**
```dart
// Утечка: client создаётся каждый раз без закрытия
Future<void> bad() async {
  final client = HttpClient();
  await client.getUrl(uri); // ...
  // client.close() — забыли!
}
```

---

## 12. Краткое резюме

1. **`dart:core`** автоматически импортирован; `String`, `DateTime`, `RegExp`, `Uri` — основные типы
2. **`dart:collection`** добавляет `LinkedHashMap`, `SplayTreeMap`, `Queue` — когда нужно больше чем литеральные `Map`/`Set`
3. **`dart:convert`** — `jsonEncode`/`jsonDecode`, `utf8`, `base64`; все codec поддерживают стриминг через `startChunkedConversion`
4. **`dart:math`** — `pi`, `e`, `sqrt`, `Random`/`Random.secure()`
5. **`dart:io`** недоступен на Web; используйте условные импорты для кросс-платформенного кода
6. **`StringBuffer`** для конкатенации строк в цикле — принципиальная разница производительности
7. **`dart:async`** — `Timer`, `Completer`, `Zone` для продвинутой async работы
