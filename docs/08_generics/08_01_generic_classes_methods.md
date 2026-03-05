# 8.1 Обобщённые классы и методы

## 1. Формальное определение

**Обобщение** (generic) — параметризация класса, метода или функции одним или несколькими типовыми параметрами (`<T>`, `<K, V>`). Позволяет писать код, работающий с любым типом, сохраняя типобезопасность.

**Типовой параметр** — placeholder для конкретного типа, подставляемого при использовании: `List<int>`, `Map<String, dynamic>`.

## 2. Зачем это нужно

- **Типобезопасность** — `List<int>` гарантирует, что в списке только `int`.
- **Повторное использование** — один класс `Box<T>` вместо `IntBox`, `StringBox`, `UserBox`.
- **Выразительные API** — `Future<User>`, `Stream<Event>`, `Either<Error, Value>`.
- **Отсутствие приведений** — без generic: `(list[0] as int)`; с generic: `list[0]` — уже `int`.
- **Документирование намерения** — тип говорит, что ожидается.

## 3. Как это работает

### Generic класс

```dart
class Box<T> {
  T value;

  Box(this.value);

  /// Преобразует содержимое
  Box<R> map<R>(R Function(T) transform) {
    return Box<R>(transform(value));
  }

  @override
  String toString() => 'Box<$T>($value)';
}

void main() {
  var intBox = Box<int>(42);
  var strBox = Box<String>('hello');

  print(intBox);  // Box<int>(42)
  print(strBox);  // Box<String>(hello)

  // map: Box<int> → Box<String>
  var mapped = intBox.map((v) => 'Число: $v');
  print(mapped);  // Box<String>(Число: 42)

  // Вывод типа (inference)
  var inferred = Box(3.14); // Box<double>
  print(inferred.runtimeType); // Box<double>
}
```

### Несколько типовых параметров

```dart
class Pair<A, B> {
  final A first;
  final B second;

  const Pair(this.first, this.second);

  /// Меняет элементы местами
  Pair<B, A> swap() => Pair(second, first);

  /// Применяет функцию к обоим элементам
  Pair<A2, B2> bimap<A2, B2>(
    A2 Function(A) mapFirst,
    B2 Function(B) mapSecond,
  ) {
    return Pair(mapFirst(first), mapSecond(second));
  }

  @override
  String toString() => '($first, $second)';
}

void main() {
  var pair = Pair('Alice', 30);
  print(pair);          // (Alice, 30)
  print(pair.swap());   // (30, Alice)

  var mapped = pair.bimap(
    (name) => name.toUpperCase(),
    (age) => age + 1,
  );
  print(mapped); // (ALICE, 31)
}
```

### Generic методы и функции

```dart
// Generic функция (top-level)
T firstWhere<T>(List<T> list, bool Function(T) test, {T? orElse}) {
  for (final item in list) {
    if (test(item)) return item;
  }
  if (orElse != null) return orElse;
  throw StateError('Не найден');
}

// Generic метод в обычном (не generic) классе
class Utils {
  /// Создаёт Map из двух списков
  static Map<K, V> zip<K, V>(List<K> keys, List<V> values) {
    var result = <K, V>{};
    for (var i = 0; i < keys.length && i < values.length; i++) {
      result[keys[i]] = values[i];
    }
    return result;
  }
}

void main() {
  var names = ['a', 'b', 'c'];
  var nums = [1, 2, 3];

  var map = Utils.zip(names, nums); // Map<String, int>
  print(map); // {a: 1, b: 2, c: 3}

  var found = firstWhere([10, 20, 30], (x) => x > 15);
  print(found); // 20
}
```

### Generic в коллекциях

