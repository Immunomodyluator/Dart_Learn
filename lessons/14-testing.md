# Урок 14. Тестирование

> Охватывает подтемы: 14.1 Unit тесты, 14.2 Mocking, 14.3 Интеграционные тесты, 14.4 Покрытие и CI

---

## 1. Формальное определение

Тестирование в Dart строится на официальном пакете **`package:test`** и **`package:mockito`** / **`package:mocktail`** для моков:

- **Unit тест** — тест изолированной единицы (функция, класс) без реальных зависимостей
- **Integration тест** — тест взаимодействия нескольких компонентов
- **Matcher** — декларативные условия проверки (`equals`, `throws`, `emits`)
- **Mock** — фиктивный объект с заданным поведением, проверяет вызовы

```yaml
# pubspec.yaml
dev_dependencies:
  test: ^1.25.0
  mockito: ^5.4.0       # или mocktail: ^1.0.0
  build_runner: ^2.4.0  # для mockito (codegen)
```

---

## 2. Зачем это нужно

- **Регрессионная защита** — изменения не ломают существующую логику
- **Документация поведения** — тест как спецификация
- **Безопасный рефакторинг** — юнит-тесты позволяют менять внутренности без страха
- **Быстрая обратная связь** — юнит-тесты выполняются за миллисекунды

---

## 3. Unit тесты (14.1)

```dart
// test/calculator_test.dart
import 'package:test/test.dart';
import '../lib/calculator.dart';

void main() {
  // group — логическая группировка
  group('Calculator', () {
    late Calculator calc;
    
    // setUp — перед каждым тестом
    setUp(() {
      calc = Calculator();
    });
    
    // tearDown — после каждого теста
    tearDown(() {
      calc.dispose();
    });
    
    // setUpAll / tearDownAll — один раз для всей группы
    setUpAll(() => print('Starting Calculator tests'));
    tearDownAll(() => print('Calculator tests complete'));

    test('add performs addition', () {
      expect(calc.add(2, 3), equals(5));
      expect(calc.add(-1, 1), equals(0));
      expect(calc.add(0, 0), equals(0));
    });

    test('divide throws on zero', () {
      expect(() => calc.divide(1, 0), throwsA(isA<ArgumentError>()));
      expect(
        () => calc.divide(1, 0),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('zero'),
          ),
        ),
      );
    });

    test('multiply with various inputs', () {
      // Несколько ожиданий в одном тесте — допустимо
      for (final (a, b, expected) in [(2, 3, 6), (0, 5, 0), (-1, -1, 1)]) {
        expect(calc.multiply(a, b), equals(expected),
            reason: '$a * $b should be $expected');
      }
    });
  });

  // Parametrized тесты
  group('String parsing', () {
    final cases = [
      ('42', 42),
      ('-7', -7),
      ('0', 0),
    ];

    for (final (input, expected) in cases) {
      test('parses "$input" → $expected', () {
        expect(int.parse(input), equals(expected));
      });
    }
  });

  // Async тест
  group('AsyncService', () {
    test('fetchData returns correct result', () async {
      final service = AsyncService();
      final result = await service.fetchData(1);
      expect(result, equals('data_1'));
    });

    test('fetchData with timeout', () async {
      final service = SlowService();
      expect(
        service.fetchData(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('stream emits expected values', () async {
      final stream = Stream.fromIterable([1, 2, 3]);
      await expectLater(
        stream,
        emitsInOrder([1, 2, 3, emitsDone]),
      );
    });
  });
}
```

### Матчеры

