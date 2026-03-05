# 8.3 Ковариантность и контравариантность

## 1. Формальное определение

**Вариантность** (variance) — описывает, как отношение наследования между типами **переносится** на generic-типы.

- **Ковариантность** (covariance) — если `Cat <: Animal`, то `List<Cat> <: List<Animal>`. Направление наследования **сохраняется**.
- **Контравариантность** (contravariance) — направление наследования **инвертируется**: `Comparator<Animal> <: Comparator<Cat>`.
- **Инвариантность** (invariance) — никакого отношения: `List<Cat>` и `List<Animal>` несовместимы.

Dart использует **runtime covariance** для generic-типов — более гибко, чем Java, но с runtime проверками.

## 2. Зачем это нужно

- **Гибкое присвоение** — `List<Cat>` можно передать как `List<Animal>`.
- **Понимание type safety** — почему ковариантность коллекций может быть небезопасна.
- **`covariant` keyword** — явное ослабление типизации параметров в переопределённых методах.
- **Проектирование API** — consumer vs producer влияет на безопасность типов.

## 3. Как это работает

### Ковариантность generic-типов

```dart
class Animal {
  String get sound => 'Звук';
}

class Cat extends Animal {
  @override
  String get sound => 'Мяу';
  void purr() => print('Мур...');
}

class Dog extends Animal {
  @override
  String get sound => 'Гав';
}

void main() {
  // Cat <: Animal
  // Dart: List<Cat> <: List<Animal> ← КОВАРИАНТНОСТЬ
  List<Cat> cats = [Cat(), Cat()];
  List<Animal> animals = cats; // ✅ Компилируется!

  // Чтение — безопасно
  Animal first = animals[0]; // ✅ Cat is Animal
  print(first.sound);        // Мяу

  // Запись — RUNTIME проверка!
  // animals.add(Dog()); // ❌ Runtime TypeError! List<Cat> не примет Dog
}
```

### Почему ковариантность коллекций опасна

```dart
void addDog(List<Animal> animals) {
  animals.add(Dog()); // Выглядит корректно...
}

void main() {
  List<Cat> cats = [Cat()];

  // Ковариантно присваиваем
  addDog(cats); // ❌ Runtime TypeError!
  // cats — это List<Cat>, Dog — не Cat!

  // Dart ловит это в RUNTIME, не compile-time.
  // Java с wildcards ловит compile-time: List<? extends Animal> — read-only.
}
```

### Ковариантность возвращаемых типов

```dart
class Farm {
  Animal produce() => Animal();
}

class CatFarm extends Farm {
  @override
  Cat produce() => Cat(); // ✅ Cat <: Animal — ковариантный return type
}

void main() {
  Farm farm = CatFarm();
  Animal a = farm.produce(); // ✅ Безопасно: Cat is Animal
}
```

### covariant keyword — параметры

```dart
class Trainer {
  void train(Animal animal) {
    print('Тренирую ${animal.sound}');
  }
}

class CatTrainer extends Trainer {
  // covariant — разрешает СУЗИТЬ тип параметра
  @override
  void train(covariant Cat cat) {
    print('Тренирую кота: ${cat.sound}');
    cat.purr(); // ✅ Доступен метод Cat
  }
}

void main() {
  CatTrainer trainer = CatTrainer();
  trainer.train(Cat()); // ✅

  // Через полиморфизм:
  Trainer t = CatTrainer();
  t.train(Cat());  // ✅
  // t.train(Dog()); // ❌ Runtime TypeError! CatTrainer ожидает Cat
}
```

### Функции и контравариантность

```dart
// Dart ослабляет контравариантность для функций ради практичности
typedef Callback = void Function(Animal);

void handleCat(Cat cat) {
  print('Обработка кота: ${cat.sound}');
}

void handleAnimal(Animal animal) {
  print('Обработка животного: ${animal.sound}');
}

void main() {
  // void Function(Animal) — ожидается
  Callback cb1 = handleAnimal; // ✅ Принимает Animal — подходит

  // void Function(Cat) — более узкий параметр
  // Теоретически контравариантно это НЕПРАВИЛЬНО:
  // cb = handleCat; // В строгой системе — ошибка
  // Dart: runtime проверка

  // Контравариантность функций (safe direction):
  // Comparator<Animal> <: Comparator<Cat>
  // Функция, принимающая Animal, может обработать и Cat
  int compareAnimals(Animal a, Animal b) => 0;

  var cats = [Cat(), Cat()];
  cats.sort(compareAnimals); // ✅ compareAnimals(Animal) принимает Cat
}
```

### is-проверка с generic

```dart
void main() {
  List<int> ints = [1, 2, 3];
  List<num> nums = ints; // ✅ Ковариантно

  // Reified generics → точная runtime проверка
  print(ints is List<int>);    // true
  print(ints is List<num>);    // true  (ковариантность!)
  print(ints is List<Object>); // true
  print(ints is List<String>); // false

  // В обратную сторону:
  List<num> numList = [1, 2, 3.14];
  print(numList is List<int>);    // false (есть double!)

  List<num> allInts = <int>[1, 2, 3];
  print(allInts is List<int>);    // true (underlying type — List<int>)
}
```

