# Урок 20. Платформенные применения Dart

> Охватывает подтемы: 20.1 Dart для сервера (Shelf), 20.2 Dart для Web (dart2web/Wasm), 20.3 Flutter обзор, 20.4 CLI инструменты

---

## 1. Формальное определение

Dart работает на нескольких платформах:

| Платформа | Runtime | Вывод |
|---|---|---|
| **CLI/Server** | Dart VM (JIT + AOT) | нативный бинарник или запуск через `dart run` |
| **Web** | dart2js → JavaScript / Wasm | JS bundle или WebAssembly |
| **Mobile/Desktop** | Flutter + AOT Dart | APK, IPA, .exe, .app |

---

## 2. Dart для сервера (20.1)

### Shelf — минималистичный HTTP фреймворк

```bash
dart pub add shelf shelf_router shelf_static
dart pub add --dev test mockito
```

```dart
// bin/server.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';

void main() async {
  final app = createApp();
  
  final server = await shelf_io.serve(
    const Pipeline()
        .addMiddleware(logRequests())        // встроенный логгер
        .addMiddleware(_corsMiddleware())     // кастомный middleware
        .addMiddleware(_authMiddleware())
        .addHandler(app),
    InternetAddress.anyIPv4,
    int.parse(Platform.environment['PORT'] ?? '8080'),
  );
  
  print('Server running on port ${server.port}');
}

Router createApp() {
  final router = Router();
  
  // REST endpoints
  router.get('/health', (Request req) =>
      Response.ok('{"status":"ok"}', headers: {'Content-Type': 'application/json'}));
  
  router.get('/users', (Request req) async {
    final users = await userRepo.findAll();
    return Response.ok(jsonEncode(users.map((u) => u.toJson()).toList()),
        headers: {'Content-Type': 'application/json'});
  });
  
  router.get('/users/<id>', (Request req, String id) async {
    final user = await userRepo.findById(id);
    if (user == null) {
      return Response.notFound(jsonEncode({'error': 'Not found'}));
    }
    return Response.ok(jsonEncode(user.toJson()),
        headers: {'Content-Type': 'application/json'});
  });
  
  router.post('/users', (Request req) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final user = await userService.createUser(body['name'], body['email']);
    return Response(201, body: jsonEncode(user.toJson()),
        headers: {'Content-Type': 'application/json'});
  });
  
  router.put('/users/<id>', (Request req, String id) async {
    final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    final user = await userService.updateUser(id, body);
    return Response.ok(jsonEncode(user.toJson()));
  });
  
  router.delete('/users/<id>', (Request req, String id) async {
    await userRepo.delete(id);
    return Response(204);
  });
  
  return router;
}

// Middleware
Middleware _corsMiddleware() => (Handler handler) => (Request request) async {
  if (request.method == 'OPTIONS') {
    return Response.ok('', headers: _corsHeaders);
  }
  final response = await handler(request);
  return response.change(headers: _corsHeaders);
};

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Middleware _authMiddleware() => (Handler handler) => (Request request) async {
  if (request.url.path.startsWith('public/')) return handler(request);
  
  final authHeader = request.headers['Authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    return Response.forbidden(jsonEncode({'error': 'Unauthorized'}));
  }
  
  final token = authHeader.substring(7);
  final userId = await validateToken(token);
  if (userId == null) {
    return Response.forbidden(jsonEncode({'error': 'Invalid token'}));
  }
  
  // Передаёт userId следующему обработчику
  return handler(request.change(context: {'userId': userId, ...request.context}));
};

// Компиляция в нативный бинарник
// dart compile exe bin/server.dart -o server
// ./server  ← быстрый старт, нет JIT warmup
```

### Альтернативы Shelf

- **Dartfrog** (shelf поверх) — batteries-included, HotReload
- **Conduit** — полноценный MVC фреймворк с ORM
- **Dart Frog** (Very Good Ventures) — CLI-first fullstack
- **gRPC** — `package:grpc` — protobuf/gRPC сервер

---

## 3. Dart для Web (20.2)

```bash
# Создать веб проект
dart create -t web my_web_app

# Структура:
# web/
#   index.html
#   main.dart
# pubspec.yaml
```

```dart
// web/main.dart
import 'dart:html';
import 'dart:convert';
import 'dart:js_interop';   // Dart 3 JS interop

void main() {
  // Работа с DOM
  final button = querySelector('#my-button') as ButtonElement;
  final output = querySelector('#output') as DivElement;
  
  button.onClick.listen((event) async {
    output.text = 'Loading...';
    
    final data = await fetchData();
    output.innerHtml = '<b>Result:</b> $data';
  });
  
  // Анимация
  window.requestAnimationFrame(animationLoop);
}

int _frame = 0;
void animationLoop(num timestamp) {
  _frame++;
  final canvas = querySelector('#canvas') as CanvasElement;
  final ctx = canvas.context2D;
  
  ctx.clearRect(0, 0, canvas.width!, canvas.height!);
  ctx.fillStyle = 'blue';
  ctx.fillRect(_frame % canvas.width!, 50, 50, 50);
  
  window.requestAnimationFrame(animationLoop);
}

Future<String> fetchData() async {
  final client = HttpRequest();
  await HttpRequest.getString('/api/data').then((response) {
    // Обработка ответа
  });
  return 'data';
}
```

