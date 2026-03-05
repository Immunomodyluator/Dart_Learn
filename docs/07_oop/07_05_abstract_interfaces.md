# 7.5 Абстрактные классы и интерфейсы

## 1. Формальное определение

**Абстрактный класс** (`abstract class`) — класс, который нельзя инстанциировать напрямую. Может содержать абстрактные (без тела) и конкретные (с телом) методы. Служит шаблоном для подклассов.

**Интерфейс** — в Dart **каждый класс** неявно объявляет интерфейс (implicit interface). Оператор `implements` требует реализовать ВСЕ публичные методы и свойства класса.

**Dart 3 модификаторы** — `interface class`, `base class`, `final class`, `sealed class`, `mixin class` — контролируют, что можно делать с классом за пределами библиотеки.

## 2. Зачем это нужно

- **Контракт** — абстрактный класс/интерфейс определяет «что», подклассы — «как».
- **Полиморфизм** — код работает с абстрактным типом, не зная конкретного.
- **Dependency Inversion** — зависимости от абстракций, а не реализаций.
- **Exhaustive checking** — `sealed` + `switch` → компилятор гарантирует обработку всех вариантов.
- **API control** — модификаторы Dart 3 защищают классы от неправильного расширения.

## 3. Как это работает

### abstract class

```dart
abstract class Shape {
  // Абстрактный метод — без тела, ОБЯЗАН быть реализован
  double get area;
  double get perimeter;

  // Конкретный метод — общая логика
  String describe() => '${runtimeType}: S=${area.toStringAsFixed(2)}';
}

class Circle extends Shape {
  final double radius;
  Circle(this.radius);

  @override
  double get area => 3.14159 * radius * radius;

  @override
  double get perimeter => 2 * 3.14159 * radius;
}

class Rectangle extends Shape {
  final double width, height;
  Rectangle(this.width, this.height);

  @override
  double get area => width * height;

  @override
  double get perimeter => 2 * (width + height);
}

void main() {
  // var s = Shape(); // ❌ Нельзя создать abstract class

  List<Shape> shapes = [Circle(5), Rectangle(3, 4)];
  for (final s in shapes) {
    print(s.describe()); // Полиморфный вызов
  }
}
```

### implements — реализация интерфейса

```dart
// Любой класс может быть интерфейсом
class Printable {
  void printOut() {
    print(toString());
  }
}

class Serializable {
  String serialize() => '';
}

// implements — реализуем ВСЕ методы заново
class Document implements Printable, Serializable {
  final String title;
  final String content;

  Document(this.title, this.content);

  @override
  void printOut() {
    print('=== $title ===');
    print(content);
  }

  @override
  String serialize() => '{"title":"$title","content":"$content"}';
}

void main() {
  Printable doc = Document('Отчёт', 'Текст отчёта');
  doc.printOut(); // Работает по интерфейсу Printable
}
```

### extends vs implements

```dart
abstract class Animal {
  String get name;
  void eat() => print('$name ест');  // Конкретый метод
  void speak();                       // Абстрактный
}

// extends — наследует eat(), реализует speak()
class Dog extends Animal {
  @override
  final String name;
  Dog(this.name);

  @override
  void speak() => print('$name: Гав!');
  // eat() — унаследован!
}

// implements — реализует ВСЁ: и eat(), и speak(), и name
class Robot implements Animal {
  @override
  final String name = 'R2D2';

  @override
  void eat() => print('Робот не ест'); // Обязан реализовать!

  @override
  void speak() => print('Бип-бип');
}
```

### interface class (Dart 3)

```dart
// interface class — разрешает только implements, запрещает extends
interface class Cacheable {
  String get cacheKey;

  Duration get ttl => const Duration(minutes: 5);

  bool isExpired(DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}

// class MyCache extends Cacheable {}
// ❌ Ошибка! interface class нельзя extends (за пределами библиотеки)

class UserCache implements Cacheable {
  final String userId;
  UserCache(this.userId);

  @override
  String get cacheKey => 'user:$userId';

  @override
  Duration get ttl => const Duration(hours: 1);

  @override
  bool isExpired(DateTime cachedAt) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}
```

### base class (Dart 3)

```dart
// base class — разрешает extends, запрещает implements
base class Event {
  final DateTime timestamp;
  Event() : timestamp = DateTime.now();

  String format() => '[$timestamp] ${runtimeType}';
}

// ✅ Можно наследоваться:
base class ClickEvent extends Event {
  final String target;
  ClickEvent(this.target);

  @override
  String format() => '${super.format()} on $target';
}

// ❌ Нельзя implements:
// class FakeEvent implements Event {} // Ошибка!
```

### final class (Dart 3)

```dart
// final class — нельзя ни extends, ни implements (за пределами библиотеки)
final class DatabaseConfig {
  final String host;
  final int port;
  final String database;

  const DatabaseConfig({
    required this.host,
    this.port = 5432,
    required this.database,
  });
}

// ❌ За пределами библиотеки:
// class MyConfig extends DatabaseConfig {} // Ошибка!
// class MyConfig implements DatabaseConfig {} // Ошибка!
```

