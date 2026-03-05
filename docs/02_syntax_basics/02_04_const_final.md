# 2.4 const и final

## 1. Формальное определение

**`final`** — переменная, которая может быть присвоена **один раз**. Значение определяется в **runtime** (при выполнении программы). После присваивания ссылка не может быть изменена, но сам объект может быть мутабельным.

**`const`** — переменная, значение которой определяется в **compile-time** (при компиляции). Объект должен быть глубоко неизменяемым (deeply immutable). `const`-объекты каноникализируются: два одинаковых `const`-объекта — это один и тот же объект в памяти.

**Уровень:** синтаксис / семантика неизменяемости.

## 2. Зачем это нужно

- **`final`** — защита от случайного переприсваивания. Гарантирует, что переменная не изменит ссылку после инициализации.
- **`const`** — максимальная оптимизация: compile-time значения не аллоцируются повторно, каноникализируются, могут быть inlined компилятором.
- **Immutability** — предсказуемый код: если значение не может измениться, не нужно отслеживать мутации.

| Сценарий                                         | Что использовать       |
| ------------------------------------------------ | ---------------------- |
| Конфигурационные значения                        | `const`                |
| Результат вычисления, известный только в runtime | `final`                |
| Неизменяемый объект (виджет во Flutter)          | `const` constructor    |
| Параметр, не меняющийся в методе                 | `final` (в параметрах) |

## 3. Как это работает

### final — одно присваивание

```dart
final name = 'Alice';       // Тип: String (inferred)
final int age = 30;          // Тип: int (explicit)
// name = 'Bob';             // ОШИБКА: final нельзя переприсвоить

// Но объект может быть мутабельным!
final list = [1, 2, 3];     // List<int>
list.add(4);                 // OK! Мутируем содержимое
// list = [5, 6];            // ОШИБКА: нельзя переприсвоить ссылку
```

### const — compile-time значение

```dart
const pi = 3.14159;          // Compile-time constant
const tau = pi * 2;          // OK: выражение из const-значений
const greeting = 'Hello, ${'World'}'; // OK: строковая интерполяция const

// const time = DateTime.now();  // ОШИБКА: now() — runtime-вызов
final time = DateTime.now();     // OK для final
```

### Что может быть const

```dart
// Литералы
const x = 42;
const s = 'hello';
const b = true;
const d = 3.14;
const n = null;

// Выражения из const
const sum = 1 + 2;
const concatenated = 'a' + 'b';
const conditional = 1 > 0 ? 'yes' : 'no';

// Const-коллекции
const list = [1, 2, 3];        // Неизменяемый List
const set = {1, 2, 3};         // Неизменяемый Set
const map = {'a': 1, 'b': 2};  // Неизменяемый Map

// Const-конструкторы (если класс поддерживает)
const point = Point(0, 0);
const size = Size(100, 200);
```

### const-конструктор

```dart
class Color {
  final int r, g, b;

  // Все поля — final, конструктор — const
  const Color(this.r, this.g, this.b);

  static const red = Color(255, 0, 0);
  static const green = Color(0, 255, 0);
  static const blue = Color(0, 0, 255);
}

void main() {
  const c1 = Color(255, 0, 0);
  const c2 = Color(255, 0, 0);

  // Каноникализация: один объект в памяти
  print(identical(c1, c2));           // true
  print(identical(c1, Color.red));    // true
}
```

### Каноникализация

```dart
const a = [1, 2, 3];
const b = [1, 2, 3];
print(identical(a, b));  // true — один объект в памяти

final c = [1, 2, 3];
final d = [1, 2, 3];
print(identical(c, d));  // false — разные объекты
```

### const в контексте vs const-переменная

```dart
// const-переменная
const list = [1, 2, 3];  // list — const, и значение — const

// const в контексте (без явного объявления переменной)
var list2 = const [1, 2, 3];  // list2 — var (переназначаема!), но значение — const
list2 = [4, 5, 6];            // OK: переприсвоили к мутабельному списку

// In Flutter:
Widget build(BuildContext context) {
  return const Text('Hello');   // const применяется к объекту Text, не к переменной
}
```

