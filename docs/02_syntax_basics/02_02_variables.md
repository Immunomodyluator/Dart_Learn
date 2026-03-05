# 2.2 Объявление переменных

## 1. Формальное определение

В Dart переменная — это **именованная ссылка на объект**. Каждая переменная хранит ссылку на объект определённого типа. Dart предоставляет несколько способов объявления переменных:

| Ключевое слово | Тип                        | Мутабельность            | Типизация              |
| -------------- | -------------------------- | ------------------------ | ---------------------- |
| `var`          | Выводится автоматически    | Мутабельная              | Статическая (inferred) |
| `Type x`       | Указан явно                | Мутабельная              | Статическая (explicit) |
| `dynamic`      | Любой (отключает проверки) | Мутабельная              | Динамическая           |
| `Object`       | Базовый тип                | Мутабельная              | Статическая            |
| `final`        | Выводится / указан         | Не переназначаема        | Статическая            |
| `const`        | Выводится / указан         | Глубоко неизменяема      | Статическая            |
| `late`         | Выводится / указан         | Отложенная инициализация | Статическая            |

**Уровень:** синтаксис / типизация.

## 2. Зачем это нужно

- **`var`** — быстрое объявление без явного типа; тип фиксируется при инициализации.
- **Explicit type** — самодокументирование кода, когда тип неочевиден из правой части.
- **`dynamic`** — «аварийный люк» для работы с нетипизированными данными (JSON, FFI). Отключает статические проверки.
- **`Object`** — безопасная альтернатива `dynamic`: разрешает хранить любой объект, но при этом ограничивает вызовы только методами `Object`.
- **`late`** — решает проблему обязательной инициализации, когда значение станет доступно позже (dependency injection, lifecycle hooks).

## 3. Как это работает

### var — вывод типа

```dart
var name = 'Alice';   // Тип: String (выведен из литерала)
name = 'Bob';         // OK: то же тип String
// name = 42;         // ОШИБКА: int нельзя присвоить переменной типа String
```

`var` фиксирует тип **навсегда** при первом присваивании. После этого переменная ведёт себя как строго типизированная.

### Явная типизация

```dart
String city = 'Moscow';
int population = 12_000_000;    // Dart 3: разделитель разрядов
double area = 2561.5;
bool isCool = true;
```

### dynamic — отключение статических проверок

```dart
dynamic value = 'Hello';
value = 42;          // OK: dynamic принимает любой тип
value = [1, 2, 3];   // OK

// Компилятор НЕ проверяет вызовы:
value.foo();         // Компилируется, но упадёт в runtime!
```

`dynamic` — это **opt-out из системы типов**. Dart не проверяет методы и свойства на этапе компиляции. Ошибки обнаружатся только при выполнении.

### Object — безопасная альтернатива dynamic

```dart
Object value = 'Hello';
value = 42;          // OK: int extends Object

// Компилятор ПРОВЕРЯЕТ вызовы:
// value.length;     // ОШИБКА: Object не имеет свойства length
print(value.toString());  // OK: toString() определён в Object

// Нужен явный cast:
if (value is String) {
  print(value.length);  // OK: smart cast после проверки
}
```

### late — отложенная инициализация

```dart
class Config {
  // Инициализация при первом обращении
  late final String apiUrl = _loadApiUrl();

  String _loadApiUrl() {
    print('Загрузка конфигурации...');
    return 'https://api.example.com';
  }
}

// apiUrl загрузится только когда к ней обратятся
final config = Config();
// Ничего не напечатано
print(config.apiUrl);  // → "Загрузка конфигурации..." → URL
print(config.apiUrl);  // → URL (без повторной загрузки)
```

### Область видимости

```dart
var globalVar = 'top-level';  // Видна во всём файле

void main() {
  var localVar = 'local';    // Видна только в main()

  {
    var blockVar = 'block';  // Видна только в этом блоке
    print(blockVar);
  }

  // print(blockVar);        // ОШИБКА: blockVar не видна здесь
}
```

## 4. Минимальный пример

