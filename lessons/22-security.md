# Урок 22. Безопасность и защита кода

> Охватывает подтемы: 22.1 Валидация входных данных, 22.2 Управление секретами, 22.3 Безопасность FFI и JS interop

---

## 1. Формальное определение

Безопасность в Dart-приложениях охватывает:
- **Валидация ввода** — защита от инъекций, переполнений, некорректных данных
- **Управление секретами** — API-ключи, пароли, токены никогда не хранятся в коде
- **FFI/JS риски** — нативный код обходит систему типов Dart; ошибки → segfault, уязвимости памяти

---

## 2. Валидация входных данных (22.1)

### Общий принцип

Никогда не доверяй внешним данным: HTTP-запросам, файлам, переменным окружения, аргументам CLI.

```dart
// ❌ Никакой валидации — path traversal уязвимость
Future<String> readUserFile(String filename) async {
  return File('/data/$filename').readAsString();
}

// ✅ Валидация и нормализация пути
import 'dart:io';
import 'path/path.dart' as p;

Future<String> readUserFile(String filename) async {
  // Запрещаем /../ переходы
  if (filename.contains('..') || filename.contains('/') || filename.contains('\\')) {
    throw SecurityException('Invalid filename: $filename');
  }
  // Только безопасные символы
  if (!RegExp(r'^[a-zA-Z0-9_\-\.]+$').hasMatch(filename)) {
    throw SecurityException('Filename contains forbidden characters');
  }
  
  final safeDir = Directory('/data').resolveSymbolicLinksSync();
  final targetPath = p.join(safeDir.path, filename);
  final resolvedPath = File(targetPath).resolveSymbolicLinksSync();
  
  // Убеждаемся, что файл внутри разрешённой директории
  if (!resolvedPath.startsWith(safeDir.path)) {
    throw SecurityException('Path traversal detected');
  }
  
  return File(resolvedPath).readAsString();
}

class SecurityException implements Exception {
  const SecurityException(this.message);
  final String message;
  @override String toString() => 'SecurityException: $message';
}
```

### SQL-инъекции (при использовании postgres/sqlite)

```dart
import 'package:postgres/postgres.dart';

// ❌ НИКОГДА не делай string interpolation в SQL
Future<User?> getUser(String name) async {
  // SQL injection! name = "'; DROP TABLE users; --"
  final result = await conn.execute("SELECT * FROM users WHERE name = '$name'");
  return result.isEmpty ? null : User.fromRow(result.first);
}

// ✅ Параметризованные запросы
Future<User?> getUser(String name) async {
  final result = await conn.execute(
    r'SELECT id, name, email FROM users WHERE name = $1',
    parameters: [name],      // значение передаётся отдельно, не в SQL строку
  );
  return result.isEmpty ? null : User.fromRow(result.first);
}

// ✅ Типизированный запрос с параметрами
Future<List<User>> getUsersByAge(int minAge, int maxAge) async {
  if (minAge < 0 || maxAge > 150 || minAge >= maxAge) {
    throw ArgumentError('Invalid age range: $minAge-$maxAge');
  }
  
  final result = await conn.execute(
    r'SELECT id, name, email FROM users WHERE age BETWEEN $1 AND $2',
    parameters: [minAge, maxAge],
  );
  return result.map(User.fromRow).toList();
}
```

### Валидация HTTP запросов

