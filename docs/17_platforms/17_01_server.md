# 17.1 Dart на сервере

## 1. Формальное определение

Dart может работать как серверный язык благодаря `dart:io` — библиотеке для работы с файлами, сокетами, HTTP и процессами. Серверные фреймворки (Shelf, dart_frog, Serverpod) строятся поверх этой библиотеки.

## 2. Зачем это нужно

- **Full-stack Dart** — один язык на клиенте (Flutter) и сервере.
- **Производительность** — AOT-компиляция, быстрый старт, низкое потребление памяти.
- **Типобезопасность** — общие модели между клиентом и сервером.
- **Async-модель** — event loop отлично подходит для HTTP-серверов.

## 3. Shelf — минималистичный middleware-фреймворк

```yaml
# pubspec.yaml
dependencies:
  shelf: ^1.4.0
  shelf_router: ^1.1.0
```

```dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

void main() async {
  final router = Router();

  router.get('/api/health', (Request request) {
    return Response.ok('{"status": "ok"}',
        headers: {'content-type': 'application/json'});
  });

  router.get('/api/users/<id>', (Request request, String id) {
    return Response.ok('{"id": "$id", "name": "User $id"}',
        headers: {'content-type': 'application/json'});
  });

  router.post('/api/users', (Request request) async {
    final body = await request.readAsString();
    return Response(201,
        body: body,
        headers: {'content-type': 'application/json'});
  });

  // Middleware pipeline
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(router.call);

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server running on http://${server.address.host}:${server.port}');
}

Middleware _corsMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await handler(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
```

### Middleware

```dart
// Аутентификация
Middleware authMiddleware() {
  return (Handler handler) {
    return (Request request) {
      final token = request.headers['authorization'];
      if (token == null || !token.startsWith('Bearer ')) {
        return Response(401, body: 'Unauthorized');
      }
      // Добавить контекст
      final updatedRequest = request.change(
        context: {'userId': _verifyToken(token.substring(7))},
      );
      return handler(updatedRequest);
    };
  };
}
```

## 4. dart_frog — полнофункциональный фреймворк

```bash
# Установка
dart pub global activate dart_frog_cli

# Создание проекта
dart_frog create my_api

# Запуск dev сервера
dart_frog dev

# Сборка production
dart_frog build
```

```dart
// routes/api/users/index.dart
import 'package:dart_frog/dart_frog.dart';

// GET /api/users → onRequest
// POST /api/users → onRequest
Response onRequest(RequestContext context) {
  return switch (context.request.method) {
    HttpMethod.get => _getUsers(context),
    HttpMethod.post => _createUser(context),
    _ => Response(statusCode: 405),
  };
}

Response _getUsers(RequestContext context) {
  return Response.json(body: [
    {'id': '1', 'name': 'Alice'},
    {'id': '2', 'name': 'Bob'},
  ]);
}

Future<Response> _createUser(RequestContext context) async {
  final body = await context.request.json();
  return Response.json(statusCode: 201, body: body);
}
```

## 5. HTTP-сервер на чистом dart:io

```dart
import 'dart:convert';
import 'dart:io';

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('Server running on port ${server.port}');

  await for (final request in server) {
    final path = request.uri.path;
    final method = request.method;

    if (method == 'GET' && path == '/api/health') {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'status': 'ok'}));
    } else {
      request.response
        ..statusCode = 404
        ..write('Not Found');
    }

    await request.response.close();
  }
}
```

## 6. Компиляция и деплой

```bash
# AOT-компиляция в нативный бинарник
dart compile exe bin/server.dart -o server

# Запуск (быстрый старт, ~5 мс)
./server

# Docker
# Dockerfile
# FROM dart:stable AS build
# WORKDIR /app
# COPY . .
# RUN dart pub get
# RUN dart compile exe bin/server.dart -o bin/server
#
# FROM scratch
# COPY --from=build /runtime/ /
# COPY --from=build /app/bin/server /app/bin/server
# EXPOSE 8080
# CMD ["/app/bin/server"]
```

---

> **Назад:** [17.0 Обзор](17_00_overview.md) · **Далее:** [17.2 Dart для веба](17_02_web.md)
