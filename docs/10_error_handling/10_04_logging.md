# 10.4 Логирование и мониторинг ошибок

## 1. Формальное определение

**Логирование ошибок** — структурированная запись информации о возникших исключениях и сбоях (время, место, стек вызовов, контекст) для последующего анализа и диагностики.

**Мониторинг ошибок** — процесс сбора, агрегации и уведомления о паттернах ошибок в реальном времени: частота, тренды, новые типы сбоев.

В Dart логирование основано на:

- Пакет `logging` (из Dart SDK team) — иерархические логгеры с уровнями.
- `Zone` — перехват всех необработанных ошибок.
- `FlutterError` — обработка ошибок рендеринга (Flutter).
- Сторонние сервисы: Sentry, Firebase Crashlytics, Datadog.

## 2. Зачем это нужно

- **Диагностика** — понять причину сбоя без доступа к устройству пользователя.
- **Приоритизация** — чинить ошибки, которые затрагивают больше пользователей.
- **Тренды** — обнаружить деградацию после деплоя.
- **SLA / SLO** — метрики error rate для мониторинга качества.
- **Аудит** — в регулируемых отраслях (финансы, здравоохранение) логи обязательны.

## 3. Как это работает

### Пакет `logging`

```dart
import 'package:logging/logging.dart';

final log = Logger('MyApp');

void setupLogging() {
  // Настройка: записывать всё от INFO и выше
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
      '${record.time} '
      '[${record.level.name}] '
      '${record.loggerName}: '
      '${record.message}'
      '${record.error != null ? '\n  Error: ${record.error}' : ''}'
      '${record.stackTrace != null ? '\n  Stack: ${record.stackTrace}' : ''}',
    );
  });
}

void main() {
  setupLogging();

  log.info('Приложение запущено');
  log.config('Сервер: api.example.com');
  log.fine('Детальная отладка');

  try {
    throw FormatException('Неверный JSON');
  } catch (e, stack) {
    log.severe('Ошибка парсинга', e, stack);
  }
}
```

### Уровни логирования

```dart
import 'package:logging/logging.dart';

final log = Logger('Demo');

void demonstrateLevels() {
  // От наименее к наиболее важным:
  log.finest('Трассировка каждого шага');         // 300
  log.finer('Вход/выход из методов');              // 400
  log.fine('Отладочная информация');                // 500
  log.config('Конфигурация загружена');             // 700
  log.info('Пользователь вошёл в систему');        // 800
  log.warning('Кеш почти заполнен');               // 900
  log.severe('Не удалось подключиться к БД');      // 1000
  log.shout('Критический сбой! Приложение падает'); // 1200
}

// В продакшене обычно: Level.WARNING или Level.INFO
// В разработке: Level.ALL или Level.FINE
```

### Иерархия логгеров

```dart
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) {
    print('[${r.loggerName}] ${r.level.name}: ${r.message}');
  });

  // Иерархия: MyApp → MyApp.Auth → MyApp.Auth.OAuth
  final appLog = Logger('MyApp');
  final authLog = Logger('MyApp.Auth');
  final oauthLog = Logger('MyApp.Auth.OAuth');

  appLog.info('Запуск');
  authLog.info('Проверка токена');
  oauthLog.fine('Refresh token отправлен');

  // Можно задать уровень для поддерева
  Logger('MyApp.Auth').level = Level.WARNING;
  authLog.info('Это не будет залогировано');  // ← ниже WARNING
  authLog.warning('А это — будет');
}
```

### Структурированное логирование (JSON)

```dart
import 'dart:convert';
import 'package:logging/logging.dart';

void setupJsonLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    final entry = {
      'timestamp': record.time.toIso8601String(),
      'level': record.level.name,
      'logger': record.loggerName,
      'message': record.message,
      if (record.error != null) 'error': record.error.toString(),
      if (record.stackTrace != null) 'stackTrace': record.stackTrace.toString(),
    };
    // В продакшене → stdout / файл / HTTP
    print(jsonEncode(entry));
  });
}

// Вывод:
// {"timestamp":"2024-01-15T10:30:45.123","level":"SEVERE","logger":"MyApp","message":"DB Error","error":"Connection refused"}
```

### Zone — перехват всех ошибок

