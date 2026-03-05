# Урок 10. Дженерики и система типов

> Охватывает подтемы: 10.1 Generic классы и методы, 10.2 Bounded generics, 10.3 Covariance/Contravariance, 10.4 Type aliases (typedef)

---

## 1. Формальное определение

**Generics** (обобщённое программирование) — параметризация типов и функций другими типами. В Dart generics реализованы через **type parameters** (`<T>`) с поддержкой:

- **Ковариантности** `out T` (Producer): можно читать, нельзя писать
- **Контравариантности** (для функциональных типов): `Function(T)` контравариантен по T
- **Ограничений** `T extends SomeType` — bounded generics
- **Reified generics** — в отличие от Java, параметры типа не стираются в runtime

Уровень: **система типов**.

---

## 2. Зачем это нужно

- **Типобезопасность без потери гибкости**: `List<String>` вместо `List<dynamic>`
- **Reuse без приведения типов**: `Stack<int>` и `Stack<String>` — отдельные типы с проверками
- **Reified generics** позволяют использовать `T` в runtime: `is T`, `is List<String>`
- **Bounded generics** ограничивают операции над параметром типа

---

## 3. Generic классы и методы (10.1)

```dart
// Generic класс
class Stack<T> {
  final List<T> _items = [];

  void push(T item) => _items.add(item);

  T pop() {
    if (_items.isEmpty) throw StateError('Stack is empty');
    return _items.removeLast();
  }

  T peek() => _items.last;
  bool get isEmpty => _items.isEmpty;
  int get size => _items.length;
}

// Generic метод — параметр типа только у метода
T identity<T>(T value) => value;

// Несколько type parameters
class Pair<A, B> {
  final A first;
  final B second;
  
  const Pair(this.first, this.second);
  
  Pair<B, A> swap() => Pair(second, first);
  
  @override
  String toString() => '($first, $second)';
}

// Generic extension
extension PairUtils<A extends Comparable<A>, B> on Pair<A, B> {
  bool get isFirstGreater => first.compareTo(first) > 0;
}

void main() {
  final stack = Stack<int>();
  stack.push(1);
  stack.push(2);
  print(stack.pop()); // 2

  final pair = Pair('hello', 42);
  print(pair.swap()); // (42, hello)

  // Type inference — часто не нужно указывать тип явно
  final strings = Stack<String>();
  final nums = Stack(); // Stack<dynamic> — нежелательно!
  
  // Reified generics: рантайм знает тип
  print(stack is Stack<int>);    // true
  print(stack is Stack<String>); // false
  print(stack is Stack<dynamic>); // false (!)
}
```

---

## 4. Bounded generics (10.2)

```dart
// T extends Comparable — T должен поддерживать compareTo
T max<T extends Comparable<T>>(List<T> list) {
  if (list.isEmpty) throw ArgumentError('Empty list');
  return list.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
}

// Множественные bounds — не поддерживаются синтаксически
// Обходное решение: определить интерфейс
abstract interface class Printable {
  String format();
}

abstract interface class Persistable {
  Future<void> save();
}

// Для реального множественного bounds — abstract class или mixin
abstract class Entity implements Printable, Persistable {}

T processEntity<T extends Entity>(T entity) {
  print(entity.format());
  return entity;
}

// Bounded generic с дефолтным значением (Dart 3 — нет, обходим через null)
class Cache<K, V extends Object> {
  final Map<K, V> _data = {};

  V? get(K key) => _data[key];

  void set(K key, V value) => _data[key] = value;

  // Метод с bounded generic
  List<V> where(bool Function(K, V) predicate) {
    return _data.entries
        .where((e) => predicate(e.key, e.value))
        .map((e) => e.value)
        .toList();
  }
}

// Рекурсивный bounded generic
class TreeNode<T extends Comparable<T>> {
  final T value;
  TreeNode<T>? left, right;
  
  TreeNode(this.value);
  
  void insert(T item) {
    if (item.compareTo(value) < 0) {
      left == null ? left = TreeNode(item) : left!.insert(item);
    } else {
      right == null ? right = TreeNode(item) : right!.insert(item);
    }
  }
}
```

---

## 5. Covariance и Contravariance (10.3)

### Ковариантность — `covariant`

Dart-списки **ковариантны** по умолчанию (как Java) — это нарушение строгой типобезопасности, но практично:

