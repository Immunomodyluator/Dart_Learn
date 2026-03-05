# 8.4 Type aliases и typedef обновлённый синтаксис

## 1. Формальное определение

**Type alias** — объявление альтернативного имени для существующего типа. В Dart записывается через ключевое слово `typedef`:

```dart
typedef Name = ExistingType;
```

С Dart 2.13 (2021) `typedef` работает для **любых типов** — не только для функций.

**Старый синтаксис** (`typedef ReturnType Name(ParamTypes)`) — deprecated для новых проектов; поддерживается для обратной совместимости.

## 2. Зачем это нужно

- **Читаемость** — замена длинных generic-типов коротким именем.
- **Единое определение** — изменяя alias, обновляется весь код.
- **Документирование намерений** — `UserId` вместо `String`, `JsonMap` вместо `Map<String, dynamic>`.
- **Упрощение callback-сигнатур** — `EventHandler` вместо `void Function(Event)`.

## 3. Как это работает

### Новый синтаксис (Dart 2.13+)

```dart
// Alias для любого типа
typedef JsonMap = Map<String, dynamic>;
typedef UserId = String;
typedef Matrix = List<List<double>>;
typedef Pair<A, B> = (A, B);                // Record type
typedef StringList = List<String>;
typedef Callback = void Function();
typedef Predicate<T> = bool Function(T);
```

### Старый синтаксис (только для функций)

```dart
// Deprecated style — НЕ используйте в новом коде
typedef void OldCallback();
typedef bool OldPredicate(String value);
typedef int OldComparator(Object a, Object b);

// Эквивалент в новом синтаксисе:
typedef NewCallback = void Function();
typedef NewPredicate = bool Function(String value);
typedef NewComparator = int Function(Object a, Object b);
```

### Alias для функций

```dart
// Простой callback
typedef VoidCallback = void Function();

// С параметрами
typedef EventHandler<T> = void Function(T event);

// Возвращающий значение
typedef Mapper<T, R> = R Function(T input);

// С именованными параметрами
typedef HttpHandler = Future<Response> Function(
  Request request, {
  Map<String, String>? headers,
});

void main() {
  // Использование
  VoidCallback onTap = () => print('Tap!');
  EventHandler<String> onMessage = (msg) => print(msg);
  Mapper<int, String> intToStr = (n) => n.toString();

  onTap();
  onMessage('Привет');
  print(intToStr(42)); // "42"
}
```

### Alias для коллекций и сложных типов

```dart
typedef JsonMap = Map<String, dynamic>;
typedef JsonList = List<JsonMap>;
typedef Headers = Map<String, String>;
typedef Matrix = List<List<double>>;

// Используем в функциях
JsonMap parseJson(String raw) {
  return {'raw': raw}; // упрощённо
}

void setHeaders(Headers headers) {
  headers.forEach((k, v) => print('$k: $v'));
}

void main() {
  JsonMap data = parseJson('{}');
  Headers h = {'Content-Type': 'application/json'};
  setHeaders(h);
}
```

### Generic type alias

```dart
// Alias с type parameter
typedef Predicate<T> = bool Function(T);
typedef Converter<S, T> = T Function(S);
typedef Factory<T> = T Function();
typedef AsyncValueGetter<T> = Future<T> Function();

// Generic alias для non-function типов
typedef Pair<A, B> = (A, B);           // Record
typedef KeyValue<K, V> = MapEntry<K, V>;
typedef ListOf<T> = List<T>;           // Не очень полезно, но допустимо

void main() {
  Predicate<int> isEven = (n) => n % 2 == 0;
  Converter<String, int> parseInt = int.parse;
  Factory<DateTime> now = DateTime.now;

  print(isEven(4));       // true
  print(parseInt('42'));  // 42
  print(now());           // текущее время
}
```

### Alias и runtime тип

```dart
typedef IntList = List<int>;

void main() {
  IntList numbers = [1, 2, 3];

  // Type alias — ПРОЗРАЧЕН!
  // IntList === List<int> в runtime

  print(numbers is IntList);   // true
  print(numbers is List<int>); // true
  print(numbers.runtimeType);  // List<int>  (НЕ IntList!)

  // Нельзя различить IntList и List<int>
  // Alias — чисто compile-time удобство
}
```

### Alias для Record Types (Dart 3+)

