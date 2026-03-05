# 7.7 Статические члены и фабричные конструкторы

## 1. Формальное определение

**Статический член** (`static`) — поле или метод, принадлежащий **классу**, а не экземпляру. Доступ через имя класса: `ClassName.member`. Не имеет доступа к `this`.

**Фабричный конструктор** (`factory`) — конструктор, который не обязан создавать новый экземпляр. Может возвращать кешированный объект, подтип или результат вычислений.

## 2. Зачем это нужно

- **static** — общие утилиты, константы, кеши, фабричные методы без `factory` keyword.
- **factory** — паттерны Singleton, Cache, Flyweight, Abstract Factory.
- **Контроль создания** — ограничить способы создания объектов.
- **Именованные конструкторы + factory** — `Shape.fromJson()`, `Logger('name')`.
- **Скрытие реализации** — factory возвращает абстрактный тип, скрывая конкретный.

## 3. Как это работает

### static поля

```dart
class AppConfig {
  // Статическая константа
  static const String version = '1.0.0';
  static const int maxRetries = 3;

  // Статическое мутабельное поле
  static bool debugMode = false;

  // late static — ленивая инициализация
  static late final DateTime startTime;

  // Приватное статическое
  static final Map<String, String> _cache = {};
}

void main() {
  print(AppConfig.version);   // 1.0.0
  AppConfig.debugMode = true; // Изменение static поля

  // AppConfig().version;     // ❌ Нельзя через экземпляр!
}
```

### static методы

```dart
class MathUtils {
  // Статические методы — утилиты
  static int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
  }

  static double lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  static int clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  // Приватный конструктор — нельзя создать экземпляр
  MathUtils._();
}

void main() {
  print(MathUtils.factorial(5)); // 120
  print(MathUtils.lerp(0, 100, 0.5)); // 50.0
  print(MathUtils.clamp(150, 0, 100)); // 100
}
```

### static vs top-level

```dart
// Top-level функция — предпочтительный Dart-стиль:
int factorial(int n) => n <= 1 ? 1 : n * factorial(n - 1);

// static метод — когда функция концептуально привязана к классу:
class Color {
  final int r, g, b;
  const Color(this.r, this.g, this.b);

  // Утилита, связанная с Color
  static Color mix(Color a, Color b) {
    return Color(
      (a.r + b.r) ~/ 2,
      (a.g + b.g) ~/ 2,
      (a.b + b.b) ~/ 2,
    );
  }

  // Предопределённые значения
  static const red = Color(255, 0, 0);
  static const green = Color(0, 255, 0);
  static const blue = Color(0, 0, 255);
}
```

### factory конструктор — основы

```dart
class Logger {
  final String name;
  static final _instances = <String, Logger>{};

  // Приватный generative конструктор
  Logger._create(this.name) {
    print('Создан Logger: $name');
  }

  // Factory — возвращает существующий или создаёт новый
  factory Logger(String name) {
    return _instances.putIfAbsent(name, () => Logger._create(name));
  }

  void log(String msg) => print('[$name] $msg');
}

void main() {
  var a = Logger('HTTP');  // Создан Logger: HTTP
  var b = Logger('HTTP');  // Ничего — из кеша
  var c = Logger('DB');    // Создан Logger: DB

  print(identical(a, b));  // true — один объект!
  print(identical(a, c));  // false
}
```

### Singleton через factory

```dart
class Database {
  static Database? _instance;

  final String connectionString;

  // Приватный конструктор
  Database._internal(this.connectionString);

  // Factory singleton
  factory Database({String connection = 'localhost:5432'}) {
    return _instance ??= Database._internal(connection);
  }

  // Или через static final:
  // static final Database instance = Database._internal('localhost:5432');

  void query(String sql) => print('[$connectionString] $sql');
}

void main() {
  var db1 = Database(connection: 'prod:5432');
  var db2 = Database(); // Вернёт тот же экземпляр

  print(identical(db1, db2)); // true
  db2.query('SELECT 1');      // [prod:5432] SELECT 1
}
```

### Factory возвращающий подтип

```dart
abstract class Cache<T> {
  T? get(String key);
  void set(String key, T value);

  // Factory выбирает реализацию
  factory Cache({int maxSize = 100}) {
    if (maxSize <= 0) {
      return NoCache<T>();
    }
    return LruCache<T>(maxSize);
  }
}

class LruCache<T> implements Cache<T> {
  final int maxSize;
  final _data = <String, T>{};

  LruCache(this.maxSize);

  @override
  T? get(String key) => _data[key];

  @override
  void set(String key, T value) {
    if (_data.length >= maxSize) {
      _data.remove(_data.keys.first);
    }
    _data[key] = value;
  }
}

class NoCache<T> implements Cache<T> {
  @override
  T? get(String key) => null;

  @override
  void set(String key, T value) {} // Ничего не кешируем
}

void main() {
  Cache<String> cache = Cache(maxSize: 10); // LruCache
  cache.set('key', 'value');
  print(cache.get('key'));       // value
  print(cache.runtimeType);     // LruCache<String>

  Cache<String> noCache = Cache(maxSize: 0); // NoCache
  noCache.set('key', 'value');
  print(noCache.get('key'));     // null
}
```

