# 6.4 Типы функций и typedef

## 1. Формальное определение

**Тип функции** (function type) — тип, описывающий сигнатуру функции: типы параметров и тип возвращаемого значения. Записывается как `ReturnType Function(ParamTypes)`.

**`typedef`** — объявление псевдонима (alias) для типа. Чаще всего применяется для присвоения имени сложному функциональному типу.

```dart
// Inline function type
void Function(String) callback;

// typedef — именованный псевдоним
typedef StringCallback = void Function(String);
StringCallback callback;  // Тот же тип, но с именем
```

## 2. Зачем это нужно

- **Читаемость** — `EventHandler` понятнее, чем `void Function(Event, {bool cancel})`.
- **Повторное использование** — один typedef вместо дублирования длинных сигнатур.
- **Контракты** — тип функции описывает ожидаемый интерфейс callback'а.
- **Самодокументирование** — имя typedef передаёт намерение: `Comparator<T>`, `Predicate<T>`.
- **Генерики** — typedef может быть параметризован: `typedef Mapper<T, R> = R Function(T)`.

## 3. Как это работает

### Синтаксис function type

```dart
// Полная форма:
//  ReturnType Function(ParamType1 name1, ParamType2 name2)

// Примеры:
int Function(int, int)               // Два int → int
void Function()                      // Без параметров, ничего не возвращает
String Function(String, {bool upper}) // Именованный параметр
Future<int> Function(String url)     // Возвращает Future

// Имена параметров необязательны, но помогают читаемости:
int Function(int a, int b)   // ← Понятнее
int Function(int, int)       // ← Тоже валидно
```

### typedef — новый синтаксис (Dart 2+)

```dart
// Общий вид:
typedef Name = Type;

// Для функций:
typedef IntBinaryOp = int Function(int a, int b);
typedef Predicate<T> = bool Function(T element);
typedef AsyncCallback = Future<void> Function();
typedef JsonMap = Map<String, dynamic>;  // typedef для любых типов!

void main() {
  IntBinaryOp add = (a, b) => a + b;
  IntBinaryOp mul = (a, b) => a * b;

  print(add(2, 3)); // 5
  print(mul(2, 3)); // 6
}
```

### typedef для нефункциональных типов (Dart 2.13+)

```dart
// Псевдоним для любого типа
typedef Json = Map<String, dynamic>;
typedef StringList = List<String>;
typedef Pair<A, B> = (A, B);  // Dart 3: typedef для record

void processJson(Json data) {
  // data — это Map<String, dynamic>
  print(data['name']);
}

// Генерик typedef
typedef Matrix<T> = List<List<T>>;

void main() {
  Matrix<int> m = [
    [1, 2, 3],
    [4, 5, 6],
  ];
  print(m[0][1]); // 2
}
```

### Старый синтаксис typedef (не рекомендуется)

```dart
// Dart 1 style — НЕ используйте в новом коде
typedef int OldStyleOp(int a, int b);

// Новый style — предпочтительный
typedef NewStyleOp = int Function(int a, int b);
```

### Функции как параметры с типом

```dart
typedef Comparator<T> = int Function(T a, T b);

// Использование typedef в параметре
List<T> sortedBy<T>(List<T> list, Comparator<T> compare) {
  return [...list]..sort(compare);
}

// Или inline function type (без typedef):
List<T> sortedByInline<T>(List<T> list, int Function(T, T) compare) {
  return [...list]..sort(compare);
}

void main() {
  var names = ['Charlie', 'Alice', 'Bob'];

  // Передаём функцию, соответствующую Comparator<String>
  var sorted = sortedBy<String>(
    names,
    (a, b) => a.compareTo(b),
  );
  print(sorted); // [Alice, Bob, Charlie]
}
```

### Функциональный тип как возвращаемое значение

```dart
typedef Validator = String? Function(String? value);

/// Фабрика валидаторов
Validator minLength(int min) {
  return (String? value) {
    if (value == null || value.length < min) {
      return 'Минимум $min символов';
    }
    return null; // null = валидно
  };
}

Validator maxLength(int max) {
  return (String? value) {
    if (value != null && value.length > max) {
      return 'Максимум $max символов';
    }
    return null;
  };
}

/// Комбинирует несколько валидаторов
Validator combine(List<Validator> validators) {
  return (String? value) {
    for (final v in validators) {
      final error = v(value);
      if (error != null) return error;
    }
    return null;
  };
}

void main() {
  var validateName = combine([
    minLength(2),
    maxLength(50),
  ]);

  print(validateName('A'));       // Минимум 2 символов
  print(validateName('Alice'));   // null (валидно)
  print(validateName('A' * 51)); // Максимум 50 символов
}
```

