# 7.6 Mixins и extension methods

## 1. Формальное определение

**Mixin** — набор методов и полей, который можно «подмешать» в класс через `with`. Позволяет повторно использовать код без классического наследования. Mixin не может иметь generative конструкторов.

**Extension method** — способ добавить методы к существующему типу без изменения его исходного кода и без наследования.

**Extension type** (Dart 3.3) — статический zero-cost wrapper, создающий новый интерфейс для существующего типа без runtime overhead.

## 2. Зачем это нужно

- **Mixin** — горизонтальное переиспользование кода (вместо множественного наследования).
- **Extension method** — расширение API сторонних и встроенных типов (`String`, `List`).
- **Extension type** — type-safe обёртка без аллокации (ID-типы, единицы измерения).
- **Разделение ответственности** — каждый mixin = одна capability.

## 3. Как это работает

### Mixin — базовый синтаксис

```dart
mixin Loggable {
  void log(String message) {
    print('[${runtimeType}] $message');
  }
}

mixin Serializable {
  Map<String, dynamic> toJson();

  String toJsonString() => toJson().toString();
}

class User with Loggable {
  final String name;
  User(this.name);
}

class Product with Loggable, Serializable {
  final String title;
  final double price;
  Product(this.title, this.price);

  @override
  Map<String, dynamic> toJson() => {'title': title, 'price': price};
}

void main() {
  var user = User('Alice');
  user.log('создан'); // [User] создан

  var product = Product('Dart Book', 29.99);
  product.log('добавлен'); // [Product] добавлен
  print(product.toJsonString());
}
```

### Mixin со state и ограничением (on)

```dart
// Mixin с состоянием
mixin Counter {
  int _count = 0;

  int get count => _count;

  void increment() => _count++;
  void reset() => _count = 0;
}

// on — ограничение: mixin применим только к подтипам Widget
abstract class Widget {
  void build();
}

mixin Hoverable on Widget {
  bool _hovered = false;

  bool get isHovered => _hovered;

  void onHover() {
    _hovered = true;
    build(); // Доступно, т.к. on Widget
  }

  void onLeave() {
    _hovered = false;
    build();
  }
}

class Button extends Widget with Hoverable {
  @override
  void build() {
    print('Button (hovered: $isHovered)');
  }
}

void main() {
  var btn = Button();
  btn.build();     // Button (hovered: false)
  btn.onHover();   // Button (hovered: true)
  btn.onLeave();   // Button (hovered: false)
}
```

### mixin class (Dart 3)

```dart
// mixin class — может быть и mixin, и class одновременно
mixin class Identifiable {
  late final String id;

  void generateId() {
    id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  }
}

// Как обычный класс:
class Standalone extends Identifiable {
  Standalone() {
    generateId();
  }
}

// Как mixin:
class Entity with Identifiable {
  final String name;
  Entity(this.name) {
    generateId();
  }
}
```

### Порядок mixins (linearization)

```dart
mixin A {
  String greet() => 'A';
}

mixin B {
  String greet() => 'B';
}

mixin C {
  String greet() => 'C';
}

class MyClass with A, B, C {}

void main() {
  print(MyClass().greet()); // 'C' — последний mixin побеждает!
}

// Линеаризация: Object → A → B → C → MyClass
// greet() ищется справа налево: C → найден!
```

### super в mixin

```dart
mixin Logger {
  void action(String name) {
    print('LOG: $name');
  }
}

mixin Auditor {
  void action(String name) {
    print('AUDIT: $name');
    // super.action(name) — вызовет следующий в цепочке (Logger)
  }
}

mixin Notifier {
  void action(String name) {
    print('NOTIFY: $name');
    super.action(name); // ❗ Не Object.action, а следующий mixin!
  }
}

class Service with Logger, Auditor {}

void main() {
  Service().action('save');
  // AUDIT: save
  // (Logger.action не вызван, т.к. Auditor не вызывает super)
}
```

### Extension methods

