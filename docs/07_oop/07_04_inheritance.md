# 7.4 Наследование и super

## 1. Формальное определение

**Наследование** — механизм, при котором класс-потомок (subclass) получает все поля и методы класса-родителя (superclass) и может добавлять новые или переопределять существующие.

В Dart используется **одиночное наследование** (`extends`) — класс может наследоваться только от одного класса. Множественное наследование отсутствует; его роль выполняют **mixins**.

**`super`** — ссылка на экземпляр родительского класса. Используется для вызова конструктора, методов и полей родителя.

## 2. Зачем это нужно

- **Повторное использование кода** — общая логика в базовом классе.
- **Полиморфизм** — разные подклассы обрабатываются через общий тип.
- **Иерархия типов** — `Cat extends Animal`, `SavingsAccount extends Account`.
- **Специализация** — подкласс уточняет или расширяет поведение родителя.
- **Template method** — базовый класс определяет алгоритм, подклассы реализуют шаги.

## 3. Как это работает

### Базовое наследование

```dart
class Animal {
  final String name;
  int _energy = 100;

  Animal(this.name);

  int get energy => _energy;

  void eat(int amount) {
    _energy += amount;
    print('$name ест. Энергия: $_energy');
  }

  void sleep() {
    _energy += 50;
    print('$name спит. Энергия: $_energy');
  }

  @override
  String toString() => '$runtimeType($name, energy: $_energy)';
}

class Dog extends Animal {
  final String breed;

  // super.name — пробрасывает параметр в конструктор Animal
  Dog(super.name, this.breed);

  // Новый метод — только у Dog
  void fetch(String item) {
    _energy -= 20; // Доступ к protected-подобному полю
    print('$name приносит $item! Энергия: $_energy');
  }
}

class Cat extends Animal {
  Cat(super.name);

  void purr() {
    print('$name мурлычет...');
  }
}

void main() {
  var dog = Dog('Бобик', 'Лабрадор');
  dog.eat(30);       // Унаследованный метод
  dog.fetch('мяч');  // Собственный метод

  var cat = Cat('Мурка');
  cat.sleep();       // Унаследованный метод
  cat.purr();        // Собственный метод

  // Полиморфизм: общий тип Animal
  List<Animal> pets = [dog, cat];
  for (final pet in pets) {
    print(pet);  // toString() у каждого свой runtimeType
  }
}
```

### Переопределение методов (@override)

```dart
class Shape {
  double get area => 0;

  String describe() => 'Фигура с площадью ${area.toStringAsFixed(2)}';
}

class Circle extends Shape {
  final double radius;
  Circle(this.radius);

  @override
  double get area => 3.14159 * radius * radius;

  @override
  String describe() => 'Круг r=$radius, S=${area.toStringAsFixed(2)}';
}

class Square extends Shape {
  final double side;
  Square(this.side);

  @override
  double get area => side * side;

  // Не переопределяем describe() — используется родительский
}

void main() {
  var shapes = <Shape>[Circle(5), Square(4)];
  for (final s in shapes) {
    print(s.describe());
  }
  // Круг r=5.0, S=78.54
  // Фигура с площадью 16.00
}
```

### super — вызов родительской реализации

```dart
class Logger {
  void log(String message) {
    print('[LOG] $message');
  }
}

class TimestampLogger extends Logger {
  @override
  void log(String message) {
    // Добавляем timestamp, затем вызываем родительский log
    var time = DateTime.now().toIso8601String().substring(11, 19);
    super.log('[$time] $message');
  }
}

class PrefixLogger extends Logger {
  final String prefix;
  PrefixLogger(this.prefix);

  @override
  void log(String message) {
    super.log('$prefix: $message');
  }
}

void main() {
  var logger = TimestampLogger();
  logger.log('Приложение запущено');
  // [LOG] [14:30:00] Приложение запущено
}
```

### super в конструкторах

