# 10.1 try / catch / finally

## 1. Формальное определение

**`try/catch/finally`** — конструкция структурной обработки исключений. `try` оборачивает потенциально опасный код, `catch` перехватывает исключения, `finally` выполняется **всегда** — независимо от того, было ли исключение.

```dart
try {
  // Код, который может бросить исключение
} on SpecificException catch (e, stackTrace) {
  // Обработка конкретного типа
} catch (e, stackTrace) {
  // Обработка любого исключения
} finally {
  // Выполняется ВСЕГДА
}
```

Dart позволяет бросать (`throw`) **любой** объект, но по конвенции — только `Exception` и `Error`.

## 2. Зачем это нужно

- **Контроль потока** — перехват ошибок без аварийного завершения.
- **Очистка ресурсов** — `finally` гарантирует освобождение (файлы, соединения).
- **Типизированная обработка** — `on` фильтрует по типу исключения.
- **Propagation** — `rethrow` пробрасывает ошибку выше с оригинальным стек-трейсом.

## 3. Как это работает

### Базовый try/catch

```dart
void main() {
  try {
    final result = 10 ~/ 0; // IntegerDivisionByZeroException
    print(result);
  } catch (e) {
    print('Ошибка: $e');
  }
  print('Программа продолжает работу');
}
```

### on — по типу исключения

```dart
void main() {
  try {
    int.parse('abc');
  } on FormatException catch (e) {
    print('Ошибка формата: ${e.message}');
  } on TypeError catch (e) {
    print('Ошибка типа: $e');
  } catch (e) {
    print('Другая ошибка: $e');
  }
}
```

### catch с StackTrace

```dart
void main() {
  try {
    _level1();
  } catch (e, stackTrace) {
    print('Ошибка: $e');
    print('Stack trace:\n$stackTrace');
  }
}

void _level1() => _level2();
void _level2() => _level3();
void _level3() => throw Exception('Глубокая ошибка');

// Stack trace покажет: _level3 → _level2 → _level1 → main
```

### finally

```dart
import 'dart:io';

void readFile(String path) {
  RandomAccessFile? file;
  try {
    file = File(path).openSync();
    final content = file.readStringSync();
    print(content);
  } on FileSystemException catch (e) {
    print('Ошибка файла: ${e.message}');
  } finally {
    // ВСЕГДА выполняется — даже при исключении или return
    file?.closeSync();
    print('Файл закрыт (если был открыт)');
  }
}
```

### throw и rethrow

```dart
// throw — бросить исключение
void validateAge(int age) {
  if (age < 0) {
    throw ArgumentError.value(age, 'age', 'Возраст не может быть отрицательным');
  }
  if (age > 150) {
    throw RangeError.range(age, 0, 150, 'age');
  }
}

// rethrow — пробросить с ОРИГИНАЛЬНЫМ стек-трейсом
void processUser(Map<String, dynamic> data) {
  try {
    validateAge(data['age'] as int);
  } catch (e) {
    print('Логируем ошибку: $e');
    rethrow; // ← Оригинальный stackTrace сохраняется!
  }
}

// throw e — ТЕРЯЕТ оригинальный стек-трейс!
void badRethrow() {
  try {
    throw Exception('original');
  } catch (e) {
    throw e; // ❌ Стек-трейс начинается здесь, а не в original throw
    // rethrow; // ✅ Стек-трейс сохраняется
  }
}
```

### on без catch

```dart
void main() {
  try {
    int.parse('abc');
  } on FormatException {
    // Без catch — не нужны e и stackTrace
    print('Неверный формат, используем значение по умолчанию');
  }
}
```

### Множественные catch-блоки

```dart
void main() {
  try {
    riskyOperation();
  } on FormatException catch (e) {
    // Конкретный тип — первый
    print('Формат: ${e.message}');
  } on IOException catch (e) {
    // Конкретный тип — второй
    print('I/O: $e');
  } on Exception catch (e) {
    // Родительский тип — ловит остальные Exception
    print('Другое исключение: $e');
  } catch (e) {
    // Ловит ВСЁ (включая Error и произвольные объекты)
    print('Неизвестное: $e');
  }

  // Порядок: от конкретного к общему!
}

void riskyOperation() => throw FormatException('bad data');
```

### Exception vs Error