```dart
import 'dart:async';
import 'package:logging/logging.dart';

final log = Logger('App');

void main() {
  setupJsonLogging();

  // Zone перехватывает ВСЕ необработанные ошибки
  runZonedGuarded(
    () {
      log.info('Приложение запущено в защитной зоне');

      // Синхронная ошибка — try/catch
      try {
        throw Exception('sync error');
      } catch (e, s) {
        log.severe('Синхронная ошибка', e, s);
      }

      // Асинхронная ошибка — перехватит Zone
      Future.delayed(Duration(milliseconds: 100), () {
        throw Exception('Необработанная async ошибка');
      });
    },
    (error, stackTrace) {
      // Сюда попадают все необработанные ошибки
      log.shout('НЕОБРАБОТАННАЯ ОШИБКА', error, stackTrace);
      // Здесь: отправить в Sentry / Crashlytics
    },
  );
}

void setupJsonLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) {
    print('[${r.level.name}] ${r.loggerName}: ${r.message}');
    if (r.error != null) print('  Error: ${r.error}');
  });
}
```

### Обёртка для отправки в сервис мониторинга

```dart
import 'dart:async';
import 'package:logging/logging.dart';

abstract class ErrorReporter {
  Future<void> report(Object error, StackTrace stackTrace, {Map<String, dynamic>? extra});
}

class ConsoleReporter implements ErrorReporter {
  @override
  Future<void> report(Object error, StackTrace stackTrace, {Map<String, dynamic>? extra}) async {
    print('=== ERROR REPORT ===');
    print('Error: $error');
    print('Stack: $stackTrace');
    if (extra != null) print('Extra: $extra');
  }
}

// Имитация Sentry-подобного сервиса
class SentryReporter implements ErrorReporter {
  final String dsn;
  SentryReporter(this.dsn);

  @override
  Future<void> report(Object error, StackTrace stackTrace, {Map<String, dynamic>? extra}) async {
    // В реальности: HTTP POST на dsn
    print('[Sentry] Отправлено: $error');
    // await http.post(Uri.parse(dsn), body: {...});
  }
}

class ErrorHandler {
  final List<ErrorReporter> reporters;
  final log = Logger('ErrorHandler');

  ErrorHandler(this.reporters);

  Future<void> handle(Object error, StackTrace stackTrace, {Map<String, dynamic>? context}) async {
    log.severe('Ошибка перехвачена', error, stackTrace);

    for (final reporter in reporters) {
      try {
        await reporter.report(error, stackTrace, extra: context);
      } catch (e) {
        log.warning('Не удалось отправить в ${reporter.runtimeType}: $e');
      }
    }
  }
}
```

### Контекст ошибки (breadcrumbs)

```dart
class Breadcrumb {
  final DateTime time;
  final String category;
  final String message;
  final Map<String, dynamic>? data;

  Breadcrumb({
    required this.category,
    required this.message,
    this.data,
  }) : time = DateTime.now();

  @override
  String toString() => '[$category] $message ${data ?? ''}';
}

class BreadcrumbTrail {
  static const _maxBreadcrumbs = 50;
  static final _crumbs = <Breadcrumb>[];

  static List<Breadcrumb> get all => List.unmodifiable(_crumbs);

  static void add(String category, String message, {Map<String, dynamic>? data}) {
    _crumbs.add(Breadcrumb(category: category, message: message, data: data));
    if (_crumbs.length > _maxBreadcrumbs) {
      _crumbs.removeAt(0); // FIFO
    }
  }

  static void clear() => _crumbs.clear();
}

void main() {
  BreadcrumbTrail.add('navigation', 'Открыта главная');
  BreadcrumbTrail.add('api', 'GET /users', data: {'status': 200});
  BreadcrumbTrail.add('navigation', 'Открыт профиль');
  BreadcrumbTrail.add('api', 'GET /users/42', data: {'status': 500});

  // При ошибке — отправляем breadcrumbs для контекста
  try {
    throw Exception('Profile load failed');
  } catch (e) {
    print('Ошибка: $e');
    print('Breadcrumbs:');
    for (final bc in BreadcrumbTrail.all) {
      print('  ${bc.time}: $bc');
    }
  }
}
```

## 4. Минимальный пример

```dart
import 'package:logging/logging.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) =>
    print('${r.level.name}: ${r.message}'));

  final log = Logger('App');
  log.info('Запуск');

  try {
    int.parse('abc');
  } catch (e, stack) {
    log.severe('Ошибка парсинга', e, stack);
  }
}
```

## 5. Практический пример

### Полная система логирования и мониторинга

