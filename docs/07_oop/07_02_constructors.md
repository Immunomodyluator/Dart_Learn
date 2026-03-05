# 7.2 Конструкторы и именованные конструкторы

## 1. Формальное определение

**Конструктор** — специальный метод, вызываемый при создании экземпляра класса. Отвечает за инициализацию полей объекта.

Dart поддерживает несколько видов конструкторов:

- **Generative** (порождающий) — создаёт новый экземпляр.
- **Named** (именованный) — дополнительные конструкторы с именами.
- **Redirecting** (перенаправляющий) — делегирует другому конструктору.
- **Const** — создаёт compile-time константный объект.
- **Factory** — контролирует создание или возвращает существующий экземпляр.

## 2. Зачем это нужно

- **Гарантия инициализации** — нельзя создать объект с неинициализированными non-nullable полями.
- **Множественные способы создания** — `Color(r, g, b)`, `Color.fromHex('#FF0000')`, `Color.white()`.
- **Неизменяемость** — `const` конструкторы для canonical instances.
- **Контроль создания** — `factory` для паттернов singleton, cache, subtype return.
- **Валидация** — `assert` и initializer list проверяют данные до создания объекта.

## 3. Как это работает

### Generative конструктор (по умолчанию)

```dart
class Point {
  double x;
  double y;

  // Полная форма
  Point(double x, double y)
      : this.x = x,
        this.y = y;
}

// Сокращённая форма — initializing formals
class Point2 {
  double x;
  double y;

  Point2(this.x, this.y); // Автоматическое присвоение
}
```

### Конструктор по умолчанию (без объявления)

```dart
class Empty {
  // Если нет конструктора, Dart создаёт:
  // Empty();
}

void main() {
  var e = Empty(); // Работает!
}
```

### Именованные конструкторы

```dart
class Color {
  final int r, g, b;

  // Главный конструктор
  Color(this.r, this.g, this.b);

  // Именованные конструкторы
  Color.red() : r = 255, g = 0, b = 0;
  Color.green() : r = 0, g = 255, b = 0;
  Color.blue() : r = 0, g = 0, b = 255;

  Color.grey(int value) : r = value, g = value, b = value;

  Color.fromHex(String hex)
      : r = int.parse(hex.substring(1, 3), radix: 16),
        g = int.parse(hex.substring(3, 5), radix: 16),
        b = int.parse(hex.substring(5, 7), radix: 16);

  @override
  String toString() => 'Color($r, $g, $b)';
}

void main() {
  print(Color.red());          // Color(255, 0, 0)
  print(Color.grey(128));      // Color(128, 128, 128)
  print(Color.fromHex('#FF8000')); // Color(255, 128, 0)
}
```

### Initializer list

```dart
class Rectangle {
  final double width;
  final double height;
  final double area; // Вычисляется по другим полям

  Rectangle(this.width, this.height)
      : assert(width > 0, 'width must be positive'),   // Проверка
        assert(height > 0, 'height must be positive'),
        area = width * height;                          // Вычисление

  // Порядок в initializer list:
  // 1) assert'ы
  // 2) присвоения полей
  // Код в теле {} выполняется ПОСЛЕ initializer list
}
```

### Именованные параметры в конструкторе

```dart
class Config {
  final String host;
  final int port;
  final bool useSSL;
  final Duration timeout;

  Config({
    required this.host,
    this.port = 8080,
    this.useSSL = false,
    this.timeout = const Duration(seconds: 30),
  });
}

void main() {
  var cfg = Config(
    host: 'example.com',
    useSSL: true,
    // port и timeout — значения по умолчанию
  );
}
```

### Redirecting конструктор

```dart
class Point {
  final double x;
  final double y;

  Point(this.x, this.y);

  // Перенаправляет на основной
  Point.origin() : this(0, 0);
  Point.onXAxis(double x) : this(x, 0);
  Point.onYAxis(double y) : this(0, y);
}
```

### Const конструктор

```dart
class ImmutablePoint {
  final double x;
  final double y;

  // Все поля — final, конструктор — const
  const ImmutablePoint(this.x, this.y);

  // Именованный const
  const ImmutablePoint.origin() : x = 0, y = 0;
}

void main() {
  // const контекст → одинаковые значения = один объект
  const a = ImmutablePoint(1, 2);
  const b = ImmutablePoint(1, 2);
  print(identical(a, b)); // true — один объект в памяти!

  // Без const — разные объекты
  var c = ImmutablePoint(1, 2);
  var d = ImmutablePoint(1, 2);
  print(identical(c, d)); // false
}
```

### Factory конструктор