```dart
class Vehicle {
  final String make;
  final int year;

  Vehicle({required this.make, required this.year});

  @override
  String toString() => '$make ($year)';
}

class Car extends Vehicle {
  final int doors;

  // Dart 3: super parameters
  Car({required super.make, required super.year, this.doors = 4});

  // Эквивалент без super parameters:
  // Car({required String make, required int year, this.doors = 4})
  //     : super(make: make, year: year);

  @override
  String toString() => '${super.toString()}, $doors дв.';
}

class ElectricCar extends Car {
  final int batteryKWh;

  ElectricCar({
    required super.make,
    required super.year,
    super.doors,
    required this.batteryKWh,
  });

  @override
  String toString() => '${super.toString()}, ${batteryKWh}kWh';
}

void main() {
  var tesla = ElectricCar(make: 'Tesla', year: 2024, batteryKWh: 75);
  print(tesla); // Tesla (2024), 4 дв., 75kWh
}
```

### Проверка типов: is, as

```dart
void processAnimal(Animal animal) {
  print('Обработка: ${animal.name}');

  // is — проверка типа + smart cast
  if (animal is Dog) {
    // Внутри блока animal автоматически Dog
    animal.fetch('палка'); // ✅ Доступен метод Dog
  } else if (animal is Cat) {
    animal.purr(); // ✅ Доступен метод Cat
  }

  // as — явное приведение (бросает исключение при ошибке)
  // var dog = animal as Dog; // ❌ CastError если animal не Dog!
}
```

### covariant — ослабление типа параметра

```dart
class Animal {
  void chase(Animal other) {
    print('${runtimeType} гонится за ${other.runtimeType}');
  }
}

class Mouse extends Animal {}

class Cat extends Animal {
  // covariant разрешает сузить тип параметра
  @override
  void chase(covariant Mouse other) {
    print('Кот гонится за мышкой!');
  }
}

void main() {
  Cat().chase(Mouse()); // ✅
  // Cat().chase(Cat()); // ❌ Runtime error: Cat is not Mouse
}
```

### noSuchMethod — перехват несуществующих методов

```dart
class DynamicProxy {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    print('Вызван: ${invocation.memberName}');
    print('Аргументы: ${invocation.positionalArguments}');
    return null;
  }
}

void main() {
  dynamic proxy = DynamicProxy();
  proxy.anyMethod(1, 2, 3); // Вызван: Symbol("anyMethod")
}
```

## 4. Минимальный пример

```dart
class Base {
  void greet() => print('Привет из Base');
}

class Child extends Base {
  @override
  void greet() {
    super.greet(); // Вызов родительского
    print('Привет из Child');
  }
}

void main() {
  Child().greet();
  // Привет из Base
  // Привет из Child
}
```

## 5. Практический пример

### Система уведомлений (Template Method)

