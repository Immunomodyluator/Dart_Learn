# 2.3 Типы и вывод типов

## 1. Формальное определение

Dart — **статически типизированный** язык с **sound type system** (звуковой системой типов). «Sound» означает, что если анализатор определил тип переменной как `String`, в runtime она **гарантированно** является `String`. Ни при каких условиях (кроме `dynamic`) тип не будет нарушен.

**Type inference** (вывод типов) — механизм, при котором компилятор определяет типы автоматически на основе контекста: инициализации, аргументов, возвращаемых значений.

**Уровень:** типизация / семантика языка.

## 2. Зачем это нужно

- **Безопасность** — sound typing гарантирует отсутствие type errors в runtime (исключение — `dynamic` и `as`).
- **Производительность** — статические типы позволяют компилятору генерировать оптимальный код (прямые вызовы вместо dispatch).
- **Tooling** — типы обеспечивают автодополнение, рефакторинг, навигацию в IDE.
- **Читаемость** — type inference убирает шум: `var items = <String>[]` вместо `List<String> items = <String>[]`.

## 3. Как это работает

### Иерархия типов в Dart

```
              Object?           ← Top type (nullable)
             /       \
         Object       Null      ← Object — top non-nullable
        /   |   \
      num  String  bool  List<T>  Map<K,V>  Function  ...
     /   \
   int  double

              Never             ← Bottom type (пустой тип)
```

| Тип       | Описание                                                                        |
| --------- | ------------------------------------------------------------------------------- |
| `Object?` | Любое значение, включая `null`. Супертип всех типов.                            |
| `Object`  | Любое не-null значение.                                                         |
| `Null`    | Тип, единственное значение которого — `null`.                                   |
| `Never`   | Тип без экземпляров. Возвращается функциями, которые всегда бросают исключение. |
| `void`    | Указывает, что возвращаемое значение не должно использоваться.                  |
| `dynamic` | Отключает статическую проверку (opt-out из type system).                        |

### Type inference в действии

```dart
// Локальные переменные
var name = 'Alice';           // → String
var count = 42;               // → int
var prices = [9.99, 19.99];   // → List<double>
var users = <String, int>{};  // → Map<String, int>

// Возвращаемый тип функции
var square = (int x) => x * x;  // → int Function(int)

// Generic-вывод
var list = [1, 2, 3];         // → List<int>
var set = {1, 2, 3};          // → Set<int>
var map = {'a': 1, 'b': 2};   // → Map<String, int>
```

### Downward inference (вывод сверху вниз)

```dart
// Тип переменной подсказывает тип элементов
List<int> ids = [];            // Пустой List<int>, а не List<dynamic>

// Тип параметра подсказывает тип лямбды
void processItems(List<String> items, bool Function(String) predicate) {}

processItems(
  ['a', 'b', 'c'],
  (item) => item.isNotEmpty,  // item выведен как String из сигнатуры
);
```

### Upward inference (вывод снизу вверх)

```dart
// Тип переменной выводится из правой части
var result = 42;               // int (upward: из литерала)
var mixed = [1, 2.0, 3];      // List<num> (LUB: least upper bound int и double)
var objects = [1, 'hello'];   // List<Object> (LUB int и String)
```

### Type promotion (продвижение типа)

```dart
void process(Object value) {
  // value — тип Object. Нельзя вызвать .length

  if (value is String) {
    // Smart cast: value продвинут до String
    print(value.length);      // OK!
    print(value.toUpperCase()); // OK!
  }

  if (value is! int) return;
  // Здесь value продвинут до int
  print(value.isEven);        // OK!
}
```

Type promotion работает с `is`, `is!`, `== null`, `!= null` и flow analysis.

### Явное приведение типов

```dart
Object obj = 'Hello';

// as — unsafe cast (может бросить TypeError)
String s = obj as String;     // OK в runtime

// as с неправильным типом
// int n = obj as int;        // TypeError в runtime!

// Безопасная альтернатива
if (obj is String) {
  String s = obj;             // Безопасно после is-check
}
```

## 4. Минимальный пример