### factory const redirect

```dart
class Symbol {
  final String name;
  const Symbol._(this.name);

  static const plus = Symbol._('+');
  static const minus = Symbol._('-');

  // factory const redirect — перенаправление на const конструктор
  // (Ограниченный случай: factory → this)
}
```

### Static + factory: Registry pattern

```dart
typedef WidgetBuilder = Widget Function(Map<String, dynamic> props);

abstract class Widget {
  String render();

  // Реестр строителей
  static final _registry = <String, WidgetBuilder>{};

  // Регистрация
  static void register(String type, WidgetBuilder builder) {
    _registry[type] = builder;
  }

  // Factory из реестра
  factory Widget.fromType(String type, Map<String, dynamic> props) {
    var builder = _registry[type];
    if (builder == null) {
      throw ArgumentError('Неизвестный тип виджета: $type');
    }
    return builder(props);
  }
}

class TextWidget implements Widget {
  final String text;
  final int fontSize;

  TextWidget({required this.text, this.fontSize = 14});

  @override
  String render() => '<span style="font-size:${fontSize}px">$text</span>';
}

class ImageWidget implements Widget {
  final String src;
  final String alt;

  ImageWidget({required this.src, this.alt = ''});

  @override
  String render() => '<img src="$src" alt="$alt" />';
}

void main() {
  // Регистрация
  Widget.register('text', (props) => TextWidget(
    text: props['text'] as String,
    fontSize: (props['fontSize'] as int?) ?? 14,
  ));

  Widget.register('image', (props) => ImageWidget(
    src: props['src'] as String,
    alt: (props['alt'] as String?) ?? '',
  ));

  // Создание из конфига (JSON, YAML, etc.)
  var config = [
    {'type': 'text', 'props': {'text': 'Hello', 'fontSize': 24}},
    {'type': 'image', 'props': {'src': 'logo.png', 'alt': 'Logo'}},
  ];

  for (final item in config) {
    var widget = Widget.fromType(
      item['type'] as String,
      item['props'] as Map<String, dynamic>,
    );
    print(widget.render());
  }
}
```

## 4. Минимальный пример

```dart
class Counter {
  static int _globalCount = 0;
  final int id;

  factory Counter() {
    _globalCount++;
    return Counter._(_globalCount);
  }

  Counter._(this.id);

  static int get totalCreated => _globalCount;
}

void main() {
  var a = Counter();
  var b = Counter();
  print('a.id=${a.id}, b.id=${b.id}'); // a.id=1, b.id=2
  print('Всего: ${Counter.totalCreated}'); // Всего: 2
}
```

## 5. Практический пример

### Service Locator

```dart
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;

  ServiceLocator._();

  final _singletons = <Type, Object>{};
  final _factories = <Type, Object Function()>{};

  /// Регистрация singleton
  void registerSingleton<T extends Object>(T instance) {
    _singletons[T] = instance;
  }

  /// Регистрация ленивого singleton
  void registerLazy<T extends Object>(T Function() factory) {
    _factories[T] = factory;
  }

  /// Получение сервиса
  T get<T extends Object>() {
    // Проверяем singleton
    if (_singletons.containsKey(T)) {
      return _singletons[T] as T;
    }

    // Проверяем factory
    if (_factories.containsKey(T)) {
      var instance = _factories[T]!() as T;
      _singletons[T] = instance; // Кешируем
      _factories.remove(T);
      return instance;
    }

    throw StateError('Сервис $T не зарегистрирован');
  }

  /// Сброс (для тестов)
  void reset() {
    _singletons.clear();
    _factories.clear();
  }
}

// Сервисы
class ApiClient {
  final String baseUrl;
  ApiClient(this.baseUrl);

  String fetch(String path) => 'GET $baseUrl$path';
}

class UserRepository {
  final ApiClient _api;
  UserRepository(this._api);

  String getUser(int id) => _api.fetch('/users/$id');
}

class AuthService {
  final ApiClient _api;
  AuthService(this._api);

  String login(String user) => _api.fetch('/login?user=$user');
}

void main() {
  var sl = ServiceLocator.instance;

  // Регистрация
  sl.registerSingleton(ApiClient('https://api.example.com'));
  sl.registerLazy(() => UserRepository(sl.get<ApiClient>()));
  sl.registerLazy(() => AuthService(sl.get<ApiClient>()));

  // Использование
  var userRepo = sl.get<UserRepository>();
  print(userRepo.getUser(1)); // GET https://api.example.com/users/1

  var auth = sl.get<AuthService>();
  print(auth.login('alice'));  // GET https://api.example.com/login?user=alice

  // Тот же UserRepository (singleton)
  var same = sl.get<UserRepository>();
  print(identical(userRepo, same)); // true
}
```

## 6. Что происходит под капотом

### static поля