### Проверка типа функции

```dart
typedef IntOp = int Function(int);

void main() {
  int double_(int x) => x * 2;
  var lambda = (int x) => x + 1;
  var genericStr = (String s) => s.length;

  print(double_ is IntOp);     // true
  print(lambda is IntOp);      // true
  print(genericStr is IntOp);  // false (String → int, не int → int)

  // Function — базовый тип всех функций
  print(double_ is Function);  // true
}
```

## 4. Минимальный пример

```dart
typedef Greeting = String Function(String name);

Greeting makeGreeting(String prefix) {
  return (name) => '$prefix, $name!';
}

void main() {
  Greeting hi = makeGreeting('Привет');
  Greeting bye = makeGreeting('Пока');

  print(hi('Dart'));  // Привет, Dart!
  print(bye('Dart')); // Пока, Dart!
}
```

## 5. Практический пример

### Event system с типизированными обработчиками

```dart
typedef EventHandler<T> = void Function(T event);
typedef Unsubscribe = void Function();

/// Типобезопасная шина событий
class EventBus {
  final _handlers = <Type, List<Function>>{};

  /// Подписка на событие типа T. Возвращает функцию отписки.
  Unsubscribe on<T>(EventHandler<T> handler) {
    final type = T;
    _handlers.putIfAbsent(type, () => []).add(handler);

    // Возвращаем замыкание-отписку
    return () {
      _handlers[type]?.remove(handler);
    };
  }

  /// Отправить событие
  void emit<T>(T event) {
    final handlers = _handlers[T];
    if (handlers == null) return;

    for (final handler in List.of(handlers)) {
      (handler as EventHandler<T>)(event);
    }
  }
}

// Типы событий
class UserLoggedIn {
  final String username;
  UserLoggedIn(this.username);
}

class OrderCreated {
  final int orderId;
  final double amount;
  OrderCreated(this.orderId, this.amount);
}

void main() {
  var bus = EventBus();

  // Подписка — handler типизирован!
  var unsub = bus.on<UserLoggedIn>((event) {
    print('Пользователь вошёл: ${event.username}');
  });

  bus.on<OrderCreated>((event) {
    print('Заказ #${event.orderId}: ${event.amount} ₽');
  });

  bus.emit(UserLoggedIn('alice'));
  bus.emit(OrderCreated(42, 1500.0));

  // Отписка
  unsub();
  bus.emit(UserLoggedIn('bob')); // Уже не сработает
}
```

### Конвейер преобразований с typedef

```dart
typedef Transform<T> = T Function(T input);

/// Конвейер: применяет список преобразований последовательно
Transform<T> pipeline<T>(List<Transform<T>> transforms) {
  return (T input) {
    var result = input;
    for (final t in transforms) {
      result = t(result);
    }
    return result;
  };
}

void main() {
  var processText = pipeline<String>([
    (s) => s.trim(),
    (s) => s.toLowerCase(),
    (s) => s.replaceAll(RegExp(r'\s+'), ' '),
    (s) => '${s[0].toUpperCase()}${s.substring(1)}',
  ]);

  print(processText('  HELLO   DART   WORLD  '));
  // Hello dart world
}
```

## 6. Что происходит под капотом

### typedef — это alias, не новый тип

```dart
typedef IntOp = int Function(int);

// IntOp — это БУКВАЛЬНО int Function(int)
// Компилятор подставляет полный тип на этапе компиляции

void main() {
  IntOp f = (x) => x * 2;
  int Function(int) g = f; // ✅ Тот же тип!

  print(f.runtimeType == g.runtimeType); // true
}
```

### Ковариантность function types

```
Dart использует ковариантность для возвращаемого типа
и контравариантность для параметров (с оговорками):

void Function(Object) → совместим с → void Function(String)
    (принимает шире)                   (принимает уже)

String Function()     → подтип →      Object Function()
    (возвращает уже)                   (возвращает шире)

Однако Dart исторически ослабляет правила контравариантности
аргументов ради практичности (runtime check).
```

### Представление в runtime

```
typedef — стёрт при компиляции. В runtime есть только
_FunctionType, хранящий:
  - returnType
  - positionalParameterTypes[]
  - namedParameterTypes{}
  - requiredNamedParameters{}
  - typeArguments[] (для generic typedef)
```

## 7. Производительность и ресурсы

