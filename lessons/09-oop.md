# Урок 9. Объектно-ориентированное программирование

> Охватывает подтемы: 9.1 Классы и конструкторы, 9.2 Геттеры и сеттеры, 9.3 Наследование, 9.4 Абстрактные классы и интерфейсы, 9.5 Mixins, 9.6 Extensions, 9.7 Extension types (Dart 3.3+), 9.8 Factory и static, 9.9 Sealed classes (Dart 3), 9.10 Class modifiers (Dart 3), 9.11 Аннотации и метаданные

---

## 1. Формальное определение

Dart — **чисто объектный язык**: всё является объектом, включая `null`, функции и числа. Объектная система включает:

- **Классы** с полями, конструкторами, методами
- **Единственное прямое наследование** + **множественные миксины**
- **Интерфейсы** — каждый класс неявно задаёт интерфейс
- **Модификаторы классов** (Dart 3): `abstract`, `base`, `final`, `interface`, `sealed`, `mixin class`
- **Extension types** (Dart 3.3): zero-cost обёртки над существующими типами

Уровень: **система типов, архитектура**.

---

## 2. Зачем это нужно

- **Классы** структурируют данные и поведение в единую абстракцию
- **Mixins** — горизонтальное переиспользование кода без иерархии
- **Extensions** — добавление методов к существующим типам без наследования
- **Sealed + exhaustiveness** — безопасная моделировать алгебраических типов данных
- **Class modifiers** — контролировать как класс может использоваться в других библиотеках

---

## 3. Классы и конструкторы (9.1)

```dart
class Point {
  // Поля — без ключевого слова var если final
  final double x;
  final double y;

  // Обычный positional конструктор
  Point(this.x, this.y);

  // Named constructor
  Point.origin() : this(0, 0);         // redirecting
  Point.fromList(List<double> l) : x = l[0], y = l[1]; // initializer list

  // Const конструктор — объект может быть compile-time константой
  const Point.fixed(this.x, this.y);

  // Операторы
  Point operator +(Point other) => Point(x + other.x, y + other.y);

  // toString, ==, hashCode
  @override
  String toString() => 'Point($x, $y)';

  @override
  bool operator ==(Object other) => other is Point && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

class MutablePoint {
  double x, y;
  MutablePoint(this.x, this.y);

  // Named params с required и default
  MutablePoint.named({required this.x, required this.y});
  
  // Параметры с дефолтными значениями
  MutablePoint.withDefaults({this.x = 0.0, this.y = 0.0});
}

// Cascades (..) — цепочка мутаций
class Builder {
  String name = '';
  int value = 0;
  
  Builder setName(String n) { name = n; return this; }
  Builder setValue(int v) { value = v; return this; }
}

void main() {
  // Cascade
  final b = Builder()
    ..name = 'example'
    ..value = 42;

  const p1 = Point.fixed(1, 2);  // compile-time constant
  final p2 = Point(3, 4);
  print(p1 + p2); // Point(4.0, 6.0)
  
  final mp = MutablePoint.withDefaults(x: 5.0);
}
```

**Late fields** — поле инициализируется лениво, но гарантированно до первого чтения:

```dart
class Calculator {
  late final double _result; // инициализируется один раз

  void compute(double input) {
    _result = input * 2; // попытка присвоить дважды → RuntimeError
  }

  double get result => _result; // LateInitializationError если не инициализировано
}
```

---

## 4. Геттеры и сеттеры (9.2)

```dart
class Temperature {
  double _celsius; // backing field

  Temperature(this._celsius);

  // Геттер
  double get fahrenheit => _celsius * 9 / 5 + 32;

  // Сеттер с валидацией
  set celsius(double value) {
    if (value < -273.15) throw ArgumentError('Below absolute zero: $value');
    _celsius = value;
  }

  double get celsius => _celsius;

  // Computed property без backing field
  bool get isFreezing => _celsius <= 0;
}

// Short-hand для read-only полей — просто final:
class ImmutableRect {
  final double width, height;
  const ImmutableRect(this.width, this.height);
  double get area => width * height;      // Геттер без backing field
  double get perimeter => 2 * (width + height);
}
```

