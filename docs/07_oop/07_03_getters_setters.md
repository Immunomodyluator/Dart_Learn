# 7.3 Геттеры и сеттеры

## 1. Формальное определение

**Геттер** (`get`) — специальный метод без параметров, вызываемый при чтении свойства. Синтаксически выглядит как обращение к полю.

**Сеттер** (`set`) — специальный метод с одним параметром, вызываемый при присвоении значения свойству.

Вместе они реализуют **вычисляемые свойства** — интерфейс поля с логикой метода.

```dart
class Circle {
  double radius;
  Circle(this.radius);

  // Геттер — вычисляемое свойство
  double get area => 3.14159 * radius * radius;

  // Сеттер — обратное вычисление
  set area(double value) => radius = (value / 3.14159).sqrt();
}
```

## 2. Зачем это нужно

- **Вычисляемые свойства** — `area` вычисляется из `radius` без хранения.
- **Валидация** — сеттер проверяет значение перед присвоением.
- **Инкапсуляция** — публичный get + приватное хранение.
- **Ленивая инициализация** — вычисление при первом обращении.
- **API стабильность** — переход от поля к геттеру не ломает вызывающий код.

## 3. Как это работает

### Неявные геттеры и сеттеры

```dart
class User {
  String name;     // → Dart генерирует get name и set name
  final int id;    // → Dart генерирует ТОЛЬКО get id (final)

  User(this.name, this.id);
}

void main() {
  var u = User('Alice', 1);
  print(u.name);   // Вызывает неявный getter
  u.name = 'Bob';  // Вызывает неявный setter
  print(u.id);     // Вызывает неявный getter
  // u.id = 2;     // ❌ Нет setter'а для final поля
}
```

### Явный геттер

```dart
class Temperature {
  double _celsius;

  Temperature(this._celsius);

  // Геттер — вычисляемое свойство
  double get fahrenheit => _celsius * 9 / 5 + 32;
  double get kelvin => _celsius + 273.15;

  // Геттер как обёртка над приватным полем
  double get celsius => _celsius;
}

void main() {
  var t = Temperature(100);
  print(t.celsius);     // 100.0
  print(t.fahrenheit);  // 212.0
  print(t.kelvin);      // 373.15
}
```

### Явный сеттер с валидацией

```dart
class Account {
  String _email = '';
  int _age = 0;

  String get email => _email;
  set email(String value) {
    if (!value.contains('@')) {
      throw FormatException('Некорректный email: $value');
    }
    _email = value;
  }

  int get age => _age;
  set age(int value) {
    if (value < 0 || value > 150) {
      throw RangeError.range(value, 0, 150, 'age');
    }
    _age = value;
  }
}

void main() {
  var acc = Account();
  acc.email = 'alice@test.com';  // ✅
  acc.age = 25;                  // ✅

  // acc.email = 'invalid';      // ❌ FormatException
  // acc.age = -5;               // ❌ RangeError
}
```

### Read-only свойство (только getter)

```dart
class Stopwatch {
  final DateTime _startTime = DateTime.now();

  // Только getter — нельзя установить снаружи
  Duration get elapsed => DateTime.now().difference(_startTime);

  String get formatted {
    var d = elapsed;
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
```

### Write-only свойство (только setter)

```dart
class PasswordManager {
  String _hash = '';

  // Только setter — пароль можно задать, но не прочитать
  set password(String plain) {
    _hash = _computeHash(plain);
  }

  bool verify(String attempt) => _computeHash(attempt) == _hash;

  String _computeHash(String input) => input.hashCode.toRadixString(16);
}

void main() {
  var pm = PasswordManager();
  pm.password = 'secret123'; // Write-only!
  // print(pm.password);     // ❌ Нет getter'а

  print(pm.verify('secret123')); // true
  print(pm.verify('wrong'));     // false
}
```

### Ленивое вычисление через getter

```dart
class Config {
  final Map<String, String> _raw;

  Config(this._raw);

  // Вычисляется каждый раз
  int get port => int.parse(_raw['PORT'] ?? '8080');

  // Кешированное ленивое значение
  late final String host = _raw['HOST'] ?? 'localhost';
  // ↑ late final + initializer → вычисляется один раз при первом обращении
}
```

