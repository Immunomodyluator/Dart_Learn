# 11.1 Unit-тесты с пакетом test

## 1. Формальное определение

**Unit-тест** — автоматизированная проверка поведения наименьшей единицы кода (функции, метода, класса) в изоляции от внешних зависимостей. В Dart стандартный фреймворк — `package:test`.

Ключевые функции API:

- `test(description, body)` — один тестовый случай.
- `group(description, body)` — группа связанных тестов.
- `expect(actual, matcher)` — утверждение (assertion).
- `setUp()` / `tearDown()` — код до/после каждого теста.
- `setUpAll()` / `tearDownAll()` — код до/после всей группы.

## 2. Зачем это нужно

- **Регрессия** — ловить поломки при изменениях.
- **Документация** — тест описывает ожидаемое поведение.
- **Рефакторинг** — менять внутреннюю реализацию без страха.
- **Скорость** — unit-тесты выполняются за миллисекунды.
- **CI/CD** — автоматическая проверка каждого коммита.

## 3. Как это работает

### Базовая структура

```dart
import 'package:test/test.dart';

void main() {
  test('описание того, что проверяем', () {
    // Arrange (подготовка)
    final list = [3, 1, 2];

    // Act (действие)
    list.sort();

    // Assert (проверка)
    expect(list, equals([1, 2, 3]));
  });
}
```

### Группировка тестов

```dart
import 'package:test/test.dart';

int add(int a, int b) => a + b;
int multiply(int a, int b) => a * b;

void main() {
  group('Арифметика', () {
    group('add', () {
      test('складывает положительные числа', () {
        expect(add(2, 3), equals(5));
      });

      test('складывает отрицательные числа', () {
        expect(add(-1, -2), equals(-3));
      });

      test('складывает с нулём', () {
        expect(add(5, 0), equals(5));
      });
    });

    group('multiply', () {
      test('умножает на ноль', () {
        expect(multiply(42, 0), equals(0));
      });

      test('умножает отрицательные', () {
        expect(multiply(-3, -4), equals(12));
      });
    });
  });
}
```

### setUp / tearDown

```dart
import 'package:test/test.dart';

class ShoppingCart {
  final _items = <String, double>{};

  void addItem(String name, double price) => _items[name] = price;
  void clear() => _items.clear();
  double get total => _items.values.fold(0.0, (sum, p) => sum + p);
  int get itemCount => _items.length;
}

void main() {
  late ShoppingCart cart;

  setUp(() {
    // Выполняется ПЕРЕД каждым тестом
    cart = ShoppingCart();
  });

  tearDown(() {
    // Выполняется ПОСЛЕ каждого теста
    cart.clear();
  });

  test('пустая корзина имеет total = 0', () {
    expect(cart.total, equals(0.0));
  });

  test('добавление одного товара', () {
    cart.addItem('Книга', 500.0);
    expect(cart.total, equals(500.0));
    expect(cart.itemCount, equals(1));
  });

  test('добавление нескольких товаров', () {
    cart.addItem('Книга', 500.0);
    cart.addItem('Ручка', 50.0);
    expect(cart.total, equals(550.0));
  });
}
```

### setUpAll / tearDownAll

```dart
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    // Один раз перед ВСЕМИ тестами
    print('Инициализация тестовой среды');
  });

  tearDownAll(() {
    // Один раз после ВСЕХ тестов
    print('Очистка тестовой среды');
  });

  test('тест 1', () => expect(1 + 1, 2));
  test('тест 2', () => expect(2 * 2, 4));
}
```

### Матчеры (Matchers)

```dart
import 'package:test/test.dart';

void main() {
  group('Основные матчеры', () {
    test('равенство', () {
      expect(42, equals(42));
      expect('hello', equals('hello'));
    });

    test('сравнение', () {
      expect(10, greaterThan(5));
      expect(3, lessThan(10));
      expect(5, greaterThanOrEqualTo(5));
      expect(5, inInclusiveRange(1, 10));
    });

    test('null и типы', () {
      expect(null, isNull);
      expect(42, isNotNull);
      expect(42, isA<int>());
      expect('hello', isA<String>());
    });

    test('строки', () {
      expect('Dart is great', contains('great'));
      expect('Hello World', startsWith('Hello'));
      expect('test.dart', endsWith('.dart'));
      expect('abc123', matches(RegExp(r'^[a-z]+\d+$')));
    });

    test('коллекции', () {
      expect([1, 2, 3], contains(2));
      expect([1, 2, 3], hasLength(3));
      expect([], isEmpty);
      expect([1], isNotEmpty);
      expect([3, 1, 2], unorderedEquals([1, 2, 3]));
      expect([1, 2, 3], containsAll([1, 3]));
      expect([1, 2, 3], everyElement(greaterThan(0)));
    });

    test('Map', () {
      final map = {'name': 'Dart', 'version': 3};
      expect(map, containsPair('name', 'Dart'));
      expect(map, contains('version'));
    });

    test('близость (для double)', () {
      expect(0.1 + 0.2, closeTo(0.3, 1e-10));
    });
  });

  group('Матчеры для исключений', () {
    test('throwsException', () {
      expect(() => throw Exception('oops'), throwsException);
    });

    test('throwsA с типом', () {
      expect(
        () => throw FormatException('bad'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throwsA с сообщением', () {
      expect(
        () => throw FormatException('invalid input'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('invalid'),
          ),
        ),
      );
    });

    test('throwsArgumentError', () {
      expect(() => throw ArgumentError('bad'), throwsArgumentError);
    });

    test('throwsStateError', () {
      expect(() => throw StateError('wrong state'), throwsStateError);
    });
  });
}
```