---

## 5. Наследование (9.3)

```dart
class Animal {
  final String name;
  Animal(this.name);

  void speak() => print('...');     // может быть переопределён
  String describe() => 'Animal: $name';
}

class Dog extends Animal {
  final String breed;
  
  Dog(super.name, this.breed); // super() параметр — Dart 2.17+
  
  @override
  void speak() => print('Woof!');

  @override
  String describe() => '${super.describe()}, breed: $breed';
}

// @override не обязателен, но обязательно рекомендован lint'ером
// Dart НЕ разрешает множественное наследование (только один extends)
```

**Constructors не наследуются** — нужно явно определить или вызвать через `super`:

```dart
class NamedDog extends Dog {
  final String nickName;
  
  NamedDog(String name, String breed, this.nickName)
      : super(name, breed);
}
```

---

## 6. Абстрактные классы и интерфейсы (9.4)

```dart
// abstract class — нельзя инстанциировать, можно иметь тело методов
abstract class Shape {
  double get area;
  double get perimeter;
  void draw() => print('Drawing ${runtimeType}'); // default implementation
}

// interface (Dart 3) — только интерфейс, нельзя extends, только implements
interface class Repository<T> {
  Future<T?> findById(String id) => throw UnimplementedError();
  Future<void> save(T entity) => throw UnimplementedError();
  Future<List<T>> findAll() => throw UnimplementedError();
}

class Circle extends Shape {
  final double radius;
  Circle(this.radius);

  @override double get area => 3.14159 * radius * radius;
  @override double get perimeter => 2 * 3.14159 * radius;
}

// Класс неявно задаёт интерфейс — implements можно применить к любому классу
class Counter {
  int _count = 0;
  void increment() => _count++;
  int get count => _count;
}

// Использование Counter как интерфейса — нужно реализовать ВСЕ его члены
class LoggingCounter implements Counter {
  final Counter _delegate;
  LoggingCounter(this._delegate);
  
  @override
  void increment() {
    print('increment called');
    _delegate.increment();
  }
  
  @override
  int get count => _delegate.count;
}
```

---

## 7. Mixins (9.5)

```dart
// mixin — набор методов и полей для добавления к классу
mixin Flyable {
  double altitude = 0;
  
  void fly(double height) {
    altitude = height;
    print('Flying at ${altitude}m');
  }
  
  void land() {
    altitude = 0;
    print('Landed');
  }
}

mixin Swimmable {
  void swim() => print('Swimming');
}

// on — ограничивает типы, к которым применимо mixin
mixin JsonSerializable on Entity {
  Map<String, dynamic> toJson();
  String toJsonString() => jsonEncode(toJson()); // использует метод из toJson()
}

abstract class Entity {
  final String id;
  Entity(this.id);
}

class Duck extends Animal with Flyable, Swimmable {
  Duck(super.name);
  
  @override
  void speak() => print('Quack!');
}

// mixin class (Dart 3) — может использоваться и как mixin, и как класс
mixin class Greetable {
  void greet() => print('Hello!');
}

class GreetableService with Greetable {} // как mixin
class StandaloneGreeter extends Greetable {} // как суперкласс
```

**Порядок линеаризации** (C3 linearization):

```dart
mixin A { String identify() => 'A'; }
mixin B { String identify() => 'B'; }
mixin C on A { String identify() => 'C + ${super.identify()}'; }

class D with A, B, C {
  // Порядок: D → C → B → A
  // D.identify() вызывает C.identify() который вызывает super (B или A?)
}
```

---

## 8. Extensions (9.6)

