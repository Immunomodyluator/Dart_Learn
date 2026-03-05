# Урок 2. Основы синтаксиса

> Охватывает подтемы: 2.1 Hello World, 2.2 Переменные, 2.3 Типы и вывод типов, 2.4 const и final, 2.5 Null Safety

---

## 1. Формальное определение

Dart — **строго типизированный, объектно-ориентированный язык** с синтаксисом в стиле C/Java. Ключевые особенности синтаксиса:

- **Sound null safety** — система типов гарантирует отсутствие null-ошибок во время компиляции
- **Вывод типов** — компилятор выводит тип из значения, явное указание необязательно
- `const` — значение вычисляется на этапе компиляции; `final` — однократное присвоение в runtime
- Всё является объектом, включая числа, функции и `null`

Уровень: **синтаксис, типизация**.

---

## 2. Зачем это нужно

**Проблемы, которые решает подход Dart:**

- **Sound null safety** устраняет целый класс ошибок NPE (NullPointerException) на уровне системы типов — компилятор не позволит использовать nullable значение без проверки
- Строгая типизация + вывод типов: код выглядит как динамически типизированный, но ведёт себя как статически типизированный
- `const` даёт Flutter возможность пропускать перерисовку виджетов — производительность связана с синтаксисом напрямую

**Сценарии:** основа для любого Dart-проекта — Flutter, сервер, CLI.

---

## 3. Как это работает

### Структура программы

Dart-программа — набор файлов `.dart`. Точка входа — функция `main`:

```dart
void main() {
  print('Hello, Dart!');
}

// С аргументами командной строки
void main(List<String> args) {
  print(args);
}
```

### Объявление переменных

```dart
// var — тип выводится, переменная мутируемая
var name = 'Alice';          // String
var age = 30;                // int
var ratio = 3.14;            // double

// Явный тип — предпочтительно в публичном API
String greeting = 'Hello';
int count = 0;

// dynamic — отключает статическую проверку (избегать!)
dynamic anything = 42;
anything = 'now a string';  // OK, но теряем все guarantees

// Object — базовый тип всего, но с проверкой
Object value = 42;
// value.toUpperCase();  // ОШИБКА компиляции — Object не имеет toUpperCase
```

### Null Safety

Ключевая особенность Dart 2.12+: **по умолчанию все типы non-nullable**.

```dart
String name = 'Alice';   // Non-nullable: никогда не может быть null
String? nullable = null; // Nullable: суффикс ? разрешает null

// Компилятор требует проверки перед использованием nullable
void greet(String? name) {
  // print(name.length);  // ОШИБКА компиляции: name может быть null
  
  if (name != null) {
    print(name.length);   // OK: компилятор знает, что null исключён (smart cast)
  }
  
  print(name?.length);    // null-aware: вернёт null если name == null
  print(name ?? 'Guest'); // null-coalescing: 'Guest' если null
  print(name!.length);    // null-assertion: принудительный unwrap (бросит если null)
}
```

### const и final

```dart
// final — однократное присвоение (вычисляется в runtime)
final DateTime now = DateTime.now();  // OK: вычисляется при запуске
final List<int> items = [1, 2, 3];   // Сама ссылка final, содержимое мутируемо!

// const — константа времени компиляции (вычисляется до запуска)
const double pi = 3.14159;
const List<int> primes = [2, 3, 5, 7]; // Полностью иммутабельна

// const DateTime.now();  // ОШИБКА: DateTime.now() не константа компиляции

// Контекстный const — если тип очевиден, const можно опустить
const list = [1, 2, 3]; // Dart выводит тип и const из контекста
```

---

## 4. Минимальный пример

```dart
void main() {
  // Вывод типов
  var city = 'Moscow';        // String
  var population = 12_000_000;  // int (нижнее подчёркивание — разделитель)
  var density = 4900.5;       // double
  var isCapital = true;       // bool

  // Null safety в действии
  String? maybeNull;
  print(maybeNull ?? 'not set'); // 'not set'

  maybeNull = 'assigned';
  print(maybeNull.toUpperCase()); // 'ASSIGNED' — safe, нет NPE

  // const vs final
  const gravity = 9.81;          // compile-time constant
  final startTime = DateTime.now(); // runtime constant

  print('$city: pop=$population, density=$density, capital=$isCapital');
  print('Gravity: $gravity, Started: $startTime');
  
  // Строковая интерполяция
  print('${city.toUpperCase()} population: $population');
}
```

---

## 5. Практический пример

Конфигурация приложения — типичный случай где const/final/nullable используются вместе:

```dart
// Конфигурация с null safety и const
class AppConfig {
  // Константы времени компиляции
  static const String appName = 'MyApp';
  static const int defaultTimeout = 30; // секунды

  // Параметры, известные только при инициализации
  final String baseUrl;
  final String? apiKey;         // Может отсутствовать в dev-режиме
  final bool isProduction;

  const AppConfig({
    required this.baseUrl,
    this.apiKey,
    this.isProduction = false,
  });

  // Вычисляемое свойство
  bool get hasApiKey => apiKey != null;

  // Безопасное применение ключа
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (apiKey case final key?) 'Authorization': 'Bearer $key',
  };
}

void main() {
  const devConfig = AppConfig(
    baseUrl: 'http://localhost:8080',
    isProduction: false,
  );

  const prodConfig = AppConfig(
    baseUrl: 'https://api.example.com',
    apiKey: 'secret-key',
    isProduction: true,
  );

  print(devConfig.hasApiKey);    // false
  print(prodConfig.headers);    // включает Authorization
  
  // Smart cast после проверки
  if (prodConfig.apiKey case final key?) {
    // key имеет тип String (non-nullable) внутри этого блока
    print('Key length: ${key.length}');
  }
}
```