### sealed class (Dart 3)

```dart
// sealed — нельзя расширять за пределами файла
// + включает exhaustive switch
sealed class AuthState {}

class Unauthenticated extends AuthState {}

class Authenticating extends AuthState {
  final String username;
  Authenticating(this.username);
}

class Authenticated extends AuthState {
  final String username;
  final String token;
  Authenticated(this.username, this.token);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// Exhaustive switch — компилятор проверяет все варианты
String describeState(AuthState state) {
  return switch (state) {
    Unauthenticated() => 'Не авторизован',
    Authenticating(:final username) => 'Вход: $username...',
    Authenticated(:final username) => 'Привет, $username!',
    AuthError(:final message) => 'Ошибка: $message',
    // Если забыть вариант → ошибка компиляции!
  };
}

void main() {
  var state = Authenticated('Alice', 'token123');
  print(describeState(state)); // Привет, Alice!
}
```

### Комбинация модификаторов

```dart
// sealed + abstract — нельзя инстанциировать + exhaustive
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final String error;
  const Failure(this.error);
}

// Использование
Result<int> divide(int a, int b) {
  if (b == 0) return Failure('Деление на ноль');
  return Success(a ~/ b);
}

void main() {
  var result = divide(10, 3);

  // Exhaustive switch
  var message = switch (result) {
    Success(:final value) => 'Результат: $value',
    Failure(:final error) => 'Ошибка: $error',
  };
  print(message); // Результат: 3
}
```

## 4. Минимальный пример

```dart
abstract class Converter<T> {
  T convert(String input);
  String get name;
}

class IntConverter extends Converter<int> {
  @override
  String get name => 'IntConverter';

  @override
  int convert(String input) => int.parse(input);
}

void main() {
  Converter<int> c = IntConverter();
  print(c.convert('42')); // 42
}
```

## 5. Практический пример

### Система платежей с sealed types

```dart
sealed class PaymentMethod {
  const PaymentMethod();
  String get displayName;
}

final class CreditCard extends PaymentMethod {
  final String number;
  final String expiry;

  const CreditCard({required this.number, required this.expiry});

  @override
  String get displayName => '**** ${number.substring(number.length - 4)}';
}

final class BankTransfer extends PaymentMethod {
  final String iban;

  const BankTransfer({required this.iban});

  @override
  String get displayName => 'IBAN: ...${iban.substring(iban.length - 4)}';
}

final class DigitalWallet extends PaymentMethod {
  final String provider; // 'Apple Pay', 'Google Pay'
  final String email;

  const DigitalWallet({required this.provider, required this.email});

  @override
  String get displayName => '$provider ($email)';
}

/// Процессор платежей — использует exhaustive switch
class PaymentProcessor {
  Future<bool> process(PaymentMethod method, double amount) async {
    print('Обработка: ${amount.toStringAsFixed(2)} ₽');

    // Exhaustive — компилятор гарантирует обработку всех типов
    return switch (method) {
      CreditCard(:final number, :final expiry) =>
        _processCard(number, expiry, amount),
      BankTransfer(:final iban) =>
        _processBankTransfer(iban, amount),
      DigitalWallet(:final provider, :final email) =>
        _processWallet(provider, email, amount),
    };
  }

  Future<bool> _processCard(String number, String expiry, double amount) async {
    print('  Карта: ****${number.substring(number.length - 4)}, exp: $expiry');
    return true;
  }

  Future<bool> _processBankTransfer(String iban, double amount) async {
    print('  Банковский перевод: $iban');
    return true;
  }

  Future<bool> _processWallet(String provider, String email, double amount) async {
    print('  $provider: $email');
    return true;
  }
}

Future<void> main() async {
  var processor = PaymentProcessor();

  var methods = <PaymentMethod>[
    CreditCard(number: '4111111111111234', expiry: '12/26'),
    BankTransfer(iban: 'RU0000000000000001234'),
    DigitalWallet(provider: 'Apple Pay', email: 'user@icloud.com'),
  ];

  for (final method in methods) {
    print('\n--- ${method.displayName} ---');
    await processor.process(method, 1500.0);
  }
}
```

## 6. Что происходит под капотом

### abstract class

```
abstract class Shape { double get area; }

Компилятор:
1. Создаёт Class object (vtable, type info)
2. НЕ генерирует конструктор вызываемый new
3. Абстрактный метод → slot в vtable указывает на
   «abstract method stub» (бросает если вызван)
4. Подклассы ОБЯЗАНЫ заполнить slot конкретной реализацией
```

### implements vs extends

```
extends Shape:
  - Копирует vtable Shape
  - Переопределяет только указанные методы
  - Наследует поля (slot'ы в объекте)

implements Shape:
  - Создаёт НОВУЮ vtable
  - Обязан реализовать ВСЕ методы
  - НЕ наследует поля (свои slot'ы)
  - Runtime: type check (obj is Shape) → true
```