```dart
import 'dart:convert';
import 'package:shelf/shelf.dart';

// Строгая валидация JSON тела запроса
Future<Response> createUserHandler(Request request) async {
  // 1. Проверяем Content-Type
  final contentType = request.headers['content-type'] ?? '';
  if (!contentType.startsWith('application/json')) {
    return Response(415, body: jsonEncode({'error': 'Content-Type must be application/json'}));
  }
  
  // 2. Ограничиваем размер тела
  const maxBodySize = 64 * 1024; // 64 KB
  final body = await request.readAsString();
  if (body.length > maxBodySize) {
    return Response(413, body: jsonEncode({'error': 'Request body too large'}));
  }
  
  // 3. Парсим JSON с обработкой ошибок
  Map<String, dynamic> data;
  try {
    data = jsonDecode(body) as Map<String, dynamic>;
  } on FormatException {
    return Response(400, body: jsonEncode({'error': 'Invalid JSON'}));
  }
  
  // 4. Проверяем обязательные поля и их типы
  final name = data['name'];
  final email = data['email'];
  final age = data['age'];
  
  if (name is! String || name.trim().isEmpty) {
    return Response(400, body: jsonEncode({'error': 'name must be a non-empty string'}));
  }
  if (name.length > 100) {
    return Response(400, body: jsonEncode({'error': 'name too long (max 100 chars)'}));
  }
  
  if (email is! String || !_isValidEmail(email)) {
    return Response(400, body: jsonEncode({'error': 'email must be valid'}));
  }
  
  if (age is! int || age < 0 || age > 150) {
    return Response(400, body: jsonEncode({'error': 'age must be integer 0-150'}));
  }
  
  // 5. Санитизация строк
  final sanitizedName = name.trim().replaceAll(RegExp(r'[<>&"\'\\]'), '');
  
  final user = await userService.createUser(sanitizedName, email, age);
  return Response(201, body: jsonEncode(user.toJson()),
      headers: {'Content-Type': 'application/json'});
}

bool _isValidEmail(String email) {
  return RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
      .hasMatch(email);
}
```

### XSS — при генерации HTML

```dart
import 'dart:html' show HtmlEscape;

// ❌ XSS уязвимость
String buildHtml(String userInput) {
  return '<div>Hello, $userInput!</div>';  // userInput = '<script>alert(1)</script>'
}

// ✅ Экранирование HTML
const _escape = HtmlEscape();
String buildHtml(String userInput) {
  return '<div>Hello, ${_escape.convert(userInput)}!</div>';
  // → <div>Hello, &lt;script&gt;alert(1)&lt;/script&gt;!</div>
}

// Для серверной генерации HTML — используй шаблонизатор mustache/jinja
// который экранирует по умолчанию
```

---

## 3. Управление секретами (22.2)

### Принципы

1. **Никогда** не коммить секреты в репозиторий
2. Использовать переменные окружения или секрет-хранилища
3. `.gitignore` для `.env` файлов

```dart
// ❌ Секрет в коде (тривиально обнаружить в репозитории)
const apiKey = 'sk-prod-abc123def456';
const dbPassword = 'super_secret_password_123';

// ✅ Из переменных окружения
import 'dart:io';

class Config {
  factory Config.fromEnvironment() {
    final apiKey = Platform.environment['API_KEY'];
    final dbUrl = Platform.environment['DATABASE_URL'];
    final jwtSecret = Platform.environment['JWT_SECRET'];
    final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
    
    if (apiKey == null || apiKey.isEmpty) {
      throw ConfigurationError('API_KEY environment variable is required');
    }
    if (dbUrl == null || dbUrl.isEmpty) {
      throw ConfigurationError('DATABASE_URL environment variable is required');
    }
    if (jwtSecret == null || jwtSecret.length < 32) {
      throw ConfigurationError('JWT_SECRET must be at least 32 characters');
    }
    
    return Config._(
      apiKey: apiKey,
      dbUrl: dbUrl,
      jwtSecret: jwtSecret,
      port: port,
    );
  }
  
  const Config._({
    required this.apiKey,
    required this.dbUrl,
    required this.jwtSecret,
    required this.port,
  });
  
  final String apiKey;
  final String dbUrl;
  final String jwtSecret;
  final int port;
}

class ConfigurationError extends Error {
  ConfigurationError(this.message);
  final String message;
  @override String toString() => 'ConfigurationError: $message';
}

// Использование (единожды при запуске)
void main() {
  late final Config config;
  try {
    config = Config.fromEnvironment();
  } on ConfigurationError catch (e) {
    stderr.writeln('Fatal configuration error: $e');
    exit(1);
  }
  
  runApp(config);
}
```

### `.env` для локальной разработки

