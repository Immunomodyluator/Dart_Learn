# 10.3 Практики ретраев и компенсации

## 1. Формальное определение

**Retry** (повторная попытка) — паттерн, при котором операция, завершившаяся ошибкой, автоматически повторяется определённое число раз с заданной стратегией задержки.

**Компенсация** (compensation / rollback) — обратные действия для отмены частично выполненной операции при сбое, обеспечивающие консистентность системы.

Типичные стратегии задержки:

- **Fixed delay** — постоянный интервал.
- **Exponential backoff** — удвоение интервала: 1с, 2с, 4с, 8с.
- **Exponential backoff + jitter** — случайный разброс для де-синхронизации клиентов.

## 2. Зачем это нужно

- **Transient errors** — временные сбои сети, перегрузка сервера (503, 429).
- **Устойчивость** — приложение не падает при первом сбое.
- **Graceful degradation** — частичные данные лучше, чем crash.
- **Saga pattern** — компенсация шагов при сбое в цепочке операций.

## 3. Как это работает

### Простой retry

```dart
Future<T> retry<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e) {
      if (attempt == maxAttempts) rethrow;
      print('Попытка $attempt/$maxAttempts не удалась: $e');
    }
  }
  throw StateError('Unreachable');
}

void main() async {
  var callCount = 0;

  final result = await retry(() async {
    callCount++;
    if (callCount < 3) throw Exception('Сбой #$callCount');
    return 'Успех!';
  });

  print(result); // Успех! (на 3-й попытке)
}
```

### Retry с exponential backoff

```dart
import 'dart:math';

Future<T> retryWithBackoff<T>(
  Future<T> Function() action, {
  int maxAttempts = 5,
  Duration initialDelay = const Duration(milliseconds: 500),
  double multiplier = 2.0,
  Duration maxDelay = const Duration(seconds: 30),
}) async {
  var delay = initialDelay;

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e) {
      if (attempt == maxAttempts) rethrow;

      print('Попытка $attempt не удалась. Повтор через ${delay.inMilliseconds}мс...');
      await Future.delayed(delay);

      // Увеличиваем задержку, но не больше maxDelay
      delay = Duration(
        milliseconds: min(
          (delay.inMilliseconds * multiplier).round(),
          maxDelay.inMilliseconds,
        ),
      );
    }
  }
  throw StateError('Unreachable');
}

// Задержки: 500мс → 1000мс → 2000мс → 4000мс → (сдаёмся)
```

### Retry с jitter (рандомизация)

```dart
import 'dart:math';

Future<T> retryWithJitter<T>(
  Future<T> Function() action, {
  int maxAttempts = 5,
  Duration baseDelay = const Duration(seconds: 1),
}) async {
  final random = Random();

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e) {
      if (attempt == maxAttempts) rethrow;

      // Full jitter: random(0, baseDelay * 2^attempt)
      final maxMs = (baseDelay.inMilliseconds * pow(2, attempt - 1)).round();
      final jitterMs = random.nextInt(maxMs + 1);
      final delay = Duration(milliseconds: jitterMs);

      print('Попытка $attempt. Повтор через ${delay.inMilliseconds}мс...');
      await Future.delayed(delay);
    }
  }
  throw StateError('Unreachable');
}

// Jitter предотвращает «thundering herd» —
// когда тысячи клиентов retry в одно время
```

### Retry с фильтром ошибок

```dart
Future<T> retryIf<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  required bool Function(Object error) shouldRetry,
  Duration delay = const Duration(seconds: 1),
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e) {
      if (!shouldRetry(e) || attempt == maxAttempts) rethrow;
      await Future.delayed(delay);
    }
  }
  throw StateError('Unreachable');
}

void main() async {
  await retryIf(
    () async => throw Exception('timeout'),
    shouldRetry: (e) {
      // Retry только для определённых ошибок
      final msg = e.toString().toLowerCase();
      return msg.contains('timeout') || msg.contains('503');
    },
  );
}
```

### Circuit Breaker