```dart
extension StringUtils on String {
  // Новый метод для всех String
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  // Getter
  bool get isBlank => trim().isEmpty;

  // Оператор
  String operator *(int times) => List.filled(times, this).join();
}

extension IntUtils on int {
  Duration get seconds => Duration(seconds: this);
  Duration get minutes => Duration(minutes: this);

  bool get isEven2 => this % 2 == 0; // isEven уже есть, пример
}

void main() {
  print('hello'.capitalize()); // Hello
  print('  '.isBlank);         // true
  print('ha' * 3);             // hahaha (оператор ?)
  // ↑ Нет, String уже имеет *, используем встроенный

  var delay = 5.seconds;       // Duration(0:00:05.000000)
  print(delay);
}
```

### Extension на генерик

```dart
extension ListUtils<T> on List<T> {
  /// Первый элемент или null
  T? get firstOrNull => isEmpty ? null : first;

  /// Разбивает на чанки
  List<List<T>> chunked(int size) {
    var chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      var end = (i + size < length) ? i + size : length;
      chunks.add(sublist(i, end));
    }
    return chunks;
  }
}

extension MapUtils<K, V> on Map<K, V> {
  /// Значение или default
  V getOrDefault(K key, V defaultValue) => this[key] ?? defaultValue;
}

void main() {
  var list = [1, 2, 3, 4, 5];
  print(list.firstOrNull);     // 1
  print(list.chunked(2));      // [[1, 2], [3, 4], [5]]

  var empty = <int>[];
  print(empty.firstOrNull);   // null
}
```

### Extension type (Dart 3.3)

```dart
// Zero-cost type-safe wrapper
extension type const UserId(int value) {
  // Можно добавить методы
  bool get isValid => value > 0;
}

extension type const Email(String value) {
  bool get isValid => value.contains('@');
}

// UserId и Email — разные типы в compile-time!
void deleteUser(UserId id) {
  print('Удаление пользователя #${id.value}');
}

void sendEmail(Email to) {
  print('Письмо → ${to.value}');
}

void main() {
  var userId = UserId(42);
  var email = Email('alice@test.com');

  deleteUser(userId);    // ✅
  sendEmail(email);      // ✅

  // deleteUser(email);  // ❌ Ошибка компиляции! Email ≠ UserId
  // deleteUser(42);     // ❌ Ошибка! int ≠ UserId

  print(userId.isValid); // true

  // Runtime: userId — это просто int! Zero overhead!
}
```

### Extension type с implements

```dart
// implements — extension type наследует интерфейс типа-репрезентации
extension type const Meters(double value) implements double {
  Meters operator +(Meters other) => Meters(value + other.value);

  String get formatted => '${value.toStringAsFixed(2)} м';
}

void main() {
  var distance = Meters(3.5);

  // Доступны методы double (через implements):
  print(distance.isFinite);     // true
  print(distance.ceil());       // 4

  // Свои методы:
  print(distance.formatted);   // 3.50 м

  // Арифметика:
  var total = Meters(1.5) + Meters(2.5);
  print(total.formatted);      // 4.00 м
}
```

## 4. Минимальный пример

```dart
mixin Greetable {
  String get name;
  void greet() => print('Привет, $name!');
}

extension on int {
  String get rubles => '$this ₽';
}

class Person with Greetable {
  @override
  final String name;
  Person(this.name);
}

void main() {
  Person('Dart').greet(); // Привет, Dart!
  print(100.rubles);      // 100 ₽
}
```

## 5. Практический пример

### Система capabilities через mixins