```dart
void processAnimals(List<Animal> animals) {
  for (final a in animals) a.speak();
}

List<Dog> dogs = [Dog('Rex')];
processAnimals(dogs); // OK в Dart — ковариантность

// Но это может привести к runtime error при записи:
List<Animal> animals = dogs; // Упрощение Dart — позволяет
animals.add(Cat('Whiskers')); // Бросит TypeError в runtime!
```

**`covariant` в параметрах методов:**

```dart
abstract class Animal {
  void feedWith(Animal food);  // принимает любое Animal
}

class Cat extends Animal {
  @override
  void feedWith(covariant Cat food) {
    // Сужаем тип параметра — covariant снимает ошибку компилятора
    // но добавляет runtime проверку
    print('Cat eating cat food');
  }
}
```

### Функциональные типы — контравариантность

```dart
// Function — контравариантен по типам параметров, ковариантен по возвращаемому
typedef Processor<T> = void Function(T);

void processItems<T>(List<T> items, Processor<T> processor) {
  for (final item in items) processor(item);
}

// Safer: использовать функциональные типы явно
void processNumbers(Processor<num> processor) {
  processor(42);
  processor(3.14);
}

// Processor<int> НЕ является подтипом Processor<num> — в строгой типизации
// Dart допускает это без проблем в большинстве случаев
```

### `out` и `in` — Dart не имеет site-variance annotations

В отличие от Kotlin (`out T`, `in T`), Dart не поддерживает site-variance декларации. Вместо этого — `covariant` keyword для параметров.

---

## 6. Type aliases — typedef (10.4)

```dart
// typedef для функциональных типов
typedef Callback<T> = void Function(T value);
typedef Predicate<T> = bool Function(T);
typedef Transformer<A, B> = B Function(A);
typedef JsonMap = Map<String, dynamic>;
typedef StringList = List<String>;

// typedef для generic типов (Dart 2.13+)
typedef Id<T> = T; // trivial alias

// Более полезные алиасы
typedef EventHandler<E> = Future<void> Function(E event);
typedef Parser<T> = T? Function(String raw);

// Использование
class EventBus<E> {
  final List<EventHandler<E>> _handlers = [];

  void subscribe(EventHandler<E> handler) => _handlers.add(handler);

  Future<void> emit(E event) async {
    for (final handler in _handlers) {
      await handler(event);
    }
  }
}

// typedef — это не newtype, это алиас!
// JsonMap и Map<String, dynamic> — ОДИН И ТОТ ЖЕ тип
JsonMap data = {'key': 'value'};
Map<String, dynamic> same = data; // OK

// Для newtype семантики используйте extension type!
extension type UserId(String raw) {}
```

---

## 7. Минимальный пример: generic Result

```dart
// Типичный паттерн Result<T, E>
sealed class Result<T, E> {
  const Result();

  factory Result.ok(T value) = Ok<T, E>;
  factory Result.err(E error) = Err<T, E>;

  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;
}

final class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}

final class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);
}

// Extension — методы на sealed типе
extension ResultUtils<T, E> on Result<T, E> {
  T getOrDefault(T defaultValue) => switch (this) {
    Ok(value: final v) => v,
    Err() => defaultValue,
  };

  Result<U, E> map<U>(U Function(T) f) => switch (this) {
    Ok(value: final v) => Ok(f(v)),
    Err(error: final e) => Err(e),
  };

  Result<T, F> mapError<F>(F Function(E) f) => switch (this) {
    Ok(value: final v) => Ok(v),
    Err(error: final e) => Err(f(e)),
  };
}

Result<int, String> parseAge(String input) {
  final n = int.tryParse(input);
  if (n == null) return Result.err('Not a number: $input');
  if (n < 0 || n > 150) return Result.err('Out of range: $n');
  return Result.ok(n);
}

void main() {
  final result = parseAge('25')
      .map((age) => age * 2)
      .getOrDefault(0);
  print(result); // 50

  parseAge('abc').map((v) => v + 1).getOrDefault(-1); // -1
}
```

---

## 8. Практический пример: типобезопасный репозиторий

```dart
// Generic Repository паттерн
abstract interface class Repository<T, ID> {
  Future<T?> findById(ID id);
  Future<List<T>> findAll();
  Future<T> save(T entity);
  Future<void> delete(ID id);
}

// Базовая реализация с кэшем
abstract class CachingRepository<T, ID> implements Repository<T, ID> {
  final Map<ID, T> _cache = {};

  ID idOf(T entity);

  @override
  Future<T?> findById(ID id) async => _cache[id];

  @override
  Future<T> save(T entity) async {
    _cache[idOf(entity)] = entity;
    return entity;
  }

  @override
  Future<void> delete(ID id) async => _cache.remove(id);

  @override
  Future<List<T>> findAll() async => _cache.values.toList();
}

// Конкретная реализация
class User {
  final String id;
  final String name;
  const User(this.id, this.name);
}

class UserRepository extends CachingRepository<User, String> {
  @override
  String idOf(User entity) => entity.id;
}
```