```dart
/// Базовый класс — определяет алгоритм отправки
abstract class NotificationSender {
  final String serviceName;

  NotificationSender(this.serviceName);

  /// Template method — общий алгоритм
  Future<bool> send(String recipient, String message) async {
    if (!validate(recipient)) {
      print('[$serviceName] Невалидный получатель: $recipient');
      return false;
    }

    var formatted = format(message);
    print('[$serviceName] Отправка → $recipient');

    var success = await deliver(recipient, formatted);

    if (success) {
      onSuccess(recipient);
    } else {
      onFailure(recipient);
    }

    return success;
  }

  // Шаги, которые подклассы переопределяют:
  bool validate(String recipient);
  String format(String message);
  Future<bool> deliver(String recipient, String message);

  // Хуки с дефолтной реализацией:
  void onSuccess(String recipient) {
    print('[$serviceName] ✅ Доставлено: $recipient');
  }

  void onFailure(String recipient) {
    print('[$serviceName] ❌ Ошибка доставки: $recipient');
  }
}

class EmailSender extends NotificationSender {
  EmailSender() : super('EMAIL');

  @override
  bool validate(String recipient) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(recipient);

  @override
  String format(String message) => '<html><body>$message</body></html>';

  @override
  Future<bool> deliver(String recipient, String message) async {
    await Future.delayed(Duration(milliseconds: 100));
    return true; // Имитация отправки
  }
}

class SmsSender extends NotificationSender {
  static const maxLength = 160;

  SmsSender() : super('SMS');

  @override
  bool validate(String recipient) =>
      RegExp(r'^\+?\d{10,15}$').hasMatch(recipient);

  @override
  String format(String message) {
    if (message.length > maxLength) {
      return '${message.substring(0, maxLength - 3)}...';
    }
    return message;
  }

  @override
  Future<bool> deliver(String recipient, String message) async {
    await Future.delayed(Duration(milliseconds: 50));
    return true;
  }

  @override
  void onSuccess(String recipient) {
    super.onSuccess(recipient);
    print('[$serviceName] Длина: ${recipient.length} символов');
  }
}

class PushSender extends NotificationSender {
  PushSender() : super('PUSH');

  @override
  bool validate(String recipient) => recipient.startsWith('device:');

  @override
  String format(String message) =>
      '{"title":"Уведомление","body":"$message"}';

  @override
  Future<bool> deliver(String recipient, String message) async {
    await Future.delayed(Duration(milliseconds: 30));
    return true;
  }
}

Future<void> main() async {
  // Полиморфизм: единый интерфейс, разная реализация
  var senders = <NotificationSender>[
    EmailSender(),
    SmsSender(),
    PushSender(),
  ];

  var recipients = [
    'user@example.com',
    '+79001234567',
    'device:abc123',
  ];

  for (var i = 0; i < senders.length; i++) {
    await senders[i].send(recipients[i], 'Добро пожаловать!');
    print('');
  }
}
```

## 6. Что происходит под капотом

### Виртуальная таблица (vtable)

```
class Animal { void eat() {...} void sleep() {...} }
class Dog extends Animal { void eat() {...} void fetch() {...} }

Animal vtable:
  ┌──────────────┐
  │ eat  → Animal.eat  │
  │ sleep → Animal.sleep│
  └──────────────┘

Dog vtable:
  ┌──────────────┐
  │ eat  → Dog.eat     │  ← ПЕРЕОПРЕДЕЛЁН
  │ sleep → Animal.sleep│  ← УНАСЛЕДОВАН
  │ fetch → Dog.fetch   │  ← ДОБАВЛЕН
  └──────────────┘

animal.eat():
  1. Прочитать animal._classId → Dog
  2. Dog.vtable[eat] → Dog.eat
  3. Вызвать Dog.eat

super.eat():
  Прямой вызов Animal.eat (без vtable lookup)
```

### Linearization (порядок наследования)

```
class A {}
class B extends A {}
class C extends B {}

Цепочка: C → B → A → Object

Поиск метода: C.vtable → B.vtable → A.vtable → Object.vtable
(но реально vtable плоская — всё уже разрешено compile-time)
```

### Memory layout

```
var dog = Dog('Бобик', 'Лабрадор');

Heap:
  ┌───────────────────────┐
  │ _classId: Dog         │
  │ name: 'Бобик'         │  ← Поле Animal
  │ _energy: 100          │  ← Поле Animal
  │ breed: 'Лабрадор'     │  ← Поле Dog
  └───────────────────────┘

Поля родителя и потомка — в одном объекте, без вложенности.
```

## 7. Производительность и ресурсы

| Аспект                 | Стоимость                                     |
| ---------------------- | --------------------------------------------- |
| Наследование полей     | Zero cost — поля хранятся в одном объекте     |
| Вызов метода подкласса | vtable lookup (AOT часто devirtualizes)       |
| super.method()         | Прямой вызов (без vtable)                     |
| is / as                | Проверка цепочки типов (быстро, кешировано)   |
| Глубокая иерархия      | Больший vtable, но одинаковая скорость lookup |

**Рекомендации:**

