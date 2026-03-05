# Урок 12. Обработка ошибок и безопасный код

> Охватывает подтемы: 12.1 try/catch/finally, 12.2 Типы ошибок, 12.3 Пользовательские исключения, 12.4 Паттерны восстановления

---

## 1. Формальное определение

Dart разделяет два вида «бросаемого»:
- **`Error`** — программная ошибка (RangeError, ArgumentError) — **не должна перехватываться** в продакшне; это баг
- **`Exception`** — ожидаемые исключительные ситуации (IOException, FormatException) — **нужно обрабатывать**

Технически `throw` принимает **любой объект** (не только `Error`/`Exception`), но это не рекомендуется.

Уровень: **надёжность, безопасность кода**.

---

## 2. Зачем это нужно

- **`Error` vs `Exception`** разделяет баги (нужно исправить) от исключений (нужно обработать)
- **Null safety** устраняет целый класс ошибок на этапе компиляции
- **`Result` pattern** делает ошибки частью типа возврата — явные контракты
- **Кастомные исключения** дают контекст и структуру для error handling

---

## 3. try/catch/finally (12.1)

```dart
import 'dart:io';

void basicErrorHandling() {
  try {
    final result = riskyOperation();
    print(result);
  } on FormatException catch (e) {
    // Перехват конкретного типа исключения
    print('Format error: ${e.message}');
  } on IOException catch (e, stackTrace) {
    // e — исключение, stackTrace — стек вызовов
    print('IO error: $e');
    print(stackTrace);
  } on Error catch (e) {
    // Error — баги, обычно не перехватываем (или только логируем + rethrow)
    print('Bug: $e');
    rethrow; // пробрасываем дальше
  } catch (e) {
    // Перехватываем всё остальное — плохая практика без rethrow
    print('Unknown: $e');
    rethrow; // лучше перебросить если не знаем что делать
  } finally {
    // Выполняется ВСЕГДА — ресурсы, cleanup
    cleanupResources();
  }
}

// async try/catch
Future<void> asyncErrorHandling() async {
  try {
    final data = await fetchData();
    await processData(data);
  } on NetworkException catch (e) {
    // Future ошибки перехватываются так же
    print('Network error: ${e.statusCode}');
  } finally {
    print('Request complete');
  }
}

// Порядок on имеет значение — дочерние типы должны быть раньше
class SpecificException extends GeneralException {}

void catchOrder() {
  try {
    throw SpecificException();
  } on SpecificException catch (e) {
    print('Specific'); // Этот блок выполнится, не следующий
  } on GeneralException catch (e) {
    print('General'); // Никогда не достигнется для SpecificException
  }
}
```

---

## 4. Иерархия типов ошибок (12.2)

```
Object
├── Error                     ← Баги (не обрабатываем — исправляем)
│   ├── AssertionError        ← Нарушение assert()
│   ├── ArgumentError         ← Неверный аргумент
│   │   └── RangeError        ← Индекс вне диапазона
│   ├── StateError            ← Объект в неверном состоянии
│   ├── TypeError             ← Неверный тип
│   ├── NullThrownError       ← throw null
│   ├── UnsupportedError      ← Метод не поддерживается
│   └── UnimplementedError    ← Метод не реализован (абстрактный)
│
└── Exception                 ← Ожидаемые ситуации (обрабатываем)
    ├── FormatException       ← Парсинг: неверный формат
    ├── IOException           ← I/O: файлы, сеть
    │   ├── FileSystemException
    │   └── HttpException
    ├── TimeoutException      ← Превышение таймаута
    └── ... (пользовательские)
```

---

## 5. Пользовательские исключения (12.3)

```dart
// Базовый кастомный Exception
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message${code != null ? ' [$code]' : ''}';
}

// Иерархия доменных исключений
sealed class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException[$statusCode]: $message';
}

final class UnauthorizedException extends ApiException {
  const UnauthorizedException([String message = 'Unauthorized'])
      : super(401, message);
}

final class NotFoundException extends ApiException {
  final String resource;
  const NotFoundException(this.resource)
      : super(404, 'Not found: $resource');
}

final class ServerException extends ApiException {
  final Object? originalError;
  const ServerException([String message = 'Internal server error', this.originalError])
      : super(500, message);
}

// Бросание с контекстом
Future<User> getUser(String id) async {
  if (id.isEmpty) throw ArgumentError.notNull('id'); // Error — это баг
  
  final response = await httpGet('/users/$id');
  
  return switch (response.statusCode) {
    200 => User.fromJson(response.body),
    401 => throw UnauthorizedException(),
    404 => throw NotFoundException('user/$id'),
    >= 500 => throw ServerException('Server error: ${response.body}'),
    _ => throw ApiException(response.statusCode, 'Unexpected status'),
  };
}

// Обработка sealed ApiException — exhaustiveness
Future<void> handleApiCall(String userId) async {
  try {
    final user = await getUser(userId);
    print(user);
  } on ApiException catch (e) {
    switch (e) {
      case UnauthorizedException():
        redirectToLogin();
      case NotFoundException(resource: final r):
        showNotFoundMessage(r);
      case ServerException(originalError: final err):
        logError(err);
        showErrorDialog('Server error, try again later');
    }
  }
}
```

