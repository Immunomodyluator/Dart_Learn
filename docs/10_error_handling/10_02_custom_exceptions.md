# 10.2 Пользовательские исключения

## 1. Формальное определение

**Пользовательское исключение** — класс, реализующий интерфейс `Exception` (для восстановимых ситуаций) или расширяющий `Error` (для программистских ошибок). Позволяет типизировать ошибки, добавлять контекст и строить иерархии.

```dart
// Рекомендуемый подход: implements Exception
class MyException implements Exception {
  final String message;
  const MyException(this.message);

  @override
  String toString() => 'MyException: $message';
}
```

`Exception` — это **интерфейс** (абстрактный класс), не требующий обязательных полей.

## 2. Зачем это нужно

- **Типизация** — `on AuthException` вместо проверки строки ошибки.
- **Контекст** — дополнительные поля (код, параметры, вложенная ошибка).
- **Иерархия** — базовый `AppException` → `NetworkException` → `TimeoutException`.
- **Документирование** — тип исключения = документация возможных ошибок.

## 3. Как это работает

### Простое исключение

```dart
class ValidationException implements Exception {
  final String field;
  final String message;

  const ValidationException(this.field, this.message);

  @override
  String toString() => 'ValidationException: поле "$field" — $message';
}

void validateEmail(String email) {
  if (!email.contains('@')) {
    throw ValidationException('email', 'должен содержать @');
  }
  if (email.length < 5) {
    throw ValidationException('email', 'слишком короткий');
  }
}

void main() {
  try {
    validateEmail('abc');
  } on ValidationException catch (e) {
    print(e);        // ValidationException: поле "email" — должен содержать @
    print(e.field);  // email
    print(e.message); // должен содержать @
  }
}
```

### Иерархия исключений

```dart
/// Базовое исключение приложения
class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause; // Вложенная ошибка

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() {
    final buffer = StringBuffer('AppException');
    if (code != null) buffer.write(' [$code]');
    buffer.write(': $message');
    if (cause != null) buffer.write(' (причина: $cause)');
    return buffer.toString();
  }
}

/// Ошибки сети
class NetworkException extends AppException {
  final int? statusCode;
  final String? url;

  const NetworkException(
    super.message, {
    this.statusCode,
    this.url,
    super.code,
    super.cause,
  });

  @override
  String toString() => 'NetworkException'
      '${statusCode != null ? ' [$statusCode]' : ''}'
      ': $message'
      '${url != null ? ' (URL: $url)' : ''}';
}

/// Ошибки авторизации
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});
}

/// Ошибки валидации (множественные)
class ValidationException extends AppException {
  final Map<String, String> errors;

  const ValidationException(this.errors)
      : super('Ошибка валидации');

  @override
  String toString() {
    final details = errors.entries
        .map((e) => '  ${e.key}: ${e.value}')
        .join('\n');
    return 'ValidationException:\n$details';
  }
}

void main() {
  try {
    throw NetworkException(
      'Сервер не отвечает',
      statusCode: 503,
      url: 'https://api.example.com/data',
      code: 'SERVICE_UNAVAILABLE',
    );
  } on NetworkException catch (e) {
    print(e);
    print('Status: ${e.statusCode}');
    print('URL: ${e.url}');
  } on AppException catch (e) {
    // Поймает AuthException, ValidationException и другие
    print('App error: $e');
  }
}
```

### sealed class для исчерпывающей обработки