## 4. Минимальный пример

```dart
void main() {
  // final — runtime constant
  final now = DateTime.now();
  print('Текущее время: $now');

  // const — compile-time constant
  const maxRetries = 3;
  const baseUrl = 'https://api.example.com';

  // Каноникализация
  const list1 = [1, 2, 3];
  const list2 = [1, 2, 3];
  print(identical(list1, list2)); // true

  // final list — мутабельное содержимое
  final mutableList = [1, 2, 3];
  mutableList.add(4);
  print(mutableList); // [1, 2, 3, 4]
}
```

## 5. Практический пример

### Конфигурация приложения с const

```dart
// lib/src/config.dart
class AppConfig {
  final String apiUrl;
  final int timeout;
  final bool debugMode;

  const AppConfig({
    required this.apiUrl,
    this.timeout = 30,
    this.debugMode = false,
  });

  static const production = AppConfig(
    apiUrl: 'https://api.myapp.com',
    timeout: 15,
  );

  static const development = AppConfig(
    apiUrl: 'http://localhost:8080',
    timeout: 60,
    debugMode: true,
  );
}

// lib/src/api_client.dart
class ApiClient {
  final AppConfig config;

  // Конструктор принимает конфигурацию
  ApiClient(this.config);

  // Заголовки — const Map, создаётся один раз
  static const _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Map<String, String> get headers => {
        ..._defaultHeaders,
        if (config.debugMode) 'X-Debug': 'true',
      };
}

void main() {
  // const-объект — zero allocation overhead
  const config = AppConfig.production;
  final client = ApiClient(config);
  print(client.headers);
}
```

**Архитектурная корректность:**

- `AppConfig` — immutable data class с const-конструктором.
- Предопределённые конфигурации (`production`, `development`) — static const. Созданы при компиляции, не аллоцируются в runtime.
- `_defaultHeaders` — статический const Map. Один объект на всё приложение.

## 6. Что происходит под капотом

### Compile-time evaluation

```
const x = 2 + 3;
```

Компилятор вычисляет `2 + 3 = 5` **при компиляции**. В IR (промежуточном представлении) хранится литерал `5`, а не выражение.

### Каноникализация в памяти

```
const a = Color(255, 0, 0);
const b = Color(255, 0, 0);

Heap:
┌─────────────────────────┐
│ Color { r:255, g:0, b:0 } │  ← один объект
└─────────────────────────┘
      ▲            ▲
      │            │
   a ─┘         b ─┘     ← обе ссылки → один объект
```

Dart VM хранит **canonical table** — хеш-таблицу всех const-объектов. При создании нового `const` проверяется: есть ли уже идентичный? Если да — возвращается существующий.

### final vs const в generated code

```dart
final x = 42;        // → аллокация (или SMI tagged pointer)
                      //   значение определяется в runtime

const y = 42;         // → литерал 42 прямо в коде (inlined)
                      //   нет аллокации, нет ссылки
```

AOT-компилятор может **inline** const-значения: вместо чтения из переменной подставляет значение напрямую в точку использования.

### const-коллекции

```dart
const list = [1, 2, 3];
// Внутренне:
// _ImmutableList с фиксированной длиной
// Попытка add/remove → UnsupportedError

list.add(4);
// Uncaught Error: Unsupported operation: Cannot add to an unmodifiable list
```

`const`-коллекции реализованы через `_ImmutableList`, `_ImmutableMap` — специальные классы VM без поддержки мутации.

## 7. Производительность и ресурсы

| Аспект        | final                        | const                                 |
| ------------- | ---------------------------- | ------------------------------------- |
| Аллокация     | В runtime (heap)             | При компиляции (canonical)            |
| Дублирование  | Каждый `final` — свой объект | Одинаковые const — один объект        |
| Доступ        | Чтение ссылки                | Inlined или чтение из canonical table |
| Сборка мусора | Подлежит GC                  | Никогда не собирается GC              |