---

## 6. Result pattern (12.4)

```dart
// Альтернатива исключениям — ошибки как часть типа
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final Exception error;
  final StackTrace stackTrace;
  const Failure(this.error, this.stackTrace);
}

extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  T? get valueOrNull => switch (this) {
    Success(value: final v) => v,
    Failure() => null,
  };

  T getOrDefault(T defaultValue) => switch (this) {
    Success(value: final v) => v,
    Failure() => defaultValue,
  };

  Result<U> map<U>(U Function(T) f) => switch (this) {
    Success(value: final v) => Success(f(v)),
    Failure(error: final e, stackTrace: final st) => Failure(e, st),
  };

  Future<Result<U>> mapAsync<U>(Future<U> Function(T) f) async =>
      switch (this) {
        Success(value: final v) => _safeRun(() => f(v)),
        Failure() => Failure(this as dynamic, StackTrace.empty),
      };
}

// Обёртка для безопасного выполнения
Future<Result<T>> safeRun<T>(Future<T> Function() fn) async {
  try {
    return Success(await fn());
  } on Exception catch (e, st) {
    return Failure(e, st);
  }
}

// Использование
Future<void> exampleUsage() async {
  final result = await safeRun(() => fetchUser('123'));

  switch (result) {
    case Success(value: final user):
      print('Got user: $user');
    case Failure(error: final e, stackTrace: final st):
      print('Failed: $e');
      // log(st);
  }

  // Цепочка операций
  final mapped = result
      .map((user) => user.name.toUpperCase())
      .getOrDefault('Unknown');
  print(mapped);
}
```

---

## 7. Паттерны восстановления

```dart
// Retry с exponential backoff
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 500),
  bool Function(Exception)? retryOn,
}) async {
  var delay = initialDelay;
  
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } on Exception catch (e) {
      if (attempt == maxAttempts) rethrow;
      if (retryOn != null && !retryOn(e)) rethrow;
      
      await Future.delayed(delay);
      delay *= 2; // exponential backoff
    }
  }
  throw StateError('Unreachable');
}

// Fallback chain
Future<T> withFallback<T>(
  List<Future<T> Function()> providers,
) async {
  Exception? lastError;
  for (final provider in providers) {
    try {
      return await provider();
    } on Exception catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? StateError('No providers');
}

// Circuit breaker (упрощённый)
class CircuitBreaker<T> {
  final String name;
  final int failureThreshold;
  final Duration recoveryTimeout;
  
  int _failures = 0;
  DateTime? _openedAt;
  
  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.recoveryTimeout = const Duration(minutes: 1),
  });
  
  bool get _isOpen => _failures >= failureThreshold &&
      _openedAt != null &&
      DateTime.now().difference(_openedAt!) < recoveryTimeout;
  
  Future<T> call(Future<T> Function() fn) async {
    if (_isOpen) throw StateError('Circuit breaker open for $name');
    
    try {
      final result = await fn();
      _failures = 0; // сброс при успехе
      return result;
    } catch (e) {
      _failures++;
      _openedAt ??= DateTime.now();
      rethrow;
    }
  }
}

// ─── Зоны для глобального перехвата ───
import 'dart:async';

void runWithErrorZone() {
  runZonedGuarded(
    () async {
      // весь код приложения
      await runApp();
    },
    (error, stackTrace) {
      // Глобальный обработчик неперехваченных ошибок
      Sentry.captureException(error, stackTrace: stackTrace);
    },
  );
}
```

---

## 8. Минимальный пример

