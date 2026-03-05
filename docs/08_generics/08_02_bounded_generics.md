# 8.2 Ограничения (bounded generics)

## 1. Формальное определение

**Bounded generic** (ограниченный generic) — типовой параметр с ограничением `extends`, требующий, чтобы подставляемый тип был подтипом указанного. Это даёт доступ к методам и свойствам ограничивающего типа.

```dart
class SortedList<T extends Comparable<T>> { ... }
// T может быть int, String, DateTime — но не Object
```

**Upper bound** — верхняя граница типа: `T extends SomeType` означает «T ⊆ SomeType».

## 2. Зачем это нужно

- **Доступ к методам** — `T extends Comparable` → можно вызвать `a.compareTo(b)`.
- **Type safety** — запрет неподходящих типов на этапе компиляции.
- **Выразительные контракты** — API говорит: «работаю с любым типом, у которого есть X».
- **Вычисления с ограничением** — `T extends num` → можно складывать, сравнивать.

## 3. Как это работает

### Базовое ограничение

```dart
// Без bound: T — это Object?, нет полезных методов
class BadSort<T> {
  void sort(List<T> items) {
    // items[0].compareTo(items[1]); // ❌ Object? не имеет compareTo
  }
}

// С bound: T extends Comparable<T>
class Sorter<T extends Comparable<T>> {
  List<T> sort(List<T> items) {
    return [...items]..sort(); // ✅ Comparable.compareTo доступен
  }

  T max(T a, T b) => a.compareTo(b) >= 0 ? a : b;
}

void main() {
  var intSorter = Sorter<int>();
  print(intSorter.sort([3, 1, 2]));   // [1, 2, 3]
  print(intSorter.max(10, 20));        // 20

  var strSorter = Sorter<String>();
  print(strSorter.sort(['c', 'a']));   // [a, c]

  // var objSorter = Sorter<Object>(); // ❌ Object не Comparable
}
```

### extends num — числовые операции

```dart
class Stats<T extends num> {
  final List<T> data;
  Stats(this.data);

  double get mean {
    var sum = 0.0;
    for (final v in data) {
      sum += v; // ✅ num поддерживает +
    }
    return sum / data.length;
  }

  T get min => data.reduce((a, b) => a < b ? a : b); // ✅ num поддерживает <
  T get max => data.reduce((a, b) => a > b ? a : b);

  double get range => (max - min).toDouble();
}

void main() {
  var intStats = Stats([10, 20, 30, 40, 50]);
  print('Mean: ${intStats.mean}');   // 30.0
  print('Range: ${intStats.range}'); // 40.0

  var doubleStats = Stats([1.5, 2.7, 3.2]);
  print('Mean: ${doubleStats.mean.toStringAsFixed(2)}'); // 2.47
}
```

### extends abstract class / interface

```dart
abstract class Identifiable {
  String get id;
}

class User implements Identifiable {
  @override
  final String id;
  final String name;
  User(this.id, this.name);

  @override
  String toString() => 'User($name)';
}

class Product implements Identifiable {
  @override
  final String id;
  final String title;
  Product(this.id, this.title);

  @override
  String toString() => 'Product($title)';
}

/// Репозиторий для любого Identifiable
class Repository<T extends Identifiable> {
  final _store = <String, T>{};

  void save(T entity) {
    _store[entity.id] = entity; // ✅ id доступен через Identifiable
  }

  T? findById(String id) => _store[id];

  List<T> findAll() => _store.values.toList();
}

void main() {
  var users = Repository<User>();
  users.save(User('u1', 'Alice'));
  users.save(User('u2', 'Bob'));
  print(users.findById('u1')); // User(Alice)

  var products = Repository<Product>();
  products.save(Product('p1', 'Dart Book'));
  print(products.findAll()); // [Product(Dart Book)]

  // var bad = Repository<int>(); // ❌ int не Identifiable
}
```

### Bounded generic method

```dart
/// Находит минимальный элемент
T minOf<T extends Comparable<T>>(List<T> items) {
  var result = items.first;
  for (final item in items.skip(1)) {
    if (item.compareTo(result) < 0) {
      result = item;
    }
  }
  return result;
}

/// Объединяет два Iterable с ограничением
List<T> mergeUnique<T extends Object>(Iterable<T> a, Iterable<T> b) {
  return {...a, ...b}.toList();
}

void main() {
  print(minOf([3, 1, 4, 1, 5])); // 1
  print(minOf(['banana', 'apple', 'cherry'])); // apple

  print(mergeUnique([1, 2, 3], [3, 4, 5])); // [1, 2, 3, 4, 5]
}
```

### Bound с generics (F-bounded polymorphism)