```dart
import 'dart:async';

enum CircuitState { closed, open, halfOpen }

class CircuitBreaker {
  final int failureThreshold;
  final Duration resetTimeout;

  CircuitState _state = CircuitState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 30),
  });

  CircuitState get state => _state;

  Future<T> execute<T>(Future<T> Function() action) async {
    switch (_state) {
      case CircuitState.open:
        // Проверяем, не пора ли попробовать снова
        if (_lastFailureTime != null &&
            DateTime.now().difference(_lastFailureTime!) > resetTimeout) {
          _state = CircuitState.halfOpen;
          print('Circuit: HALF-OPEN (пробуем...)');
        } else {
          throw CircuitOpenException(
            'Circuit breaker OPEN. Повтор через '
            '${resetTimeout.inSeconds - DateTime.now().difference(_lastFailureTime!).inSeconds}с',
          );
        }

      case CircuitState.halfOpen:
        // Пробуем одну операцию
        try {
          final result = await action();
          _reset();
          print('Circuit: CLOSED (восстановлен)');
          return result;
        } catch (e) {
          _trip();
          rethrow;
        }

      case CircuitState.closed:
        try {
          final result = await action();
          _failureCount = 0; // Сброс при успехе
          return result;
        } catch (e) {
          _failureCount++;
          if (_failureCount >= failureThreshold) {
            _trip();
          }
          rethrow;
        }
    }

    // halfOpen пробует одну операцию
    return await action();
  }

  void _trip() {
    _state = CircuitState.open;
    _lastFailureTime = DateTime.now();
    print('Circuit: OPEN (${_failureCount} ошибок)');
  }

  void _reset() {
    _state = CircuitState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
  }
}

class CircuitOpenException implements Exception {
  final String message;
  const CircuitOpenException(this.message);
  @override
  String toString() => message;
}
```

### Компенсация (Saga pattern)

```dart
typedef AsyncAction = Future<void> Function();

class SagaStep {
  final String name;
  final AsyncAction execute;
  final AsyncAction compensate;

  const SagaStep({
    required this.name,
    required this.execute,
    required this.compensate,
  });
}

class Saga {
  final List<SagaStep> steps;
  final _completedSteps = <SagaStep>[];

  Saga(this.steps);

  Future<void> run() async {
    for (final step in steps) {
      try {
        print('▶ Выполняем: ${step.name}');
        await step.execute();
        _completedSteps.add(step);
        print('  ✅ ${step.name} — успех');
      } catch (e) {
        print('  ❌ ${step.name} — ошибка: $e');
        await _compensate();
        rethrow;
      }
    }
    print('✅ Все шаги выполнены');
  }

  Future<void> _compensate() async {
    print('\n🔄 Откат выполненных шагов...');
    // Компенсируем в обратном порядке
    for (final step in _completedSteps.reversed) {
      try {
        print('  ↩ Откат: ${step.name}');
        await step.compensate();
        print('    ✅ Откат ${step.name} — успех');
      } catch (e) {
        print('    ⚠️ Откат ${step.name} не удался: $e');
        // Логируем, но продолжаем откат остальных
      }
    }
  }
}
```

### Timeout + Retry

```dart
Future<T> retryWithTimeout<T>(
  Future<T> Function() action, {
  int maxAttempts = 3,
  Duration timeout = const Duration(seconds: 5),
  Duration retryDelay = const Duration(seconds: 1),
}) async {
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      print('Попытка $attempt: таймаут (${timeout.inSeconds}с)');
      if (attempt == maxAttempts) {
        throw TimeoutException('Все $maxAttempts попыток завершились таймаутом');
      }
      await Future.delayed(retryDelay);
    } catch (e) {
      if (attempt == maxAttempts) rethrow;
      await Future.delayed(retryDelay);
    }
  }
  throw StateError('Unreachable');
}
```

### Fallback (деградация)

```dart
Future<T> withFallback<T>(
  Future<T> Function() primary,
  Future<T> Function() fallback, {
  String? label,
}) async {
  try {
    return await primary();
  } catch (e) {
    print('${label ?? 'Primary'} недоступен: $e. Используем fallback.');
    return await fallback();
  }
}

void main() async {
  final data = await withFallback(
    () => fetchFromApi(),    // Основной источник
    () => fetchFromCache(),  // Кеш-fallback
    label: 'API',
  );
  print(data);
}

Future<String> fetchFromApi() async => throw Exception('503');
Future<String> fetchFromCache() async => 'cached_data';
```

## 4. Минимальный пример