```dart
void main() {
  // var — тип выводится
  var message = 'Hello';   // String

  // Явная типизация
  int count = 0;

  // dynamic — любой тип, нет проверок
  dynamic anything = 42;
  anything = 'now a string';

  // Object — любой тип, есть проверки
  Object something = 42;
  // something.isEven; // ОШИБКА — нужна проверка типа

  // late — отложенная инициализация
  late String loaded;
  loaded = 'initialized later';

  print('$message $count $anything $something $loaded');
}
```

## 5. Практический пример

### Модель пользователя с разными видами переменных

```dart
class UserProfile {
  // final — не переназначается после конструктора
  final String id;
  final String email;

  // Мутабельная — может меняться
  String displayName;

  // late final — вычисляется при первом обращении
  late final String avatarUrl = _generateAvatarUrl();

  // Nullable — может быть null
  String? bio;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.bio,
  });

  String _generateAvatarUrl() {
    // Дорогая операция — выполняется лениво
    return 'https://avatars.example.com/${id.hashCode}';
  }

  @override
  String toString() {
    return 'UserProfile($displayName, bio: ${bio ?? "не указано"})';
  }
}

void main() {
  var user = UserProfile(
    id: 'u-001',
    email: 'alice@example.com',
    displayName: 'Alice',
  );

  user.displayName = 'Alice Smith';  // OK — мутабельное поле
  // user.id = 'u-002';             // ОШИБКА — final
  user.bio = 'Dart-разработчик';    // OK — nullable поле

  print(user);
  print(user.avatarUrl);  // lazy: вычисляется здесь
}
```

## 6. Что происходит под капотом

### Переменные в памяти

В Dart VM все переменные хранят **ссылки на объекты в heap**. Нет примитивных типов на уровне языковой модели (в отличие от Java с `int` vs `Integer`).

```
Stack (переменная)         Heap (объект)
┌──────────────┐           ┌──────────────────┐
│  name ───────┼──────────►│ String: "Alice"   │
├──────────────┤           ├──────────────────┤
│  count ──────┼──────────►│ int: 42           │
├──────────────┤           │ (tagged pointer   │
│              │           │  для small ints)  │
└──────────────┘           └──────────────────┘
```

**Оптимизация Small Integer (SMI):**
Dart VM использует **tagged pointers** для малых целых чисел. Числа, помещающиеся в указатель (обычно 63 бита на 64-bit платформах), хранятся прямо в ссылке, без аллокации в heap. Это делает `int` операции почти такими же быстрыми, как примитивы в C.

### var vs dynamic — разница на уровне IR

```dart
var x = 42;       // Kernel IR знает: x имеет тип int
x.isEven;         // Прямой вызов метода int.isEven

dynamic y = 42;   // Kernel IR: тип = dynamic
y.isEven;         // Dynamic dispatch → проверка в runtime
```

`var` с выведенным типом генерирует **статический вызов** (быстро). `dynamic` генерирует **динамический dispatch** через `noSuchMethod` lookup (медленно).

### late переменные

`late` переменная — это обёртка с внутренним sentinel-значением:

```
// Логически:
class _LateWrapper<T> {
  bool _initialized = false;
  T? _value;

  T get value {
    if (!_initialized) throw LateInitializationError();
    return _value as T;
  }

  set value(T v) {
    _value = v;
    _initialized = true;
  }
}
```

При обращении к неинициализированной `late` переменной выбрасывается `LateInitializationError`.

## 7. Производительность и ресурсы

| Операция            | Стоимость                                        |
| ------------------- | ------------------------------------------------ |
| `var x = 42` (SMI)  | ~0 аллокаций (tagged pointer)                    |
| `var s = 'text'`    | 1 аллокация в heap                               |
| `dynamic` dispatch  | В 5–10× медленнее статического                   |
| `late` overhead     | 1 bool-проверка при каждом чтении                |
| `Object` + is-check | 1 type test (очень быстрый — таблица типов в VM) |

**Правила:**

- Используйте `var` / explicit type — это **бесплатно** (статический dispatch).
- `dynamic` — только для работы с нетипизированными данными. Каждый вызов метода через `dynamic` — dynamic dispatch.
- `late final` для дорогих операций — ленивая инициализация экономит ресурсы при старте.

