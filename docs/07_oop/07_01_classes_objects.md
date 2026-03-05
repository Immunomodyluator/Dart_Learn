# 7.1 Классы и объекты

## 1. Формальное определение

**Класс** — именованный тип, описывающий структуру (поля) и поведение (методы) объектов. Класс служит шаблоном для создания экземпляров.

**Объект** (экземпляр) — конкретная сущность, созданная по шаблону класса и размещённая в куче (heap).

В Dart **всё является объектом**: числа, строки, функции, `null` — все наследуют от `Object?`.

## 2. Зачем это нужно

- **Инкапсуляция** — объединение данных и логики в единый модуль с контролируемым доступом.
- **Моделирование предметной области** — класс `User`, `Order`, `Payment` отражают реальные сущности.
- **Повторное использование** — один класс → множество экземпляров.
- **Типизация** — компилятор проверяет, что `user.name` существует.
- **Полиморфизм** — разные классы реализуют один интерфейс.

## 3. Как это работает

### Объявление класса

```dart
class Point {
  // Поля (instance variables)
  double x;
  double y;

  // Конструктор (сокращённая форма)
  Point(this.x, this.y);

  // Метод экземпляра
  double distanceTo(Point other) {
    var dx = x - other.x;
    var dy = y - other.y;
    return (dx * dx + dy * dy).sqrt(); // import 'dart:math';
  }

  // Переопределение toString
  @override
  String toString() => 'Point($x, $y)';
}
```

### Создание объектов

```dart
void main() {
  // new не обязателен с Dart 2
  var p1 = Point(1, 2);
  var p2 = Point(3, 4);

  print(p1);             // Point(1.0, 2.0)
  print(p1.x);           // 1.0
  print(p1.distanceTo(p2));

  // Тип указан явно
  Point p3 = Point(0, 0);
}
```

### Поля: инициализация и доступ

```dart
class User {
  // Финальные поля — устанавливаются один раз
  final String name;
  final String email;

  // Поле с значением по умолчанию
  int loginCount = 0;

  // Late — инициализация отложена
  late final DateTime lastLogin;

  // Приватное поле (начинается с _)
  // Приватность в Dart — на уровне БИБЛИОТЕКИ, не класса
  String _passwordHash = '';

  User(this.name, this.email);
}

void main() {
  var user = User('Alice', 'alice@example.com');
  print(user.name);       // Alice
  user.loginCount++;      // Мутируемое поле
  // user.name = 'Bob';   // ❌ Ошибка: final поле
  // user._passwordHash;  // ✅ В той же библиотеке — доступно!
}
```

### Методы

```dart
class Counter {
  int _value = 0;

  // Метод без возвращаемого значения
  void increment() {
    _value++;
  }

  // Метод с возвращаемым значением
  int get value => _value;

  // Метод с параметрами
  void incrementBy(int amount) {
    _value += amount;
  }

  // Каскадный паттерн: возврат this
  Counter tap(void Function(int) action) {
    action(_value);
    return this;
  }
}
```

### this — ссылка на текущий экземпляр

```dart
class Rectangle {
  double width;
  double height;

  // this в конструкторе — разрешение конфликта имён
  Rectangle({required this.width, required this.height});

  // this в методе
  bool contains(Rectangle other) {
    return width >= other.width && height >= other.height;
  }

  // this для каскадов
  Rectangle scale(double factor) {
    width *= factor;
    height *= factor;
    return this; // Для chaining: rect.scale(2).scale(3)
  }
}
```

### Каскадный оператор (`..`)

```dart
class Builder {
  String? title;
  String? body;
  int priority = 0;

  void send() => print('Sending: $title / $body (p=$priority)');
}

void main() {
  // Без каскадов:
  var b1 = Builder();
  b1.title = 'Hello';
  b1.body = 'World';
  b1.priority = 1;
  b1.send();

  // С каскадами — чище:
  Builder()
    ..title = 'Hello'
    ..body = 'World'
    ..priority = 1
    ..send();

  // ?.. — null-aware cascade (Dart 2.12+)
  Builder? maybeNull;
  maybeNull
    ?..title = 'test'
    ..send(); // Не выполнится если maybeNull == null
}
```

### Оператор сравнения и hashCode

```dart
class Coordinate {
  final int x;
  final int y;

  const Coordinate(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coordinate && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

void main() {
  var a = Coordinate(1, 2);
  var b = Coordinate(1, 2);

  print(a == b);           // true (по значению)
  print(identical(a, b));  // false (разные объекты)

  var set = {a, b};
  print(set.length);       // 1 (одинаковый hashCode)
}
```