```dart
Future<String> fetchWithRetry(String url) async {
  for (var i = 1; i <= 3; i++) {
    try {
      return await _fetch(url);
    } catch (e) {
      if (i == 3) rethrow;
      await Future.delayed(Duration(seconds: i));
    }
  }
  throw StateError('Unreachable');
}

Future<String> _fetch(String url) async {
  throw Exception('timeout'); // Имитация ошибки
}
```

## 5. Практический пример

### Заказ с Saga-компенсацией

```dart
import 'dart:math';

final _random = Random();
bool _mayFail(double probability) => _random.nextDouble() < probability;

/// Имитация сервисов
Future<String> reserveInventory(String item, int qty) async {
  await Future.delayed(Duration(milliseconds: 100));
  if (_mayFail(0.1)) throw Exception('Товар "$item" закончился');
  final id = 'inv-${_random.nextInt(10000)}';
  print('    Резерв: $qty × $item → $id');
  return id;
}

Future<void> cancelReservation(String reservationId) async {
  await Future.delayed(Duration(milliseconds: 50));
  print('    Отмена резерва: $reservationId');
}

Future<String> chargePayment(double amount) async {
  await Future.delayed(Duration(milliseconds: 200));
  if (_mayFail(0.3)) throw Exception('Банк отклонил платёж');
  final id = 'pay-${_random.nextInt(10000)}';
  print('    Списание: $amount ₽ → $id');
  return id;
}

Future<void> refundPayment(String paymentId) async {
  await Future.delayed(Duration(milliseconds: 100));
  print('    Возврат: $paymentId');
}

Future<void> sendConfirmation(String email) async {
  await Future.delayed(Duration(milliseconds: 50));
  if (_mayFail(0.2)) throw Exception('Email сервис недоступен');
  print('    Email: $email');
}

// SAGA: Оформление заказа
Future<void> placeOrder({
  required String item,
  required int quantity,
  required double price,
  required String email,
}) async {
  String? reservationId;
  String? paymentId;

  try {
    // Шаг 1: Резерв товара
    print('Шаг 1: Резервирование...');
    reservationId = await reserveInventory(item, quantity);

    // Шаг 2: Оплата
    print('Шаг 2: Оплата...');
    paymentId = await chargePayment(price * quantity);

    // Шаг 3: Уведомление
    print('Шаг 3: Уведомление...');
    await sendConfirmation(email);

    print('\n✅ Заказ оформлен!');
  } catch (e) {
    print('\n❌ Ошибка: $e');
    print('🔄 Компенсация...');

    // Откат в обратном порядке
    if (paymentId != null) {
      try {
        await refundPayment(paymentId);
      } catch (re) {
        print('    ⚠️ Не удалось вернуть средства: $re');
      }
    }

    if (reservationId != null) {
      try {
        await cancelReservation(reservationId);
      } catch (re) {
        print('    ⚠️ Не удалось отменить резерв: $re');
      }
    }

    rethrow;
  }
}

void main() async {
  try {
    await placeOrder(
      item: 'Dart Book',
      quantity: 2,
      price: 1500.0,
      email: 'user@example.com',
    );
  } catch (e) {
    print('\nЗаказ не оформлен: $e');
  }
}
```

## 6. Что происходит под капотом

```
Retry с exponential backoff:

Attempt 1: action() → fail
  delay = 500ms
  await Future.delayed(500ms) → Timer в event queue

Attempt 2: action() → fail
  delay = 1000ms (500 * 2)
  await Future.delayed(1000ms)

Attempt 3: action() → fail
  delay = 2000ms (1000 * 2)
  await Future.delayed(2000ms)

Attempt 4: action() → success!
  return result

Суммарное ожидание: 500 + 1000 + 2000 = 3500ms

Circuit Breaker state machine:

  CLOSED ──(N failures)──► OPEN
     ▲                       │
     │                       │ (resetTimeout)
     │                       ▼
     └───(success)──── HALF-OPEN
     └───(failure)──── OPEN
         (1 попытка)

Saga compensation:

  Step1.execute() ✅ → Step2.execute() ✅ → Step3.execute() ❌
                                                    │
                                              compensate:
                                    Step2.compensate() ← Step1.compensate()
                                    (обратный порядок!)
```

## 7. Производительность и ресурсы