```dart
void main() {
  // Все стандартные коллекции — generic
  List<int> numbers = [1, 2, 3];
  Set<String> names = {'Alice', 'Bob'};
  Map<String, int> ages = {'Alice': 30, 'Bob': 25};

  // Вложенные generics
  List<List<int>> matrix = [
    [1, 2, 3],
    [4, 5, 6],
  ];

  Map<String, List<int>> scores = {
    'math': [90, 85, 92],
    'physics': [78, 88, 95],
  };

  // Literal inference
  var inferred = [1, 2, 3]; // List<int>
  var mixed = [1, 'two'];   // List<Object>
}
```

### Generic конструкторы

```dart
class Cache<T> {
  final Map<String, T> _store = {};
  final Duration ttl;

  Cache({this.ttl = const Duration(minutes: 5)});

  // Именованный конструктор — тип T наследуется от класса
  Cache.noExpiry() : ttl = const Duration(days: 365 * 100);

  void set(String key, T value) => _store[key] = value;
  T? get(String key) => _store[key];
}

void main() {
  var cache = Cache<String>(ttl: Duration(hours: 1));
  cache.set('greeting', 'Hello');
  print(cache.get('greeting')); // Hello

  // cache.set('num', 42); // ❌ int нельзя в Cache<String>
}
```

### Generic mixin

```dart
mixin Observable<T> {
  final _listeners = <void Function(T)>[];

  void addListener(void Function(T) listener) {
    _listeners.add(listener);
  }

  void notify(T event) {
    for (final l in _listeners) {
      l(event);
    }
  }
}

class Counter with Observable<int> {
  int _value = 0;

  void increment() {
    _value++;
    notify(_value); // Уведомляет с int
  }
}

void main() {
  var counter = Counter();
  counter.addListener((value) => print('Счётчик: $value'));
  counter.increment(); // Счётчик: 1
  counter.increment(); // Счётчик: 2
}
```

### Generic extension

```dart
extension ListUtils<T> on List<T> {
  /// Безопасный доступ по индексу
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// Разбиение на пары
  List<(T, T)> pairs() {
    var result = <(T, T)>[];
    for (var i = 0; i < length - 1; i += 2) {
      result.add((this[i], this[i + 1]));
    }
    return result;
  }
}

void main() {
  var list = [1, 2, 3, 4, 5];
  print(list.getOrNull(10)); // null
  print(list.pairs());       // [(1, 2), (3, 4)]
}
```

### Reified generics — тип доступен в runtime

```dart
void printType<T>(T value) {
  print('Значение: $value');
  print('T = $T');
  print('value is T: ${value is T}');
}

void checkList(Object obj) {
  // В Java это НЕВОЗМОЖНО (type erasure)!
  if (obj is List<int>) {
    print('Список int, сумма: ${obj.reduce((a, b) => a + b)}');
  } else if (obj is List<String>) {
    print('Список строк: ${obj.join(", ")}');
  }
}

void main() {
  printType<int>(42);
  // Значение: 42
  // T = int
  // value is T: true

  checkList([1, 2, 3]);        // Список int, сумма: 6
  checkList(['a', 'b', 'c']); // Список строк: a, b, c
}
```

## 4. Минимальный пример

```dart
class Stack<T> {
  final _items = <T>[];

  void push(T item) => _items.add(item);
  T pop() => _items.removeLast();
  T get peek => _items.last;
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;
}

void main() {
  var stack = Stack<int>();
  stack.push(1);
  stack.push(2);
  stack.push(3);

  while (!stack.isEmpty) {
    print(stack.pop()); // 3, 2, 1
  }
}
```

## 5. Практический пример

### Result type (Either)