```dart
// Основные матчеры
expect(value, equals(42));
expect(value, isNotNull);
expect(value, isNull);
expect(value, isTrue);
expect(value, isFalse);
expect(value, isA<String>());
expect(value, isNot(equals(0)));

// Числа
expect(3.14, closeTo(3.14159, 0.01));
expect(5, greaterThan(4));
expect(5, lessThanOrEqualTo(5));
expect(5, inInclusiveRange(1, 10));

// Строки
expect('Hello', startsWith('He'));
expect('Hello', endsWith('lo'));
expect('Hello, World', contains('World'));
expect('hello', equalsIgnoringCase('HELLO'));
expect('foo123', matches(RegExp(r'foo\d+')));

// Collections
expect([1, 2, 3], hasLength(3));
expect([1, 2, 3], contains(2));
expect([1, 2, 3], containsAll([1, 3]));
expect([1, 2, 3], orderedEquals([1, 2, 3]));
expect([1, 2, 3], unorderedEquals([3, 1, 2]));
expect({'a': 1}, containsPair('a', 1));
expect([], isEmpty);
expect([1], isNotEmpty);
expect([1, 2, 3], everyElement(greaterThan(0)));
expect([1, 2, 3], anyElement(equals(2)));

// Исключения
expect(() => throw Exception(), throwsException);
expect(() => throw ArgumentError(), throwsArgumentError);
expect(() => throw StateError('bad'), throwsStateError);
expect(
  () async => throw Exception(),
  throwsA(isA<Exception>()),
);

// Streams
await expectLater(stream, emits(1));
await expectLater(stream, emitsInOrder([1, 2, 3]));
await expectLater(stream, emitsThrough(5));
await expectLater(stream, neverEmits(anything));
await expectLater(stream, emitsError(isA<Exception>()));
```

---

## 4. Mocking (14.2)

```dart
// С mocktail (нет кодогенерации, проще)
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Создаём Mock классы
class MockHttpClient extends Mock implements HttpClient {}
class MockRepository extends Mock implements UserRepository {}

// Для Future/Stream — нужен правильный fallback
class FakeUser extends Fake implements User {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUser()); // для matchers
  });

  group('UserService', () {
    late MockRepository mockRepo;
    late UserService service;

    setUp(() {
      mockRepo = MockRepository();
      service = UserService(mockRepo);
    });

    test('getUser calls repository and returns user', () async {
      // Arrange — настройка мока
      final expectedUser = User('1', 'Alice');
      when(() => mockRepo.findById('1'))
          .thenAnswer((_) async => expectedUser);

      // Act
      final user = await service.getUser('1');

      // Assert
      expect(user, equals(expectedUser));
      verify(() => mockRepo.findById('1')).called(1);
    });

    test('getUser throws when not found', () async {
      when(() => mockRepo.findById(any()))
          .thenAnswer((_) async => null);

      expect(
        () => service.getUser('999'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('saveUser validates before saving', () async {
      final user = User('', 'Bad'); // invalid empty id
      
      expect(
        () => service.saveUser(user),
        throwsA(isA<ValidationException>()),
      );
      
      // Проверяем что репозиторий НЕ вызывался
      verifyNever(() => mockRepo.save(any()));
    });

    test('saves with correct data', () async {
      when(() => mockRepo.save(any()))
          .thenAnswer((invocation) async => invocation.positionalArguments[0]);
      
      await service.saveUser(User('123', 'Alice'));
      
      // Проверяем что был вызван с правильным аргументом
      verify(() => mockRepo.save(
        any(that: isA<User>().having((u) => u.name, 'name', 'Alice'))
      )).called(1);
    });
  });
}

// С mockito (с кодогенерацией)
// Запуск: dart run build_runner build
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'user_service_test.mocks.dart';

@GenerateMocks([UserRepository, HttpClient])
void main() {
  final mockRepo = MockUserRepository();
  when(mockRepo.findById('1')).thenAnswer((_) async => User('1', 'Alice'));
  
  verify(mockRepo.findById('1')).called(1);
  verifyNoMoreInteractions(mockRepo);
}
```

---

## 5. Интеграционные тесты (14.3)

```dart
// test/integration/api_test.dart
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  late Process server;
  late String baseUrl;

  setUpAll(() async {
    // Запускаем сервер
    server = await Process.start('dart', ['run', 'bin/server.dart']);
    baseUrl = 'http://localhost:8080';
    // Ждём запуска
    await Future.delayed(Duration(milliseconds: 500));
  });

  tearDownAll(() async {
    server.kill();
  });

  test('GET /users returns list', () async {
    final response = await http.get(Uri.parse('$baseUrl/users'));
    expect(response.statusCode, equals(200));
    
    final body = jsonDecode(response.body) as List;
    expect(body, isNotEmpty);
  });

  test('POST /users creates user', () async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': 'Test User', 'email': 'test@example.com'}),
    );
    
    expect(response.statusCode, equals(201));
    
    final created = jsonDecode(response.body);
    expect(created['id'], isNotNull);
    expect(created['name'], equals('Test User'));
  });
}
```

---

## 6. Покрытие и CI (14.4)