| Аспект                  | Стоимость                        |
| ----------------------- | -------------------------------- |
| Retry (3 попытки)       | 3× cost операции + delays        |
| Exponential backoff (5) | До ~31 сек суммарно (1+2+4+8+16) |
| Circuit Breaker         | O(1) — check state + счётчик     |
| Saga (N шагов)          | N executions + ≤N compensations  |
| Jitter                  | Random + одно умножение          |

**Рекомендации:**

- Retry только для **transient** ошибок (сеть, 503, 429).
- Установите **максимальную задержку** (cap) для backoff.
- Circuit breaker — для высоконагруженных систем с downstream зависимостями.
- Jitter обязателен при >100 клиентов (thundering herd).

## 8. Частые ошибки и антипаттерны

### ❌ Retry для non-retriable ошибок

```dart
// ❌ Retry для 404 или AuthError — никогда не поможет
await retry(() => callApi(), maxAttempts: 5);

// ✅ Фильтруйте
await retryIf(
  () => callApi(),
  shouldRetry: (e) => e is TimeoutException || e.toString().contains('503'),
);

Future<void> callApi() async => throw Exception('404 Not Found');
```

### ❌ Retry без задержки

```dart
// ❌ Мгновенный retry — DoS на свой сервер
for (var i = 0; i < 100; i++) {
  try { await callApi(); break; } catch (_) {}
}

// ✅ С задержкой
// await retryWithBackoff(() => callApi());
```

### ❌ Бесконечный retry

```dart
// ❌ Никогда не сдаётся
// while (true) {
//   try { await action(); break; } catch (_) {
//     await Future.delayed(Duration(seconds: 1));
//   }
// }

// ✅ Ограничение по попыткам И по общему времени
// await retryWithTimeout(action, maxAttempts: 5, timeout: Duration(seconds: 30));
```

### ❌ Компенсация без обработки ошибок компенсации

```dart
// ❌ Если compensate бросит — всё сломается
Future<void> bad() async {
  try {
    await step1();
    await step2();
  } catch (e) {
    await compensateStep1(); // Что если ЭТО тоже бросит?
    rethrow;
  }
}

// ✅ Каждая компенсация в своём try/catch
Future<void> good() async {
  try {
    await step1();
    await step2();
  } catch (e) {
    try { await compensateStep1(); } catch (ce) {
      print('Компенсация step1 не удалась: $ce');
      // Логируем для ручного разрешения
    }
    rethrow;
  }
}

Future<void> step1() async {}
Future<void> step2() async => throw Exception('fail');
Future<void> compensateStep1() async {}
```

## 9. Сравнение с альтернативами

| Паттерн             | Когда                    | Сложность | Подходит для              |
| ------------------- | ------------------------ | --------- | ------------------------- |
| Simple retry        | Transient errors         | Низкая    | Любые приложения          |
| Exponential backoff | API rate limits          | Средняя   | HTTP клиенты              |
| Circuit breaker     | Downstream failures      | Высокая   | Микросервисы              |
| Saga                | Distributed transactions | Высокая   | Многошаговые процессы     |
| Fallback            | Graceful degradation     | Низкая    | UX                        |
| Bulkhead            | Resource isolation       | Высокая   | Высоконагруженные системы |

## 10. Когда НЕ стоит использовать

- **Non-transient ошибки** — retry для 404, auth error, validation → бесполезно.
- **Идемпотентность не гарантирована** — retry POST без idempotency key может создать дубликаты.
- **Огромный payload** — retry загрузки 1GB файла → лучше resumable upload.
- **Простые скрипты** — overhead Saga/Circuit Breaker не оправдан.

## 11. Краткое резюме

1. **Retry** — повтор при transient ошибках; обязательно с ограничением попыток.
2. **Exponential backoff** — 1с → 2с → 4с → ...; снижает нагрузку при сбоях.
3. **Jitter** — рандомизация задержки; предотвращает thundering herd.
4. **Circuit breaker** — CLOSED → OPEN → HALF-OPEN; защита от каскадных сбоев.
5. **Saga** — последовательность шагов с компенсацией в обратном порядке.
6. **Fallback** — деградация: API → кеш → default; UX не страдает.
7. **Фильтр ошибок** — retry только для retriable ошибок.
8. **Компенсация** — каждый шаг отката в своём try/catch.

---

> **Назад:** [10.2 Пользовательские исключения](10_02_custom_exceptions.md) · **Далее:** [10.4 Логирование и мониторинг ошибок](10_04_logging.md)