### Getter/setter в абстрактном классе

```dart
abstract class Measurable {
  // Абстрактные get/set — контракт для подклассов
  double get length;
  set length(double value);
}

class Segment implements Measurable {
  double _start;
  double _end;

  Segment(this._start, this._end);

  @override
  double get length => (_end - _start).abs();

  @override
  set length(double value) {
    _end = _start + value;
  }
}
```

## 4. Минимальный пример

```dart
class Square {
  double side;

  Square(this.side);

  double get area => side * side;
  double get perimeter => 4 * side;

  set area(double value) => side = value.sqrt();
}

void main() {
  var s = Square(5);
  print(s.area);      // 25.0
  print(s.perimeter); // 20.0

  s.area = 16;        // Обратное вычисление через setter
  print(s.side);      // 4.0
}
```

## 5. Практический пример

### ViewModel с реактивными свойствами

```dart
typedef Listener = void Function();

/// Простая реактивная модель
class ObservableModel {
  final _listeners = <Listener>[];

  void addListener(Listener l) => _listeners.add(l);
  void removeListener(Listener l) => _listeners.remove(l);
  void _notify() {
    for (final l in _listeners) {
      l();
    }
  }
}

class UserProfile extends ObservableModel {
  String _name;
  String _email;
  DateTime? _lastModified;

  UserProfile({required String name, required String email})
      : _name = name,
        _email = email;

  // --- Геттеры ---

  String get name => _name;
  String get email => _email;
  DateTime? get lastModified => _lastModified;

  // Вычисляемое свойство
  String get displayName {
    var parts = _name.split(' ');
    if (parts.length >= 2) {
      return '${parts.first} ${parts.last[0]}.';
    }
    return _name;
  }

  String get initials {
    return _name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join();
  }

  bool get isComplete => _name.isNotEmpty && _email.contains('@');

  // --- Сеттеры с валидацией и уведомлением ---

  set name(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError('Имя не может быть пустым');
    }
    if (_name != value) {
      _name = value.trim();
      _lastModified = DateTime.now();
      _notify(); // Уведомляем слушателей
    }
  }

  set email(String value) {
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(value)) {
      throw FormatException('Некорректный email: $value');
    }
    if (_email != value) {
      _email = value;
      _lastModified = DateTime.now();
      _notify();
    }
  }

  @override
  String toString() => 'UserProfile($displayName, $email)';
}

void main() {
  var profile = UserProfile(name: 'Иван Петров', email: 'ivan@test.ru');

  // Подписка на изменения
  profile.addListener(() {
    print('Профиль изменён: $profile');
  });

  print(profile.displayName); // Иван П.
  print(profile.initials);    // ИП
  print(profile.isComplete);  // true

  profile.name = 'Анна Сидорова'; // → "Профиль изменён: ..."
  profile.email = 'anna@test.ru'; // → "Профиль изменён: ..."

  // profile.email = 'invalid'; // ❌ FormatException
}
```

## 6. Что происходит под капотом

### Поле vs getter/setter

```
// Обычное поле:
class A {
  int x = 0;
}

Компилятор генерирует:
  - Slot для хранения x в объекте
  - Неявный get x → return slot
  - Неявный set x(int v) → slot = v

// Явный getter:
class B {
  int get x => computeX();  // Нет slot'а! Вычисляется каждый раз.
}

Снаружи A.x и B.x выглядят ОДИНАКОВО.
Это позволяет менять реализацию без изменения API.
```

### Inline оптимизация

```
var c = Circle(5);
print(c.area); // AOT может inline:
               // print(3.14159 * c.radius * c.radius);
               // Никакого вызова метода!

Простые getters (без side effects) → inlined компилятором.
```

### Приоритет setter vs поле

```
class Demo {
  int _x = 0;

  int get x => _x;
  set x(int v) {
    print('setter called');
    _x = v;
  }
}

// demo.x = 5 → вызывает SET x, не пишет напрямую в поле
// Setter ЗАМЕНЯЕТ неявный setter для _x
```

## 7. Производительность и ресурсы