**Архитектурная корректность:** `const` на объекте означает, что виджеты Flutter не будут перерисовываться при изменении родителя — это прямое влияние синтаксиса на производительность.

---

## 6. Что происходит под капотом

### Null safety: flow analysis

Dart-анализатор выполняет **definite assignment analysis** и **type promotion**:

```dart
String? name = getValue();

// Анализатор отслеживает состояние переменной в каждой точке потока
if (name == null) return;
// Здесь анализатор знает: name — non-nullable String
print(name.length); // Нет нужды в ? или !
```

Это **compile-time feature** — никаких runtime-проверок не добавляется. В AOT-коде нет накладных расходов на null-проверки, прошедшие анализ.

### const: canonicalization

```dart
// Оба объекта — один и тот же объект в памяти
const a = [1, 2, 3];
const b = [1, 2, 3];
print(identical(a, b)); // true — canonicalized

// final — разные объекты
final c = [1, 2, 3];
final d = [1, 2, 3];
print(identical(c, d)); // false
```

Dart VM хранит `const` объекты в **константном пуле** — аналог String pool в JVM, но для всех const-значений.

### var vs dynamic в runtime

```dart
var x = 42;      // Тип String зафиксирован компилятором — x: int
dynamic y = 42;  // Тип проверяется в runtime — медленнее, небезопасно
```

`dynamic` отключает весь статический анализ и переходит к runtime-диспатчу — дороже по производительности.

---

## 7. Производительность и ресурсы

**Эффективность:**
- `const`-объекты не аллоцируются заново — используются из пула
- Flow analysis устраняет лишние null-проверки из скомпилированного кода
- Вывод типов не влияет на runtime — это compile-time оптимизация

**Узкие места:**
- Злоупотребление `dynamic` отключает оптимизации (inline caching, monomorphic dispatch)
- `String?` с частым `!` вместо правильной обработки — потенциальный `Null check operator used on a null value`

---

## 8. Частые ошибки и антипаттерны

**1. `!` вместо правильной обработки null:**
```dart
// НЕВЕРНО — бросает исключение в runtime
String name = user.displayName!;

// ВЕРНО — явное значение по умолчанию
String name = user.displayName ?? 'Anonymous';
```

**2. `dynamic` без необходимости:**
```dart
// НЕВЕРНО — теряем все гарантии типизации
dynamic result = fetchData();
result.process(); // Нет проверки компилятором

// ВЕРНО — явный тип или Object с приведением
Object result = fetchData();
if (result is String) print(result.length); // smart cast
```

**3. Мутируемый `final` контейнер:**
```dart
final items = <int>[1, 2, 3];
items.add(4); // РАБОТАЕТ! final означает только что items не может быть переназначен
// Для настоящей иммутабельности:
const fixedItems = [1, 2, 3]; // или List.unmodifiable(...)
```

**4. Ненужное `var` вместо типа в публичном API:**
```dart
// НЕВЕРНО — непонятно что возвращает функция
var processUser(var data) => ...

// ВЕРНО — явные типы в сигнатурах
User processUser(Map<String, dynamic> data) => ...
```

---

## 9. Сравнение с альтернативами

| Аспект | Dart | Kotlin | TypeScript | Java |
|---|---|---|---|---|
| Null safety | Sound (compile-time) | Sound (compile-time) | Unsound (loopholes) | Опциональные аннотации |
| Вывод типов | `var`, полный контекстный | `val`/`var` | `let`/`const` | `var` (Java 10+) |
| `const` | compile-time canonic. | `const val` | `as const` | `static final` |
| `dynamic` | Доступен (опасно) | Нет аналога | `any` | Reflection |
| NPE возможен? | Только через `!` | Только через `!!` | Да (any, неверные типы) | Да |

**Преимущество Dart:** sound null safety без исключений (no loopholes) — если код компилируется, NPE невозможен без явного `!`.

---

## 10. Когда НЕ стоит использовать подход Dart

- **Быстрое прототипирование** с частыми изменениями типов — строгая типизация замедляет первые итерации
- **Интеграция с динамическими JSON API** где схема неизвестна — `Map<String, dynamic>` везде теряет все преимущества типизации (решение: code generation через `json_serializable`)
- **Код-ревью стека TypeScript** — `unsound` null safety TypeScript означает разные гарантии

---

## 11. Краткое резюме

1. **Sound null safety** — главное отличие от большинства языков: если компилятор не ругается, NullPointerException невозможен без явного `!`.
2. **`var` выводит тип, `dynamic` отключает типизацию** — это принципиально разные вещи; `dynamic` следует избегать.
3. **`const` = compile-time + canonicalization**: два `const [1,2,3]` — один объект в памяти; важно для производительности Flutter.
4. **`final` фиксирует ссылку, а не содержимое**: `final list = []` — ссылка final, но `list.add(x)` работает.
5. **Smart cast после null-check** — анализатор отслеживает flow и автоматически повышает тип без явного приведения.
6. **`??` и `?.` — основные операторы** при работе с nullable: избегать `!` везде кроме случаев, где null логически невозможен.
7. **Строковая интерполяция `$variable` и `${expression}`** — предпочтительна конкатенации через `+`.