| Аспект                  | Стоимость                                  |
| ----------------------- | ------------------------------------------ |
| typedef                 | Нулевая — стирается при компиляции         |
| Inline function type    | Identical с typedef                        |
| `is` проверка func type | Сравнение сигнатур в runtime (редко нужно) |
| Хранение функции в поле | Указатель на Closure object                |

**typedef не добавляет overhead** — это чистый alias для компилятора.

## 8. Частые ошибки и антипаттерны

### ❌ typedef для простых типов

```dart
// ПЛОХО: typedef не добавляет ясности
typedef MyString = String;
typedef MyInt = int;

// ХОРОШО: typedef для сложных типов или с доменным смыслом
typedef UserId = int;      // ← Спорно: потеря type safety (UserId == int)
typedef Json = Map<String, dynamic>; // ← Полезно: сокращает длинный тип
```

### ❌ Old-style typedef

```dart
// УСТАРЕЛО — не используйте:
typedef int OldOp(int a, int b);

// НОВЫЙ стиль:
typedef NewOp = int Function(int a, int b);
```

### ❌ Ожидание type safety от typedef

```dart
typedef UserId = int;
typedef ProductId = int;

// UserId и ProductId — это оба int! Проверка типов не поможет:
void deleteUser(UserId id) => print('deleted user $id');

void main() {
  ProductId productId = 42;
  deleteUser(productId); // ✅ Компилируется! Нет ошибки!

  // Для настоящей type safety используйте extension types (Dart 3.3):
  // extension type UserId(int id) implements int {}
}
```

### ❌ Забыть generic параметр

```dart
typedef Handler<T> = void Function(T);

// ОШИБКА: забыли указать T — будет Handler<dynamic>
void register(Handler handler) {} // handler = void Function(dynamic)

// ПРАВИЛЬНО:
void register<T>(Handler<T> handler) {}
// или конкретный тип:
void registerString(Handler<String> handler) {}
```

### ❌ Слишком глубокая вложенность function types

```dart
// НЕЧИТАЕМО:
void Function(String Function(int Function(bool))) chaos;

// РЕШЕНИЕ: разбить на typedef'ы
typedef BoolToInt = int Function(bool);
typedef IntToString = String Function(BoolToInt);
typedef Processor = void Function(IntToString);

Processor clear; // Тот же тип, но понятный
```

## 9. Сравнение с альтернативами

| Подход                    | Пример                                    | Когда использовать                    |
| ------------------------- | ----------------------------------------- | ------------------------------------- |
| Inline function type      | `void Function(int)`                      | Одноразовое использование             |
| typedef                   | `typedef Cb = void Function(int)`         | Повторное использование, длинные типы |
| Abstract class (SAM)      | `abstract class OnClick { void call(); }` | Нужны дополнительные методы           |
| Extension type (Dart 3.3) | `extension type UserId(int id) {}`        | Type-safe wrapper без overhead        |

### typedef vs extension type для wrapper'ов

```dart
// typedef — НЕ type-safe  (alias)
typedef UserId = int;

// extension type — type-safe (zero-cost wrapper)
extension type const UserId2(int value) {}

void main() {
  UserId a = 42;
  int b = a; // ✅ — typedef не различает типы

  UserId2 c = UserId2(42);
  // int d = c; // ❌ — extension type не совместим напрямую
}
```

## 10. Когда НЕ стоит использовать

- **`typedef MyString = String`** — бессмысленный alias без добавления смысла.
- **Один раз в коде** — если function type встречается однократно, inline читабельнее.
- **Ожидание type safety** — typedef = alias, не новый тип. Для safety → extension type.
- **Старый синтаксис** — `typedef int F(int)` устарел, используйте `typedef F = int Function(int)`.

## 11. Краткое резюме

1. **Function type** — `ReturnType Function(Params)` описывает сигнатуру функции.
2. **typedef** — именованный alias для типа: `typedef Name = Type`.
3. **Нулевой overhead** — typedef стирается при компиляции.
4. **Generic typedef** — `typedef Mapper<T, R> = R Function(T)` — параметризованные alias'ы.
5. **Non-function typedef** (Dart 2.13+) — `typedef Json = Map<String, dynamic>`.
6. **Не path к type safety** — `typedef UserId = int` не защищает от путаницы; для этого → `extension type`.
7. **Новый синтаксис** — всегда `typedef Name = ...`, не `typedef R Name(...)`.

---

> **Назад:** [6.3 Замыкания и лексическая область](06_03_closures.md) · **Далее:** [7.0 ООП — обзор](../07_oop/07_00_overview.md)