```bash
# .env (никогда не коммитить!)
API_KEY=sk-dev-your-key-here
DATABASE_URL=postgres://user:password@localhost:5432/mydb
JWT_SECRET=development-secret-change-in-production-please

# .gitignore
.env
.env.local
.env.*.local
*.secret
```

```dart
// Загрузка .env в dev (пакет dotenv)
import 'package:dotenv/dotenv.dart';

void main() async {
  // Загружаем .env только в dev
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    final env = DotEnv()..load(['.env']);
    // env заполняет Platform.environment для текущего процесса
  }
  
  final config = Config.fromEnvironment();
  // ...
}
```

### Безопасная генерация случайных значений

```dart
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';

// ❌ НИКОГДА не используй Random() для безопасности
final insecure = Random();
final token = insecure.nextInt(1000000).toString();  // предсказуемо!

// ✅ Random.secure() — криптографически стойкий PRNG
String generateSecureToken({int bytes = 32}) {
  final random = Random.secure();
  final buffer = Uint8List(bytes);
  for (var i = 0; i < bytes; i++) {
    buffer[i] = random.nextInt(256);
  }
  return base64Url.encode(buffer);
}

// Генерация ID сессии
final sessionId = generateSecureToken(bytes: 32);   // 256-bit

// Безопасное сравнение (защита от timing attack)
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return result == 0;
}
```

### HTTPS и TLS

```dart
import 'dart:io';

// ✅ Принудительный HTTPS в продакшн
Future<HttpServer> startSecureServer({
  required String certFile,
  required String keyFile,
}) async {
  final context = SecurityContext()
    ..useCertificateChainFile(certFile)
    ..usePrivateKeyFile(keyFile);
  
  return HttpServer.bindSecure(
    InternetAddress.anyIPv4,
    443,
    context,
    backlog: 64,
  );
}

// ✅ HTTP → HTTPS редирект
Future<void> startHttpRedirect() async {
  final httpServer = await HttpServer.bind(InternetAddress.anyIPv4, 80);
  httpServer.listen((req) {
    req.response
      ..statusCode = HttpStatus.movedPermanently
      ..headers.set('Location', 'https://${req.headers.host}${req.uri}')
      ..close();
  });
}

// ✅ При HttpClient — всегда проверяй сертификат (по умолчанию проверяется)
final client = HttpClient();
// client.badCertificateCallback = (cert, host, port) => true;  
// ← НИКОГДА не отключай в продакшн! Это MITM уязвимость

// Доверять только конкретным CA (certificate pinning, advanced)
client.badCertificateCallback = (X509Certificate cert, String host, int port) {
  // Только если знаешь зачем — certificate pinning
  return false; // отклонить любой недоверенный сертификат
};
```

---

## 4. Безопасность FFI (22.3)

Dart FFI предоставляет прямой доступ к нативной памяти — ошибки дают buffer overflow, segfault, use-after-free.

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

// ❌ Утечка памяти / use-after-free
Pointer<Utf8> unsafeGetString() {
  final ptr = 'hello'.toNativeUtf8();
  // Возвращаем указатель, но нет гарантии освобождения
  return ptr;
}

// ✅ Всегда используй try/finally для освобождения
String safeNativeCall(String input) {
  final ptr = input.toNativeUtf8();
  try {
    // вызов нативной функции
    final result = nativeFunc(ptr);
    return result.toDartString();
  } finally {
    malloc.free(ptr);   // ВСЕГДА освобождаем
  }
}

// ✅ Arena для управления несколькими аллокациями
String processWithArena(String input, int size) {
  return using((Arena arena) {
    final inputPtr = input.toNativeUtf8(allocator: arena);
    final outputPtr = arena<Uint8>(size);
    
    nativeProcess(inputPtr, outputPtr, size);
    
    return String.fromCharCodes(outputPtr.asTypedList(size)
        .takeWhile((b) => b != 0));
    // arena.releaseAll() вызывается автоматически при выходе из using
  });
}

// ❌ Буферное переполнение
void writeUnsafe(Pointer<Uint8> buffer, List<int> data) {
  for (var i = 0; i < data.length; i++) {
    buffer[i] = data[i];   // нет проверки размера буфера!
  }
}