### Producer/Consumer (PECS)

```dart
// Producer Extends, Consumer Super (из Java, применимо концептуально)

// PRODUCER — читаем данные → covariant (extends)
// Безопасно: List<Cat> как Iterable<Animal>
void printSounds(Iterable<Animal> animals) {
  for (final a in animals) {
    print(a.sound); // Только читаем
  }
}

// CONSUMER — пишем данные → нужна точная типизация
void fillWithCats(List<Cat> cats) {
  cats.add(Cat()); // Пишем конкретный тип
}

void main() {
  var cats = [Cat(), Cat()];

  // Producer: List<Cat> → Iterable<Animal> (covariant, safe)
  printSounds(cats); // ✅

  // Consumer: требуется точный тип
  fillWithCats(cats); // ✅

  // Нельзя: List<Animal> animals = cats; animals.add(Dog());
  // Это breaking PECS — consumer с covariant типом
}
```

### Пример: ковариантность в коллекциях Dart

```dart
void main() {
  // Set<int> <: Set<num> <: Set<Object>
  Set<int> intSet = {1, 2, 3};
  Set<num> numSet = intSet; // ✅ Covariant

  // Map<K, V> — ковариантен по обоим параметрам
  Map<String, int> strInt = {'a': 1};
  Map<String, num> strNum = strInt; // ✅
  Map<Object, Object> objObj = strInt; // ✅

  // Future<T> — ковариантен
  Future<int> futInt = Future.value(42);
  Future<num> futNum = futInt; // ✅
  Future<Object> futObj = futInt; // ✅
}
```

## 4. Минимальный пример

```dart
class Box<T> {
  T value;
  Box(this.value);
}

void readBox(Box<Object> box) {
  print(box.value); // Только чтение — безопасно
}

void main() {
  Box<String> strBox = Box('hello');

  // Ковариантность: Box<String> <: Box<Object>
  readBox(strBox); // ✅ hello

  // Но если readBox попытается записать int → runtime error!
}
```

## 5. Практический пример

### Type-safe event system с учётом вариантности

```dart
// Иерархия событий
class AppEvent {
  final DateTime timestamp;
  AppEvent() : timestamp = DateTime.now();
}

class UIEvent extends AppEvent {
  final String widgetId;
  UIEvent(this.widgetId);
}

class ClickEvent extends UIEvent {
  final double x, y;
  ClickEvent(String widgetId, this.x, this.y) : super(widgetId);
}

class KeyEvent extends UIEvent {
  final String key;
  KeyEvent(String widgetId, this.key) : super(widgetId);
}

// Event handler — контравариантно по событию
typedef EventHandler<T extends AppEvent> = void Function(T event);

class EventBus {
  final _handlers = <Type, List<Function>>{};

  /// Подписка — handler для T
  void on<T extends AppEvent>(EventHandler<T> handler) {
    _handlers.putIfAbsent(T, () => []).add(handler);
  }

  /// Emit — вызывает обработчики для T и его суперклассов
  void emit<T extends AppEvent>(T event) {
    // Обработчики для точного типа
    var handlers = _handlers[T];
    if (handlers != null) {
      for (final h in handlers) {
        (h as EventHandler<T>)(event);
      }
    }

    // В реальной системе: обход иерархии типов вверх
    // для вызова обработчиков суперклассов (AppEvent, UIEvent, etc.)
  }
}

void main() {
  var bus = EventBus();

  // Handler для UIEvent — принимает ЛЮБОЙ UIEvent (и подтипы)
  bus.on<UIEvent>((event) {
    print('UI Event на виджете: ${event.widgetId}');
  });

  // Handler для конкретного ClickEvent
  bus.on<ClickEvent>((event) {
    print('Click: (${event.x}, ${event.y}) на ${event.widgetId}');
  });

  bus.emit(ClickEvent('btn1', 100, 200));
  bus.emit(KeyEvent('input1', 'Enter'));
}
```

## 6. Что происходит под капотом

### Runtime covariance проверка

```
List<Cat> cats = [Cat()];
List<Animal> animals = cats; // OK compile-time

animals.add(Dog());
// Runtime:
// 1. animals → указывает на List<Cat>
// 2. add(Dog()) → проверка: Dog is Cat? → false!
// 3. TypeError thrown

Dart вставляет implicit downcast:
  animals.add(Dog()) →
  animals.add(Dog() as Cat) → TypeError!
```

### Type test с reified generics

```
List<int> ints = [1, 2, 3];
ints is List<num>?

Runtime:
  1. ints._typeArg = int
  2. Вопрос: List<int> <: List<num>?
  3. Covariant: int <: num? → yes
  4. Результат: true

Это работает ТОЛЬКО с reified generics (Dart, C#).
Java: List<Integer> is List<Number> → ОШИБКА компиляции!
```