## 8. Частые ошибки и антипаттерны

### ❌ dynamic вместо конкретного типа

```dart
// Плохо: потеря всех статических проверок
dynamic user = fetchUser();
print(user.nme);  // Опечатка! Компилятор не заметит. Crash в runtime.

// Хорошо: конкретный тип
User user = fetchUser();
print(user.name);  // Компилятор проверит наличие 'name'
```

### ❌ var без инициализации

```dart
// Ошибка: тип не может быть выведен
// var x;  // тип → dynamic (неявно!)

// Правильно: инициализировать или указать тип
var x = 0;         // int
int x;             // Будет non-nullable, нужно инициализировать до использования
```

### ❌ Путаница var и dynamic

```dart
var a = 42;        // Тип: int (зафиксирован!)
// a = 'hello';    // ОШИБКА: нельзя присвоить String переменной int

dynamic b = 42;    // Тип: dynamic
b = 'hello';       // OK (но опасно)
```

### ❌ late без гарантии инициализации

```dart
late String name;

void printName() {
  print(name);  // LateInitializationError если name не установлен!
}
```

`late` перекладывает проверку инициализации на runtime. Если забыть инициализировать — crash.

### ❌ Mutable top-level переменные

```dart
// Антипаттерн: глобальное мутабельное состояние
var currentUser = User('guest');

// Проблема: кто угодно может изменить, нет контроля
```

## 9. Сравнение с альтернативами

| Концепция                | Dart         | Kotlin       | TypeScript       | Java                    |
| ------------------------ | ------------ | ------------ | ---------------- | ----------------------- |
| Вывод типа               | `var x = 42` | `val x = 42` | `let x = 42`     | `var x = 42` (Java 10+) |
| Мутабельная              | `var`        | `var`        | `let`            | обычное объявление      |
| Неизменяемая ссылка      | `final`      | `val`        | `const`          | `final`                 |
| Динамическая типизация   | `dynamic`    | ❌ (нет)     | `any`            | ❌                      |
| Безопасная «любой тип»   | `Object`     | `Any`        | `unknown`        | `Object`                |
| Отложенная инициализация | `late`       | `lateinit`   | ❌               | ❌                      |
| Nullable                 | `String?`    | `String?`    | `string \| null` | `@Nullable`             |

**Dart `var`** ≈ **Kotlin `var`**: оба выводят тип и фиксируют его. Но в отличие от Kotlin, Dart не имеет `val` — вместо него используется `final`.

## 10. Когда НЕ стоит использовать

- **`dynamic`** — почти никогда. Используйте только при работе с `jsonDecode()` или FFI, и немедленно приводите к конкретному типу.
- **`late`** — не используйте как замену nullable. Если значение может отсутствовать — используйте `String?`, а не `late String`.
- **`var` без инициализации** — создаёт `dynamic` неявно. Всегда инициализируйте `var` или используйте explicit type.

## 11. Краткое резюме

1. **`var`** — выводит тип при инициализации и фиксирует его навсегда. Основной способ объявления локальных переменных.
2. **`dynamic`** — отключает систему типов. Используйте только при работе с нетипизированными данными и немедленно кастуйте.
3. **`Object`** vs **`dynamic`**: `Object` — безопасный (компилятор проверяет вызовы), `dynamic` — небезопасный (всё разрешено, ошибки в runtime).
4. **`late`** — отложенная инициализация. Полезно для dependency injection и ленивых вычислений. Но `LateInitializationError` при забытой инициализации.
5. **Все переменные** — ссылки на объекты в heap. Нет примитивов на уровне языка (но VM оптимизирует SMI через tagged pointers).
6. **Top-level переменные** инициализируются лениво. Не создавайте мутабельные top-level переменные.
7. **`dynamic` dispatch в 5–10× медленнее** статического. Каждое использование `dynamic` — осознанная потеря и типобезопасности, и производительности.

---

> **Следующий:** [2.3 Типы и вывод типов](02_03_types_inference.md)