```dart
// Добавляем методы к существующим типам
extension StringUtils on String {
  String toTitleCase() => split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
  
  bool get isPalindrome {
    final clean = toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return clean == clean.split('').reversed.join();
  }
}

extension IntRange on int {
  Iterable<int> to(int end, {int step = 1}) sync* {
    for (var i = this; i <= end; i += step) yield i;
  }
}

// Extension на nullable типах
extension NullableString on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  String get orEmpty => this ?? '';
}

void main() {
  print('hello world'.toTitleCase()); // 'Hello World'
  print('racecar'.isPalindrome);      // true
  
  for (int i in 1.to(10, step: 2)) {
    print(i); // 1, 3, 5, 7, 9
  }
  
  String? nullable;
  print(nullable.isNullOrEmpty); // true
}
```

Если два extension конфликтуют — нужен явный `ExtensionName(obj).method()`:

```dart
extension E1 on String { void check() => print('E1'); }
extension E2 on String { void check() => print('E2'); }

void main() {
  E1('hello').check(); // явно выбирает E1
}
```

---

## 9. Extension types (Dart 3.3+) (9.7)

Zero-cost обёртки над существующими типами — не создают новый объект в runtime:

```dart
// Обёртка над int — не создаёт объект в runtime!
extension type UserId(int id) {
  bool get isValid => id > 0;
  UserId next() => UserId(id + 1);
}

extension type EmailAddress(String raw) implements String {
  // implements String — можно передавать туда где ожидается String
  bool get isValid => RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(raw);
}

// Extension type с const
extension type const Velocity(double metersPerSecond) {
  static const zero = Velocity(0);
  
  double get kmh => metersPerSecond * 3.6;
  bool get isSupersonic => metersPerSecond > 343;
  
  Velocity operator +(Velocity other) =>
      Velocity(metersPerSecond + other.metersPerSecond);
}

void takesUserId(UserId id) { /* ... */ }
void takesInt(int n) { /* ... */ }

void main() {
  final id = UserId(42);
  takesUserId(id);      // OK
  // takesInt(id);      // ОШИБКА — UserId не Int без implements
  takesInt(id.id);      // OK — через backing field
  
  final email = EmailAddress('user@example.com');
  print(email.length);  // OK — implements String доступен
  print(email.isValid); // true
  
  final v = Velocity(100);
  print(v.kmh);         // 360.0
}
```

---

## 10. Factory и static (9.8)

```dart
class Logger {
  static final Map<String, Logger> _cache = {};

  final String name;
  Logger._internal(this.name);

  // Factory constructor — возвращает кэшированный экземпляр
  factory Logger(String name) => _cache.putIfAbsent(name, () => Logger._internal(name));

  void log(String message) => print('[$name] $message');
}

// Abstract class + factory для паттерна Abstract Factory
abstract class Connection {
  factory Connection.create(String type) {
    return switch (type) {
      'http' => HttpConnection(),
      'ws' => WebSocketConnection(),
      _ => throw ArgumentError('Unknown connection type: $type'),
    };
  }

  void connect();
  void disconnect();
}

class HttpConnection implements Connection {
  @override void connect() => print('HTTP connect');
  @override void disconnect() => print('HTTP disconnect');
}

class WebSocketConnection implements Connection {
  @override void connect() => print('WS connect');
  @override void disconnect() => print('WS disconnect');
}

// Static методы vs top-level functions
class MathUtils {
  static double clamp(double value, double min, double max) =>
      value.clamp(min, max);

  // private constructor — нельзя создать экземпляр
  MathUtils._();
}
```

---

## 11. Sealed classes (Dart 3) (9.9)

`sealed` — иерархия с exhaustiveness check; все подтипы должны быть в той же библиотеке:

```dart
// Все наследники sealed класса должны быть в одном файле
sealed class Shape {
  const Shape();
}

class Circle extends Shape {
  final double radius;
  const Circle(this.radius);
}

class Rectangle extends Shape {
  final double width, height;
  const Rectangle(this.width, this.height);
}

class Triangle extends Shape {
  final double a, b, c;
  const Triangle(this.a, this.b, this.c);
}

// Компилятор знает ВСЕ подтипы → exhaustive switch без default
double area(Shape shape) => switch (shape) {
  Circle(radius: final r) => 3.14159 * r * r,
  Rectangle(width: final w, height: final h) => w * h,
  Triangle(a: final a, b: final b, c: final c) => _heroFormula(a, b, c),
};

double _heroFormula(double a, double b, double c) {
  final s = (a + b + c) / 2;
  return sqrt(s * (s-a) * (s-b) * (s-c));
}

// Более практичный пример — результат операции
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final String error;
  const Err(this.error);
}

void processResult(Result<int> result) {
  switch (result) {
    case Ok(value: final v):
      print('Success: $v');
    case Err(error: final e):
      print('Error: $e');
  }
}
```

---

## 12. Class modifiers (Dart 3) (9.10)

| Модификатор | Значение |
|---|---|
| `abstract` | Нельзя инстанциировать |
| `base` | Нельзя `implements` (только extends/with) извне библиотеки |
| `final` | Нельзя ничего — ни extends, ни implements извне |
| `interface` | Только `implements` извне, нельзя `extends` |
| `sealed` | Не используется вне своей библиотеки; exhaustiveness |
| `mixin class` | Можно использовать и как mixin, и как класс |

```dart
// base — внешний код обязан наследоваться через extends
base class Authenticator {
  bool authenticate(String token) {
    return _validate(token); // защищённая логика
  }
  bool _validate(String token) => token.isNotEmpty;
}

// В другой библиотеке:
// class MyAuth implements Authenticator {} // ОШИБКА
// class MyAuth extends Authenticator {}    // OK

// interface — только contract, без наследования реализации
interface class Serializable {
  Map<String, dynamic> toJson();
  String get id;
}

// final — закрытая иерархия, нельзя расширять снаружи
final class Money {
  final int cents;
  final String currency;
  const Money(this.cents, this.currency);
  // В другой библиотеке нельзя ни extends ни implements
}
```

---

## 13. Аннотации и метаданные (9.11)

```dart
// Аннотации — compile-time метаданные для инструментов и кодогенераторов
@override        // встроенная: lint проверяет что метод существует в суперклассе
@deprecated      // встроенная: предупреждение при использовании
@pragma('vm:never-inline') // встроенная: для VM оптимизации

// Пользовательская аннотация
class Range {
  final double min, max;
  const Range(this.min, this.max);
}

class Validate {
  const Validate();
}

class UserDto {
  @Range(0, 150)
  final int age;
  
  @Validate()
  final String email;
  
  const UserDto(this.age, this.email);
}

// Чтение аннотаций через dart:mirrors (NOT рекомендуется в production)
// В реальных проектах используют build_runner + source_gen

// Распространённые аннотации пакетов:
// @JsonSerializable() — json_serializable генерирует fromJson/toJson
// @freezed          — freezed генерирует copyWith, ==, toString
// @injectable       — get_it DI генерирует регистрацию
// @HiveType(typeId: 1) — Hive генерирует TypeAdapter
```

---

## 14. Минимальный полный пример

```dart
sealed class Expr {}

class Num extends Expr {
  final double value;
  Num(this.value);
}

class Add extends Expr {
  final Expr left, right;
  Add(this.left, this.right);
}

class Mul extends Expr {
  final Expr left, right;
  Mul(this.left, this.right);
}

// extension на sealed type — полиморфизм без наследования методов
extension Eval on Expr {
  double evaluate() => switch (this) {
    Num(value: final v) => v,
    Add(left: final l, right: final r) => l.evaluate() + r.evaluate(),
    Mul(left: final l, right: final r) => l.evaluate() * r.evaluate(),
  };
  
  String display() => switch (this) {
    Num(value: final v) => '$v',
    Add(left: final l, right: final r) => '(${l.display()} + ${r.display()})',
    Mul(left: final l, right: final r) => '(${l.display()} * ${r.display()})',
  };
}

void main() {
  // (2 + 3) * 4 = 20
  final expr = Mul(Add(Num(2), Num(3)), Num(4));
  print(expr.display());   // ((2.0 + 3.0) * 4.0)
  print(expr.evaluate());  // 20.0
}
```