```
class Config {
  static int x = 42;
}

static поля хранятся НЕ в объекте, а в Class object:

Heap:
  Class "Config":
    ┌──────────────────┐
    │ vtable: [...]     │
    │ static_x: 42      │  ← Одно место для всех
    └──────────────────┘

  Instance of Config:         Instance of Config:
    ┌──────────────────┐    ┌──────────────────┐
    │ _classId: Config  │    │ _classId: Config  │
    │ (instance fields) │    │ (instance fields) │
    └──────────────────┘    └──────────────────┘
                             Нет static полей тут!
```

### factory — нет this

```
// Generative:
Config(this.host) {
  // this → свежеаллоцированный объект
}

// Factory:
factory Config(String host) {
  // this → НЕДОСТУПЕН! Нет аллокации ещё
  return Config._internal(host); // Возвращает что угодно
}

factory — это обычная static-like функция
с синтаксическим сахаром (вызывается через Config(...))
```

### Lazy static

```
static late final x = heavyComputation();

Dart генерирует:
  static _x_initialized = false;
  static _x_value;

  static get x {
    if (!_x_initialized) {
      _x_value = heavyComputation();
      _x_initialized = true;
    }
    return _x_value;
  }

Потокобезопасно в Dart (single-threaded per isolate).
```

## 7. Производительность и ресурсы

| Аспект                 | Стоимость                 |
| ---------------------- | ------------------------- |
| static const           | Zero cost (compile-time)  |
| static final           | Одна аллокация, потом кеш |
| static метод           | Прямой вызов (без vtable) |
| factory (simple)       | = static метод + return   |
| factory (singleton)    | Один null-check           |
| factory (cache lookup) | HashMap lookup            |

**Рекомендации:**

- `static const` для констант — best performance.
- `static final` для runtime-инициализированных значений.
- factory singleton через `??=` — один null-check.
- Не делайте каждый класс singleton — усложняет тестирование.

## 8. Частые ошибки и антипаттерны

### ❌ Класс-утилита вместо top-level функций

```dart
// ❌ Java-стиль: class с только static
class StringUtils {
  StringUtils._();
  static String capitalize(String s) => ...;
  static bool isBlank(String s) => ...;
}
StringUtils.capitalize('hello');

// ✅ Dart-стиль: top-level функции или extensions
String capitalize(String s) => ...;

extension on String {
  String capitalize() => ...;
}
'hello'.capitalize();
```

### ❌ Singleton везде

```dart
// ❌ Singleton усложняет тестирование
class ApiClient {
  static final instance = ApiClient._();
  ApiClient._();
}

// ✅ Dependency injection — легко подменить в тестах
class ApiClient {
  final String baseUrl;
  ApiClient(this.baseUrl);
}
```

### ❌ Мутабельные static поля

```dart
class Config {
  static String apiKey = ''; // ❌ Глобальное мутабельное состояние!
}

// В любом месте кода:
Config.apiKey = 'hacked'; // Изменено для всех!

// ✅ Используйте static final или const:
class Config {
  static const apiKey = String.fromEnvironment('API_KEY');
}
```

### ❌ factory без причины

```dart
// ❌ factory, когда достаточно generative
class Point {
  final double x, y;
  factory Point(double x, double y) {
    return Point._(x, y); // Зачем factory?
  }
  Point._(this.x, this.y);
}

// ✅ Просто generative:
class Point {
  final double x, y;
  const Point(this.x, this.y);
}
```

## 9. Сравнение с альтернативами

| Аспект                | Dart static          | Java static       | Kotlin companion        | TypeScript static  |
| --------------------- | -------------------- | ----------------- | ----------------------- | ------------------ |
| Поля                  | `static int x`       | `static int x`    | `companion { val x }`   | `static x: number` |
| Методы                | `static void f()`    | `static void f()` | `companion { fun f() }` | `static f()`       |
| Factory               | `factory` keyword    | Static method     | `companion invoke`      | Static method      |
| Top-level alternative | ✅ (предпочтительно) | ❌                | ✅                      | ✅ (module-level)  |
| Наследование static   | ❌                   | ❌                | ❌                      | ❌                 |

## 10. Когда НЕ стоит использовать

- **static для всего** — если метод работает с экземпляром → instance метод.
- **Singleton для stateless** — если нет состояния → top-level функция.
- **Мутабельные static** — глобальное мутабельное состояние = источник багов.
- **factory без возврата кеша/подтипа** — если factory просто `return ClassName._(...)`, замените на generative.
- **Класс только со static** — Dart-стиль: top-level функции + extensions.

## 11. Краткое резюме

1. **`static`** — принадлежит классу, не экземпляру; нет доступа к `this`.
2. **`static const`** — compile-time константа; zero cost.
3. **`static final`** — runtime-инициализация, одна аллокация.
4. **`factory`** — конструктор без обязательного создания нового объекта.
5. **Singleton** — `factory` + `static _instance` + `??=`.
6. **Registry** — `static Map` + `factory` → конструирование по ключу.
7. **Предпочитайте top-level** — Dart-идиома: функции и переменные вне классов.

---

> **Назад:** [7.6 Mixins и extension methods](07_06_mixins_extensions.md) · **Далее:** [8.0 Обобщения — обзор](../08_generics/08_00_overview.md)