## 4. Минимальный пример

```dart
class Dog {
  final String name;
  int age;

  Dog(this.name, this.age);

  void bark() => print('$name: Гав!');

  @override
  String toString() => 'Dog($name, $age лет)';
}

void main() {
  var dog = Dog('Бобик', 3);
  dog.bark();       // Бобик: Гав!
  print(dog);       // Dog(Бобик, 3 лет)
  dog.age++;
  print(dog.age);   // 4
}
```

## 5. Практический пример

### Мини-банковский аккаунт

```dart
import 'dart:math';

/// Банковский счёт с историей операций
class BankAccount {
  final String id;
  final String owner;
  double _balance;
  final List<Transaction> _history = [];

  BankAccount({
    required this.owner,
    double initialBalance = 0,
  })  : id = _generateId(),
        _balance = initialBalance {
    if (initialBalance > 0) {
      _history.add(Transaction('Начальный баланс', initialBalance));
    }
  }

  // Публичный доступ только на чтение
  double get balance => _balance;
  List<Transaction> get history => List.unmodifiable(_history);

  /// Пополнение
  void deposit(double amount) {
    if (amount <= 0) throw ArgumentError('Сумма должна быть > 0');
    _balance += amount;
    _history.add(Transaction('Пополнение', amount));
  }

  /// Снятие
  bool withdraw(double amount) {
    if (amount <= 0) throw ArgumentError('Сумма должна быть > 0');
    if (amount > _balance) return false; // Недостаточно средств

    _balance -= amount;
    _history.add(Transaction('Снятие', -amount));
    return true;
  }

  /// Перевод на другой счёт
  bool transferTo(BankAccount other, double amount) {
    if (!withdraw(amount)) return false;
    other.deposit(amount);
    _history.last = Transaction('Перевод → ${other.id}', -amount);
    other._history.last = Transaction('Перевод ← $id', amount);
    return true;
  }

  static String _generateId() {
    var rng = Random();
    return 'ACC-${rng.nextInt(999999).toString().padLeft(6, '0')}';
  }

  @override
  String toString() => 'BankAccount($id, $owner, ${_balance.toStringAsFixed(2)} ₽)';
}

class Transaction {
  final String description;
  final double amount;
  final DateTime timestamp;

  Transaction(this.description, this.amount)
      : timestamp = DateTime.now();

  @override
  String toString() =>
      '${timestamp.toIso8601String().substring(0, 19)} | '
      '${amount >= 0 ? "+" : ""}${amount.toStringAsFixed(2)} ₽ | $description';
}

void main() {
  var alice = BankAccount(owner: 'Alice', initialBalance: 1000);
  var bob = BankAccount(owner: 'Bob');

  alice.deposit(500);
  alice.transferTo(bob, 300);

  print(alice);         // BankAccount(ACC-..., Alice, 1200.00 ₽)
  print(bob);           // BankAccount(ACC-..., Bob, 300.00 ₽)

  print('\n--- История Alice ---');
  for (final tx in alice.history) {
    print(tx);
  }
}
```

## 6. Что происходит под капотом

### Объект в памяти

```
var p = Point(1, 2);

Stack (переменная p):
  ┌──────────┐
  │ ref: ──→ │
  └──────────┘

Heap (объект):
  ┌─────────────────────────┐
  │ _classId: Point         │  ← Указатель на описание класса
  │ _hashCode: ...          │
  │ x: 1.0                  │  ← Instance variable
  │ y: 2.0                  │  ← Instance variable
  └─────────────────────────┘

Описание класса (Class object):
  ┌─────────────────────────┐
  │ name: "Point"           │
  │ superclass: Object      │
  │ methods: [distanceTo, toString, ...]
  │ vtable: [...]           │  ← Виртуальная таблица методов
  └─────────────────────────┘
```

### Приватность

```
В Dart приватность — на уровне БИБЛИОТЕКИ (файла / part'ов),
а не класса!

library my_lib;

class A {
  int _private = 1;
}

class B {
  void read(A a) {
    print(a._private); // ✅ Доступно! Та же библиотека
  }
}

// Из другой библиотеки:
// a._private → ❌ Ошибка компиляции
```

### Dispatch методов