### Асинхронные тесты

```dart
import 'package:test/test.dart';

Future<int> fetchValue() async {
  await Future.delayed(Duration(milliseconds: 100));
  return 42;
}

Future<void> failingOperation() async {
  await Future.delayed(Duration(milliseconds: 50));
  throw Exception('Network error');
}

Stream<int> countStream(int max) async* {
  for (var i = 1; i <= max; i++) {
    await Future.delayed(Duration(milliseconds: 10));
    yield i;
  }
}

void main() {
  test('async/await в тесте', () async {
    final result = await fetchValue();
    expect(result, equals(42));
  });

  test('completion matcher для Future', () {
    // Без await — используем матчер
    expect(fetchValue(), completion(equals(42)));
  });

  test('throwsA для async-ошибок', () {
    expect(failingOperation(), throwsA(isA<Exception>()));
  });

  test('тестирование Stream', () {
    expect(
      countStream(3),
      emitsInOrder([1, 2, 3]),
    );
  });

  test('Stream матчеры', () {
    expect(
      countStream(5),
      emitsInOrder([
        emits(1),                // Ожидаем 1
        emits(greaterThan(1)),   // Ожидаем >1
        emitsAnyOf([3, 4]),      // Ожидаем 3 или 4
        emitsThrough(5),         // Пропускаем до 5
      ]),
    );
  });

  test('Stream завершается', () {
    expect(countStream(2), emitsInOrder([1, 2, emitsDone]));
  });
}
```

### Тестирование с fake_async

```dart
import 'package:test/test.dart';
import 'package:fake_async/fake_async.dart';

class Debouncer {
  final Duration delay;
  int _callCount = 0;

  Debouncer(this.delay);

  int get callCount => _callCount;

  Future<void> run(void Function() action) async {
    await Future.delayed(delay);
    action();
    _callCount++;
  }
}

void main() {
  test('debouncer вызывает action после задержки', () {
    fakeAsync((async) {
      var called = false;
      final debouncer = Debouncer(Duration(seconds: 5));

      debouncer.run(() => called = true);

      // Прошло 3 секунды — ещё не вызвано
      async.elapse(Duration(seconds: 3));
      expect(called, isFalse);

      // Прошло ещё 2 секунды (итого 5) — вызвано
      async.elapse(Duration(seconds: 2));
      expect(called, isTrue);
      expect(debouncer.callCount, equals(1));
    });
  });
}
```

### Пропуск и условный запуск

```dart
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('пропущенный тест', () {
    // ...
  }, skip: 'Не реализовано (#123)');

  test('условный пропуск', () {
    // ...
  }, skip: Platform.isWindows ? 'Не работает на Windows' : null);

  test('тест с таймаутом', () async {
    await Future.delayed(Duration(milliseconds: 100));
    expect(true, isTrue);
  }, timeout: Timeout(Duration(seconds: 5)));

  test('тест с тегом', () {
    expect(1, equals(1));
  }, tags: ['slow', 'integration']);
}
```

### Параметризованные тесты

```dart
import 'package:test/test.dart';

bool isPalindrome(String s) => s == s.split('').reversed.join();

void main() {
  final cases = {
    'abba': true,
    'racecar': false, // нечётная длина, но палиндром — исправим!
    'hello': false,
    'a': true,
    '': true,
    'level': true,
  };

  group('isPalindrome', () {
    for (final entry in cases.entries) {
      test('"${entry.key}" → ${entry.value}', () {
        expect(isPalindrome(entry.key), equals(entry.value));
      });
    }
  });
}
```

### Кастомные матчеры

```dart
import 'package:test/test.dart';

// Кастомный матчер: проверяет, что число чётное
const isEven = _IsEven();

class _IsEven extends Matcher {
  const _IsEven();

  @override
  bool matches(Object? item, Map matchState) =>
      item is int && item.isEven;

  @override
  Description describe(Description description) =>
      description.add('чётное число');

  @override
  Description describeMismatch(
    Object? item, Description mismatchDescription,
    Map matchState, bool verbose,
  ) {
    if (item is! int) {
      return mismatchDescription.add('не является int');
    }
    return mismatchDescription.add('$item — нечётное');
  }
}

void main() {
  test('кастомный матчер isEven', () {
    expect(4, isEven);
    expect(0, isEven);
    // expect(3, isEven); // ← Failed: Expected: чётное число. Actual: 3 — нечётное
  });
}
```