```bash
# Запуск тестов
dart test

# Запуск конкретного файла/группы
dart test test/calculator_test.dart
dart test --name "add performs"

# Coverage
dart test --coverage=coverage/
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov --in=coverage --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json \
  --report-on=lib

# HTML репорт
genhtml coverage/lcov.info -o coverage/html
```

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      
      - name: Install dependencies
        run: dart pub get
      
      - name: Analyze
        run: dart analyze
      
      - name: Run tests
        run: dart test --coverage=coverage/
      
      - name: Format coverage
        run: |
          dart pub global activate coverage
          dart pub global run coverage:format_coverage \
            --lcov --in=coverage --out=coverage/lcov.info \
            --packages=.dart_tool/package_config.json \
            --report-on=lib
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info
```

---

## 7. Минимальный пример

```dart
// lib/fizzbuzz.dart
String fizzBuzz(int n) {
  if (n % 15 == 0) return 'FizzBuzz';
  if (n % 3 == 0) return 'Fizz';
  if (n % 5 == 0) return 'Buzz';
  return '$n';
}

// test/fizzbuzz_test.dart
import 'package:test/test.dart';
import '../lib/fizzbuzz.dart';

void main() {
  group('fizzBuzz', () {
    test('returns Fizz for multiples of 3', () {
      expect(fizzBuzz(3), 'Fizz');
      expect(fizzBuzz(9), 'Fizz');
    });

    test('returns Buzz for multiples of 5', () {
      expect(fizzBuzz(5), 'Buzz');
      expect(fizzBuzz(25), 'Buzz');
    });

    test('returns FizzBuzz for multiples of 15', () {
      expect(fizzBuzz(15), 'FizzBuzz');
      expect(fizzBuzz(30), 'FizzBuzz');
    });

    test('returns number string for others', () {
      expect(fizzBuzz(1), '1');
      expect(fizzBuzz(7), '7');
    });
  });
}
```

---

## 8. Под капотом

- **`package:test`** использует `Isolate.spawnUri` для изолированного запуска тестов
- Каждый тест-файл запускается в отдельном изоляте — нет разделяемого состояния между файлами
- **Coverage** собирается через Observatory/VM Service Protocol (instrumenting the JIT)
- **Mocker pattern** в mocktail использует `noSuchMethod` перехват

---

## 9. Производительность

- **Параллельный запуск тестов**: `dart test -j 4` — 4 изолята параллельно
- **Тег slow тестов**: `@Tags(['slow'])` — отделяйте медленные интеграционные тесты
  ```dart
  @Tags(['slow'])
  void main() { ... }
  ```
  Запуск без slow: `dart test --exclude-tags slow`

---

## 10. Частые ошибки

**1. Нет `setUp` — состояние между тестами:**
```dart
// ПЛОХО — тесты зависят от порядка
late Calculator calc;
void main() {
  calc = Calculator(); // один объект на все тесты
  test('adds', () { calc.add(1, 2); });
  test('state carried over...', () { ... });
}
// ХОРОШО: calc = Calculator() в setUp()
```

**2. Забыть `async/await` в async тестах:**
```dart
// Тест всегда проходит — Future не ожидается
test('async', () { // отсутствует async
  expect(service.fetch(), completion(equals('result'))); // OK но не await
});
// ХОРОШО:
test('async', () async {
  expect(await service.fetch(), equals('result'));
});
```

**3. Слишком много в одном тесте:**
```dart
// ПЛОХО — много assertions, непонятно что сломалось
test('all validation', () {
  expect(validate(''), isFalse);
  expect(validate('a'), isTrue);
  expect(validate(null), isFalse);
  // 20 строк assertions...
});
// ЛУЧШЕ: отдельные тесты на каждый случай
```

---

## 11. Краткое резюме

1. **`package:test`** — основной тест-фреймворк; `test()`, `group()`, `setUp/tearDown`
2. **Матчеры** — declarative assertions; предпочтительнее `equals(x)` чем `== x`
3. **`expect(stream, emitsInOrder(...))`** — для тестирования стримов
4. **mocktail** (без codegen) vs **mockito** (с codegen через build_runner) — выбор по предпочтениям проекта
5. **`verify/verifyNever`** — проверка вызовов методов мока
6. **`dart test --coverage`** → lcov → HTML репорт; интеграция с codecov/coveralls
7. **Интеграционные тесты** в отдельном файле/папке, запускаются отдельно от unit тестов