```dart
/// Sealed — компилятор проверяет, что все случаи обработаны
sealed class PaymentError implements Exception {
  final String message;
  const PaymentError(this.message);
}

class InsufficientFunds extends PaymentError {
  final double available;
  final double required_;
  const InsufficientFunds(this.available, this.required_)
      : super('Недостаточно средств');
}

class CardDeclined extends PaymentError {
  final String reason;
  const CardDeclined(this.reason) : super('Карта отклонена');
}

class PaymentTimeout extends PaymentError {
  final Duration elapsed;
  const PaymentTimeout(this.elapsed) : super('Таймаут оплаты');
}

String handlePaymentError(PaymentError error) {
  // Exhaustive — компилятор проверит все подтипы
  return switch (error) {
    InsufficientFunds(:final available, :final required_) =>
      'Не хватает ${(required_ - available).toStringAsFixed(2)} ₽',
    CardDeclined(:final reason) =>
      'Карта отклонена: $reason. Попробуйте другую.',
    PaymentTimeout(:final elapsed) =>
      'Оплата не прошла за ${elapsed.inSeconds}с. Повторите.',
  };
}

void main() {
  final error = InsufficientFunds(500.0, 750.0);
  print(handlePaymentError(error));
  // Не хватает 250.00 ₽
}
```

### Exception с вложенной причиной (cause chaining)

```dart
class DatabaseException implements Exception {
  final String operation;
  final String message;
  final Object? cause;
  final StackTrace? causeStackTrace;

  const DatabaseException(
    this.operation,
    this.message, {
    this.cause,
    this.causeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('DatabaseException [$operation]: $message');
    if (cause != null) {
      buffer.write('\n  Caused by: $cause');
    }
    return buffer.toString();
  }
}

Future<void> saveUser(Map<String, dynamic> data) async {
  try {
    // Имитация ошибки БД
    throw FormatException('invalid UTF-8 in column "name"');
  } catch (e, s) {
    // Оборачиваем в domain-specific исключение
    throw DatabaseException(
      'INSERT',
      'Не удалось сохранить пользователя',
      cause: e,
      causeStackTrace: s,
    );
  }
}

void main() async {
  try {
    await saveUser({'name': 'test'});
  } on DatabaseException catch (e) {
    print(e);
    // DatabaseException [INSERT]: Не удалось сохранить пользователя
    //   Caused by: FormatException: invalid UTF-8 in column "name"
  }
}
```

### Enum-based error codes

```dart
enum ErrorCode {
  notFound('NOT_FOUND', 'Ресурс не найден'),
  unauthorized('UNAUTHORIZED', 'Требуется авторизация'),
  forbidden('FORBIDDEN', 'Доступ запрещён'),
  conflict('CONFLICT', 'Конфликт данных'),
  internal('INTERNAL', 'Внутренняя ошибка');

  final String code;
  final String defaultMessage;
  const ErrorCode(this.code, this.defaultMessage);
}

class ApiException implements Exception {
  final ErrorCode errorCode;
  final String? message;
  final Map<String, dynamic>? details;

  const ApiException(this.errorCode, {this.message, this.details});

  String get displayMessage => message ?? errorCode.defaultMessage;

  @override
  String toString() => 'ApiException [${errorCode.code}]: $displayMessage';
}

void main() {
  try {
    throw ApiException(
      ErrorCode.notFound,
      message: 'Пользователь с ID 42 не найден',
      details: {'id': 42},
    );
  } on ApiException catch (e) {
    print(e.errorCode.code);    // NOT_FOUND
    print(e.displayMessage);    // Пользователь с ID 42 не найден
    print(e.details);           // {id: 42}
  }
}
```

### Mixin для расширения исключений

```dart
mixin Retriable on Exception {
  /// Можно ли повторить операцию
  bool get isRetriable;

  /// Рекомендуемая задержка перед повтором
  Duration get retryDelay => const Duration(seconds: 1);
}

class TransientException implements Exception, Retriable {
  final String message;
  const TransientException(this.message);

  @override
  bool get isRetriable => true;

  @override
  Duration get retryDelay => const Duration(seconds: 2);

  @override
  String toString() => 'TransientException: $message';
}

class PermanentException implements Exception, Retriable {
  final String message;
  const PermanentException(this.message);

  @override
  bool get isRetriable => false;

  @override
  String toString() => 'PermanentException: $message';
}

Future<T> withRetry<T>(Future<T> Function() action, {int maxAttempts = 3}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e) {
      if (e is Retriable && e.isRetriable && attempt < maxAttempts) {
        print('Повтор через ${e.retryDelay.inSeconds}с... (попытка $attempt)');
        await Future.delayed(e.retryDelay);
      } else {
        rethrow;
      }
    }
  }
  throw StateError('Unreachable');
}
```

