# 11.2 Mocking и stubbing

## 1. Формальное определение

**Mock** — объект-заменитель, который имитирует поведение реальной зависимости и позволяет проверить, какие методы были вызваны, с какими аргументами и сколько раз.

**Stub** — объект с заранее заданными ответами на вызовы. Не проверяет вызовы, только возвращает нужные данные.

**Fake** — упрощённая, но рабочая реализация зависимости (например, `FakeDatabase` на основе `Map` вместо реальной БД).

В Dart:

- `package:mockito` + `@GenerateMocks` — генерация mock-классов через `build_runner`.
- Ручные Fake-классы — `implements` или `extends Fake`.

## 2. Зачем это нужно

- **Изоляция** — тестируем только свой код, не сеть/БД/файловую систему.
- **Скорость** — mock отвечает мгновенно, без I/O.
- **Контроль** — задаём любое поведение: успех, ошибка, таймаут.
- **Верификация** — проверяем, что зависимость вызвана правильно.
- **Детерминизм** — тесты не зависят от внешнего окружения.

## 3. Как это работает

### Ручной Fake (без пакетов)

```dart
// lib/src/user_repository.dart
abstract class UserRepository {
  Future<String> findById(int id);
  Future<void> save(String name);
}

// lib/src/user_service.dart
class UserService {
  final UserRepository _repo;
  UserService(this._repo);

  Future<String> getGreeting(int userId) async {
    final name = await _repo.findById(userId);
    return 'Привет, $name!';
  }
}
```

```dart
// test/user_service_test.dart
import 'package:test/test.dart';

// Ручной Fake
class FakeUserRepository implements UserRepository {
  final Map<int, String> _data = {};
  final List<String> savedNames = [];

  void seed(int id, String name) => _data[id] = name;

  @override
  Future<String> findById(int id) async {
    final name = _data[id];
    if (name == null) throw Exception('User $id not found');
    return name;
  }

  @override
  Future<void> save(String name) async {
    savedNames.add(name);
  }
}

// Абстрактный класс и сервис определены выше
abstract class UserRepository {
  Future<String> findById(int id);
  Future<void> save(String name);
}

class UserService {
  final UserRepository _repo;
  UserService(this._repo);

  Future<String> getGreeting(int userId) async {
    final name = await _repo.findById(userId);
    return 'Привет, $name!';
  }
}

void main() {
  late FakeUserRepository fakeRepo;
  late UserService service;

  setUp(() {
    fakeRepo = FakeUserRepository();
    fakeRepo.seed(1, 'Иван');
    fakeRepo.seed(2, 'Мария');
    service = UserService(fakeRepo);
  });

  test('getGreeting возвращает приветствие', () async {
    final greeting = await service.getGreeting(1);
    expect(greeting, equals('Привет, Иван!'));
  });

  test('getGreeting для несуществующего пользователя', () async {
    expect(
      () => service.getGreeting(999),
      throwsA(isA<Exception>()),
    );
  });
}
```

### Fake через `extends Fake`

```dart
import 'package:test/test.dart';

// Dart предоставляет класс Fake в package:test
// Все невызванные методы бросят UnimplementedError

abstract class HttpClient {
  Future<String> get(String url);
  Future<String> post(String url, {required String body});
  Future<void> close();
}

class FakeHttpClient extends Fake implements HttpClient {
  final responses = <String, String>{};

  @override
  Future<String> get(String url) async {
    return responses[url] ?? 'not found';
  }

  // post и close не переопределены — бросят UnimplementedError
  // если будут случайно вызваны
}

void main() {
  test('FakeHttpClient возвращает заданный ответ', () async {
    final client = FakeHttpClient();
    client.responses['/api/users'] = '{"name": "Dart"}';

    final result = await client.get('/api/users');
    expect(result, contains('Dart'));
  });
}
```

### Mockito: настройка

```yaml
# pubspec.yaml
dev_dependencies:
  test: ^1.25.0
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

### Mockito: генерация мока

```dart
// test/api_service_test.dart
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

// --- Зависимость ---
abstract class ApiClient {
  Future<Map<String, dynamic>> get(String path);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body);
}

// --- Сервис ---
class TodoService {
  final ApiClient _client;
  TodoService(this._client);

  Future<String> getTodoTitle(int id) async {
    final response = await _client.get('/todos/$id');
    return response['title'] as String;
  }

  Future<int> createTodo(String title) async {
    final response = await _client.post('/todos', {'title': title});
    return response['id'] as int;
  }
}

// --- Генерация --- (запуск: dart run build_runner build)
@GenerateMocks([ApiClient])
import 'api_service_test.mocks.dart';