```dart
// Capability mixins
mixin Draggable {
  double posX = 0;
  double posY = 0;

  void dragTo(double x, double y) {
    posX = x;
    posY = y;
    print('${runtimeType} перемещён в ($x, $y)');
  }
}

mixin Resizable {
  double width = 100;
  double height = 100;

  void resize(double w, double h) {
    width = w;
    height = h;
    print('${runtimeType} размер: ${w}x$h');
  }
}

mixin Rotatable {
  double angle = 0;

  void rotate(double degrees) {
    angle = (angle + degrees) % 360;
    print('${runtimeType} повёрнут на ${angle}°');
  }
}

mixin Selectable {
  bool _selected = false;

  bool get isSelected => _selected;

  void select() {
    _selected = true;
    print('${runtimeType} выбран');
  }

  void deselect() {
    _selected = false;
    print('${runtimeType} снят');
  }
}

// Комбинируем нужные capabilities
class TextBox with Draggable, Resizable, Selectable {
  String text;
  TextBox(this.text);
}

class Image with Draggable, Resizable, Rotatable, Selectable {
  final String src;
  Image(this.src);
}

class Line with Draggable, Rotatable {
  final double length;
  Line(this.length);
}

void main() {
  var textBox = TextBox('Hello');
  textBox.select();
  textBox.dragTo(100, 200);
  textBox.resize(300, 50);

  print('');

  var img = Image('photo.png');
  img.dragTo(50, 50);
  img.rotate(45);
  img.resize(200, 200);

  print('');

  var line = Line(100);
  line.dragTo(0, 0);
  line.rotate(90);
  // line.resize(...)  // ❌ Line не имеет Resizable
  // line.select()     // ❌ Line не имеет Selectable
}
```

### Extension methods для Iterable

```dart
extension IterableUtils<T> on Iterable<T> {
  /// Группировка по ключу
  Map<K, List<T>> groupBy<K>(K Function(T) keyFn) {
    var result = <K, List<T>>{};
    for (final item in this) {
      result.putIfAbsent(keyFn(item), () => []).add(item);
    }
    return result;
  }

  /// Подсчёт элементов по условию
  int countWhere(bool Function(T) test) {
    var count = 0;
    for (final item in this) {
      if (test(item)) count++;
    }
    return count;
  }

  /// Максимум по критерию
  T? maxBy<R extends Comparable>(R Function(T) selector) {
    T? best;
    R? bestValue;
    for (final item in this) {
      var value = selector(item);
      if (bestValue == null || value.compareTo(bestValue) > 0) {
        best = item;
        bestValue = value;
      }
    }
    return best;
  }
}

void main() {
  var people = [
    (name: 'Alice', age: 30, city: 'Moscow'),
    (name: 'Bob', age: 25, city: 'SPb'),
    (name: 'Carol', age: 35, city: 'Moscow'),
    (name: 'Dave', age: 28, city: 'SPb'),
  ];

  // groupBy
  var byCity = people.groupBy((p) => p.city);
  print(byCity.keys); // (Moscow, SPb)

  // countWhere
  var over30 = people.countWhere((p) => p.age >= 30);
  print('Старше 30: $over30'); // 2

  // maxBy
  var oldest = people.maxBy((p) => p.age);
  print('Старший: ${oldest?.name}'); // Carol
}
```

## 6. Что происходит под капотом

### Mixin linearization

```
class D extends A with B, C

Dart создаёт промежуточные классы:
  Object → A → A+B → A+B+C → D

A+B — анонимный класс:
  - extends A
  - копирует методы B (переопределяя при конфликте)

A+B+C — анонимный класс:
  - extends A+B
  - копирует методы C

Поэтому: последний mixin «побеждает» при конфликте имён.
super в mixin → вызывает предыдущий в цепочке.
```

### Extension methods — static dispatch

```
extension on String {
  void hello() => print('Hi from $this');
}

'Dart'.hello();

Компилируется как:
  _StringExtension_hello('Dart');

Extension НЕ добавляет методы в класс.
Это СТАТИЧЕСКИЙ dispatch, не виртуальный!

Следствие:
  dynamic s = 'Dart';
  s.hello(); // ❌ NoSuchMethodError! Dynamic не видит extensions
```

### Extension type — erasure

```
extension type UserId(int value) {}

var id = UserId(42);

Runtime: id — это просто int 42.
UserId «стирается» при компиляции.
Нет аллокации, нет wrapper-объекта.

typeof(id) → int (в runtime!)
```