```dart
class ValidationException implements Exception {
  final Map<String, String> fields;
  const ValidationException(this.fields);

  @override
  String toString() => 'Validation failed: $fields';
}

class UserService {
  Future<void> createUser(String name, String email) async {
    final errors = <String, String>{};
    if (name.trim().isEmpty) errors['name'] = 'Required';
    if (!email.contains('@')) errors['email'] = 'Invalid email';

    if (errors.isNotEmpty) throw ValidationException(errors);

    // сохранение...
    await Future.delayed(Duration(milliseconds: 100));
    print('User created: $name');
  }
}

void main() async {
  final service = UserService();

  try {
    await service.createUser('', 'not-an-email');
  } on ValidationException catch (e) {
    print(e); // Validation failed: {name: Required, email: Invalid email}
  }
}
```

---

## 9. Под капотом

### Как `throw` работает в Dart

- **JIT**: throw создаёт объект исключения + захватывает стек→ runtime overhead при каждом `throw`
- **AOT**: компилятор может оптимизировать пути без исключений; пути с исключениями — «cold code»

### Почему исключения медленные

```dart
// Бенчмарк: 1M итераций
// try/catch (без исключения): +~0% overhead
// try/catch (с исключением): ~10-100x медленнее из-за stack capture
```

Поэтому `Result<T>` паттерн быстрее для **ожидаемых** ошибок (валидация, not found).

---

## 10. Производительность

- **`try/catch` без исключения** — нет overhead (zero-cost)
- **`throw` + stack capture** — дорого; не использовать для control flow
- **`Result<T>`** — обычный объект; быстрее исключений для часто ожидаемых ошибок
- **`rethrow`** дешевле чем `throw e` — переиспользует стек-трейс без нового захвата

---

## 11. Частые ошибки

**1. `catch (e)` без rethrow для неизвестных ошибок:**
```dart
// ПЛОХО — проглатывает ошибки!
try {
  await riskyOp();
} catch (e) {
  print(e); // ошибка потеряна, программа продолжает как ни в чём не бывало
}

// ХОРОШО
try {
  await riskyOp();
} on ExpectedException catch (e) {
  handle(e); // только известные
} catch (e, st) {
  log(e, st);
  rethrow; // непонятное — пробрасываем
}
```

**2. Выкидывать `Error` как пользовательское исключение:**
```dart
// ПЛОХО — Error означает BUG
throw StateError('user not found'); // это не баг, а ожидаемая ситуация

// ХОРОШО
throw NotFoundException('user/$id');
```

**3. Не освобождать ресурсы:**
```dart
// ПЛОХО — file не закроется при исключении
final file = File('data.txt').openSync();
processFile(file); // если выбросит — file утечёт

// ХОРОШО
final file = File('data.txt').openSync();
try {
  processFile(file);
} finally {
  file.closeSync();
}
```

**4. Исключения для control flow:**
```dart
// ПЛОХО — медленно и семантически неверно
try {
  final user = userMap[id]!; // бросает NoSuchMethodError если null
} catch (e) {
  createDefaultUser();
}

// ХОРОШО
final user = userMap[id] ?? createDefaultUser();
```

---

## 12. Сравнение с другими языками

| Аспект | Dart | Java | Kotlin | Go | Rust |
|---|---|---|---|---|---|
| Checked exceptions | НЕТ | Да | НЕТ | N/A | N/A |
| Error/Exception split | Да | Нет (все Throwable) | Нет | N/A | N/A |
| Result type | Нет (сторонние) | Нет | `Result<T>` | `(T, error)` | `Result<T, E>` |
| finally | Да | Да | Да | `defer` | Drop trait |
| Rethrow | `rethrow` | `throw e` (теряет стек) | `throw` | N/A | N/A |

---

## 13. Когда НЕ использовать исключения

- **Валидация пользовательского ввода** — используйте `Result` или `Either`
- **"Not found"** — возвращайте `null` или `Result<T?>`
- **Control flow** — никогда
- **Частые ожидаемые ошибки** — `Result` паттерн производительнее

---

## 14. Краткое резюме

1. **`Error` — баги** (не перехватывать в prod, исправлять); **`Exception` — ожидаемые ситуации** (обрабатывать)
2. **`rethrow`** при перехвате непонятных ошибок — не проглатывать; сохраняет исходный стек-трейс
3. **`on ConcreteType catch (e)`** предпочтительнее `catch (e)` — явный контракт
4. **`finally`** всегда выполняется — используйте для закрытия ресурсов
5. **Кастомные исключения** через `implements Exception` с полями для контекста
6. **`Result<T>`** паттерн — для ожидаемых ошибок делает их частью типа; быстрее throw
7. **`runZonedGuarded`** — глобальный обработчик для необработанных исключений (логирование, Sentry)
8. **Не использовать исключения для control flow** — медленно и семантически неверно