```dart
/// F-bounded: T extends Comparable<T>
/// Класс ссылается на СЕБЯ через generic
abstract class Copyable<T extends Copyable<T>> {
  T copy();
}

class Document extends Copyable<Document> {
  final String title;
  final String content;

  Document(this.title, this.content);

  @override
  Document copy() => Document(title, content);

  @override
  String toString() => 'Document($title)';
}

class Spreadsheet extends Copyable<Spreadsheet> {
  final int rows, cols;

  Spreadsheet(this.rows, this.cols);

  @override
  Spreadsheet copy() => Spreadsheet(rows, cols);

  @override
  String toString() => 'Spreadsheet(${rows}x$cols)';
}

// Generic функция работает с любым Copyable
T duplicate<T extends Copyable<T>>(T original) {
  var copy = original.copy(); // Возвращает T, не Copyable!
  return copy;
}

void main() {
  var doc = Document('Report', 'Content');
  Document copy = duplicate(doc); // Тип верный: Document
  print(copy); // Document(Report)
}
```

### Множественные bounds (через промежуточный тип)

```dart
// Dart НЕ поддерживает T extends A & B напрямую
// Решение: создать промежуточный абстрактный класс/mixin

abstract class Serializable {
  Map<String, dynamic> toJson();
}

abstract class Validatable {
  bool get isValid;
}

// Комбинированный bound
abstract class SerializableEntity implements Serializable, Validatable {}

class User extends SerializableEntity {
  final String name;
  final String email;

  User(this.name, this.email);

  @override
  Map<String, dynamic> toJson() => {'name': name, 'email': email};

  @override
  bool get isValid => name.isNotEmpty && email.contains('@');
}

/// Сохраняет только валидные, сериализуемые сущности
class DataStore<T extends SerializableEntity> {
  final _items = <T>[];

  void save(T item) {
    if (!item.isValid) {     // ✅ Validatable.isValid
      throw ArgumentError('Невалидная сущность');
    }
    _items.add(item);
    var json = item.toJson(); // ✅ Serializable.toJson
    print('Сохранено: $json');
  }
}

void main() {
  var store = DataStore<User>();
  store.save(User('Alice', 'alice@test.com')); // Сохранено: {name: Alice, ...}
  // store.save(User('', 'invalid'));          // ❌ ArgumentError
}
```

### Default type (Object?)

```dart
// Без bound: T extends Object? (nullable)
class Wrapper<T> {
  T value;
  Wrapper(this.value);
}

var w = Wrapper<String?>('hello');
w.value = null; // ✅ T = String?

// С extends Object: T не может быть nullable
class StrictWrapper<T extends Object> {
  T value;
  StrictWrapper(this.value);
}

// var sw = StrictWrapper<String?>(null); // ❌ String? не extends Object
var sw = StrictWrapper<String>('hello');  // ✅
```

## 4. Минимальный пример

```dart
T clamp<T extends num>(T value, T min, T max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

void main() {
  print(clamp(15, 0, 10));      // 10
  print(clamp(3.14, 0.0, 1.0)); // 1.0
}
```

## 5. Практический пример

### Priority Queue с bounded generic

```dart
class PriorityQueue<T extends Comparable<T>> {
  final _items = <T>[];

  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;
  T get peek => _items.first;

  /// Добавляет элемент, сохраняя порядок
  void enqueue(T item) {
    var index = _items.length;
    _items.add(item);
    _siftUp(index);
  }

  /// Извлекает минимальный элемент
  T dequeue() {
    var min = _items.first;
    var last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _siftDown(0);
    }
    return min;
  }

  void _siftUp(int index) {
    while (index > 0) {
      var parent = (index - 1) ~/ 2;
      if (_items[index].compareTo(_items[parent]) >= 0) break;
      _swap(index, parent);
      index = parent;
    }
  }

  void _siftDown(int index) {
    while (true) {
      var smallest = index;
      var left = 2 * index + 1;
      var right = 2 * index + 2;

      if (left < _items.length &&
          _items[left].compareTo(_items[smallest]) < 0) {
        smallest = left;
      }
      if (right < _items.length &&
          _items[right].compareTo(_items[smallest]) < 0) {
        smallest = right;
      }

      if (smallest == index) break;
      _swap(index, smallest);
      index = smallest;
    }
  }

  void _swap(int i, int j) {
    var tmp = _items[i];
    _items[i] = _items[j];
    _items[j] = tmp;
  }
}

/// Задача с приоритетом
class Task implements Comparable<Task> {
  final String name;
  final int priority; // Меньше = важнее

  Task(this.name, this.priority);

  @override
  int compareTo(Task other) => priority.compareTo(other.priority);

  @override
  String toString() => '$name(p$priority)';
}

void main() {
  var queue = PriorityQueue<Task>();

  queue.enqueue(Task('Багфикс', 1));
  queue.enqueue(Task('Рефакторинг', 5));
  queue.enqueue(Task('Новая фича', 3));
  queue.enqueue(Task('Критический баг', 0));

  while (!queue.isEmpty) {
    print(queue.dequeue()); // По приоритету: 0, 1, 3, 5
  }
}
```