```dart
void main() {
  // Type inference
  var x = 42;              // int
  var y = 3.14;            // double
  var z = x + y;           // double (int + double = double)

  // Type promotion
  Object value = 'Hello';
  if (value is String) {
    print(value.toUpperCase()); // HELLO — автокаст
  }

  // Generics inference
  var items = [1, 2, 3];  // List<int>
  var doubled = items.map((e) => e * 2); // Iterable<int>

  print('$z, $doubled');
}
```

## 5. Практический пример

### Типобезопасный парсер JSON-ответа

```dart
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;

  const ApiResponse.ok(this.data)
      : success = true,
        error = null;

  const ApiResponse.fail(this.error)
      : success = false,
        data = null;
}

// Типобезопасный парсинг
ApiResponse<List<String>> parseUsers(Map<String, dynamic> json) {
  if (json['status'] != 'ok') {
    return ApiResponse.fail(json['error'] as String? ?? 'Unknown error');
  }

  final rawList = json['users'];
  if (rawList is! List) {
    return ApiResponse.fail('Invalid users format');
  }

  // Type promotion: rawList теперь List
  final users = rawList.cast<String>().toList();
  return ApiResponse.ok(users);
}

void main() {
  final json = {
    'status': 'ok',
    'users': ['Alice', 'Bob', 'Charlie'],
  };

  final response = parseUsers(json);  // ApiResponse<List<String>>

  if (response.success) {
    // Type promotion: data гарантированно не null
    for (final user in response.data!) {
      print(user);  // String — тип известен
    }
  }
}
```

**Архитектурная корректность:**

- `ApiResponse<T>` — обобщённый тип, позволяющий использовать разные модели данных.
- `dynamic` ограничен границей `Map<String, dynamic>` (вход из JSON). Внутри — строгие типы.
- `is!` check — безопасная проверка перед cast.

## 6. Что происходит под капотом

### Sound type system vs unsound

```
   Sound (Dart, Kotlin)              Unsound (TypeScript, Java generics)
   ─────────────────                 ──────────────────────────────────
   Если компилятор сказал            Компилятор может «соврать»:
   String → в runtime String         String? → в runtime может быть number

   Нет runtime type errors            Возможны ClassCastException
   (кроме dynamic/as)                 в неожиданных местах
```

### Reified generics

В Dart дженерики **сохраняются в runtime** (reified), в отличие от Java (type erasure):

```dart
void main() {
  var list = <int>[1, 2, 3];
  print(list is List<int>);    // true — тип сохранён
  print(list is List<String>); // false — можно проверить!

  // В Java: list instanceof List<Integer> → НЕВОЗМОЖНО (type erasure)
}
```

### Как работает type inference у компилятора

CFE (Common Front End) проходит AST в два этапа:

1. **Top-down** (downward inference): тип из контекста (аннотация переменной, параметр функции) передаётся вниз к выражениям.
2. **Bottom-up** (upward inference): типы литералов и подвыражений собираются вверх, вычисляя LUB (Least Upper Bound).

```
// Пример: List<int> ids = [1, 2, 3];
//
// Downward: List<int> → ожидается List<int> → элементы должны быть int
// Upward: 1:int, 2:int, 3:int → LUB = int → List<int>
// Результат: согласован, ОК
```

### Type promotion — flow analysis

Dart использует **flow-sensitive type analysis**: тип переменной может меняться в зависимости от потока управления.

```dart
void example(int? x) {
  // x имеет тип int? (nullable)
  if (x == null) return;
  // x продвинут до int (non-nullable)
  print(x.abs());  // OK
}
```

Это работает потому, что анализатор отслеживает все пути выполнения и гарантирует, что после `if (x == null) return` переменная `x` точно не null.

## 7. Производительность и ресурсы

| Аспект                         | Влияние                                                |
| ------------------------------ | ------------------------------------------------------ |
| Статический тип → прямой вызов | Максимальная скорость                                  |
| `dynamic` → dynamic dispatch   | 5–10× медленнее                                        |
| `as` cast                      | ~5 нс (проверка таблицы типов)                         |
| `is` check                     | ~5 нс                                                  |
| Reified generics               | Небольшой overhead по памяти (хранение type arguments) |
| Type inference                 | Нулевой runtime overhead (всё решается при компиляции) |