## 4. Минимальный пример

```dart
// test/simple_test.dart
import 'package:test/test.dart';

String greet(String name) => 'Привет, $name!';

void main() {
  test('greet возвращает приветствие', () {
    expect(greet('Dart'), equals('Привет, Dart!'));
  });
}
```

Запуск:

```bash
dart test test/simple_test.dart
```

## 5. Практический пример

### Тестирование класса BankAccount

```dart
// lib/src/bank_account.dart
class InsufficientFundsException implements Exception {
  final double requested;
  final double available;
  const InsufficientFundsException(this.requested, this.available);

  @override
  String toString() =>
      'Недостаточно средств: запрошено $requested, доступно $available';
}

class BankAccount {
  final String owner;
  double _balance;
  final _history = <String>[];

  BankAccount(this.owner, [this._balance = 0.0]) {
    if (_balance < 0) throw ArgumentError('Начальный баланс не может быть отрицательным');
  }

  double get balance => _balance;
  List<String> get history => List.unmodifiable(_history);

  void deposit(double amount) {
    if (amount <= 0) throw ArgumentError('Сумма должна быть положительной');
    _balance += amount;
    _history.add('+$amount');
  }

  void withdraw(double amount) {
    if (amount <= 0) throw ArgumentError('Сумма должна быть положительной');
    if (amount > _balance) {
      throw InsufficientFundsException(amount, _balance);
    }
    _balance -= amount;
    _history.add('-$amount');
  }

  void transfer(BankAccount to, double amount) {
    withdraw(amount);
    to.deposit(amount);
  }
}
```

```dart
// test/bank_account_test.dart
import 'package:test/test.dart';
import 'package:my_project/src/bank_account.dart';

void main() {
  late BankAccount account;

  setUp(() {
    account = BankAccount('Иван', 1000.0);
  });

  group('Создание', () {
    test('создаёт аккаунт с начальным балансом', () {
      expect(account.owner, equals('Иван'));
      expect(account.balance, equals(1000.0));
    });

    test('создаёт аккаунт с нулевым балансом по умолчанию', () {
      final acc = BankAccount('Анна');
      expect(acc.balance, equals(0.0));
    });

    test('не допускает отрицательный начальный баланс', () {
      expect(
        () => BankAccount('Тест', -100),
        throwsArgumentError,
      );
    });
  });

  group('Пополнение', () {
    test('увеличивает баланс', () {
      account.deposit(500.0);
      expect(account.balance, equals(1500.0));
    });

    test('записывает в историю', () {
      account.deposit(200.0);
      expect(account.history, contains('+200.0'));
    });

    test('не допускает нулевую или отрицательную сумму', () {
      expect(() => account.deposit(0), throwsArgumentError);
      expect(() => account.deposit(-100), throwsArgumentError);
    });
  });

  group('Снятие', () {
    test('уменьшает баланс', () {
      account.withdraw(300.0);
      expect(account.balance, equals(700.0));
    });

    test('бросает InsufficientFundsException при нехватке средств', () {
      expect(
        () => account.withdraw(2000.0),
        throwsA(
          isA<InsufficientFundsException>()
            .having((e) => e.requested, 'requested', 2000.0)
            .having((e) => e.available, 'available', 1000.0),
        ),
      );
    });
  });

  group('Перевод', () {
    late BankAccount recipient;

    setUp(() {
      recipient = BankAccount('Мария', 500.0);
    });

    test('переводит деньги между аккаунтами', () {
      account.transfer(recipient, 300.0);
      expect(account.balance, equals(700.0));
      expect(recipient.balance, equals(800.0));
    });

    test('не переводит при нехватке средств', () {
      expect(
        () => account.transfer(recipient, 5000.0),
        throwsA(isA<InsufficientFundsException>()),
      );

      // Баланс получателя не изменился
      expect(recipient.balance, equals(500.0));
    });
  });

  group('История', () {
    test('записывает все операции', () {
      account.deposit(100.0);
      account.withdraw(50.0);
      account.deposit(200.0);

      expect(account.history, ['+100.0', '-50.0', '+200.0']);
    });

    test('история неизменяема извне', () {
      account.deposit(100.0);
      expect(
        () => (account.history as List).add('hacked'),
        throwsUnsupportedError,
      );
    });
  });
}
```

## 6. Что происходит под капотом

