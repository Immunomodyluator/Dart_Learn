# 11.3 Интеграционные и E2E тесты

## 1. Формальное определение

**Интеграционный тест** — тест, который проверяет взаимодействие нескольких компонентов системы вместе (без полной изоляции), но может заменять внешние сервисы (БД, API) тестовыми двойниками.

**E2E тест (End-to-End)** — тест, который проходит весь путь пользователя через приложение с реальными зависимостями (или максимально приближёнными к реальным).

| Уровень     | Что мокируется       | Что реально              |
| ----------- | -------------------- | ------------------------ |
| Unit        | Все зависимости      | Только тестируемый класс |
| Integration | Внешние сервисы      | Несколько классов вместе |
| E2E         | Ничего (или минимум) | Всё приложение           |

## 2. Зачем это нужно

- **Unit-тесты не ловят всё** — компоненты могут работать поодиночке, но ломаться вместе.
- **Контракты** — проверить, что `Service → Repository → Database` работают как единое целое.
- **Реалистичность** — ближе к реальному поведению приложения.
- **Рефакторинг** — можно менять внутреннюю структуру, если интеграция не сломалась.
- **Конфигурация** — ловить ошибки в подключении, сериализации, маршрутизации.

## 3. Как это работает

### Интеграционный тест: несколько классов вместе

```dart
// lib/src/models.dart
class Product {
  final int id;
  final String name;
  final double price;

  const Product({required this.id, required this.name, required this.price});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as int,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
  );
}

// lib/src/product_repository.dart
abstract class ProductDatabase {
  Future<Map<String, dynamic>?> findById(int id);
  Future<void> insert(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> findAll();
}

class ProductRepository {
  final ProductDatabase _db;
  ProductRepository(this._db);

  Future<Product?> getById(int id) async {
    final data = await _db.findById(id);
    return data != null ? Product.fromJson(data) : null;
  }

  Future<void> save(Product product) async {
    await _db.insert(product.toJson());
  }

  Future<List<Product>> getAll() async {
    final rows = await _db.findAll();
    return rows.map(Product.fromJson).toList();
  }
}

// lib/src/order_service.dart
class OrderService {
  final ProductRepository _repo;
  OrderService(this._repo);

  Future<double> calculateTotal(List<int> productIds) async {
    var total = 0.0;
    for (final id in productIds) {
      final product = await _repo.getById(id);
      if (product == null) throw Exception('Product $id not found');
      total += product.price;
    }
    return total;
  }
}
```