### sealed class — exhaustive check

```
sealed class Result { ... }
class Success extends Result { ... }
class Failure extends Result { ... }

Компилятор знает ВСЕ подтипы Result (в том же файле).
switch (result) {
  Success() => ...,
  Failure() => ...,
  // Компилятор: «все варианты покрыты ✅»
}

Если добавить новый подтип — switch станет
non-exhaustive → ошибка компиляции!
```

### Модификаторы — enforcement

```
Модификатор     | extends | implements | construct
----------------|---------|------------|----------
(нет)           | ✅      | ✅        | ✅
abstract        | ✅      | ✅        | ❌
interface       | ❌*     | ✅        | ✅
base            | ✅      | ❌*       | ✅
final           | ❌*     | ❌*       | ✅
sealed          | ❌*     | ❌*       | ❌
mixin           | ❌      | ✅        | ❌

* — за пределами библиотеки. Внутри библиотеки — можно.
```

## 7. Производительность и ресурсы

| Аспект                | Стоимость                                              |
| --------------------- | ------------------------------------------------------ |
| abstract class        | = обычный класс (нет runtime overhead)                 |
| implements            | = extends по производительности                        |
| sealed switch         | = обычный switch (нет дополнительных проверок runtime) |
| Модификаторы (Dart 3) | Compile-time only, zero runtime cost                   |
| is / as               | O(1) — кешированный type check                         |

Модификаторы Dart 3 — это **compile-time enforcement**, не runtime.

## 8. Частые ошибки и антипаттерны

### ❌ implements вместо extends (потеря реализации)

```dart
abstract class Repository {
  // 10 утилитных методов с реализацией...
  void log(String msg) => print('[REPO] $msg');
}

// ❌ implements — все 10 методов надо реализовать заново!
class UserRepo implements Repository {
  @override
  void log(String msg) => print('[REPO] $msg'); // Дублирование!
}

// ✅ extends — наследует реализацию, переопределяет нужное
class UserRepo2 extends Repository {
  // log() — унаследован!
}
```

### ❌ sealed class без switch

```dart
// Если не используете exhaustive switch, sealed бесполезен
sealed class Event {}
class Click extends Event {}
class Hover extends Event {}

void handle(Event e) {
  // ❌ if-else цепочка — теряем exhaustive проверку
  if (e is Click) { ... }
  else if (e is Hover) { ... }

  // ✅ switch — компилятор проверяет полноту
  switch (e) {
    case Click(): ...
    case Hover(): ...
  }
}
```

### ❌ God interface

```dart
// ❌ Один интерфейс с 20 методами
abstract class Everything {
  void read();
  void write();
  void delete();
  void format();
  void serialize();
  // ...
}

// ✅ ISP: маленькие, сфокусированные интерфейсы
abstract class Readable { void read(); }
abstract class Writable { void write(); }
abstract class Deletable { void delete(); }

class Document implements Readable, Writable {
  @override
  void read() { ... }
  @override
  void write() { ... }
}
```

## 9. Сравнение с альтернативами

| Аспект              | Dart                 | Java           | Kotlin          | TypeScript      |
| ------------------- | -------------------- | -------------- | --------------- | --------------- |
| abstract class      | ✅                   | ✅             | ✅              | ✅ (abstract)   |
| Implicit interface  | ✅ (каждый класс)    | ❌ (explicit)  | ❌              | ✅ (structural) |
| sealed              | ✅ (Dart 3)          | ✅ (Java 17)   | ✅              | ❌ (union ≈)    |
| interface keyword   | ✅ `interface class` | ✅ `interface` | ✅ `interface`  | ✅ `interface`  |
| final class         | ✅ (Dart 3)          | ✅ `final`     | ✅ по умолчанию | ❌              |
| Multiple implements | ✅                   | ✅             | ✅              | ✅              |

## 10. Когда НЕ стоит использовать

- **abstract для одного подкласса** — если только один наследник → обычный класс проще.
- **sealed для открытого расширения** — если пользователи библиотеки должны добавлять подтипы.
- **final class для внутреннего кода** — избыточно, если код только ваш.
- **interface class без причины** — если наследование допустимо, не запрещайте его.
- **implements вместо extends** — когда нужна унаследованная реализация.

## 11. Краткое резюме

1. **abstract class** — нельзя инстанциировать; может содержать абстрактные и конкретные методы.
2. **implements** — реализация ВСЕХ методов; любой класс — implicit interface.
3. **extends** — наследование с возможностью переопределения.
4. **sealed** (Dart 3) — ограничивает подтипы текущим файлом; exhaustive switch.
5. **interface class** — только `implements`, нельзя `extends` (вне библиотеки).
6. **base class** — только `extends`, нельзя `implements` (вне библиотеки).
7. **final class** — ни `extends`, ни `implements` (вне библиотеки).

---

> **Назад:** [7.4 Наследование и super](07_04_inheritance.md) · **Далее:** [7.6 Mixins и extension methods](07_06_mixins_extensions.md)