```dart
class Logger {
  static final Map<String, Logger> _cache = {};
  final String name;

  // Приватный generative конструктор
  Logger._internal(this.name);

  // Factory — может возвращать существующий экземпляр
  factory Logger(String name) {
    return _cache.putIfAbsent(name, () => Logger._internal(name));
  }

  void log(String msg) => print('[$name] $msg');
}

void main() {
  var a = Logger('HTTP');
  var b = Logger('HTTP');
  print(identical(a, b)); // true — один объект из кеша!

  var c = Logger('DB');
  print(identical(a, c)); // false — другой ключ
}
```

### Factory возвращающий подтип

```dart
abstract class Shape {
  double get area;

  // Factory выбирает подтип по данным
  factory Shape.fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'circle' => Circle(json['radius'] as double),
      'rect' => Rect(json['w'] as double, json['h'] as double),
      _ => throw ArgumentError('Unknown shape: ${json['type']}'),
    };
  }
}

class Circle implements Shape {
  final double radius;
  Circle(this.radius);

  @override
  double get area => 3.14159 * radius * radius;
}

class Rect implements Shape {
  final double w, h;
  Rect(this.w, this.h);

  @override
  double get area => w * h;
}

void main() {
  var shapes = [
    Shape.fromJson({'type': 'circle', 'radius': 5.0}),
    Shape.fromJson({'type': 'rect', 'w': 3.0, 'h': 4.0}),
  ];

  for (final s in shapes) {
    print('${s.runtimeType}: area = ${s.area}');
  }
}
```

### super параметры (Dart 3)

```dart
class Animal {
  final String name;
  final int age;

  Animal({required this.name, required this.age});
}

// До Dart 3:
class Dog1 extends Animal {
  final String breed;
  Dog1({required super.name, required super.age, required this.breed});
  // ↑ super.name пробрасывает в Animal(name: name)
}

// Эквивалент старого синтаксиса:
class Dog2 extends Animal {
  final String breed;
  Dog2({required String name, required int age, required this.breed})
      : super(name: name, age: age);
}
```

## 4. Минимальный пример

```dart
class Temperature {
  final double celsius;

  Temperature(this.celsius);
  Temperature.fromFahrenheit(double f) : celsius = (f - 32) * 5 / 9;
  Temperature.freezing() : celsius = 0;

  double get fahrenheit => celsius * 9 / 5 + 32;

  @override
  String toString() => '${celsius.toStringAsFixed(1)}°C';
}

void main() {
  print(Temperature(100));                  // 100.0°C
  print(Temperature.fromFahrenheit(212));   // 100.0°C
  print(Temperature.freezing());            // 0.0°C
}
```

## 5. Практический пример

### HTTP Response builder

```dart
class HttpResponse {
  final int statusCode;
  final String reasonPhrase;
  final Map<String, String> headers;
  final String body;

  // Приватный generative — всё через named/factory
  const HttpResponse._({
    required this.statusCode,
    required this.reasonPhrase,
    this.headers = const {},
    this.body = '',
  });

  // Именованные конструкторы для типовых ответов
  const HttpResponse.ok({String body = '', Map<String, String> headers = const {}})
      : this._(statusCode: 200, reasonPhrase: 'OK', headers: headers, body: body);

  const HttpResponse.notFound({String body = 'Not Found'})
      : this._(statusCode: 404, reasonPhrase: 'Not Found', body: body);

  const HttpResponse.serverError({String body = 'Internal Server Error'})
      : this._(statusCode: 500, reasonPhrase: 'Internal Server Error', body: body);

  HttpResponse.redirect(String location)
      : this._(
          statusCode: 302,
          reasonPhrase: 'Found',
          headers: {'Location': location},
        );

  HttpResponse.json(Object data, {int statusCode = 200})
      : this._(
          statusCode: statusCode,
          reasonPhrase: 'OK',
          headers: {'Content-Type': 'application/json'},
          body: data.toString(), // В реальности: jsonEncode(data)
        );

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isRedirect => statusCode >= 300 && statusCode < 400;
  bool get isError => statusCode >= 400;

  @override
  String toString() => 'HTTP $statusCode $reasonPhrase\n'
      '${headers.entries.map((e) => '${e.key}: ${e.value}').join('\n')}'
      '${body.isNotEmpty ? '\n\n$body' : ''}';
}

void main() {
  var ok = HttpResponse.ok(body: '{"status":"ok"}');
  var redir = HttpResponse.redirect('https://example.com');
  var err = HttpResponse.notFound();

  print(ok.isSuccess);    // true
  print(redir.isRedirect); // true
  print(err.isError);      // true

  print(ok);
}
```

## 6. Что происходит под капотом

### Порядок выполнения

```
var obj = MyClass(args);

1. Аллокация памяти в heap (все поля = null/default)
2. Initializer list (слева направо):
   - assert'ы
   - field = expression
   - super(...)   ← ОБЯЗАТЕЛЬНО последний в init list
3. Тело конструктора super-класса
4. Тело конструктора текущего класса

Для const конструктора:
- Шаги 1-4 выполняются compile-time
- Результат кешируется (canonicalization)
```

### const canonicalization