```dart
void main() {
  // === EXCEPTION: восстановимые ситуации ===
  // Ловите и обрабатывайте

  try {
    final value = int.parse('not-a-number');
  } on FormatException {
    print('Ожидаемая ошибка — обрабатываем');
  }

  // === ERROR: баги в коде ===
  // НЕ ловите — ИСПРАВЛЯЙТЕ код

  // RangeError — обращение за пределы массива
  // TypeError — несоответствие типов
  // AssertionError — нарушение assert
  // StateError — вызов метода в неправильном состоянии
  // StackOverflowError — бесконечная рекурсия

  // ❌ Плохо: ловить Error в production
  // try {
  //   list[100]; // RangeError
  // } catch (e) {
  //   // Маскирует баг!
  // }

  // ✅ Хорошо: проверить перед доступом
  final list = [1, 2, 3];
  if (list.length > 100) {
    print(list[100]);
  }
}
```

### throw любого объекта

```dart
void main() {
  // Dart позволяет бросать ЛЮБОЙ объект
  try {
    throw 'Строка как ошибка'; // ⚠️ Работает, но плохая практика
  } catch (e) {
    print('Тип: ${e.runtimeType}, значение: $e');
    // Тип: String, значение: Строка как ошибка
  }

  try {
    throw 42; // ⚠️ Работает
  } catch (e) {
    print('Тип: ${e.runtimeType}, значение: $e');
    // Тип: int, значение: 42
  }

  // ✅ Правильно: бросайте Exception или Error
  // throw FormatException('описание');
  // throw ArgumentError('описание');
}
```

### async try/catch

```dart
Future<String> fetchData() async {
  await Future.delayed(Duration(milliseconds: 100));
  throw Exception('Сервер недоступен');
}

void main() async {
  // try/catch работает с await
  try {
    final data = await fetchData();
    print(data);
  } on Exception catch (e) {
    print('Ошибка: $e'); // Ошибка: Exception: Сервер недоступен
  }

  // Без await — ошибка НЕ ловится здесь!
  try {
    fetchData(); // ❌ Future с ошибкой, но try/catch не поймает
  } catch (e) {
    print('Не попадём сюда');
  }
  // Ошибка будет unhandled!
}
```

### Вложенные try/catch

```dart
void main() {
  try {
    try {
      throw FormatException('inner');
    } on FormatException catch (e) {
      print('Внутренний catch: $e');
      // Обработали — внешний catch НЕ вызывается
    }
    print('Продолжение внешнего try');
  } catch (e) {
    print('Внешний catch: $e');
  }

  // С rethrow:
  try {
    try {
      throw FormatException('inner');
    } on FormatException catch (e) {
      print('Внутренний catch: $e');
      rethrow; // Пробрасываем во внешний
    }
  } catch (e) {
    print('Внешний catch: $e'); // ← Сюда попадаем
  }
}
```

### assert — проверки только в debug

```dart
void processOrder(int quantity, double price) {
  // assert работает ТОЛЬКО в debug mode (dart --enable-asserts)
  // В production — assert полностью игнорируется
  assert(quantity > 0, 'Количество должно быть > 0');
  assert(price >= 0, 'Цена не может быть отрицательной');

  print('Заказ: $quantity × $price = ${quantity * price}');
}

void main() {
  processOrder(5, 19.99);   // ✅
  // processOrder(-1, 19.99); // AssertionError в debug mode
}
```

## 4. Минимальный пример

```dart
void main() {
  try {
    final result = int.parse('abc');
    print(result);
  } on FormatException catch (e) {
    print('Ошибка: ${e.message}'); // Ошибка: abc
  } finally {
    print('Готово');
  }
}
```

## 5. Практический пример

### Безопасный парсер конфигурации