```dart
// test/integration/order_flow_test.dart
import 'package:test/test.dart';

// Здесь мы мокируем только БД, но Repository и Service — реальные

class InMemoryDatabase implements ProductDatabase {
  final _store = <int, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> findById(int id) async => _store[id];

  @override
  Future<void> insert(Map<String, dynamic> data) async {
    _store[data['id'] as int] = data;
  }

  @override
  Future<List<Map<String, dynamic>>> findAll() async => _store.values.toList();
}

// Определения классов выше (Product, ProductDatabase, ProductRepository, OrderService)

abstract class ProductDatabase {
  Future<Map<String, dynamic>?> findById(int id);
  Future<void> insert(Map<String, dynamic> data);
  Future<List<Map<String, dynamic>>> findAll();
}

class Product {
  final int id;
  final String name;
  final double price;
  const Product({required this.id, required this.name, required this.price});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price};
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as int, name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
  );
}

class ProductRepository {
  final ProductDatabase _db;
  ProductRepository(this._db);
  Future<Product?> getById(int id) async {
    final data = await _db.findById(id);
    return data != null ? Product.fromJson(data) : null;
  }
  Future<void> save(Product product) async => await _db.insert(product.toJson());
  Future<List<Product>> getAll() async {
    final rows = await _db.findAll();
    return rows.map(Product.fromJson).toList();
  }
}

class OrderService {
  final ProductRepository _repo;
  OrderService(this._repo);
  Future<double> calculateTotal(List<int> productIds) async {
    var total = 0.0;
    for (final id in productIds) {
      final product = await _repo.getById(id);
      if (product == null) throw Exception('Product $id not found');
      total += product.price;
    }
    return total;
  }
}

void main() {
  late InMemoryDatabase db;
  late ProductRepository repo;
  late OrderService orderService;

  setUp(() async {
    db = InMemoryDatabase();
    repo = ProductRepository(db);
    orderService = OrderService(repo);

    // Seed тестовые данные
    await repo.save(Product(id: 1, name: 'Книга', price: 500.0));
    await repo.save(Product(id: 2, name: 'Ручка', price: 50.0));
    await repo.save(Product(id: 3, name: 'Тетрадь', price: 100.0));
  });

  group('Интеграция: OrderService + Repository + Database', () {
    test('calculateTotal суммирует цены продуктов', () async {
      final total = await orderService.calculateTotal([1, 2, 3]);
      expect(total, equals(650.0));
    });

    test('calculateTotal для одного продукта', () async {
      final total = await orderService.calculateTotal([2]);
      expect(total, equals(50.0));
    });

    test('calculateTotal бросает при несуществующем продукте', () async {
      expect(
        () => orderService.calculateTotal([1, 999]),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('999'),
        )),
      );
    });

    test('полный цикл: сохранение → чтение → расчёт', () async {
      // Добавляем новый продукт
      await repo.save(Product(id: 4, name: 'Ластик', price: 30.0));

      // Проверяем что он сохранился
      final product = await repo.getById(4);
      expect(product, isNotNull);
      expect(product!.name, equals('Ластик'));

      // Считаем с новым продуктом
      final total = await orderService.calculateTotal([1, 4]);
      expect(total, equals(530.0));
    });
  });

  group('Repository ↔ Database', () {
    test('getAll возвращает все сохранённые продукты', () async {
      final products = await repo.getAll();
      expect(products, hasLength(3));
      expect(
        products.map((p) => p.name),
        containsAll(['Книга', 'Ручка', 'Тетрадь']),
      );
    });

    test('getById для несуществующего возвращает null', () async {
      final product = await repo.getById(999);
      expect(product, isNull);
    });
  });
}
```

### Тестирование HTTP-сервера (dart:io)

```dart
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

// Простейший HTTP сервер
Future<HttpServer> startTestServer() async {
  final server = await HttpServer.bind('localhost', 0); // 0 = случайный порт

  server.listen((request) async {
    switch ('${request.method} ${request.uri.path}') {
      case 'GET /health':
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'status': 'ok'}));
      case 'GET /users':
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode([
            {'id': 1, 'name': 'Иван'},
            {'id': 2, 'name': 'Мария'},
          ]));
      case 'POST /users':
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        request.response
          ..statusCode = 201
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({...data, 'id': 3}));
      default:
        request.response
          ..statusCode = 404
          ..write('Not found');
    }
    await request.response.close();
  });

  return server;
}

void main() {
  late HttpServer server;
  late HttpClient client;
  late String baseUrl;

  setUpAll(() async {
    server = await startTestServer();
    baseUrl = 'http://localhost:${server.port}';
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close();
    await server.close();
  });

  Future<(int, dynamic)> get(String path) async {
    final request = await client.getUrl(Uri.parse('$baseUrl$path'));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return (response.statusCode, jsonDecode(body));
  }

  Future<(int, dynamic)> post(String path, Map<String, dynamic> data) async {
    final request = await client.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(data));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return (response.statusCode, jsonDecode(body));
  }

  test('GET /health', () async {
    final (status, body) = await get('/health');
    expect(status, equals(200));
    expect(body, containsPair('status', 'ok'));
  });

  test('GET /users', () async {
    final (status, body) = await get('/users');
    expect(status, equals(200));
    expect(body, isList);
    expect(body, hasLength(2));
  });

  test('POST /users', () async {
    final (status, body) = await post('/users', {'name': 'Алексей'});
    expect(status, equals(201));
    expect(body, containsPair('name', 'Алексей'));
    expect(body, containsPair('id', 3));
  });

  test('GET /unknown → 404', () async {
    final request = await client.getUrl(Uri.parse('$baseUrl/unknown'));
    final response = await request.close();
    expect(response.statusCode, equals(404));
  });
}
```

### Тестирование CLI-процесса