**const — бесплатен**. Это лучшая оптимизация, которую вы можете сделать: zero allocation, zero GC, один объект в памяти.

**Во Flutter** `const` widgets особенно важны:

```dart
// Без const: при каждом rebuild() — новый объект Text
Text('Hello')

// C const: один объект на всё время жизни приложения
const Text('Hello')
```

Flutter сравнивает виджеты через `identical()`. Если виджет — `const`, сравнение мгновенно (`true`), и rebuild поддерева пропускается.

## 8. Частые ошибки и антипаттерны

### ❌ final не защищает содержимое

```dart
final list = [1, 2, 3];
list.add(4);           // OK! list мутабельный
list[0] = 999;         // OK!

// Если нужна неизменяемость содержимого — используйте const или List.unmodifiable:
final immutable = List.unmodifiable([1, 2, 3]);
immutable.add(4);      // UnsupportedError
```

### ❌ const где невозможно

```dart
// ОШИБКА: DateTime.now() — рантайм-вызов
// const now = DateTime.now();

// ОШИБКА: конструктор не const
// const list = List.filled(3, 0); // List.filled != const

// OK:
const list = [0, 0, 0];
```

### ❌ Забытый const в Flutter

```dart
// Плохо (линтер предупредит): лишние аллокации
return Container(
  child: Text('Static text'),  // Новый объект при каждом build
);

// Хорошо: const подавляет пересоздание
return Container(
  child: const Text('Static text'),
);
```

### ❌ const для мутабельных объектов

```dart
class MutablePoint {
  int x, y;                      // Не final!
  MutablePoint(this.x, this.y);
  // const MutablePoint(this.x, this.y); // ОШИБКА: поля не final
}
```

const-конструктор требует, чтобы **все поля** были `final`.

## 9. Сравнение с альтернативами

| Концепция             | Dart       | Kotlin                  | TypeScript           | Java             |
| --------------------- | ---------- | ----------------------- | -------------------- | ---------------- |
| Неизменяемая ссылка   | `final`    | `val`                   | `const`              | `final`          |
| Compile-time constant | `const`    | `const val` (limited)   | `as const` (partial) | `static final`   |
| Каноникализация       | ✅ (const) | ❌                      | ❌                   | String pool only |
| Deep immutability     | ✅ (const) | ❌ (val не гарантирует) | ❌                   | ❌               |
| const-конструктор     | ✅         | ❌                      | ❌                   | ❌               |

**Уникальность Dart:** const-конструкторы и каноникализация — нет аналогов в mainstream языках. Это позволяет Flutter делать `const Widget()` — один объект, zero rebuild.

## 10. Когда НЕ стоит использовать

- **`const` для динамических данных** — значения из API, пользовательского ввода, конфигурации env — не могут быть const. Используйте `final`.
- **`final` для переменных в циклах** — `for (final i = 0; ...)` не имеет смысла; используйте `var` или `for (final item in list)`.
- **Чрезмерная погоня за const** — не нужно делать const абсолютно всё. Lint `prefer_const_declarations` поможет найти подходящие места.

## 11. Краткое резюме

1. **`final`** = одно присваивание, значение определяется в **runtime**. Ссылка неизменна, объект может быть мутабельным.
2. **`const`** = значение определяется при **компиляции**. Объект глубоко неизменяем.
3. **Каноникализация** — одинаковые const-объекты занимают одно место в памяти. `identical(const A(), const A())` → `true`.
4. **const-конструктор** требует, чтобы все поля были `final`, а конструктор — `const`.
5. **const коллекции** (`const [1, 2, 3]`) — иммутабельны. Попытка модификации → `UnsupportedError`.
6. **Во Flutter** `const` виджеты критичны: предотвращают пересоздание поддерева при rebuild.
7. **Правило**: если значение известно при компиляции → `const`. Если известно при запуске, но не меняется → `final`. Если меняется → `var`.

---

> **Следующий:** [2.5 Null Safety](02_05_null_safety.md)