- Избегайте иерархий глубже 3–4 уровней.
- `is` проверка — O(1) в AOT (кешированные type cids).
- AOT девиртуализирует >90% вызовов в типичном коде.

## 8. Частые ошибки и антипаттерны

### ❌ Забыли вызвать super конструктор

```dart
class Base {
  final int value;
  Base(this.value);
}

class Child extends Base {
  // ❌ Ошибка: The superclass 'Base' doesn't have
  //    a zero-argument constructor
  // Child();

  Child(int v) : super(v); // ✅
}
```

### ❌ Глубокое наследование вместо композиции

```dart
// ❌ Антипаттерн: God hierarchy
class Widget extends Component
    // extends UIElement extends Drawable extends Serializable ...

// ✅ Композиция:
class Widget {
  final Renderer renderer;
  final Serializer serializer;
  Widget(this.renderer, this.serializer);
}
```

### ❌ @override без аннотации

```dart
class Parent {
  void doWork() {}
}

class Child extends Parent {
  // ❌ Без @override — работает, но линтер предупреждает
  void doWork() {} // annotate_overrides lint

  // ✅ С аннотацией:
  @override
  void doWork() {}
}
```

### ❌ Нарушение принципа Лисков (LSP)

```dart
class Rectangle {
  double width, height;
  Rectangle(this.width, this.height);
  double get area => width * height;
}

// ❌ Square нарушает LSP:
class Square extends Rectangle {
  Square(double side) : super(side, side);

  @override
  set width(double v) {
    super.width = v;
    super.height = v; // Неожиданно меняет height!
  }
}

// В коде, ожидающем Rectangle, Square ведёт себя не так:
// rect.width = 5; rect.height = 10;
// rect.area → 50? Нет! 100 если Square!
```

## 9. Сравнение с альтернативами

| Аспект                     | Dart         | Java            | Kotlin          | Python             |
| -------------------------- | ------------ | --------------- | --------------- | ------------------ |
| Одиночное наследование     | ✅ `extends` | ✅ `extends`    | ✅ `:`          | ❌ (множественное) |
| Множественное наследование | ❌ (mixins)  | ❌ (interfaces) | ❌ (interfaces) | ✅ (MRO)           |
| super параметры            | ✅ (Dart 3)  | ❌              | ❌              | ❌                 |
| Smart cast (is)            | ✅           | ✅ (Java 16)    | ✅              | ❌ (isinstance)    |
| covariant                  | ✅           | ❌              | ❌              | ❌ (duck typing)   |
| sealed class               | ✅ (Dart 3)  | ✅ (Java 17)    | ✅              | ❌                 |

## 10. Когда НЕ стоит использовать

- **«Is-a» не подходит** — если подкласс не является разновидностью суперкласса → используйте композицию.
- **Наследование ради reuse** — нужны только 2 метода из 20? Используйте mixin или delegation.
- **Глубокие иерархии** — >3–4 уровня → трудно поддерживать.
- **Изменение контракта** — если подкласс нарушает LSP (меняет поведение, а не расширяет).
- **Кросс-библиотечное наследование непредназначенных классов** — Dart 3 модификаторы (`final`, `base`, `sealed`) могут запретить это.

## 11. Краткое резюме

1. **`extends`** — одиночное наследование; подкласс получает всё от суперкласса.
2. **`@override`** — переопределение метода; всегда ставьте аннотацию.
3. **`super`** — вызов конструктора или метода родителя.
4. **`super.param`** (Dart 3) — проброс параметров без boilerplate.
5. **`is` / `as`** — проверка и приведение типов; `is` делает smart cast.
6. **`covariant`** — разрешает сужение типа параметра в подклассе (runtime check).
7. **Принцип Лисков** — подкласс должен быть подстановочным; если нет → композиция.

---

> **Назад:** [7.3 Геттеры и сеттеры](07_03_getters_setters.md) · **Далее:** [7.5 Абстрактные классы и интерфейсы](07_05_abstract_interfaces.md)