```dart
import 'dart:convert';

class ConfigError implements Exception {
  final String key;
  final String reason;
  ConfigError(this.key, this.reason);

  @override
  String toString() => 'ConfigError: ключ "$key" — $reason';
}

class AppConfig {
  final String host;
  final int port;
  final bool debug;
  final Duration timeout;

  AppConfig._({
    required this.host,
    required this.port,
    required this.debug,
    required this.timeout,
  });

  /// Парсинг конфигурации с детальной обработкой ошибок
  factory AppConfig.fromJson(String jsonString) {
    late final Map<String, dynamic> json;

    try {
      json = jsonDecode(jsonString) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw ConfigError('(root)', 'невалидный JSON: ${e.message}');
    } on TypeError {
      throw ConfigError('(root)', 'ожидается JSON-объект, не массив');
    }

    // Валидация обязательных полей
    final host = _requireString(json, 'host');
    final port = _requireInt(json, 'port', min: 1, max: 65535);
    final debug = json['debug'] as bool? ?? false;

    final timeoutSec = json['timeoutSec'] as int? ?? 30;
    if (timeoutSec < 1 || timeoutSec > 300) {
      throw ConfigError('timeoutSec', 'должен быть 1–300, получено $timeoutSec');
    }

    return AppConfig._(
      host: host,
      port: port,
      debug: debug,
      timeout: Duration(seconds: timeoutSec),
    );
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) throw ConfigError(key, 'обязательное поле отсутствует');
    if (value is! String) throw ConfigError(key, 'ожидается строка, получено ${value.runtimeType}');
    if (value.isEmpty) throw ConfigError(key, 'не может быть пустым');
    return value;
  }

  static int _requireInt(Map<String, dynamic> json, String key,
      {int? min, int? max}) {
    final value = json[key];
    if (value == null) throw ConfigError(key, 'обязательное поле отсутствует');
    if (value is! int) throw ConfigError(key, 'ожидается число, получено ${value.runtimeType}');
    if (min != null && value < min) throw ConfigError(key, 'минимум $min, получено $value');
    if (max != null && value > max) throw ConfigError(key, 'максимум $max, получено $value');
    return value;
  }

  @override
  String toString() => 'AppConfig(host: $host, port: $port, '
      'debug: $debug, timeout: ${timeout.inSeconds}s)';
}

void main() {
  // ✅ Валидная конфигурация
  try {
    final config = AppConfig.fromJson(
        '{"host": "localhost", "port": 8080, "debug": true}');
    print(config);
  } on ConfigError catch (e) {
    print('Ошибка конфигурации: $e');
  }

  // ❌ Невалидная
  try {
    AppConfig.fromJson('{"host": "localhost"}'); // port отсутствует
  } on ConfigError catch (e) {
    print(e); // ConfigError: ключ "port" — обязательное поле отсутствует
  }

  // ❌ Невалидный JSON
  try {
    AppConfig.fromJson('{invalid json}');
  } on ConfigError catch (e) {
    print(e); // ConfigError: ключ "(root)" — невалидный JSON: ...
  }
}
```

## 6. Что происходит под капотом

```
throw FormatException('bad'):
  1. Создаётся объект FormatException
  2. Записывается текущий StackTrace
  3. Раскрутка стека (stack unwinding):
     - Текущая функция прерывается
     - Управление передаётся ближайшему catch-блоку
     - Если catch не найден — на уровень выше
     - Если нигде не пойман — unhandled exception → crash

try {
  code();
} on FormatException catch (e, s) {
  handle(e, s);
} catch (e, s) {
  handleOther(e, s);
} finally {
  cleanup();
}

Компиляция:
  1. try-блок → обёрнут в exception handler
  2. on FormatException → type test: e is FormatException?
  3. catch (e, s) → fallback handler (ловит Object)
  4. finally → вызывается ВСЕГДА:
     - после нормального завершения try
     - после catch
     - после rethrow (перед propagation выше)
     - даже после return внутри try/catch!

rethrow vs throw e:
  rethrow → StackTrace из ОРИГИНАЛЬНОГО throw сохраняется
  throw e → StackTrace начинается ЗДЕСЬ (теряется origin)
```

## 7. Производительность и ресурсы

| Аспект                      | Стоимость                                |
| --------------------------- | ---------------------------------------- |
| `try` блок (нет исключения) | Почти zero — enter/exit handler          |
| `throw`                     | Создание объекта + StackTrace capture    |
| StackTrace capture          | Заметно (~10-100 мкс)                    |
| `catch` (перехват)          | Stack unwinding (дороже обычного return) |
| `finally`                   | Один вызов (дёшево)                      |
| `on Type` test              | Один `is` check                          |

**Рекомендации:**

- `try/catch` без исключений — бесплатно.
- Не используйте exceptions для обычного control flow (дорого).
- StackTrace capture — самая дорогая часть; в hot paths избегайте throw.
- `Error.stackTrace` может быть null; `catch (e, s)` всегда даёт StackTrace.