## 6. Что происходит под капотом

### Compile-time bound check

```
class Sorter<T extends Comparable<T>> { ... }

Sorter<int>    → int extends Comparable<int>?    ✅
Sorter<String> → String extends Comparable<String>? ✅
Sorter<Object> → Object extends Comparable<Object>? ❌ Ошибка!

Проверка — compile-time. В runtime bound не проверяется повторно.
```

### Runtime type с bound

```
var sorter = Sorter<int>();

sorter.runtimeType → Sorter<int>
sorter is Sorter<int>      → true
sorter is Sorter<num>      → false (точное совпадение)
sorter is Sorter<Comparable> → нет, <int> ≠ <Comparable>

Bound НЕ хранится в runtime — только подставленный тип.
```

### Implicit upper bound

```
class Box<T> { ... }
// Неявно: T extends Object?

class Box<T extends Object> { ... }
// T не может быть nullable

class Box<T extends num> { ... }
// T может быть int, double (но не num? или int?)
```

## 7. Производительность и ресурсы

| Аспект           | Стоимость                                     |
| ---------------- | --------------------------------------------- |
| Bound check      | Compile-time only                             |
| Метод bound-типа | Виртуальный вызов (может быть devirtualized)  |
| `T extends num`  | AOT может unbox числа                         |
| F-bounded        | = обычный bound, без дополнительного overhead |

Bounds — **compile-time конструкция**. Runtime стоимость = 0.

## 8. Частые ошибки и антипаттерны

### ❌ Забыли bound — потеряли API

```dart
// ❌ T = Object?, нет compareTo
T max<T>(T a, T b) {
  // return a.compareTo(b) > 0 ? a : b; // ❌ Ошибка!
  return a as dynamic > b ? a : b; // Хак с dynamic — ПЛОХО
}

// ✅ С bound
T max<T extends Comparable<T>>(T a, T b) {
  return a.compareTo(b) > 0 ? a : b; // ✅
}
```

### ❌ Слишком строгий bound

```dart
// ❌ Требуем конкретный тип вместо интерфейса
class Processor<T extends List<int>> { ... }
// Нельзя передать UnmodifiableListView<int>!

// ✅ Используем интерфейс
class Processor<T extends Iterable<int>> { ... }
```

### ❌ F-bounded без необходимости

```dart
// ❌ F-bounded когда достаточно простого bound
abstract class Useless<T extends Useless<T>> {
  void doSomething(); // Не использует T
}

// ✅ Простой abstract class
abstract class Better {
  void doSomething();
}
```

## 9. Сравнение с альтернативами

| Аспект          | Dart                    | Java              | C#               | Rust         |
| --------------- | ----------------------- | ----------------- | ---------------- | ------------ |
| Upper bound     | `T extends X`           | `T extends X`     | `where T : X`    | `T: Trait`   |
| Multiple bounds | Через промежуточный тип | `T extends A & B` | `where T : A, B` | `T: A + B`   |
| Lower bound     | ❌                      | `? super T`       | ❌               | ❌           |
| Default bound   | `Object?`               | `Object`          | `object`         | По контексту |
| F-bounded       | ✅                      | ✅                | ✅               | ✅ (Self)    |

Java уникальна в поддержке lower bounds (`? super T`), Dart этого не имеет.

## 10. Когда НЕ стоит использовать

- **Bound не добавляет методы** — если не вызываете методы ограничивающего типа, bound бесполезен.
- **`Object` как bound** — `<T extends Object>` полезен ТОЛЬКО для запрета nullable типов.
- **F-bounded без использования T** — если `copy()` возвращает `Copyable`, а не `T`, F-bound избыточен.
- **Слишком узкий bound** — ограничение должно быть минимально необходимым.

## 11. Краткое резюме

1. **`T extends X`** — T должен быть подтипом X; даёт доступ к API X.
2. **`T extends Comparable<T>`** — стандартный bound для сортировки/сравнения.
3. **`T extends Object`** — запрет nullable типов.
4. **Множественные bounds** — через промежуточный abstract class (Dart).
5. **F-bounded** — `T extends Copyable<T>` — тип ссылается на себя.
6. **Compile-time** — проверка bounds выполняется при компиляции, не в runtime.
7. **Минимальный bound** — ограничивайте ровно столько, сколько нужно для используемых методов.

---

> **Назад:** [8.1 Обобщённые классы и методы](08_01_generic_classes_methods.md) · **Далее:** [8.3 Ковариантность и контравариантность](08_03_variance.md)