```dart
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('dart --version возвращает версию', () async {
    final result = await Process.run('dart', ['--version']);
    expect(result.exitCode, equals(0));
    // Версия может быть в stdout или stderr
    final output = '${result.stdout}${result.stderr}';
    expect(output, contains('Dart'));
  });

  test('dart compile проверяет синтаксис', () async {
    // Создаём временный файл
    final tempDir = await Directory.systemTemp.createTemp('dart_test_');
    final file = File('${tempDir.path}/test.dart');
    await file.writeAsString('''
void main() {
  print('Hello');
}
''');

    try {
      final result = await Process.run(
        'dart',
        ['analyze', file.path],
      );
      expect(result.exitCode, equals(0));
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
```

### Тестирование с файловой системой

```dart
import 'dart:io';
import 'package:test/test.dart';

class ConfigLoader {
  Future<Map<String, String>> load(String path) async {
    final file = File(path);
    if (!await file.exists()) return {};

    final lines = await file.readAsLines();
    final config = <String, String>{};
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split('=');
      if (parts.length == 2) {
        config[parts[0].trim()] = parts[1].trim();
      }
    }
    return config;
  }
}

void main() {
  late Directory tempDir;
  late ConfigLoader loader;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('config_test_');
    loader = ConfigLoader();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('загружает конфигурацию из файла', () async {
    final file = File('${tempDir.path}/app.conf');
    await file.writeAsString('''
# Комментарий
host = localhost
port = 8080
debug = true
''');

    final config = await loader.load(file.path);

    expect(config, {
      'host': 'localhost',
      'port': '8080',
      'debug': 'true',
    });
  });

  test('возвращает пустой map для несуществующего файла', () async {
    final config = await loader.load('${tempDir.path}/nonexistent.conf');
    expect(config, isEmpty);
  });

  test('игнорирует пустые строки и комментарии', () async {
    final file = File('${tempDir.path}/sparse.conf');
    await file.writeAsString('''

# Только комментарии

# и пустые строки

key = value
''');

    final config = await loader.load(file.path);
    expect(config, hasLength(1));
    expect(config['key'], equals('value'));
  });
}
```

### Теги и конфигурация `dart_test.yaml`

```yaml
# dart_test.yaml
tags:
  integration:
    timeout: 30s
  slow:
    timeout: 2m
    skip: "Пропущено в CI"

platforms: [vm]

# Запуск только интеграционных тестов:
# dart test --tags integration

# Запуск всех кроме slow:
# dart test --exclude-tags slow
```

```dart
// test/tagged_test.dart
@Tags(['integration'])
library;

import 'package:test/test.dart';

void main() {
  test('подключение к тестовой БД', () async {
    // Этот тест запускается только с --tags integration
    await Future.delayed(Duration(seconds: 1));
    expect(true, isTrue);
  }, tags: ['slow']);
}
```

## 4. Минимальный пример

```dart
// test/integration/simple_integration_test.dart
import 'package:test/test.dart';

// Два реальных класса работают вместе
class Formatter {
  String format(String name) => name.trim().toUpperCase();
}

class Greeter {
  final Formatter _formatter;
  Greeter(this._formatter);

  String greet(String name) {
    final formatted = _formatter.format(name);
    return 'Привет, $formatted!';
  }
}

void main() {
  test('Greeter + Formatter работают вместе', () {
    // Оба класса — реальные, не моки
    final greeter = Greeter(Formatter());
    expect(greeter.greet('  dart  '), equals('Привет, DART!'));
  });
}
```

## 5. Практический пример

### E2E тест: полный REST API flow