```dart
typedef Position = ({double x, double y});
typedef Named<T> = ({T value, String name});
typedef Result<T> = (T value, String? error);

void main() {
  Position p = (x: 10.5, y: 20.3);
  print('${p.x}, ${p.y}');

  Named<int> item = (value: 42, name: 'ответ');
  print('${item.name}: ${item.value}');

  Result<int> ok = (200, null);
  Result<int> err = (0, 'Not Found');
  print(ok);  // (200, null)
  print(err); // (0, Not Found)
}
```

### Alias для Sealed class / Union-подобных типов

```dart
// Alias может ссылаться на sealed-семейства
sealed class Either<L, R> {}
class Left<L, R> extends Either<L, R> {
  final L value;
  Left(this.value);
}
class Right<L, R> extends Either<L, R> {
  final R value;
  Right(this.value);
}

// Alias для конкретных вариантов
typedef ErrorOrValue<T> = Either<String, T>;
typedef ParseResult = Either<FormatException, int>;

ErrorOrValue<int> parse(String s) {
  final n = int.tryParse(s);
  if (n != null) return Right(n);
  return Left('Невалидное число: $s');
}
```

## 4. Минимальный пример

```dart
typedef JsonMap = Map<String, dynamic>;

JsonMap createUser(String name, int age) {
  return {'name': name, 'age': age};
}

void main() {
  JsonMap user = createUser('Алексей', 30);
  print(user); // {name: Алексей, age: 30}
}
```

## 5. Практический пример

### Типизированный HTTP-клиент с typedef

```dart
typedef JsonMap = Map<String, dynamic>;
typedef Headers = Map<String, String>;
typedef QueryParams = Map<String, String>;
typedef ResponseParser<T> = T Function(JsonMap json);
typedef ErrorHandler = void Function(int statusCode, String message);

/// Конфигурация запроса
class RequestConfig<T> {
  final String path;
  final Headers headers;
  final QueryParams queryParams;
  final ResponseParser<T> parser;
  final ErrorHandler? onError;

  const RequestConfig({
    required this.path,
    required this.parser,
    this.headers = const {},
    this.queryParams = const {},
    this.onError,
  });
}

/// Модель пользователя
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(JsonMap json) => User(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
      );

  @override
  String toString() => 'User($id, $name, $email)';
}

/// API-клиент (упрощённый)
class ApiClient {
  final String baseUrl;
  final Headers _defaultHeaders;

  ApiClient({
    required this.baseUrl,
    Headers defaultHeaders = const {},
  }) : _defaultHeaders = defaultHeaders;

  /// GET-запрос с типизированным парсингом
  Future<T> get<T>(RequestConfig<T> config) async {
    // В реальном коде — HTTP запрос
    final mergedHeaders = {..._defaultHeaders, ...config.headers};

    print('GET $baseUrl${config.path}');
    print('Headers: $mergedHeaders');
    if (config.queryParams.isNotEmpty) {
      print('Query: ${config.queryParams}');
    }

    // Имитация ответа
    final JsonMap fakeResponse = {
      'id': 1,
      'name': 'Алексей',
      'email': 'alex@example.com',
    };

    return config.parser(fakeResponse);
  }
}

typedef UserParser = ResponseParser<User>;
typedef UsersParser = ResponseParser<List<User>>;

void main() async {
  final client = ApiClient(
    baseUrl: 'https://api.example.com',
    defaultHeaders: {
      'Authorization': 'Bearer token123',
      'Accept': 'application/json',
    },
  );

  // UserParser — то же самое, что User Function(JsonMap)
  final UserParser parseUser = User.fromJson;

  // Типизированный запрос
  final user = await client.get<User>(
    RequestConfig(
      path: '/users/1',
      parser: parseUser,
      queryParams: {'fields': 'id,name,email'},
      onError: (code, msg) => print('Ошибка $code: $msg'),
    ),
  );

  print(user); // User(1, Алексей, alex@example.com)
}
```

## 6. Что происходит под капотом

```
typedef JsonMap = Map<String, dynamic>;
JsonMap data = {};

Компиляция:
  1. typedef → ALIAS, не новый тип
  2. JsonMap заменяется на Map<String, dynamic> ВСЮДУ
  3. В runtime: runtimeType → _Map<String, dynamic> (не "JsonMap")

typedef Predicate<T> = bool Function(T);
Predicate<int> p = (n) => n > 0;

Компиляция:
  1. Predicate<int> → bool Function(int)
  2. p — Closure с signature bool Function(int)
  3. p is Predicate<int> → true (= p is bool Function(int))

Ключевое:
  - typedef НЕ создаёт новый тип (nominal type)
  - typedef — структурная подстановка имени
  - UserId = String → UserId и String ОДИНАКОВЫ!
  - Нельзя: void fn(UserId id) {} → защитить от передачи String
```