```
Dart использует single dispatch:
метод выбирается по типу ПОЛУЧАТЕЛЯ (this), не аргументов.

obj.method(arg)
      │
      ▼
obj._classId → vtable → method code

AOT компилятор часто девиртуализирует вызовы:
если тип known → прямой вызов вместо vtable lookup.
```

## 7. Производительность и ресурсы

| Аспект                  | Стоимость                               |
| ----------------------- | --------------------------------------- |
| Создание объекта        | Аллокация в heap + инициализация полей  |
| Доступ к полю           | Direct offset (как struct field)        |
| Вызов метода            | vtable lookup (часто devirtualized AOT) |
| `identical()`           | Сравнение указателей — O(1)             |
| `==` (переопределённый) | Зависит от реализации                   |

**Рекомендации:**

- Используйте `const` конструкторы для неизменяемых объектов (canonical instances).
- Для value-типов переопределяйте `==` и `hashCode`.
- Dart VM эффективно аллоцирует — не бойтесь создавать объекты.

## 8. Частые ошибки и антипаттерны

### ❌ Забытая инициализация non-nullable поля

```dart
class Bad {
  String name; // ❌ Non-nullable, но нет инициализации!
  // Ошибка компиляции: non-nullable field must be initialized
}

class Good {
  String name;
  Good(this.name); // ✅

  // Или:
  // String name = 'default';
  // late String name; // Инициализируется позже
}
```

### ❌ Мутация private полей из той же библиотеки

```dart
class Config {
  int _maxRetries = 3; // «Приватное»
}

void main() {
  var c = Config();
  c._maxRetries = 999; // ✅ Работает! Та же библиотека

  // Решение: вынести класс в отдельный файл/библиотеку
}
```

### ❌ Забытый hashCode при переопределении ==

```dart
class Item {
  final int id;
  Item(this.id);

  @override
  bool operator ==(Object other) => other is Item && id == other.id;

  // ❌ Забыли hashCode!
  // Set и Map будут работать НЕПРАВИЛЬНО

  // ✅ Обязательно:
  @override
  int get hashCode => id.hashCode;
}
```

### ❌ Каскад вместо возвращаемого значения

```dart
// ПЛОХО: каскад не работает как выражение в return
// return list..add(item); // Вернёт list, не результат add()

// Каскад возвращает ПОЛУЧАТЕЛЬ, не результат метода!
var result = [1, 2]..add(3);
print(result); // [1, 2, 3] — Вернулся list, а не void
```

## 9. Сравнение с альтернативами

| Аспект             | Dart             | Java                 | Kotlin                 | TypeScript      |
| ------------------ | ---------------- | -------------------- | ---------------------- | --------------- |
| Всё — объект       | ✅               | ❌ (примитивы)       | ✅                     | ❌              |
| `new` обязателен   | Нет (с Dart 2)   | Да                   | Нет                    | Да              |
| Приватность        | Библиотека (`_`) | Класс (`private`)    | Класс (`private`)      | Нет runtime     |
| Data classes       | Нет (вручную)    | Нет (record Java 16) | ✅ `data class`        | Нет             |
| `==` по умолчанию  | Identity         | Identity             | Identity (data: value) | Identity        |
| Каскады (`..`)     | ✅               | ❌                   | ✅ (`apply`)           | ❌              |
| Implicit interface | ✅               | ❌                   | ❌                     | ✅ (structural) |

## 10. Когда НЕ стоит использовать

- **Простые данные без поведения** — рассмотрите `Record` (Dart 3): `(String, int)` вместо класса с двумя полями.
- **Одноразовая группировка** — Map или record вместо класса.
- **Статические утилиты** — top-level функции читабельнее, чем класс со `static` методами.
- **Enum с фиксированным набором** — `enum` вместо класса с константами.

## 11. Краткое резюме

1. **Класс** — шаблон: поля (данные) + методы (поведение).
2. **Всё — объект** — даже `int`, `null` и функции.
3. **`_` prefix** — приватность на уровне библиотеки, не класса.
4. **`..` каскад** — цепочка вызовов на одном объекте.
5. **`==` и `hashCode`** — переопределяйте ВМЕСТЕ для value-семантики.
6. **`this`** — ссылка на текущий экземпляр; используется в конструкторах и для снятия неоднозначности.
7. **`const` конструкторы** — канонические экземпляры (один объект в памяти).

---

> **Назад:** [7.0 Обзор](07_00_overview.md) · **Далее:** [7.2 Конструкторы](07_02_constructors.md)