```dart
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

// Extension для ergonomic API
extension ResultOps<T> on Result<T> {
  /// Преобразование значения
  Result<R> map<R>(R Function(T) f) => switch (this) {
    Ok(:final value) => Ok(f(value)),
    Err(:final error) => Err(error),
  };

  /// Цепочка операций
  Result<R> flatMap<R>(Result<R> Function(T) f) => switch (this) {
    Ok(:final value) => f(value),
    Err(:final error) => Err(error),
  };

  /// Значение или fallback
  T getOrElse(T Function() fallback) => switch (this) {
    Ok(:final value) => value,
    Err() => fallback(),
  };

  /// Значение или throw
  T getOrThrow() => switch (this) {
    Ok(:final value) => value,
    Err(:final error) => throw Exception(error),
  };

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;
}

// Использование
Result<int> parseInt(String s) {
  var value = int.tryParse(s);
  if (value == null) return Err('Не число: $s');
  return Ok(value);
}

Result<double> divide(int a, int b) {
  if (b == 0) return Err('Деление на ноль');
  return Ok(a / b);
}

void main() {
  // Цепочка операций
  var result = parseInt('42')
      .flatMap((n) => divide(n, 7))
      .map((d) => d.toStringAsFixed(2));

  print(result.getOrElse(() => 'ошибка')); // 6.00

  // Ошибка в цепочке
  var err = parseInt('abc')
      .flatMap((n) => divide(n, 7))
      .map((d) => d.toStringAsFixed(2));

  print(err.getOrElse(() => 'ошибка')); // ошибка
}
```

### Generic Repository

```dart
abstract class Repository<T, ID> {
  Future<T?> findById(ID id);
  Future<List<T>> findAll();
  Future<T> save(T entity);
  Future<bool> deleteById(ID id);
}

class InMemoryRepository<T, ID> implements Repository<T, ID> {
  final _store = <ID, T>{};
  final ID Function(T) _getId;

  InMemoryRepository(this._getId);

  @override
  Future<T?> findById(ID id) async => _store[id];

  @override
  Future<List<T>> findAll() async => _store.values.toList();

  @override
  Future<T> save(T entity) async {
    _store[_getId(entity)] = entity;
    return entity;
  }

  @override
  Future<bool> deleteById(ID id) async => _store.remove(id) != null;
}

class User {
  final int id;
  final String name;
  User(this.id, this.name);

  @override
  String toString() => 'User($id, $name)';
}

Future<void> main() async {
  var repo = InMemoryRepository<User, int>((u) => u.id);

  await repo.save(User(1, 'Alice'));
  await repo.save(User(2, 'Bob'));

  var all = await repo.findAll();
  print(all); // [User(1, Alice), User(2, Bob)]

  var found = await repo.findById(1);
  print(found); // User(1, Alice)
}
```

## 6. Что происходит под капотом

### Reified vs Erased generics

```
Java (Type Erasure):
  List<int> list = new ArrayList<>();
  list instanceof List<int>  → ОШИБКА! Невозможно в runtime

Dart (Reified):
  var list = <int>[1, 2, 3];
  list is List<int>    → true   ✅
  list is List<String> → false  ✅
  list is List<Object> → true   ✅ (ковариантность)

Dart хранит типовой аргумент в объекте:
  ┌─────────────────────────┐
  │ _classId: _GrowableList │
  │ _typeArgs: [int]         │ ← Reified!
  │ _length: 3               │
  │ _data: [1, 2, 3]         │
  └─────────────────────────┘
```

### Monomorphization vs shared code

```
Dart НЕ делает monomorphization (в отличие от C++/Rust).
Один скомпилированный код для Box<int> и Box<String>.

Box<T>:
  - Поля хранятся как Object? внутри
  - Type argument хранится отдельно для runtime проверок
  - Компилятор вставляет casts при необходимости

AOT оптимизации:
  - Если T known → inline + devirtualize
  - Если T = int и AOT видит это → может unbox
```

### Type inference

```dart
var list = [1, 2, 3];
// Компилятор:
// 1. Элементы: 1(int), 2(int), 3(int)
// 2. LUB (Least Upper Bound) = int
// 3. Тип = List<int>

var mixed = [1, 'two', 3.0];
// LUB(int, String, double) = Object
// Тип = List<Object>
```

## 7. Производительность и ресурсы