**Type inference не имеет runtime-стоимости** — это чисто compile-time операция. `var x = 42` и `int x = 42` генерируют абсолютно одинаковый код.

## 8. Частые ошибки и антипаттерны

### ❌ Unnecessary cast

```dart
// Плохо: лишний cast после is-check
if (value is String) {
  print((value as String).length);  // as String — избыточен!
}

// Хорошо: type promotion делает cast автоматически
if (value is String) {
  print(value.length);
}
```

### ❌ LUB-сюрприз

```dart
var list = [1, 2.0];   // List<num>, не List<int>!
// list.add('hello');   // ОШИБКА: String не num

var mixed = [1, 'a'];  // List<Object>
```

Если типы элементов не совпадают, Dart вычисляет LUB (наименьший общий супертип). Это может быть неожиданно.

### ❌ Потеря type promotion

```dart
class Box {
  Object? value;
}

void process(Box box) {
  if (box.value is String) {
    // НЕ РАБОТАЕТ! box.value может измениться между проверкой и использованием
    // print(box.value.length); // ОШИБКА

    // Решение: присвоить в локальную переменную
    final v = box.value;
    if (v is String) {
      print(v.length);  // OK
    }
  }
}
```

Type promotion не работает для полей класса (они могут быть изменены другим потоком или setter'ом). Продвигаются только **локальные переменные** и **final поля**.

### ❌ Использование `as` без проверки

```dart
// Опасно:
final name = json['name'] as String;  // TypeError если null или не String

// Безопасно:
final name = json['name'];
if (name is String) {
  print(name);
}
```

## 9. Сравнение с альтернативами

| Аспект           | Dart             | Kotlin              | TypeScript              | Java                     |
| ---------------- | ---------------- | ------------------- | ----------------------- | ------------------------ |
| Soundness        | Sound            | Sound               | Unsound                 | Mostly sound             |
| Reified generics | ✅               | ✅                  | ❌ (erased)             | ❌ (erased)              |
| Type inference   | ✅ (local)       | ✅ (local + lambda) | ✅ (everywhere)         | ✅ (limited)             |
| Smart cast       | ✅ (`is` + flow) | ✅ (`is` + flow)    | ✅ (narrowing)          | ❌ (нужен explicit cast) |
| Union types      | ❌               | ❌                  | ✅ (`string \| number`) | ❌                       |
| Null safety      | Sound            | Sound               | Configurable            | Annotations only         |

**Dart и Kotlin** — близнецы по sound typing и smart cast. TypeScript — unsound (design choice для совместимости с JS). Java — sound, но без smart cast и с erased generics.

## 10. Когда НЕ стоит использовать

- **Explicit type everywhere** — не нужно писать `String name = 'Alice'`, если `var name = 'Alice'` очевидно. Избыточные аннотации — шум.
- **`as` вместо `is`** — `as` бросает исключение при несовпадении. Используйте `is` + smart cast для безопасности.
- **Борьба с type inference** — если компилятор выводит не тот тип, это сигнал о проблеме в логике, а не повод для `as`.

## 11. Краткое резюме

1. **Sound type system** — если Dart сказал `String`, это всегда `String` в runtime. Нет сюрпризов (кроме `dynamic`/`as`).
2. **Type inference** — `var`, generic arguments, lambda parameters выводятся автоматически. Zero runtime cost.
3. **Reified generics** — `List<int>` знает свой тип в runtime. Можно проверить через `is List<int>`. В Java это невозможно.
4. **Type promotion** — `is`-check продвигает тип автоматически (smart cast). Работает только для локальных переменных.
5. **`Object` vs `dynamic`**: `Object` — безопасный top-type; `dynamic` — opt-out из type system.
6. **LUB** (Least Upper Bound) — при смешении типов Dart вычисляет ближайший общий супертип. `[1, 2.0]` → `List<num>`.
7. **`as` — unsafe**, `is` — safe. Предпочитайте `is` + smart cast вместо `as`.

---

> **Следующий:** [2.4 const и final](02_04_const_final.md)