```dart
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

// ── Тестируемое приложение (упрощённый REST API) ──

class TodoApp {
  final _todos = <int, Map<String, dynamic>>{};
  var _nextId = 1;
  HttpServer? _server;

  Future<int> start() async {
    _server = await HttpServer.bind('localhost', 0);
    _server!.listen(_handleRequest);
    return _server!.port;
  }

  Future<void> stop() async => await _server?.close();

  void _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final method = request.method;

      if (path == '/todos' && method == 'GET') {
        _respond(request, 200, _todos.values.toList());
      } else if (path == '/todos' && method == 'POST') {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        final id = _nextId++;
        _todos[id] = {'id': id, ...body as Map<String, dynamic>, 'done': false};
        _respond(request, 201, _todos[id]);
      } else if (path.startsWith('/todos/') && method == 'PATCH') {
        final id = int.parse(path.split('/').last);
        if (!_todos.containsKey(id)) {
          _respond(request, 404, {'error': 'Not found'});
          return;
        }
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        _todos[id]!.addAll(body as Map<String, dynamic>);
        _respond(request, 200, _todos[id]);
      } else if (path.startsWith('/todos/') && method == 'DELETE') {
        final id = int.parse(path.split('/').last);
        if (_todos.remove(id) != null) {
          _respond(request, 204, null);
        } else {
          _respond(request, 404, {'error': 'Not found'});
        }
      } else {
        _respond(request, 404, {'error': 'Not found'});
      }
    } catch (e) {
      _respond(request, 500, {'error': e.toString()});
    }
  }

  void _respond(HttpRequest request, int status, Object? body) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    if (body != null) request.response.write(jsonEncode(body));
    request.response.close();
  }
}

// ── E2E тест ──

void main() {
  late TodoApp app;
  late HttpClient client;
  late String baseUrl;

  setUpAll(() async {
    app = TodoApp();
    final port = await app.start();
    baseUrl = 'http://localhost:$port';
    client = HttpClient();
  });

  tearDownAll(() async {
    client.close();
    await app.stop();
  });

  // Вспомогательные методы
  Future<(int, dynamic)> httpGet(String path) async {
    final req = await client.getUrl(Uri.parse('$baseUrl$path'));
    final res = await req.close();
    final body = await utf8.decoder.bind(res).join();
    return (res.statusCode, body.isNotEmpty ? jsonDecode(body) : null);
  }

  Future<(int, dynamic)> httpPost(String path, Map<String, dynamic> data) async {
    final req = await client.postUrl(Uri.parse('$baseUrl$path'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(data));
    final res = await req.close();
    final body = await utf8.decoder.bind(res).join();
    return (res.statusCode, jsonDecode(body));
  }

  Future<(int, dynamic)> httpPatch(String path, Map<String, dynamic> data) async {
    final req = await client.openUrl('PATCH', Uri.parse('$baseUrl$path'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(data));
    final res = await req.close();
    final body = await utf8.decoder.bind(res).join();
    return (res.statusCode, jsonDecode(body));
  }

  Future<int> httpDelete(String path) async {
    final req = await client.deleteUrl(Uri.parse('$baseUrl$path'));
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  }

  // ── Тесты ──

  test('E2E: полный CRUD цикл', () async {
    // 1. Список пуст
    var (status, body) = await httpGet('/todos');
    expect(status, 200);
    expect(body, isEmpty);

    // 2. Создаём задачу
    (status, body) = await httpPost('/todos', {'title': 'Купить молоко'});
    expect(status, 201);
    expect(body['title'], 'Купить молоко');
    expect(body['done'], false);
    final id = body['id'];

    // 3. Проверяем что появилась в списке
    (status, body) = await httpGet('/todos');
    expect(status, 200);
    expect(body, hasLength(1));

    // 4. Обновляем (отмечаем выполненной)
    (status, body) = await httpPatch('/todos/$id', {'done': true});
    expect(status, 200);
    expect(body['done'], true);

    // 5. Удаляем
    status = await httpDelete('/todos/$id');
    expect(status, 204);

    // 6. Проверяем что список снова пуст
    (status, body) = await httpGet('/todos');
    expect(body, isEmpty);
  });

  test('DELETE несуществующего → 404', () async {
    final status = await httpDelete('/todos/999');
    expect(status, 404);
  });
}
```

## 6. Что происходит под капотом

```
Unit vs Integration vs E2E:

Unit test:                Integration test:           E2E test:
  ┌─────────┐             ┌─────────────────┐         ┌───────────────────┐
  │ Service  │ ← mock     │ Service          │         │ HTTP Client       │
  │ (tested) │            │ ↓                │         │ ↓                 │
  └─────────┘             │ Repository       │         │ HTTP Server       │
                          │ ↓                │         │ ↓                 │
                          │ InMemoryDB(fake) │         │ Service → Repo    │
                          └─────────────────┘         │ ↓                 │
                                                      │ Real/InMemory DB  │
                                                      └───────────────────┘

Порядок выполнения:
  setUpAll()          → запуск сервера / seed данных (один раз)
    setUp()           → сброс состояния
    test('...')        → HTTP запрос → ответ → expect
    tearDown()        → очистка
  tearDownAll()       → остановка сервера

HttpServer.bind('localhost', 0):
  0 → ОС выбирает свободный порт
  → server.port → получаем назначенный порт
  → предотвращает конфликты при параллельном запуске тестов
```