```dart
import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';

// ── Конфигурация логирования ──

enum Environment { development, staging, production }

class LogConfig {
  final Environment env;
  final Level minLevel;
  final bool jsonOutput;

  const LogConfig({
    required this.env,
    required this.minLevel,
    required this.jsonOutput,
  });

  factory LogConfig.forEnv(Environment env) => switch (env) {
    Environment.development => LogConfig(
      env: env, minLevel: Level.ALL, jsonOutput: false),
    Environment.staging => LogConfig(
      env: env, minLevel: Level.FINE, jsonOutput: true),
    Environment.production => LogConfig(
      env: env, minLevel: Level.WARNING, jsonOutput: true),
  };
}

// ── Форматтеры ──

String _formatHuman(LogRecord r) {
  final buffer = StringBuffer()
    ..write('${r.time.toIso8601String()} ')
    ..write('[${r.level.name.padRight(7)}] ')
    ..write('${r.loggerName}: ')
    ..write(r.message);
  if (r.error != null) buffer.write('\n  ⚠ ${r.error}');
  if (r.stackTrace != null) {
    final lines = r.stackTrace.toString().split('\n').take(5);
    for (final line in lines) {
      buffer.write('\n    $line');
    }
  }
  return buffer.toString();
}

String _formatJson(LogRecord r) => jsonEncode({
  'ts': r.time.toIso8601String(),
  'level': r.level.name,
  'logger': r.loggerName,
  'msg': r.message,
  if (r.error != null) 'error': r.error.toString(),
  if (r.stackTrace != null) 'stack': r.stackTrace.toString().split('\n').take(10).toList(),
});

// ── Инициализация ──

void initLogging(LogConfig config) {
  Logger.root.level = config.minLevel;
  Logger.root.onRecord.listen((record) {
    final output = config.jsonOutput
      ? _formatJson(record)
      : _formatHuman(record);
    print(output);
  });
}

// ── Обработчик необработанных ошибок ──

void runApp(LogConfig config, void Function() appMain) {
  initLogging(config);
  final log = Logger('App');

  runZonedGuarded(
    () {
      log.info('Запуск в режиме ${config.env.name}');
      appMain();
    },
    (error, stackTrace) {
      log.shout('НЕОБРАБОТАННАЯ ОШИБКА', error, stackTrace);
    },
  );
}

// ── Использование ──

final _log = Logger('OrderService');

Future<void> processOrder(String orderId) async {
  _log.info('Обработка заказа $orderId');

  try {
    _log.fine('Проверка наличия...');
    await Future.delayed(Duration(milliseconds: 100));

    _log.fine('Списание средств...');
    await Future.delayed(Duration(milliseconds: 200));
    if (orderId == 'fail') throw Exception('Платёж отклонён');

    _log.info('Заказ $orderId успешно обработан');
  } catch (e, stack) {
    _log.severe('Ошибка обработки заказа $orderId', e, stack);
    rethrow;
  }
}

void main() {
  final config = LogConfig.forEnv(Environment.development);

  runApp(config, () async {
    await processOrder('ok-123');
    try {
      await processOrder('fail');
    } catch (_) {
      // Обработано через логирование
    }
  });
}
```

## 6. Что происходит под капотом

```
Logger hierarchy:
                    root (Level.ALL)
                     │
                   onRecord.listen(handler)
                     │
               ┌─────┼──────┐
            MyApp  MyApp.Auth  MyApp.DB
                    │
               MyApp.Auth.OAuth

LogRecord flow:
  log.severe('msg', error, stack)
      │
      ▼
  LogRecord(level, message, loggerName, error, stackTrace, time)
      │
      ▼
  Logger.parent?.onRecord → ... → root.onRecord
      │
      ▼
  StreamSubscription → handler(record)
      │
      ▼
  print / file / HTTP POST

Zone error handling:
  runZonedGuarded(body, onError)
      │
      │  Zone.current = new Zone with error handler
      ▼
  body() executes
      │
      ├── sync throw → try/catch (обычный)
      │
      └── async throw (не пойманный) → Zone.handleUncaughtError
              │
              ▼
          onError(error, stackTrace) ← Все необработанные
```

## 7. Производительность и ресурсы

| Аспект                               | Стоимость                       |
| ------------------------------------ | ------------------------------- |
| `log.info('...')`                    | ~1μs (строка + проверка уровня) |
| `log.info('...')` при уровне WARNING | ~0.1μs (пропускается)           |
| JSON encode                          | ~5-10μs на запись               |
| Запись в файл                        | ~50-100μs (I/O)                 |
| HTTP POST в Sentry                   | ~50-500ms (сеть)                |
| `runZonedGuarded`                    | Negligible overhead             |