---

## 15. Что происходит под капотом

- **Класс** компилируется в объект с vtable (таблица виртуальных методов) в AOT
- **Mixin** линеаризуется в цепочку суперклассов (нет отдельного объекта)
- **Extension type** — zero-cost: в AOT компилируется в прямые вызовы на underlying typed, объект не создаётся
- **Sealed** — только compile-time конструкция; в runtime нет разницы с обычным классом

---

## 16. Производительность

- **`const` конструкторы** → один экземпляр в пуле констант, без аллокации при каждом `const` вызове
- **Extension types** → нулевая накладная в AOT; в JIT небольшой overhead на вызовы
- **Mixins** → нет overhead по сравнению с обычным наследованием
- **`late final`** → ленивая инициализация, но с нулевой проверкой после первой инициализации в JIT; в AOT оптимизируется

---

## 17. Частые ошибки

**1. `implements` вместо `extends` для abstract class:**
```dart
abstract class Base {
  void method() => print('default'); // есть реализация
}

class Wrong implements Base {
  @override void method() {} // должна реализовать ВСЕХ, включая method
}

class Correct extends Base {} // всё ок — наследует method
```

**2. Мюутирующий mixin с состоянием — опасно при множественном использовании:**
```dart
mixin Counter {
  int count = 0; // каждый экземпляр получает свою копию — ОК
  void increment() => count++;
}
// Но: если хранить ссылку на mixin — путаница
```

**3. Circular dependency в factory:**
```dart
// Не делайте factory который создаёт тот же тип без условия выхода
factory Singleton() => Singleton(); // StackOverflow!
```

**4. Забыть `const` в конструкторе:**
```dart
class Config {
  final String host;
  Config(this.host); // без const — нельзя использовать как const
}
// const c = Config('localhost'); // ОШИБКА
```

---

## 18. Сравнение с другими языками

| Аспект | Dart | Java | Kotlin | Python |
|---|---|---|---|---|
| Интерфейс | Неявный (каждый класс) | interface | interface | Protocol |
| Mixin | `mixin` | нет | нет (delegation) | множественное наследование |
| Extension методы | `extension on` | нет | `fun T.method()` | нет (monkey patching) |
| Sealed | `sealed` | `sealed` (Java 17+) | `sealed class` | нет |
| Zero-cost wrapper | Extension type | нет | `@JvmInline value class` | нет |

---

## 19. Когда НЕ использовать

- **Наследование** вместо **composition** — принцип «prefer composition over inheritance» работает в Dart так же
- **`late`** без необходимости — добавляет runtime проверку; предпочитайте nullable или инициализацию в конструкторе
- **Extension на типах из других пакетов** без осторожности — конфликты имён при обновлении пакетов
- **Mixin для состояния** — mixins с мютабельными полями трудно отслеживать

---

## 20. Краткое резюме

1. **Конструкторы не наследуются** — но можно пробросить через `super(param)` (Dart 2.17+)
2. **Каждый класс задаёт интерфейс** — `implements` можно применить к любому классу
3. **Mixin** — горизонтальное переиспользование без иерархии; порядок `with A, B` важен (B переопределяет A)
4. **Extension** добавляет методы без наследования; конфликт разрешается явным `ExtensionName(obj).method()`
5. **Extension type** — zero-cost обёртка; идеален для доменных типов (`UserId`, `Velocity`)
6. **Sealed** + switch expression = exhaustiveness + ADT (algebraic data types) pattern в Dart
7. **Class modifiers** (base/final/interface/sealed) — инструмент для авторов библиотек, контролирующих публичное API
8. **Аннотации** — compile-time метаданные; основное применение — кодогенерация через build_runner