---

## 9. Под капотом

### Dart vs Java Generics

**Reified generics** — ключевое отличие Dart от Java:

```dart
// В Java — type erasure: List<String> и List<Integer> одинаковы в runtime
// В Dart — reified:
void checkType<T>(dynamic value) {
  print(value is T); // Работает в Dart!
}
checkType<String>(42);   // false
checkType<String>('hi'); // true

// Создание экземпляра через тип — не поддерживается напрямую
// (нет new T() как в C#/TypeScript)
// Обход: фабричная функция
T create<T>(T Function() factory) => factory();
```

### Type inference

```dart
// Dart выводит тип через constraint propagation
var list = [1, 2, 3]; // List<int>

// Bidirectional type inference
List<int> numbers = []; // [] выводится как List<int>
final stack = Stack<String>()..push('a')..push('b'); // тип выведен
```

---

## 10. Производительность

- **Reified generics** в AOT — нет стирания типов; runtime type checks быстрые
- **`dynamic`** — динамическая диспетчеризация каждого вызова: в 2-5+ раз медленнее
- **Bounded generics** vs `Object` + приведение — generics быстрее (нет casting overhead в AOT)
- Создание generic типа не требует дополнительных аллокаций по сравнению с конкретным типом

---

## 11. Частые ошибки

**1. `List<dynamic>` вместо `List<T>`:**
```dart
// ПЛОХО — теряем типобезопасность
List mixData(List a, List b) => [...a, ...b];

// ХОРОШО
List<T> merge<T>(List<T> a, List<T> b) => [...a, ...b];
```

**2. Ковариантность списков и запись:**
```dart
List<Dog> dogs = [Dog('Rex')];
List<Animal> animals = dogs; // OK в Dart
animals.add(Cat('Whiskers')); // Runtime TypeError! 

// Безопаснее: List<Animal> animals = List<Animal>.from(dogs);
```

**3. `extends` vs `implements` в bounded generic:**
```dart
// В Dart bounds — только extends:
T process<T extends Serializable>(T item) { ... }
// Нет синтаксиса T implements Serializable
```

**4. typedef не создаёт новый тип:**
```dart
typedef Age = int;
typedef Weight = int;
void setAge(Age age) { ... }
Weight w = 70;
setAge(w); // OK — одно и то же! Для newtype используйте extension type
```

---

## 12. Сравнение с другими языками

| Аспект | Dart | Java | Kotlin | TypeScript |
|---|---|---|---|---|
| Reified generics | ДА | Нет (erasure) | Inline reified | Нет (structural) |
| Site variance | Нет | `? extends/super` | `out/in` | `extends/in` |
| Declaration variance | Нет | Нет | `class Box<out T>` | Нет |
| Bounded generics | `T extends X` | `T extends X` | `T : X` | `T extends X` |
| Type aliases | `typedef` | Нет | `typealias` | `type` |
| Default type params | Нет | Нет | Нет | Да `<T = string>` |

---

## 13. Когда НЕ использовать generics

- **Один конкретный тип** — нет смысла делать generic
- **`dynamic` для гетерогенных данных** — иногда правильнее использовать sealed или discriminated union
- **Overengineering**: `Repository<T, ID>` полезен, но `Worker<T extends Object, R extends Object, E extends Exception>` — возможно, уже лишнее

---

## 14. Краткое резюме

1. **Reified generics** — параметры типа не стираются; можно делать `is List<String>` в runtime
2. **Bounded generics** (`T extends X`) — ограничение + доступ к методам X внутри generic кода
3. **Dart-коллекции ковариантны** — `List<Dog>` можно присвоить `List<Animal>`, но запись вызовет TypeError
4. **`covariant` keyword** расширяет тип параметра метода при переопределении
5. **`typedef`** — псевдоним типа, не новый тип; для newtype — `extension type`
6. **Type inference** работает bidirectionally — Dart выводит типы из контекста
7. **`dynamic` медленнее** чем generic в AOT; предпочитайте типизированный код