```bash
# Компиляция в JS
dart compile js web/main.dart -o web/main.dart.js

# Оптимизированная для продакшн
dart compile js web/main.dart -o build/main.dart.js -O4 --minify

# WebAssembly (Dart 3.3+, требует Chrome 119+)
dart compile wasm web/main.dart -o build/main.wasm
```

---

## 4. Flutter обзор (20.3)

Flutter — UI фреймворк на Dart; рисует всё сам через Skia/Impeller:

```dart
// Минимальное Flutter приложение
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Text('Count: $_count', style: Theme.of(context).textTheme.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _count++),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### Когда Flutter vs чистый Dart

| Задача | Инструмент |
|---|---|
| Mobile/Desktop UI | Flutter |
| Веб приложение (SPA) | Flutter Web или dart2js |
| REST API сервер | Dart + Shelf/Conduit |
| CLI инструмент | Dart CLI |
| Скрипты, утилиты | Dart script |

---

## 5. CLI инструменты (20.4)

```dart
// bin/cli.dart — полноценный CLI инструмент
import 'dart:io';
import 'package:args/args.dart';

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addCommand('generate')
    ..addCommand('analyze')
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output', negatable: false)
    ..addFlag('help', abbr: 'h', help: 'Show help', negatable: false)
    ..addOption('output', abbr: 'o', help: 'Output directory', defaultsTo: 'build')
    ..addOption('format', allowed: ['json', 'yaml', 'csv'], defaultsTo: 'json');

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    print('Usage: my_tool <command> [options]');
    print(parser.usage);
    exit(0);
  }

  final verbose = args['verbose'] as bool;
  final outputDir = args['output'] as String;

  switch (args.command?.name) {
    case 'generate':
      runGenerate(args.command!, outputDir, verbose);
    case 'analyze':
      runAnalyze(args.command!, verbose);
    case null:
      stderr.writeln('Please specify a command');
      stderr.writeln(parser.usage);
      exit(1);
    default:
      stderr.writeln('Unknown command: ${args.command!.name}');
      exit(1);
  }
}

void runGenerate(ArgResults args, String outputDir, bool verbose) {
  final dir = Directory(outputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
    if (verbose) print('Created directory: $outputDir');
  }
  
  print('Generating into $outputDir...');
  // ... генерация
}

void runAnalyze(ArgResults args, bool verbose) {
  print('Analyzing...');
  // ... анализ
}
```

```bash
# Компиляция в нативный бинарник
dart compile exe bin/cli.dart -o my_tool
./my_tool generate -o output --verbose

# Глобальная установка
dart pub global activate .          # локальный пакет
dart pub global activate my_tool    # c pub.dev

# Обёртка для pub global (автоматически создаёт shell script):
# ~/.pub-cache/bin/my_tool
```

---

## 6. Компиляция

```bash
# JIT (разработка)
dart run bin/server.dart

# AOT (продакшн)
dart compile exe bin/server.dart -o server  # нативный бинарник ~10-30 MB
./server

# Snapshot (быстрый запуск без JIT тепло-вверх)
dart compile snapshot bin/server.dart -o server.snapshot
dart run server.snapshot

# JavaScript (Web)
dart compile js web/main.dart -o build/main.js

# WebAssembly
dart compile wasm web/main.dart -o build/app.wasm
```

---

## 7. Минимальный пример: JSON API в 50 строк

```dart
import 'dart:io';
import 'dart:convert';

void main() async {
  final server = await HttpServer.bind('localhost', 8080);
  print('Server on :8080');

  final data = <String, Map<String, dynamic>>{};

  await for (final req in server) {
    final path = req.uri.path;
    final method = req.method;

    try {
      if (method == 'GET' && path.startsWith('/items/')) {
        final id = path.split('/').last;
        final item = data[id];
        if (item == null) {
          respond(req, 404, {'error': 'Not found'});
        } else {
          respond(req, 200, item);
        }
      } else if (method == 'POST' && path == '/items') {
        final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        data[id] = {...body, 'id': id};
        respond(req, 201, data[id]!);
      } else if (method == 'GET' && path == '/items') {
        respond(req, 200, {'items': data.values.toList()});
      } else {
        respond(req, 404, {'error': 'Not found'});
      }
    } catch (e) {
      respond(req, 500, {'error': e.toString()});
    }
  }
}

void respond(HttpRequest req, int status, Object body) {
  req.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  req.response.close();
}
```

---

## 8. Производительность по платформам

| Аспект | VM JIT | AOT native | dart2js | Wasm |
|---|---|---|---|---|
| Startup time | ~100-500ms | ~5-20ms | N/A (браузер) | N/A |
| Peak performance | Хорошо (JIT opt) | Отлично | Зависит от V8 | Хорошо |
| Размер бинарника | N/A | ~5-30 MB | ~100KB-2MB | ~5-15 MB |
| Tree shaking | Нет | Да | Да | Да |

---

## 9. Краткое резюме

1. **Dart versatile**: CLI, HTTP сервер, Web, мобильный/desktop через Flutter — один язык
2. **Shelf** — минималистичный и composable HTTP фреймворк; router + middleware + handlers
3. **`dart compile exe`** — нативный бинарник; быстрый запуск, никакого JDK/VM на хосте
4. **dart2js** — компиляция в JS для Web; `-O4 --minify` для продакшн
5. **WebAssembly** (Dart 3.3+) — лучшая производительность числовых задач в браузере
6. **Flutter** — мобильный/desktop/web UI; не нужен web-специфичный HTML/CSS
7. **`package:args`** — парсинг CLI аргументов; поддержка субкоманд, флагов, опций