## 7. Производительность и ресурсы

| Аспект                   | Стоимость                                                  |
| ------------------------ | ---------------------------------------------------------- |
| Mixin                    | = extends (linearization compile-time)                     |
| Extension method         | = static function call (inlined)                           |
| Extension type           | Zero cost (type erasure)                                   |
| `with` нескольких mixins | Промежуточные классы (compile-time), runtime = одна vtable |

**Рекомендации:**

- Extension methods бесплатны — используйте смело.
- Extension types — zero overhead, идеальны для type-safe ID/units.
- Mixins не дороже обычного наследования.

## 8. Частые ошибки и антипаттерны

### ❌ Extension на dynamic

```dart
extension on String {
  void hello() => print('Hi');
}

void main() {
  dynamic s = 'test';
  s.hello(); // ❌ NoSuchMethodError!
  // Extensions — static dispatch, не работают с dynamic!

  (s as String).hello(); // ✅
}
```

### ❌ Mixin с конструктором

```dart
// ❌ mixin не может иметь generative конструктор
mixin Bad {
  // Bad(this.x); // Ошибка!
  // final int x;
}

// ✅ mixin class может:
mixin class Configurable {
  late final String config;
  // Но конструктор нельзя вызвать через with!
}
```

### ❌ Конфликт имён в mixins

```dart
mixin A { String get id => 'A'; }
mixin B { String get id => 'B'; }

class C with A, B {}

// C().id → 'B' (последний побеждает, без предупреждения!)
// Решение: переопределить явно
class D with A, B {
  @override
  String get id => 'D own id';
}
```

### ❌ Extension type и is-проверка

```dart
extension type UserId(int value) {}

void main() {
  var id = UserId(42);
  print(id is int);    // true! (в runtime это int)
  print(id is UserId); // true
  print(42 is UserId); // true! (int == UserId в runtime)
  // Extension type не создаёт настоящий тип в runtime!
}
```

## 9. Сравнение с альтернативами

| Подход              | Mixin               | Extension method | Extension type | Наследование |
| ------------------- | ------------------- | ---------------- | -------------- | ------------ |
| Добавляет state     | ✅                  | ❌               | ❌             | ✅           |
| Множественное       | ✅ (with)           | ✅ (много ext)   | ❌             | ❌           |
| Работает с existing | ❌ (при объявлении) | ✅               | ✅             | ❌           |
| Runtime тип         | В иерархии          | Нет              | Стирается      | В иерархии   |
| Dynamic dispatch    | ✅                  | ❌ (static)      | ❌ (static)    | ✅           |
| Override            | ✅                  | ❌               | ❌             | ✅           |

## 10. Когда НЕ стоит использовать

- **Mixin с тяжёлым state** — если mixin хранит сложное состояние, возможно это должен быть класс (композиция).
- **Extension method для core behavior** — extensions не переопределяемы; для полиморфизма → mixin/interface.
- **Extension type для runtime полиморфизма** — `is`-проверка ненадёжна (type erasure).
- **Mixin вместо интерфейса** — если нужен контракт без реализации → `abstract class`/`interface class`.

## 11. Краткое резюме

1. **mixin** — подмешиваемый набор методов/полей; `with` вместо наследования.
2. **`on` clause** — ограничение: mixin доступен только для подтипов указанного класса.
3. **Linearization** — последний mixin в `with` побеждает при конфликте.
4. **Extension method** — статические методы для существующих типов; не видны через `dynamic`.
5. **Extension type** (Dart 3.3) — zero-cost wrapper; стирается в runtime.
6. **mixin class** (Dart 3) — класс, который можно использовать и как mixin, и как base class.
7. **Static dispatch** — extensions и extension types разрешаются compile-time.

---

> **Назад:** [7.5 Абстрактные классы и интерфейсы](07_05_abstract_interfaces.md) · **Далее:** [7.7 Статические члены и фабричные конструкторы](07_07_static_factory.md)