```
const a = Point(1, 2);
const b = Point(1, 2);

Компилятор:
1. Вычисляет const Point(1, 2) → объект в read-only памяти
2. Обе переменные указывают на ОДИН объект
3. identical(a, b) → true

Экономия: один объект вместо N копий
```

### Factory vs generative

```
Generative:
  1. ВСЕГДА создаёт новый экземпляр
  2. Имеет доступ к this и initializer list
  3. Может быть const

Factory:
  1. Может вернуть СУЩЕСТВУЮЩИЙ экземпляр
  2. НЕ имеет доступа к this
  3. Может вернуть подтип
  4. НЕ может быть const (кроме factory const redirect)
```

## 7. Производительность и ресурсы

| Конструктор | Стоимость                               |
| ----------- | --------------------------------------- |
| Generative  | Аллокация + init полей                  |
| Named       | То же что generative                    |
| Redirecting | Один extra call (inlined)               |
| Const       | Zero runtime cost (compile-time)        |
| Factory     | Аллокация + логика (или lookup из кеша) |

**Рекомендации:**

- `const` когда все поля `final` и значения известны compile-time.
- `factory` для кеширования/singleton — не для каждого класса.
- Initializer list → предпочтительнее тела конструктора для `final` полей.

## 8. Частые ошибки и антипаттерны

### ❌ Забытый super() в подклассе

```dart
class Base {
  final String name;
  Base(this.name); // Нет default конструктора!
}

class Child extends Base {
  // ❌ Ошибка: Base не имеет конструктора без аргументов
  // Child();

  // ✅ Нужно вызвать super:
  Child(String name) : super(name);
}
```

### ❌ Присвоение final в теле конструктора

```dart
class Bad {
  final int x;

  Bad(int x) {
    this.x = x; // ❌ final нельзя присвоить в теле!
  }
}

class Good {
  final int x;
  Good(this.x); // ✅ Сокращённая форма

  // Или через initializer list:
  // Good(int x) : this.x = x;
}
```

### ❌ Тяжёлая логика в конструкторе

```dart
class Bad {
  Bad() {
    // ❌ HTTP запрос, чтение файла, тяжёлые вычисления
    // Конструктор должен быть быстрым и предсказуемым
  }
}

class Good {
  Good();

  // Тяжёлые операции — в отдельном async методе
  static Future<Good> create() async {
    var instance = Good();
    await instance._init();
    return instance;
  }

  Future<void> _init() async {
    // Асинхронная инициализация
  }
}
```

### ❌ const конструктор с мутабельным полем

```dart
class Bad {
  int x; // Мутабельное!
  const Bad(this.x); // ❌ Ошибка: const класс не может иметь non-final поля
}

class Good {
  final int x; // Все поля final
  const Good(this.x); // ✅
}
```

## 9. Сравнение с альтернативами

| Возможность          | Dart                     | Java                | Kotlin             | TypeScript               |
| -------------------- | ------------------------ | ------------------- | ------------------ | ------------------------ |
| Named конструкторы   | ✅ `Class.name()`        | ❌ (static factory) | ❌ (companion)     | ❌                       |
| Initializing formals | ✅ `this.x`              | ❌                  | ❌                 | ✅ (TS param properties) |
| Initializer list     | ✅ `: x = ...`           | ❌                  | ❌                 | ❌                       |
| const конструктор    | ✅                       | ❌                  | ❌                 | ❌                       |
| Factory              | ✅ `factory` keyword     | Manual static       | Companion `invoke` | Manual static            |
| super parameters     | ✅ `super.name` (Dart 3) | ❌                  | ❌                 | ❌                       |
| Default конструктор  | Автогенерируется         | Автогенерируется    | Автогенерируется   | Автогенерируется         |

## 10. Когда НЕ стоит использовать

- **const конструктор + мутабельные поля** — невозможно; все поля должны быть `final`.
- **Factory для каждого класса** — используйте только когда нужен контроль создания.
- **Много именованных конструкторов** — если >5, возможно, стоит разбить на подклассы или использовать Builder.
- **Асинхронная логика в конструкторе** — конструктор не может быть `async`; используйте `static Future<T> create()`.

## 11. Краткое резюме

1. **Generative** — стандартный конструктор, создаёт новый экземпляр.
2. **Named** — `Class.name()` для альтернативных способов создания.
3. **Initializer list** — `: field = expr, assert(...)` до тела конструктора.
4. **Initializing formals** — `this.x` и `super.x` сокращают boilerplate.
5. **Const** — compile-time создание; одинаковые аргументы → один объект.
6. **Factory** — может вернуть кеш или подтип; нет доступа к `this`.
7. **Redirecting** — `Class.name() : this(...)` делегирует другому конструктору.

---

> **Назад:** [7.1 Классы и объекты](07_01_classes_objects.md) · **Далее:** [7.3 Геттеры и сеттеры](07_03_getters_setters.md)