## 7. Производительность и ресурсы

| Аспект               | Unit      | Integration | E2E             |
| -------------------- | --------- | ----------- | --------------- |
| Время теста          | ≤1 мс     | 10–100 мс   | 100мс–5с        |
| Настройка            | Мгновенно | InMemory DB | Сервер + клиент |
| Хрупкость            | Низкая    | Средняя     | Высокая         |
| Затраты на поддержку | Низкие    | Средние     | Высокие         |
| Реалистичность       | Низкая    | Средняя     | Высокая         |

**Правило пирамиды:**

- 70% unit-тестов (быстрые, много).
- 20% интеграционных (средние, несколько).
- 10% E2E (медленные, ключевые сценарии).

## 8. Частые ошибки и антипаттерны

### ❌ Жёстко заданный порт

```dart
// ❌ Может конфликтовать с другими процессами
// final server = await HttpServer.bind('localhost', 8080);

// ✅ Случайный порт
// final server = await HttpServer.bind('localhost', 0);
// final port = server.port;
```

### ❌ Забыли очистить состояние

```dart
// ❌ Тесты зависят от порядка
// test('создаёт пользователя', () async { ... }); // создал id=1
// test('список пуст', () async { ... }); // ← упадёт, т.к. пользователь уже есть!

// ✅ Очищайте в setUp или используйте отдельные экземпляры
```

### ❌ Забыли остановить сервер

```dart
// ❌ Порт занят для следующего запуска тестов
// setUpAll(() async { server = await startServer(); });
// ...нет tearDownAll!

// ✅
// tearDownAll(() async { await server.close(); });
```

### ❌ Слишком много E2E тестов

```dart
// ❌ 500 E2E тестов → запуск 30 минут
// Баланс: unit >> integration > E2E
```

## 9. Сравнение с альтернативами

| Подход                   | Dart-инструмент               | Скорость | Когда                  |
| ------------------------ | ----------------------------- | -------- | ---------------------- |
| InMemory интеграционный  | `package:test` + Fake DB      | Быстро   | Бизнес-логика + данные |
| HTTP интеграционный      | `package:test` + `HttpServer` | Средне   | REST API тесты         |
| CLI тест                 | `Process.run`                 | Средне   | Консольные приложения  |
| Flutter integration_test | `package:integration_test`    | Медленно | Flutter UI E2E         |
| Contract testing         | Pact / HTTP mock              | Средне   | Микросервисы           |

## 10. Когда НЕ стоит использовать

- **Простая бизнес-логика** — unit-тест быстрее и надёжнее.
- **UI-визуалы** — Golden tests (Flutter) лучше для проверки рендеринга.
- **Внешние API в CI** — нестабильно; используйте contract тесты или WireMock.
- **Каждая мелкая функция** — пирамида: 70% unit, 20% integration, 10% E2E.

## 11. Краткое резюме

1. **Интеграционный тест** — несколько реальных компонентов вместе, внешние зависимости заменены (InMemory DB, тестовый HTTP сервер).
2. **E2E тест** — весь путь: HTTP запрос → сервер → обработка → ответ.
3. **`HttpServer.bind('localhost', 0)`** — случайный порт, без конфликтов.
4. **`setUpAll` / `tearDownAll`** — запуск и остановка серверов и тяжёлых ресурсов.
5. **Теги** — `@Tags(['integration'])` + `dart test --tags integration`.
6. **Пирамида тестирования** — 70% unit, 20% integration, 10% E2E.
7. **Очистка** — всегда останавливайте серверы, удаляйте временные файлы.
8. **Детерминизм** — используйте изолированное состояние для каждого теста.

---

> **Назад:** [11.2 Mocking и stubbing](11_02_mocking.md) · **Далее:** [11.4 Покрытие кода и CI-интеграция](11_04_coverage_ci.md)