## 4. Минимальный пример

```dart
class NotFoundError implements Exception {
  final String entity;
  final String id;
  const NotFoundError(this.entity, this.id);

  @override
  String toString() => '$entity с ID "$id" не найден';
}

void main() {
  try {
    throw NotFoundError('User', '42');
  } on NotFoundError catch (e) {
    print(e); // User с ID "42" не найден
  }
}
```

## 5. Практический пример

### Полная система ошибок для HTTP API клиента

```dart
/// Базовое исключение API
sealed class ApiException implements Exception {
  final String message;
  final String? requestId;
  const ApiException(this.message, {this.requestId});
}

/// Сетевая ошибка (нет соединения)
class ConnectionException extends ApiException {
  final String url;
  const ConnectionException(this.url, {super.requestId})
      : super('Нет соединения с $url');
}

/// HTTP ошибка (ответ с кодом >= 400)
class HttpException extends ApiException {
  final int statusCode;
  final String? body;

  const HttpException(this.statusCode, {String? message, this.body, super.requestId})
      : super(message ?? 'HTTP $statusCode');

  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;
  bool get isRetriable => isServerError || statusCode == 429;
}

/// Ошибка десериализации
class DeserializationException extends ApiException {
  final Type targetType;
  final Object? cause;

  const DeserializationException(this.targetType, {this.cause, super.requestId})
      : super('Не удалось десериализовать в $targetType');
}

/// Обработка на уровне UI
String userFriendlyMessage(ApiException error) {
  return switch (error) {
    ConnectionException() =>
      'Проверьте подключение к интернету',
    HttpException(statusCode: 401) =>
      'Сессия истекла. Войдите заново.',
    HttpException(statusCode: 403) =>
      'У вас нет доступа к этому ресурсу',
    HttpException(statusCode: 404) =>
      'Запрашиваемые данные не найдены',
    HttpException(statusCode: 429) =>
      'Слишком много запросов. Подождите.',
    HttpException(isServerError: true) =>
      'Сервер временно недоступен. Попробуйте позже.',
    HttpException() =>
      'Произошла ошибка (${error.statusCode})',
    DeserializationException() =>
      'Ошибка обработки данных. Обновите приложение.',
  };
}

void main() {
  final errors = <ApiException>[
    ConnectionException('https://api.example.com'),
    HttpException(401, message: 'Unauthorized', requestId: 'req-123'),
    HttpException(503, message: 'Service Unavailable'),
    DeserializationException(Map<String, dynamic>),
  ];

  for (final error in errors) {
    print('${error.runtimeType}:');
    print('  Техническое: $error');
    print('  Пользователю: ${userFriendlyMessage(error)}');
    print('');
  }
}
```

## 6. Что происходит под капотом

```
class MyException implements Exception {
  final String message;
  MyException(this.message);
}

throw MyException('test');

Внутренне:
  1. MyException — обычный Dart-класс
  2. implements Exception — маркерный интерфейс (нет методов)
  3. throw — бросает ЛЮБОЙ Object; Exception — конвенция
  4. on MyException catch (e) — проверка: e is MyException

Иерархия:
  Object
    └── Exception (interface, пустой)
         └── MyException (implements)
    └── Error (class, has stackTrace)
         └── ArgumentError (extends)

Exception vs Error:
  Exception — нет обязательных полей, нет stackTrace property
  Error — имеет .stackTrace getter

sealed class:
  sealed → компилятор знает все подтипы
  switch → exhaustive checking (все случаи)
  Нельзя расширить вне файла определения
```

## 7. Производительность и ресурсы