| Аспект               | Стоимость                                            |
| -------------------- | ---------------------------------------------------- |
| Неявный get/set      | Прямой доступ к полю (inlined)                       |
| Простой явный get    | Inlined в release → = прямой доступ                  |
| Getter с вычислением | Зависит от сложности вычисления                      |
| Setter с валидацией  | Overhead проверки при каждом присвоении              |
| `late final` getter  | Один раз вычисление + bool check «инициализировано?» |

**Рекомендации:**

- Простые getters — бесплатны (inlined).
- Тяжёлые вычисления в getter → кешируйте (`late final` или ручной кеш).
- Не ставьте тяжёлую логику в setter — неожиданно для вызывающего.

## 8. Частые ошибки и антипаттерны

### ❌ Тяжёлая логика в getter

```dart
class Bad {
  // ❌ Каждый вызов .items перестраивает список!
  List<Item> get items {
    var result = <Item>[];
    for (var raw in _rawData) {
      result.add(Item.parse(raw)); // Парсинг каждый раз!
    }
    return result;
  }
}

class Good {
  late final List<Item> items = [
    for (var raw in _rawData) Item.parse(raw),
  ]; // Вычисляется ОДИН раз
}
```

### ❌ Побочные эффекты в getter

```dart
class Bad {
  int _count = 0;

  // ❌ Getter меняет состояние!
  int get count => _count++; // Каждый доступ инкрементирует

  // Пользователь ожидает: print(obj.count) — безопасно
  // Реальность: каждый print увеличивает count
}
```

### ❌ Рассогласованные get/set типы

```dart
// В Dart get и set для одного имени должны иметь совместимые типы:
class Demo {
  int get value => 42;
  // set value(String v) {} // ❌ int vs String — ошибка компиляции!
  set value(int v) {}       // ✅ Совпадающий тип
}
```

### ❌ Getter возвращает мутабельную внутреннюю коллекцию

```dart
class Bad {
  final _items = <String>['a', 'b'];
  List<String> get items => _items; // ❌ Внешний код может мутировать!
}

class Good {
  final _items = <String>['a', 'b'];
  List<String> get items => List.unmodifiable(_items); // ✅ Копия/обёртка
}
```

## 9. Сравнение с альтернативами

| Аспект              | Dart get/set            | Java                 | Kotlin                         | C#                 | Python      |
| ------------------- | ----------------------- | -------------------- | ------------------------------ | ------------------ | ----------- |
| Синтаксис           | `get x =>` / `set x(v)` | `getX()` / `setX(v)` | `val x get()` / `var x set(v)` | `{ get; set; }`    | `@property` |
| Вызов               | `obj.x`                 | `obj.getX()`         | `obj.x`                        | `obj.X`            | `obj.x`     |
| Неявные             | ✅ для полей            | ❌                   | ✅ для полей                   | ✅ auto-properties | ❌          |
| Переход поле→getter | Прозрачный              | Ломает API           | Прозрачный                     | Прозрачный         | `@property` |

В Java переход от поля к getter/setter ломает API (`obj.x` → `obj.getX()`). В Dart, Kotlin и C# — прозрачная замена.

## 10. Когда НЕ стоит использовать

- **Getter с побочными эффектами** — getter должен быть чистым; для side effects → метод.
- **Тяжёлые вычисления без кеша** — если вычисление дорогое, используйте `late final` или метод `computeX()`.
- **Setter без getter** — write-only свойства сбивают с толку; допустимо только для `password`-подобных случаев.
- **Замена метода с глаголом** — `user.save` как getter? Нет. Это действие → метод `user.save()`.

## 11. Краткое резюме

1. **Неявные get/set** — Dart генерирует для каждого поля.
2. **Явный getter** — `T get name => expr;` для вычисляемых свойств.
3. **Явный setter** — `set name(T v) { ... }` для валидации и реактивности.
4. **Прозрачная замена** — переход от поля к getter/setter не ломает API.
5. **Getter без setter** — read-only свойство.
6. **Getter не должен иметь side effects** — это нарушает ожидания пользователя API.
7. **Кешируйте тяжёлые getter** — `late final` или ручной кеш.

---

> **Назад:** [7.2 Конструкторы](07_02_constructors.md) · **Далее:** [7.4 Наследование и super](07_04_inheritance.md)