// ✅ Проверка границ
void writeSafe(Pointer<Uint8> buffer, int bufferSize, List<int> data) {
  if (data.length > bufferSize) {
    throw RangeError('Data (${data.length}) exceeds buffer size ($bufferSize)');
  }
  for (var i = 0; i < data.length; i++) {
    buffer[i] = data[i];
  }
}
```

### Валидация возвращаемых значений из нативного кода

```dart
// Нативный код может вернуть NULL или ошибочное значение
final typedef = DynamicLibrary.open('libmylib.so');
final nativeOpen = lib.lookupFunction<
    Pointer<OpaqueStruct> Function(Pointer<Utf8>),
    Pointer<OpaqueStruct> Function(Pointer<Utf8>)
>('my_open');

Pointer<OpaqueStruct> openResource(String path) {
  final pathPtr = path.toNativeUtf8();
  try {
    final result = nativeOpen(pathPtr);
    
    // ✅ Всегда проверяем NULL из нативного кода
    if (result == nullptr) {
      throw NativeException('Failed to open: $path (native returned NULL)');
    }
    
    return result;
  } finally {
    malloc.free(pathPtr);
  }
}

class NativeException implements Exception {
  const NativeException(this.message);
  final String message;
  @override String toString() => 'NativeException: $message';
}
```

---

## 5. Под капотом

- **Dart VM sandbox**: Dart код выполняется в управляемой среде; типобезопасность гарантирует отсутствие buffer overflow в чистом Dart коде
- **FFI** — прямой доступ к нативной C ABI; обходит все гарантии VM; ошибки = UB/segfault
- **`Random.secure()`** — делегирует к OS CSPRNG (`/dev/urandom` на Linux, `CryptGenRandom` на Windows)
- **Параметризованные SQL** — параметры передаются в отдельном packet за пределами SQL string; парсер SQL их не интерпретирует
- **`base64Url`** vs `base64` — URL-safe вариант заменяет `+→-`, `/→_`; не нужен URL encoding для токенов

---

## 6. Частые ошибки

```dart
// ❌ Логирование секретов
print('Connecting with password: ${config.dbPassword}');

// ✅ Никогда не логируй секреты
logger.info('Connecting to database at ${config.dbHost}');

// ❌ Возвращать StackTrace клиенту
return Response.internalServerError(body: error.toString());

// ✅ Логируй детали на сервере, клиенту — generic error
logger.error('Unhandled error', error, stackTrace);
return Response.internalServerError(
    body: jsonEncode({'error': 'Internal server error', 'requestId': requestId}));

// ❌ Хранить сессии в памяти сервера без TTL
final sessions = <String, Session>{};
sessions[sessionId] = Session(userId: userId);  // никогда не истекает!

// ✅ TTL + secure regeneration
final sessions = <String, Session>{};
void createSession(String userId) {
  final sessionId = generateSecureToken();
  final expiry = DateTime.now().add(const Duration(hours: 24));
  sessions[sessionId] = Session(userId: userId, expiry: expiry);
  // Периодически очищай истёкшие сессии
}

// ❌ Слабое сравнение токенов (timing attack)
if (token == expectedToken) { ... }

// ✅ Constant-time compare
if (constantTimeEquals(token, expectedToken)) { ... }
```

---

## 7. Краткое резюме

1. **Никогда не доверяй внешним данным** — валидируй тип, диапазон, длину, формат перед use
2. **Параметризованные SQL запросы** — никогда не строй SQL через `'... $userInput ...'`
3. **Секреты в переменных окружения** — `.env` для dev, vault/secrets для прод; не коммитить
4. **`Random.secure()`** — для токенов, сессионных ID, salt; `Random()` — только для игр/UI
5. **HTTPS всегда** — не отключай `badCertificateCallback` в продакшн
6. **FFI: `try/finally` и arena** — каждая нативная аллокация должна быть освобождена; проверяй NULL
7. **Не логируй секреты** — ни в консоль, ни в файл, ни через HTTP-ответ клиенту