| Аспект                 | Стоимость                              |
| ---------------------- | -------------------------------------- |
| Generic class instance | +1 слот для type args                  |
| `is T` проверка        | Type comparison (быстро, reified)      |
| Generic method call    | Передача type arg (может быть inlined) |
| Reification            | Небольшой memory overhead vs erasure   |
| Inference              | Compile-time only, zero runtime cost   |

**Рекомендации:**

- Generics дешёвые — не избегайте их ради «экономии».
- Reified generics позволяют runtime проверки; используйте `is List<int>`.
- На AOT type arguments часто optimized away если не используются.

## 8. Частые ошибки и антипаттерны

### ❌ dynamic вместо generic

```dart
// ❌ Потеря типобезопасности
class BadBox {
  dynamic value;
  BadBox(this.value);
}

var box = BadBox(42);
String s = box.value; // Runtime error!

// ✅ Generic
class GoodBox<T> {
  T value;
  GoodBox(this.value);
}

var box2 = GoodBox(42);
// String s = box2.value; // ❌ Ошибка КОМПИЛЯЦИИ!
```

### ❌ Ненужная явная типизация

```dart
// ❌ Redundant type arguments
List<int> list = <int>[1, 2, 3];
Map<String, int> map = <String, int>{'a': 1};

// ✅ Inference работает:
var list = [1, 2, 3];          // List<int>
var map = {'a': 1};            // Map<String, int>
```

### ❌ Raw type (без параметра)

```dart
// ❌ Raw type → List<dynamic>
List list = [1, 'two', 3.0]; // List<dynamic>!

// ✅ Явный тип
List<Object> list = [1, 'two', 3.0];
// или
var list = <Object>[1, 'two', 3.0];
```

### ❌ toString() вместо T

```dart
// ❌ Строковая проверка типа
void process(Object value) {
  if (value.runtimeType.toString() == 'int') { ... } // Хрупко!
}

// ✅ Generic + is
void process<T>(T value) {
  if (value is int) { ... }
}
```

## 9. Сравнение с альтернативами

| Аспект       | Dart              | Java               | C#                | TypeScript            | Rust               |
| ------------ | ----------------- | ------------------ | ----------------- | --------------------- | ------------------ |
| Generics     | Reified           | Erased             | Reified           | Erased (compile only) | Monomorphized      |
| Runtime is   | ✅ `is List<int>` | ❌                 | ✅ `is List<int>` | ❌                    | ❌ (no reflection) |
| Inference    | ✅                | ✅ (Java 10 `var`) | ✅                | ✅                    | ✅                 |
| Variance     | Runtime covariant | Use-site           | Declaration-site  | Structural            | Traits             |
| Default type | ❌                | ❌                 | ❌                | ✅ `<T = string>`     | ✅                 |

## 10. Когда НЕ стоит использовать

- **Один конкретный тип** — если класс работает только с `String`, не делайте `<T>`.
- **Слишком глубокая вложенность** — `Map<String, List<Map<int, Set<T>>>>` — нечитаемо; вводите typedef.
- **Generic ради generic** — не параметризуйте, если нет реального reuse.

## 11. Краткое резюме

1. **`<T>`** — типовой параметр: `class Box<T>`, `T find<T>(...)`.
2. **Reified** — типовой аргумент живёт в runtime: `obj is List<int>` работает.
3. **Inference** — компилятор выводит `<T>` из контекста.
4. **Несколько параметров** — `<K, V>`, `<A, B, C>`.
5. **Generic всё** — классы, методы, mixins, extensions, typedefs.
6. **Не используйте `dynamic`** — generic безопаснее и не дороже.
7. **Не дублируйте классы** — один `Box<T>` вместо `IntBox`, `StringBox`.

---

> **Назад:** [8.0 Обзор](08_00_overview.md) · **Далее:** [8.2 Ограничения (bounded generics)](08_02_bounded_generics.md)