```
dart test test/bank_account_test.dart

1. dart test запускает dart_test_runner
2. Парсит dart_test.yaml (если есть) для конфигурации
3. Собирает все test() и group() вызовы (declarative)

Порядок выполнения:
  setUpAll()
  ├── setUp()
  ├── test('тест 1') → expect() → Matcher.matches()
  ├── tearDown()
  ├── setUp()
  ├── test('тест 2') → expect() → throw TestFailure если не совпало
  ├── tearDown()
  tearDownAll()

expect(actual, matcher):
  1. matcher.matches(actual, matchState)
  2. Если false → throw TestFailure с описанием:
     - matcher.describe() → ожидание
     - matcher.describeMismatch() → что получено

Результат:
  ✅ +1: Создание создаёт аккаунт с начальным балансом
  ✅ +2: Пополнение увеличивает баланс
  ...
  ❌ -1: Снятие ... (если тест упал)

Exit code:
  0 — все тесты прошли
  1 — есть failed тесты
```

## 7. Производительность и ресурсы

| Аспект                   | Стоимость                     |
| ------------------------ | ----------------------------- |
| Один `test()`            | ~0.1–1 мс (без I/O)           |
| `expect()` + matcher     | ~1 μs                         |
| `setUp()` / `tearDown()` | ~1 μs (без создания объектов) |
| Запуск `dart test`       | ~2–5 сек (холодный старт)     |
| 1000 unit-тестов         | < 10 сек                      |

**Рекомендации:**

- Не делайте I/O в unit-тестах — используйте mock/fake.
- Выносите тяжёлую инициализацию в `setUpAll`.
- Используйте `--concurrency` для параллельного запуска файлов.

## 8. Частые ошибки и антипаттерны

### ❌ Тест без assertion

```dart
// ❌ Тест всегда «зелёный» — ничего не проверяет
test('fetchData работает', () async {
  await fetchData();
});

// ✅ Проверяем результат
test('fetchData возвращает данные', () async {
  final data = await fetchData();
  expect(data, isNotEmpty);
});

Future<List<int>> fetchData() async => [1, 2, 3];
```

### ❌ Зависимость между тестами

```dart
var counter = 0;

// ❌ Тесты зависят от порядка выполнения
test('increment', () { counter++; expect(counter, 1); });
test('check', () { expect(counter, 1); }); // Может упасть!

// ✅ Каждый тест независим
// Используйте setUp() для инициализации
```

### ❌ Тестирование приватных деталей

```dart
// ❌ Тестируем внутреннюю структуру
// expect(account._balance, equals(1000)); // Не скомпилируется из другого файла

// ✅ Тестируем через публичный API
// expect(account.balance, equals(1000));
```

### ❌ Слишком много проверок в одном тесте

```dart
// ❌ Один тест — 20 expect-ов, непонятно что именно сломалось
test('всё работает', () {
  // ...множество проверок...
});

// ✅ Одно поведение — один тест
test('deposit увеличивает баланс', () { /* ... */ });
test('deposit записывает в историю', () { /* ... */ });
```

## 9. Сравнение с альтернативами

| Фреймворк      | Язык       | Особенности                      |
| -------------- | ---------- | -------------------------------- |
| `package:test` | Dart       | Стандарт, матчеры, async, Stream |
| JUnit          | Java       | Аннотации, правила (rules)       |
| pytest         | Python     | Fixtures, parametrize, плагины   |
| Jest           | JavaScript | Snapshot тесты, mock всего       |
| xUnit          | C#         | Теория (data-driven), DI         |

**`package:test` выделяется:**

- Встроенная поддержка `async/await` и `Stream`.
- Выразительная система матчеров (`having`, `predicate`).
- `fake_async` для управления временем.

## 10. Когда НЕ стоит использовать

- **Тривиальный код** — геттер `String get name => _name;` не нужно тестировать.
- **Сгенерированный код** — `json_serializable`, `freezed` уже протестированы.
- **UI-верстка** — для визуального тестирования используйте Golden tests (Flutter).
- **Внешние API** — для них нужны integration tests с mock-сервером.

## 11. Краткое резюме

1. **`test()`** — один тестовый случай; `group()` — логическая группа.
2. **`expect(actual, matcher)`** — утверждение; при несовпадении — `TestFailure`.
3. **Матчеры** — `equals`, `contains`, `throwsA`, `isA<T>().having()`, `closeTo`.
4. **setUp / tearDown** — изоляция состояния между тестами.
5. **Async тесты** — `async/await`, `completion()`, `emitsInOrder()`.
6. **`fake_async`** — управление временем без реальных задержек.
7. **Параметризация** — цикл `for` + `test()` для data-driven тестов.
8. **Один тест — одно поведение**; тесты не зависят друг от друга.

---

> **Назад:** [11.0 Тестирование — обзор](11_00_overview.md) · **Далее:** [11.2 Mocking и stubbing](11_02_mocking.md)