void main() {
  late MockApiClient mockClient;
  late TodoService service;

  setUp(() {
    mockClient = MockApiClient();
    service = TodoService(mockClient);
  });

  group('getTodoTitle', () {
    test('возвращает title из ответа API', () async {
      // Arrange: задаём поведение мока
      when(mockClient.get('/todos/1')).thenAnswer(
        (_) async => {'id': 1, 'title': 'Купить молоко'},
      );

      // Act
      final title = await service.getTodoTitle(1);

      // Assert
      expect(title, equals('Купить молоко'));
      verify(mockClient.get('/todos/1')).called(1);
    });

    test('пробрасывает ошибку API', () async {
      when(mockClient.get(any)).thenThrow(Exception('503'));

      expect(
        () => service.getTodoTitle(1),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('createTodo', () {
    test('отправляет POST и возвращает id', () async {
      when(mockClient.post('/todos', {'title': 'Тест'})).thenAnswer(
        (_) async => {'id': 42, 'title': 'Тест'},
      );

      final id = await service.createTodo('Тест');

      expect(id, equals(42));
      verify(mockClient.post('/todos', {'title': 'Тест'})).called(1);
    });
  });

  test('verifyNoMoreInteractions', () async {
    when(mockClient.get('/todos/1')).thenAnswer(
      (_) async => {'id': 1, 'title': 'Test'},
    );

    await service.getTodoTitle(1);

    verify(mockClient.get('/todos/1')).called(1);
    verifyNoMoreInteractions(mockClient);
  });
}
```

### Mockito: when / verify / argument matchers

```dart
import 'package:mockito/mockito.dart';

// Предполагаем, что MockApiClient сгенерирован
// Примеры использования when():

void exampleStubbing(MockApiClient mock) {
  // thenAnswer — для Future (асинхронный ответ)
  when(mock.get(any)).thenAnswer((_) async => {'data': 'ok'});

  // thenReturn — для синхронных методов
  // when(mock.syncMethod()).thenReturn('value');

  // thenThrow — имитация ошибки
  when(mock.get('/error')).thenThrow(Exception('fail'));

  // Несколько вызовов — разные ответы
  var callCount = 0;
  when(mock.get('/counter')).thenAnswer((_) async {
    callCount++;
    return {'count': callCount};
  });

  // Argument matchers
  when(mock.get(argThat(startsWith('/api')))).thenAnswer(
    (_) async => {'api': true},
  );

  when(mock.post(any, argThat(containsPair('title', isNotNull)))).thenAnswer(
    (_) async => {'id': 1},
  );
}

void exampleVerification(MockApiClient mock) {
  // Проверка вызова
  verify(mock.get('/todos/1'));

  // Проверка количества
  verify(mock.get(any)).called(3);

  // Проверка отсутствия вызова
  verifyNever(mock.post(any, any));

  // Захват аргументов
  final captured = verify(mock.get(captureAny)).captured;
  print(captured); // ['/todos/1', '/todos/2', ...]
}

// Заглушка для компиляции
abstract class MockApiClient {
  Future<Map<String, dynamic>> get(dynamic path);
  Future<Map<String, dynamic>> post(dynamic path, dynamic body);
}
```

### Паттерн: внедрение зависимостей для тестируемости

```dart
// ❌ Нетестируемо — жёсткая зависимость
class BadService {
  Future<String> getData() async {
    // final response = await http.get(Uri.parse('https://api.example.com/data'));
    // return response.body;
    return 'hardcoded'; // Нельзя подменить
  }
}

// ✅ Тестируемо — зависимость через конструктор
abstract class DataSource {
  Future<String> fetch();
}

class GoodService {
  final DataSource _source;
  GoodService(this._source);

  Future<String> getData() async {
    final raw = await _source.fetch();
    return raw.toUpperCase();
  }
}

// В тесте:
class FakeDataSource implements DataSource {
  @override
  Future<String> fetch() async => 'test data';
}

// GoodService(FakeDataSource()) — легко тестировать!
```

## 4. Минимальный пример

```dart
import 'package:test/test.dart';

// Зависимость
abstract class Clock {
  DateTime now();
}

// Fake
class FakeClock implements Clock {
  DateTime _now;
  FakeClock(this._now);

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

// Тестируемый код
String timeOfDay(Clock clock) {
  final hour = clock.now().hour;
  if (hour < 12) return 'Утро';
  if (hour < 18) return 'День';
  return 'Вечер';
}

void main() {
  test('утро в 8:00', () {
    final clock = FakeClock(DateTime(2024, 1, 1, 8, 0));
    expect(timeOfDay(clock), equals('Утро'));
  });

  test('вечер в 20:00', () {
    final clock = FakeClock(DateTime(2024, 1, 1, 20, 0));
    expect(timeOfDay(clock), equals('Вечер'));
  });
}
```

## 5. Практический пример

### Тестирование AuthService с mock

```dart
// lib/src/auth_service.dart
abstract class TokenStorage {
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> deleteToken();
}

abstract class AuthApi {
  Future<String> login(String email, String password);
  Future<void> logout(String token);
}

class AuthService {
  final AuthApi _api;
  final TokenStorage _storage;

  AuthService(this._api, this._storage);

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null;
  }

  Future<void> login(String email, String password) async {
    final token = await _api.login(email, password);
    await _storage.saveToken(token);
  }

  Future<void> logout() async {
    final token = await _storage.getToken();
    if (token != null) {
      await _api.logout(token);
      await _storage.deleteToken();
    }
  }
}
```

```dart
// test/auth_service_test.dart
import 'package:test/test.dart';

// --- Вставляем или импортируем определения выше ---

// Fake-реализации
class FakeTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<void> deleteToken() async => _token = null;
}

class FakeAuthApi implements AuthApi {
  final Map<String, String> _users = {};
  final List<String> logoutCalls = [];
  bool shouldFail = false;

  void addUser(String email, String password) => _users[email] = password;

  @override
  Future<String> login(String email, String password) async {
    if (shouldFail) throw Exception('Сервер недоступен');
    if (_users[email] != password) throw Exception('Неверные учётные данные');
    return 'token_${email.hashCode}';
  }

  @override
  Future<void> logout(String token) async {
    logoutCalls.add(token);
  }
}

// Базовые классы (если нет импортов)
abstract class TokenStorage {
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> deleteToken();
}

abstract class AuthApi {
  Future<String> login(String email, String password);
  Future<void> logout(String token);
}

class AuthService {
  final AuthApi _api;
  final TokenStorage _storage;

  AuthService(this._api, this._storage);

  Future<bool> isLoggedIn() async {
    final token = await _storage.getToken();
    return token != null;
  }

  Future<void> login(String email, String password) async {
    final token = await _api.login(email, password);
    await _storage.saveToken(token);
  }

  Future<void> logout() async {
    final token = await _storage.getToken();
    if (token != null) {
      await _api.logout(token);
      await _storage.deleteToken();
    }
  }
}

void main() {
  late FakeAuthApi fakeApi;
  late FakeTokenStorage fakeStorage;
  late AuthService authService;

  setUp(() {
    fakeApi = FakeAuthApi();
    fakeApi.addUser('test@mail.com', 'pass123');
    fakeStorage = FakeTokenStorage();
    authService = AuthService(fakeApi, fakeStorage);
  });

  group('isLoggedIn', () {
    test('false когда нет токена', () async {
      expect(await authService.isLoggedIn(), isFalse);
    });

    test('true после входа', () async {
      await authService.login('test@mail.com', 'pass123');
      expect(await authService.isLoggedIn(), isTrue);
    });
  });

  group('login', () {
    test('сохраняет токен при успешном входе', () async {
      await authService.login('test@mail.com', 'pass123');
      final token = await fakeStorage.getToken();
      expect(token, isNotNull);
      expect(token, startsWith('token_'));
    });

    test('бросает при неверном пароле', () async {
      expect(
        () => authService.login('test@mail.com', 'wrong'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Неверные'),
        )),
      );
    });

    test('бросает при сбое сервера', () async {
      fakeApi.shouldFail = true;
      expect(
        () => authService.login('test@mail.com', 'pass123'),
        throwsException,
      );
    });
  });

  group('logout', () {
    test('удаляет токен и уведомляет API', () async {
      await authService.login('test@mail.com', 'pass123');
      await authService.logout();

      expect(await authService.isLoggedIn(), isFalse);
      expect(fakeApi.logoutCalls, hasLength(1));
    });

    test('ничего не делает если нет токена', () async {
      await authService.logout(); // Не бросает
      expect(fakeApi.logoutCalls, isEmpty);
    });
  });
}
```

## 6. Что происходит под капотом

```
Mockito (с @GenerateMocks):

1. @GenerateMocks([ApiClient])
   → build_runner анализирует ApiClient через dart:mirrors / analyzer
   → генерирует api_service_test.mocks.dart:
      class MockApiClient extends Mock implements ApiClient { ... }

2. when(mock.get('/path'))
   → Mock записывает вызов в _pending invocation
   → .thenAnswer(handler) → сохраняет handler для этого вызова

3. Вызов mock.get('/path') в тесте:
   → Mock ищет совпадение в зарегистрированных стубах
   → При совпадении вызывает handler, иначе → null / default

4. verify(mock.get('/path')).called(1)
   → Mock проверяет журнал вызовов
   → Несовпадение → throw TestFailure

Fake (ручной):

1. class FakeRepo implements UserRepo { ... }
   → Dart проверяет implements на этапе компиляции
   → Все методы ДОЛЖНЫ быть определены

2. extends Fake implements UserRepo
   → Fake предоставляет noSuchMethod() → throw UnimplementedError
   → Переопределяем только нужные методы
```

## 7. Производительность и ресурсы

| Аспект                     | Стоимость           |
| -------------------------- | ------------------- |
| Создание Fake              | ~1 μs               |
| Создание Mock (mockito)    | ~5 μs               |
| `when().thenAnswer()`      | ~1 μs               |
| `verify().called()`        | ~1 μs               |
| `build_runner` (генерация) | 5–30 сек (один раз) |

**Сравнение Fake vs Mock:**

| Критерий                | Fake                    | Mock (mockito)         |
| ----------------------- | ----------------------- | ---------------------- |
| Скорость создания теста | Медленнее (нужен код)   | Быстрее (генерация)    |
| Гибкость                | Любая логика            | when/verify шаблоны    |
| Связанность             | Сильнее (дублирует API) | Слабее (автогенерация) |
| Отладка                 | Легче                   | Сложнее (прокси)       |
| Без `build_runner`      | Да                      | Нет                    |

## 8. Частые ошибки и антипаттерны

### ❌ Мокирование того, что не нужно

```dart
// ❌ Мок для чистой функции
// when(mockMath.add(1, 2)).thenReturn(3);
// Зачем? Просто вызовите add(1, 2).

// ✅ Мокируйте только I/O и внешние зависимости:
// HTTP, БД, файлы, таймеры, рандом
```

### ❌ Забыли запустить build_runner

```bash
# ❌ Ошибка: xxx.mocks.dart не найден
# dart test
# → Error: Could not find api_service_test.mocks.dart

# ✅ Запустите генерацию:
# dart run build_runner build
```

### ❌ Stub без verify (или verify без stub)

```dart
// ❌ Задали поведение, но не проверили вызов
// when(mock.save(any)).thenAnswer((_) async {});
// await service.process();
// ...и всё? А save() точно вызвался?

// ✅ Добавьте verify
// when(mock.save(any)).thenAnswer((_) async {});
// await service.process();
// verify(mock.save(any)).called(1);
```

### ❌ Слишком жёсткие verify

```dart
// ❌ Хрупкий тест — проверяем порядок, количество, аргументы
// verifyInOrder([
//   mock.log('start'),
//   mock.fetch('/a'),
//   mock.fetch('/b'),
//   mock.log('end'),
// ]);

// ✅ Проверяйте результат, а не каждый промежуточный вызов
// expect(result, equals(expectedData));
// verify(mock.fetch(any)).called(greaterThan(0));
```

## 9. Сравнение с альтернативами

| Подход         | Плюсы                        | Минусы                           | Когда               |
| -------------- | ---------------------------- | -------------------------------- | ------------------- |
| Ручной Fake    | Полный контроль, без codegen | Дублирование API                 | Простые зависимости |
| `extends Fake` | Только нужные методы         | Ручной код                       | ≤3 метода           |
| `mockito`      | Автогенерация, when/verify   | build_runner, сложнее отлаживать | Много зависимостей  |
| `mocktail`     | Без codegen, null-safe       | Менее популярен                  | Без build_runner    |

## 10. Когда НЕ стоит использовать

- **Чистые функции** — `add(1, 2)` не нужно мокировать.
- **Value objects** — `DateTime`, `Uri`, коллекции — используйте реальные.
- **Интеграционные тесты** — весь смысл в реальных зависимостях.
- **Слишком много моков** — если 5+ моков → возможно, класс делает слишком много.

## 11. Краткое резюме

1. **Mock** — имитация + верификация вызовов (`when`/`verify`).
2. **Stub** — заранее заданные ответы (подмножество mock).
3. **Fake** — упрощённая рабочая реализация (`implements` / `extends Fake`).
4. **`package:mockito`** — `@GenerateMocks` + `build_runner` для автогенерации.
5. **Внедрение зависимостей** — передавайте зависимости через конструктор.
6. **Мокируйте I/O** — сеть, БД, файлы. Не мокируйте чистые функции.
7. **`verify`** — проверяйте вызовы, но не перестарайтесь (хрупкие тесты).
8. **Альтернатива** — `mocktail` работает без `build_runner`.

---

> **Назад:** [11.1 Unit-тесты с пакетом test](11_01_unit_tests.md) · **Далее:** [11.3 Интеграционные и E2E тесты](11_03_integration_tests.md)