**Рекомендации:**

- В продакшене: `Level.WARNING` или `Level.INFO`.
- Логи `fine`/`finer`/`finest` — только для debug.
- Отправку в Sentry делайте async, не блокируя UI.
- Батчинг: накапливайте логи и отправляйте пакетом (раз в 5-10 секунд).

## 8. Частые ошибки и антипаттерны

### ❌ `print()` вместо логгера

```dart
// ❌ Нет уровней, нет фильтрации, нет структуры
void fetchData() {
  print('fetching data...');
  try {
    throw Exception('fail');
  } catch (e) {
    print('error: $e'); // Нет стека, нет контекста
  }
}

// ✅ Логгер
import 'package:logging/logging.dart';
final _log = Logger('DataService');

void fetchDataGood() {
  _log.info('Загрузка данных...');
  try {
    throw Exception('fail');
  } catch (e, stack) {
    _log.severe('Ошибка загрузки', e, stack);
  }
}
```

### ❌ Логирование sensitive данных

```dart
// ❌ Пароль в логах!
// log.info('Login: user=$user, password=$password');

// ✅ Маскирование
void logLogin(String user) {
  final _log = Logger('Auth');
  _log.info('Login: user=$user');
  // Пароль НИКОГДА не логируем
}
```

### ❌ Игнорирование stackTrace

```dart
import 'package:logging/logging.dart';
final _log = Logger('Demo');

void bad() {
  try {
    throw Exception('oops');
  } catch (e) {
    // ❌ Потерян stack trace
    _log.severe('Ошибка: $e');
  }
}

void good() {
  try {
    throw Exception('oops');
  } catch (e, stack) {
    // ✅ Передаём error и stack
    _log.severe('Ошибка', e, stack);
  }
}
```

### ❌ Слишком много логов в продакшене

```dart
// ❌ Level.ALL в продакшене → гигабайты логов
// Logger.root.level = Level.ALL;

// ✅ Конфигурируйте по окружению
void configureLevel(bool isProduction) {
  Logger.root.level = isProduction ? Level.WARNING : Level.ALL;
}
```

## 9. Сравнение с альтернативами

| Подход                   | Уровни          | Структура   | Продакшен    | Сложность |
| ------------------------ | --------------- | ----------- | ------------ | --------- |
| `print()`                | Нет             | Нет         | Нет          | Нулевая   |
| `package:logging`        | 8 уровней       | Иерархия    | Да           | Низкая    |
| `dart:developer` `log()` | Нет             | Нет         | DevTools     | Низкая    |
| Sentry SDK               | Severity        | Breadcrumbs | Да           | Средняя   |
| Crashlytics              | Fatal/Non-fatal | Keys        | Да (Flutter) | Средняя   |

**Типичная комбинация:**

- `package:logging` для локального вывода.
- `runZonedGuarded` для глобального перехвата.
- Sentry/Crashlytics для продакшен-мониторинга.

## 10. Когда НЕ стоит использовать

- **Простые CLI утилиты** — `print()` / `stderr` достаточно.
- **Тестовый код** — логгер засоряет вывод тестов; используйте `expect()`.
- **Sensitive данные** — никогда не логируйте пароли, токены, PII.
- **Hot path** — не ставьте `log.fine()` в цикл на миллион итераций.

## 11. Краткое резюме

1. **`package:logging`** — стандартный пакет с 8 уровнями (FINEST → SHOUT) и иерархией логгеров.
2. **Уровни** — `fine` для debug, `info` для событий, `severe`/`shout` для ошибок.
3. **Structured logging** — JSON-формат для автоматического парсинга (ELK, Datadog).
4. **`runZonedGuarded`** — перехватывает все необработанные async-ошибки.
5. **Breadcrumbs** — цепочка событий до ошибки для контекста при диагностике.
6. **Конфигурация по окружению** — `Level.ALL` в dev, `Level.WARNING` в prod.
7. **Логгируйте error + stack** — `log.severe('msg', error, stackTrace)`.
8. **Не логируйте sensitive** — пароли, токены, персональные данные.

---

> **Назад:** [10.3 Практики ретраев и компенсации](10_03_retry_compensation.md) · **Далее:** [11.0 Тестирование — обзор](../11_testing/11_00_overview.md)
