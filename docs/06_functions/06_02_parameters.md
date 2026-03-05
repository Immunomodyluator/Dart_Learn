# 6.2 Параметры: позиционные, именованные, опциональные

## 1. Формальное определение

Dart разделяет параметры функций на четыре категории:

- **Обязательные позиционные** — `void f(int a, int b)` — передаются по порядку, обязательны.
- **Опциональные позиционные** — `void f([int a = 0])` — в `[]`, имеют значение по умолчанию или nullable.
- **Именованные** — `void f({int a = 0})` — в `{}`, передаются по имени: `f(a: 5)`.
- **Обязательные именованные** — `void f({required int a})` — именованные, но обязательные (Dart 2.12+).

Позиционные и именованные нельзя смешивать в одной группе — сначала позиционные, потом `[]` или `{}`.

## 2. Зачем это нужно

- **Читаемость** — именованные параметры самодокументируются: `createUser(name: 'Алиса', age: 30)`.
- **Гибкость** — опциональные параметры с defaults позволяют не передавать то, что не нужно.
- **Flutter** — виджеты используют именованные параметры повсеместно: `Text('Hello', style: ..., textAlign: ...)`.
- **required** — гарантирует передачу важных именованных параметров на этапе компиляции.
- **API backwards-compatibility** — добавление опциональных параметров не ломает существующий код.

## 3. Как это работает

### Обязательные позиционные

```dart
// Все параметры обязательны, порядок важен
int add(int a, int b) => a + b;

String fullName(String first, String last) => '$first $last';

void main() {
  print(add(3, 4));                    // 7
  print(fullName('Иван', 'Петров'));   // Иван Петров
  // add(3);        // Ошибка компиляции: не хватает аргумента
  // add(3, 4, 5);  // Ошибка: лишний аргумент
}
```

### Опциональные позиционные `[...]`

```dart
// В квадратных скобках, с значением по умолчанию
String greet(String name, [String greeting = 'Привет']) {
  return '$greeting, $name!';
}

// Nullable без default
String describe(String item, [String? detail]) {
  if (detail != null) {
    return '$item ($detail)';
  }
  return item;
}

void main() {
  print(greet('Алиса'));                // Привет, Алиса!
  print(greet('Алиса', 'Здравствуй')); // Здравствуй, Алиса!
  print(describe('Dart'));              // Dart
  print(describe('Dart', 'язык'));      // Dart (язык)
}
```

### Именованные параметры `{...}`

```dart
// В фигурных скобках, передаются по имени
void createUser({
  String name = 'Аноним',
  int age = 0,
  String? email,
}) {
  print('$name, $age лет, email: ${email ?? "не указан"}');
}

void main() {
  createUser();                              // Аноним, 0 лет
  createUser(name: 'Борис', age: 25);        // Борис, 25 лет
  createUser(age: 30, name: 'Вера');          // Порядок не важен!
  createUser(email: 'a@b.com', name: 'Г.');   // Любые можно пропустить
}
```

### required именованные параметры

```dart
// required — компилятор заставит передать
class HttpRequest {
  final String url;
  final String method;
  final Map<String, String>? headers;
  final String? body;

  HttpRequest({
    required this.url,       // Обязательный
    required this.method,    // Обязательный
    this.headers,            // Опциональный
    this.body,               // Опциональный
  });
}

void main() {
  var req = HttpRequest(
    url: 'https://api.example.com/users',
    method: 'GET',
    // headers и body — опциональны
  );

  // HttpRequest(); // Ошибка: url и method required!
}
```

### Комбинирование

```dart
// Обязательные позиционные + именованные
void log(String message, {String level = 'INFO', DateTime? timestamp}) {
  var ts = timestamp ?? DateTime.now();
  print('[$level] $ts: $message');
}

// Обязательные позиционные + опциональные позиционные
double power(double base, [double exponent = 2]) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

void main() {
  log('Запуск', level: 'DEBUG');
  print(power(3));      // 9.0 (3^2)
  print(power(2, 10));  // 1024.0 (2^10)
}

// НЕЛЬЗЯ: [] и {} одновременно
// void bad(int a, [int b], {int c}); // Ошибка!
```

### Значения по умолчанию — только const

```dart
// Default — compile-time const
void example({
  int count = 0,
  String label = 'default',
  List<int> items = const [],      // const!
  Map<String, int> map = const {}, // const!
}) {
  print('$count, $label, $items, $map');
}

// Для non-const defaults — используйте nullable + ??
void flexible({List<int>? items}) {
  var list = items ?? []; // Новый mutable список каждый раз
  list.add(1);
  print(list);
}
```

## 4. Минимальный пример

```dart
// Все четыре вида в действии
void demo(
  int required1,                          // обязательный позиционный
  String required2, {                     // обязательный позиционный
  required bool mustHave,                 // required именованный
  String optional = 'default',            // опциональный именованный
}) {
  print('$required1, $required2, $mustHave, $optional');
}

void main() {
  demo(42, 'hello', mustHave: true);
  demo(1, 'world', mustHave: false, optional: 'custom');
}
```

## 5. Практический пример

### Конфигуратор HTTP-клиента (Flutter-стиль API)