## 8. Частые ошибки и антипаттерны

### ❌ Пустой catch (проглатывание ошибок)

```dart
// ❌ Ошибка проглочена — баги невидимы
try {
  riskyOperation();
} catch (e) {
  // Ничего не делаем
}

// ✅ Как минимум — логирование
try {
  riskyOperation();
} catch (e, s) {
  print('Ошибка: $e\n$s');
}

void riskyOperation() => throw Exception('oops');
```

### ❌ throw e вместо rethrow

```dart
void main() {
  try {
    try {
      throw Exception('original');
    } catch (e) {
      throw e; // ❌ Теряет оригинальный стек-трейс
      // rethrow; // ✅ Сохраняет оригинальный стек-трейс
    }
  } catch (e, s) {
    print(s); // С throw e — стек начинается на 2 уровня выше
  }
}
```

### ❌ catch (Object) ловит Error

```dart
// ❌ Ловит даже StackOverflowError и OutOfMemoryError
try {
  recursiveFunction(0);
} catch (e) {
  print('Поймал: $e'); // Поймал StackOverflowError — плохо!
}

// ✅ Ловите только Exception
try {
  riskyOperation();
} on Exception catch (e) {
  print('Поймал: $e'); // Только Exception, не Error
}

void recursiveFunction(int n) => recursiveFunction(n + 1);
void riskyOperation() => throw Exception('expected');
```

### ❌ Exception для control flow

```dart
// ❌ Дорого! Exception — не для обычного ветвления
int? findIndex(List<int> list, int value) {
  try {
    for (var i = 0; i < list.length; i++) {
      if (list[i] == value) throw i; // ❌ Бросаем int как "результат"
    }
  } catch (index) {
    return index as int;
  }
  return null;
}

// ✅ Обычный return
int? findIndexCorrect(List<int> list, int value) {
  for (var i = 0; i < list.length; i++) {
    if (list[i] == value) return i;
  }
  return null;
}
```

## 9. Сравнение с альтернативами

| Подход                 | Когда                   | Плюсы                        | Минусы                  |
| ---------------------- | ----------------------- | ---------------------------- | ----------------------- |
| `try/catch`            | Исключительные ситуации | Чёткая семантика, StackTrace | Дорого при throw        |
| Nullable return (`T?`) | Ожидаемое отсутствие    | Дёшево, type-safe            | Теряется причина ошибки |
| Result type (`sealed`) | Функциональный стиль    | Явный, composable            | Больше кода             |
| Error codes            | Legacy                  | Простой                      | Легко забыть проверить  |
| `assert`               | Debug-only              | Zero-cost в production       | Нет в release           |

### Result type как альтернатива

```dart
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final String message;
  const Err(this.message);
}

Result<int> safeParse(String s) {
  final n = int.tryParse(s);
  if (n != null) return Ok(n);
  return Err('Невалидное число: $s');
}

void main() {
  final result = safeParse('42');
  switch (result) {
    case Ok(:final value):
      print('Число: $value');
    case Err(:final message):
      print('Ошибка: $message');
  }
}
```

## 10. Когда НЕ стоит использовать

- **Обычный control flow** — exception дорогой; используйте `if`, nullable, Result.
- **Ловить Error в production** — Error = баг; исправляйте код.
- **Пустой catch** — проглатывание ошибок скрывает баги.
- **Глубокие вложенные try/catch** — упрощайте логику или разбивайте на функции.

## 11. Краткое резюме

1. **`try/catch/finally`** — базовая конструкция обработки исключений.
2. **`on Type`** — фильтрация по типу; порядок от конкретного к общему.
3. **`catch (e, stackTrace)`** — доступ к объекту ошибки и стек-трейсу.
4. **`finally`** — выполняется всегда; для очистки ресурсов.
5. **`throw`** — бросить исключение; **`rethrow`** — пробросить с оригинальным стеком.
6. **Exception** — ловите и обрабатывайте; **Error** — исправляйте код.
7. **`assert`** — проверки только в debug mode; в release — zero-cost.
8. **Не проглатывайте** — пустой `catch` скрывает баги.

---

> **Назад:** [10.0 Обработка ошибок — обзор](10_00_overview.md) · **Далее:** [10.2 Пользовательские исключения](10_02_custom_exceptions.md)