## 7. Производительность и ресурсы

| Аспект              | Стоимость                          |
| ------------------- | ---------------------------------- |
| typedef объявление  | Zero — compile-time only           |
| Использование alias | Zero — прямая подстановка          |
| Runtime type check  | Нет overhead — alias прозрачен     |
| Памяти              | Не потребляет — нет данных         |
| Вложенные alias     | Раскрываются рекурсивно, zero cost |

**Вывод:** typedef — чисто compile-time конструкция, нулевая стоимость в runtime.

## 8. Частые ошибки и антипаттерны

### ❌ Ожидание nominal typing (type safety)

```dart
typedef UserId = String;
typedef ProductId = String;

// ❌ Ожидание: UserId ≠ ProductId
void getUser(UserId id) => print('User $id');

void main() {
  ProductId productId = 'prod-123';
  getUser(productId); // ✅ Компилируется! UserId = String = ProductId

  // Alias НЕ защищает от передачи "чужого" типа
  // Для nominal typing — используйте extension type:
  // extension type UserId(String value) implements String {}
}
```

### ❌ Использование старого синтаксиса

```dart
// ❌ Устаревший синтаксис
typedef void OldStyle(int x, int y);

// ✅ Новый синтаксис
typedef NewStyle = void Function(int x, int y);
```

### ❌ Избыточные alias

```dart
// ❌ Не добавляет ясности
typedef MyString = String;
typedef MyInt = int;
typedef MyList = List;

// ✅ Осмысленные alias
typedef JsonMap = Map<String, dynamic>;
typedef EventHandler<T> = void Function(T event);
typedef Validator = bool Function(String input);
```

### ❌ Alias для простого типа без семантики

```dart
// ❌ Имя не объясняет, зачем
typedef S = String;
typedef M = Map<String, dynamic>;

// ✅ Имя несёт смысл
typedef ApiResponse = Map<String, dynamic>;
typedef Endpoint = String;
```

## 9. Сравнение с альтернативами

| Подход                       | Новый тип?          | Nominal? | Overhead   | Когда использовать             |
| ---------------------------- | ------------------- | -------- | ---------- | ------------------------------ |
| `typedef X = T`              | ❌ Alias            | ❌       | Zero       | Сокращение длинных типов       |
| `extension type X(T _)`      | ✅ Wrapper          | ✅       | Zero       | Type safety (UserId ≠ String)  |
| `class X { final T value; }` | ✅ Class            | ✅       | Allocation | Полноценная обёртка с методами |
| Inline class (Dart 3)        | ✅ = extension type | ✅       | Zero       | То же, что extension type      |

### typedef vs extension type

```dart
// typedef — alias, не защищает
typedef UserId = String;
String name = 'Alice';
UserId id = name; // ✅ Работает — нет защиты

// extension type — nominal, защищает
extension type const SafeUserId(String value) {
  // UserId и String — разные типы
}

void main() {
  SafeUserId uid = SafeUserId('user-42');
  // String s = uid; // ❌ Compile error!
  String s = uid.value; // ✅ Явное извлечение
}
```

## 10. Когда НЕ стоит использовать

- **Для type safety** — alias не создаёт новый тип; используйте `extension type`.
- **Для тривиальных типов** — `typedef S = String` не помогает.
- **Слишком много alias** — загромождает код; используйте, когда тип реально сложный.
- **Вложенное переименование** — `typedef A = B; typedef B = C;` — путает.

## 11. Краткое резюме

1. **`typedef Name = Type`** — создаёт alias (псевдоним) для любого типа.
2. **Прозрачен в runtime** — alias ≡ оригинальный тип; `runtimeType` показывает оригинал.
3. **Основное применение** — сокращение `Map<String, dynamic>` → `JsonMap`, callback-сигнатуры.
4. **Generic alias** — `typedef Predicate<T> = bool Function(T)` — параметризованные.
5. **Record alias** — `typedef Position = ({double x, double y})` — именованные records.
6. **НЕ nominal** — `UserId` = `String`; для type safety используйте `extension type`.
7. **Старый синтаксис** — `typedef void Fn(int)` → deprecated; используйте `typedef Fn = void Function(int)`.
8. **Zero cost** — compile-time подстановка, никакого runtime overhead.

---

> **Назад:** [8.3 Ковариантность и контравариантность](08_03_variance.md) · **Далее:** [9.0 Обработка ошибок — обзор](../09_error_handling/09_00_overview.md)