### Sound vs unsound

```
Dart's covariance — UNSOUND для записи:
  List<Cat> cats = [Cat()];
  List<Animal> animals = cats;
  animals.add(Dog()); // Компилируется, но runtime error

Sound: система типов, где compile-time проверка
       гарантирует отсутствие runtime type errors.

Dart выбрал: soundness для большинства случаев +
             runtime check для covariant generics.

Почему? Практичность > академическая чистота.
Без covariance: List<Cat> нельзя передать как List<Animal> — неудобно.
```

## 7. Производительность и ресурсы

| Аспект                   | Стоимость                         |
| ------------------------ | --------------------------------- |
| Covariant assignment     | Zero (compile-time)               |
| Runtime type check (add) | Один is-check при мутации         |
| `covariant` keyword      | Один is-check при вызове          |
| `is List<T>`             | Type comparison (быстро, reified) |
| Invariant (точный тип)   | Zero runtime checks               |

**Рекомендации:**

- Ковариантное чтение — бесплатно.
- Ковариантная запись — runtime check; в hot loops может быть заметно.
- Если тип точный — нет overhead.

## 8. Частые ошибки и антипаттерны

### ❌ Мутация ковариантной коллекции

```dart
void addAnimal(List<Animal> animals) {
  animals.add(Dog()); // Компилируется!
}

void main() {
  List<Cat> cats = [Cat()];
  addAnimal(cats); // ❌ Runtime TypeError!

  // Решение 1: принимать Iterable (read-only)
  // void printAnimals(Iterable<Animal> animals) { ... }

  // Решение 2: явная копия
  // addAnimal(List<Animal>.from(cats));
}
```

### ❌ Неожиданный covariant runtime error

```dart
class AnimalShelter {
  void adopt(Animal animal) { ... }
}

class CatShelter extends AnimalShelter {
  @override
  void adopt(covariant Cat cat) { ... }
}

void main() {
  AnimalShelter shelter = CatShelter();
  shelter.adopt(Dog()); // ❌ Runtime TypeError!
  // Код выглядит корректно (AnimalShelter.adopt(Animal)),
  // но CatShelter сузил тип
}
```

### ❌ Путаница: covariant параметр vs return

```dart
class Producer<T> {
  T produce() => ... ; // Return type — ковариантен (безопасно)
}

class Consumer<T> {
  void consume(T item) => ... ; // Параметр — НЕ безопасен с covariance
}

// Producer<Cat> <: Producer<Animal> — ✅ безопасно (read)
// Consumer<Cat> <: Consumer<Animal> — ⚠️ runtime check (write)
```

## 9. Сравнение с альтернативами

| Аспект                 | Dart                | Java                  | C#                  | Kotlin  | TypeScript   |
| ---------------------- | ------------------- | --------------------- | ------------------- | ------- | ------------ |
| Generics covariant     | Runtime (все)       | Wildcards `? extends` | Declaration `out T` | `out T` | Structural   |
| Generics contravariant | ❌ (нет)            | `? super T`           | `in T`              | `in T`  | Structural   |
| Invariant              | По умолчанию safe   | Raw type              | Default             | Default | —            |
| `covariant` keyword    | ✅ (параметры)      | ❌                    | ❌                  | ❌      | —            |
| Sound                  | Partially (runtime) | Yes (wildcards)       | Yes (declaration)   | Yes     | No (unsound) |

## 10. Когда НЕ стоит использовать

- **`covariant` без причины** — не ставьте `covariant` «на всякий случай»; он маскирует ошибки типов.
- **Мутация covariant коллекции** — принимайте `Iterable<T>` для read-only, `List<T>` для записи с точным типом.
- **Глубокие иерархии с covariant** — каждый уровень добавляет runtime check; предпочитайте generics.
- **Игнорирование runtime errors** — covariance errors = баги; не ловите TypeError.

## 11. Краткое резюме

1. **Ковариантность** — `List<Cat> <: List<Animal>` — Dart делает это для всех generic-типов.
2. **Безопасно для чтения** — ковариантный generic безопасен для `Iterable`, `Stream`, `Future`.
3. **Опасно для записи** — `animals.add(Dog())` на `List<Cat>` → runtime `TypeError`.
4. **`covariant` keyword** — сужает тип параметра в override; runtime check.
5. **Return type** — всегда ковариантен (сужение безопасно).
6. **PECS** — Producer Extends (read), Consumer Super (write) — концептуальное правило.
7. **Reified** — Dart проверяет generic-типы в runtime, что делает ковариантность обнаруживаемой.

---

> **Назад:** [8.2 Ограничения (bounded generics)](08_02_bounded_generics.md) · **Далее:** [8.4 Type aliases и typedef](08_04_type_aliases.md)