```dart
class ApiClient {
  final String baseUrl;
  final Duration timeout;
  final Map<String, String> defaultHeaders;
  final bool logging;

  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.defaultHeaders = const {'Accept': 'application/json'},
    this.logging = false,
  });

  Future<String> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    Duration? customTimeout,
  }) async {
    var effectiveTimeout = customTimeout ?? timeout;
    var effectiveHeaders = {...defaultHeaders, ...?headers};

    var url = '$baseUrl$path';
    if (queryParams != null && queryParams.isNotEmpty) {
      var query = queryParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      url = '$url?$query';
    }

    if (logging) {
      print('GET $url');
      print('Headers: $effectiveHeaders');
      print('Timeout: $effectiveTimeout');
    }

    // Имитация запроса
    return '{"status": "ok"}';
  }
}

void main() async {
  var client = ApiClient(
    baseUrl: 'https://api.example.com',
    logging: true,
  );

  // Минимальный вызов
  await client.get('/users');

  // С дополнительными параметрами
  await client.get(
    '/users',
    queryParams: {'page': '1', 'limit': '10'},
    headers: {'Authorization': 'Bearer token'},
  );
}
```

## 6. Что происходит под капотом

### Передача аргументов

```
Dart: все аргументы передаются по значению (by value).
Но "значение" для объектов — это ссылка!

f(int x) — копирует значение int
f(List<int> list) — копирует ссылку (не список!)

Dart VM:
  Call f:
    Push arg0 (value/reference)
    Push arg1
    ...
    CallFunction f, argCount=N
```

### Именованные параметры — desugaring

```dart
void f({int a = 0, int b = 0}) { ... }
f(b: 5, a: 3);

// Компилятор сортирует по порядку объявления:
// → f(a: 3, b: 5) → f._invoke(3, 5)
// Именованные параметры — синтаксический сахар на уровне компилятора
```

### Default values — canonical const

```dart
void f({List<int> items = const []}) {}

// const [] — canonical singleton в heap
// Каждый вызов f() без items получает ТОТ ЖЕ объект
// f() → items = const []
// f() → items = const [] (identical!)
```

## 7. Производительность и ресурсы

| Аспект                  | Стоимость                             |
| ----------------------- | ------------------------------------- |
| Позиционные аргументы   | Прямой push в stack — минимальная     |
| Именованные аргументы   | +сортировка при компиляции, 0 runtime |
| Default values          | 0 — подставляются при компиляции      |
| `const []` default      | Singleton — 0 аллокаций               |
| Nullable default + `??` | 1 null-check + условная аллокация     |

Нет runtime-стоимости у именованных параметров — всё разрешается при компиляции.

## 8. Частые ошибки и антипаттерны

### ❌ Мутабельный default

```dart
// ОШИБКА КОМПИЛЯЦИИ: default должен быть const
// void f({List<int> items = []}) {} // Error!

// Правильно:
void f({List<int> items = const []}) {} // Но items immutable!

// Если нужен мутабельный:
void f({List<int>? items}) {
  var list = items ?? [];
  list.add(1); // OK — новый список
}
```

### ❌ Слишком много позиционных параметров

```dart
// Плохо: что значит каждый аргумент?
createUser('Алиса', 30, true, false, 'admin', 5);

// Хорошо: именованные параметры
createUser(
  name: 'Алиса',
  age: 30,
  isActive: true,
  isVerified: false,
  role: 'admin',
  level: 5,
);
```

### ❌ Забыть required для nullable именованного

```dart
// Хочу, чтобы null был допустимым значением, но параметр обязателен:
void process({required String? name}) {
  // name может быть null, но ДОЛЖЕН быть явно передан
}

process(name: null);  // OK
process(name: 'Алиса'); // OK
// process(); // Ошибка: name required!
```

### ❌ bool-параметры без имени

```dart
// Плохо:
void setVisibility(bool visible, bool animated);
setVisibility(true, false); // Что true? Что false?

// Хорошо:
void setVisibility({required bool visible, bool animated = true});
setVisibility(visible: true, animated: false); // Понятно!
```

## 9. Сравнение с альтернативами

| Аспект              | Dart          | Java      | JavaScript         | Python              | Kotlin              |
| ------------------- | ------------- | --------- | ------------------ | ------------------- | ------------------- |
| Именованные         | `{name: v}`   | ❌        | ❌ (destructuring) | `name=v`            | `name = v`          |
| Required named      | `required`    | ❌        | ❌                 | ❌ (все named opti) | ❌ (все named opti) |
| Default values      | ✅            | Overloads | ✅                 | ✅                  | ✅                  |
| Optional positional | `[param]`     | Overloads | Spread             | `*args`             | `vararg`            |
| Named + positional  | ✅ (не mix)   | ❌        | ❌                 | ✅                  | ✅                  |
| Const default       | ✅ (required) | N/A       | Eval at call       | Eval at call        | Eval at call        |

Dart уникален разделением на `[]` (опциональные позиционные) и `{}` (именованные) + `required`.

## 10. Когда НЕ стоит использовать

- **Именованные для 1-2 очевидных параметров** — `add(a: 3, b: 4)` хуже, чем `add(3, 4)`.
- **Позиционные для > 3 параметров** — теряется читаемость. Переходите на именованные.
- **`required` для всех** — если у параметра есть разумный default, не делайте его required.
- **Default const коллекции, если нужен mutable** — используйте `?` + `??` паттерн.

## 11. Краткое резюме

1. **Четыре вида**: обязательные позиционные, опциональные `[...]`, именованные `{...}`, required именованные.
2. **`[]` и `{}` нельзя смешивать** в одной функции.
3. **Default values — только const** — `const []`, `const {}`, литералы.
4. **`required`** (Dart 2.12+) — делает именованный параметр обязательным.
5. **Именованные для > 2 параметров** — самодокументирующийся код.
6. **Bool-параметры** — всегда именованные для читаемости.
7. **Мутабельный default** — `List<int>? items` + `items ?? []`.

---

> **Назад:** [6.1 Синтаксис функций](06_01_syntax.md) · **Далее:** [6.3 Замыкания](06_03_closures.md)