| Аспект                     | Стоимость                  |
| -------------------------- | -------------------------- |
| Создание Exception         | Аллокация объекта (дёшево) |
| `const` Exception          | Zero — compile-time const  |
| throw + StackTrace capture | ~10-100 мкс                |
| `on Type` check            | Один `is` check (быстро)   |
| sealed switch              | Direct dispatch (без `is`) |
| Иерархия 3 уровня          | Нет overhead vs 1 уровень  |

**Рекомендации:**

- Используйте `const` конструктор, если исключение stateless.
- Не создавайте избыточно глубокие иерархии.
- sealed class → exhaustive switch → компилятор проверяет полноту.

## 8. Частые ошибки и антипаттерны

### ❌ extends Exception вместо implements

```dart
// ❌ Exception имеет factory constructor → extends не работает напрямую
// class Bad extends Exception {} // Ошибка компиляции!

// ✅ implements Exception
class Good implements Exception {
  final String message;
  const Good(this.message);

  @override
  String toString() => message;
}
```

### ❌ Слишком общее исключение

```dart
// ❌ Один тип на всё — неинформативно
class AppError implements Exception {
  final String message;
  AppError(this.message);
}

// throw AppError('not found');     // Что не найдено?
// throw AppError('unauthorized');  // Какой ресурс?

// ✅ Специализированные типы
class NotFoundException implements Exception { /* ... */ }
class UnauthorizedException implements Exception { /* ... */ }
```

### ❌ Забыли toString

```dart
class BadException implements Exception {
  final String message;
  BadException(this.message);
  // Нет toString → print покажет "Instance of 'BadException'"
}

// ✅ Всегда переопределяйте toString
class GoodException implements Exception {
  final String message;
  GoodException(this.message);

  @override
  String toString() => 'GoodException: $message';
}
```

### ❌ Error для бизнес-логики

```dart
// ❌ Error — для багов, не для бизнес-ситуаций
class InsufficientBalanceError extends Error {
  final double balance;
  InsufficientBalanceError(this.balance);
}

// ✅ Exception — для ожидаемых бизнес-ситуаций
class InsufficientBalanceException implements Exception {
  final double balance;
  InsufficientBalanceException(this.balance);
}
```

## 9. Сравнение с альтернативами

| Подход                       | Типизация    | Exhaustive | Контекст     | Когда                 |
| ---------------------------- | ------------ | ---------- | ------------ | --------------------- |
| `implements Exception`       | ✅ `on Type` | ❌         | ✅ Поля      | По умолчанию          |
| `sealed class` + `Exception` | ✅           | ✅ switch  | ✅           | Конечный набор ошибок |
| Result type (sealed)         | ✅           | ✅         | ✅           | Функциональный стиль  |
| Enum + Exception             | ✅           | ✅ enum    | ⚠️ Ограничен | Коды ошибок           |
| String message               | ❌           | ❌         | ❌           | Никогда               |

## 10. Когда НЕ стоит использовать

- **Одноразовые скрипты** — `throw Exception('msg')` достаточно.
- **Глубокие иерархии > 3 уровней** — сложно поддерживать.
- **Перехват Error** — `MyError extends Error` для бизнес-логики — антипаттерн.
- **По исключению на каждую строку** — группируйте по доменам.

## 11. Краткое резюме

1. **`implements Exception`** — стандартный способ создания пользовательских исключений.
2. **Поля** — добавляйте контекст: `field`, `code`, `cause`, `statusCode`.
3. **`toString()`** — всегда переопределяйте для читаемых логов.
4. **Иерархия** — `AppException` → `NetworkException` → `HttpException`.
5. **`sealed class`** — exhaustive switch; компилятор проверяет полноту обработки.
6. **Cause chaining** — оборачивайте низкоуровневые ошибки в доменные.
7. **`const`** — используйте для stateless исключений.
8. **Exception ≠ Error** — бизнес-ситуации → Exception; баги → Error.

---

> **Назад:** [10.1 try / catch / finally](10_01_try_catch.md) · **Далее:** [10.3 Практики ретраев и компенсации](10_03_retry_compensation.md)
