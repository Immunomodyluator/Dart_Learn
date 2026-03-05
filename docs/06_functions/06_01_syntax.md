# 6.1 Синтаксис функций

## 1. Формальное определение

**Функция** в Dart — объект типа `Function`, представляющий исполняемый блок кода с именем (или без), параметрами и возвращаемым типом. Dart поддерживает три формы объявления:

- **Именованная функция** — `ReturnType name(params) { body }` — классическое объявление.
- **Стрелочная функция** — `ReturnType name(params) => expression;` — сокращение для одного выражения.
- **Анонимная функция** (лямбда) — `(params) { body }` или `(params) => expr` — без имени.

Все функции — объекты первого класса: могут быть присвоены переменным, переданы как аргументы.

## 2. Зачем это нужно

- **Модульность** — разбиение кода на переиспользуемые блоки.
- **First-class objects** — передача функций как данных: коллбэки, обработчики, стратегии.
- **Arrow syntax** — компактная запись для простых функций (повсеместно в Flutter).
- **Анонимные функции** — inline-коллбэки для `map`, `where`, `sort`, event listeners.
- **Top-level функции** — не нужно создавать класс для утилитарных функций (в отличие от Java).

## 3. Как это работает

### Именованные функции

```dart
// С явным возвращаемым типом
int add(int a, int b) {
  return a + b;
}

// Без возвращаемого типа (выводится как dynamic — не рекомендуется)
multiply(a, b) {
  return a * b;
}

// void — функция ничего не возвращает
void greet(String name) {
  print('Привет, $name!');
}

// Top-level функция (вне класса)
bool isEven(int n) => n.isEven;

void main() {
  print(add(2, 3));     // 5
  greet('Dart');          // Привет, Dart!
  print(isEven(4));      // true
}
```

### Стрелочные функции (arrow)

```dart
// => expr — сокращение для { return expr; }
int square(int x) => x * x;

String greeting(String name) => 'Привет, $name!';

bool isPositive(int n) => n > 0;

// void со стрелкой
void log(String msg) => print('[LOG] $msg');

// Многострочное выражение — НЕ поддерживается:
// int complex(int x) => {  // Ошибка!
//   var a = x * 2;
//   return a + 1;
// };

// Правильно для сложной логики:
int complex(int x) {
  var a = x * 2;
  return a + 1;
}
```

### Анонимные функции (лямбды)

```dart
void main() {
  // С телом
  var list = [1, 2, 3];
  list.forEach((item) {
    print('Элемент: $item');
  });

  // Стрелочная лямбда
  var doubled = list.map((n) => n * 2).toList();

  // Присвоение переменной
  var greet = (String name) => 'Привет, $name!';
  print(greet('мир')); // Привет, мир!

  // С явным типом переменной
  int Function(int, int) sum = (a, b) => a + b;
  print(sum(3, 4)); // 7

  // Как аргумент функции
  var sorted = [3, 1, 4, 1, 5];
  sorted.sort((a, b) => a.compareTo(b));
}
```

### Функции как объекты

```dart
void main() {
  // Ссылка на именованную функцию (tear-off)
  var numbers = [1, -2, 3, -4, 5];
  var positives = numbers.where(isPositive);
  print(positives.toList()); // [1, 3, 5]

  // Передача функции как аргумента
  execute(add, 3, 4);       // 7
  execute(multiply, 3, 4);  // 12

  // Хранение в коллекции
  var operations = <String, int Function(int, int)>{
    '+': (a, b) => a + b,
    '-': (a, b) => a - b,
    '*': (a, b) => a * b,
  };
  print(operations['*']!(5, 3)); // 15
}

bool isPositive(int n) => n > 0;
int add(int a, int b) => a + b;
int multiply(int a, int b) => a * b;

void execute(int Function(int, int) op, int a, int b) {
  print(op(a, b));
}
```

### Вложенные функции

```dart
void main() {
  // Локальные функции — видны только внутри
  String formatName(String first, String last) {
    String capitalize(String s) {
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1).toLowerCase();
    }

    return '${capitalize(first)} ${capitalize(last)}';
  }

  print(formatName('иван', 'ПЕТРОВ')); // Иван Петров
}
```

### Возвращаемые значения

```dart
// Каждая функция возвращает значение. Без return → null.
void doNothing() {
  // implicit return null
}

// Never — функция никогда не завершается нормально
Never throwError(String msg) {
  throw Exception(msg);
}

// Множественные return
String classify(int n) {
  if (n < 0) return 'отрицательное';
  if (n == 0) return 'ноль';
  return 'положительное';
}
```

## 4. Минимальный пример

```dart
// Именованная
int double_(int x) => x * 2;

// Анонимная
var triple = (int x) => x * 3;

void main() {
  print(double_(5));  // 10
  print(triple(5));   // 15

  // Inline лямбда
  var nums = [1, 2, 3];
  print(nums.map((n) => n * 10).toList()); // [10, 20, 30]
}
```

## 5. Практический пример

### Построитель pipeline обработки данных

```dart
typedef Transform<T> = T Function(T);

class Pipeline<T> {
  final List<Transform<T>> _steps = [];

  Pipeline<T> addStep(Transform<T> step) {
    _steps.add(step);
    return this; // Для chaining
  }

  T execute(T input) {
    var result = input;
    for (final step in _steps) {
      result = step(result);
    }
    return result;
  }
}

// Переиспользуемые функции-шаги
String trim(String s) => s.trim();
String toLowerCase(String s) => s.toLowerCase();
String removeExtraSpaces(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  var pipeline = Pipeline<String>()
      .addStep(trim)
      .addStep(toLowerCase)
      .addStep(removeExtraSpaces)
      .addStep((s) => s.replaceAll(RegExp(r'[^\w\s]'), '')); // inline шаг

  var raw = '  Hello,   WORLD!   How   ARE  you?  ';
  var clean = pipeline.execute(raw);
  print(clean); // 'hello world how are you'
}
```

## 6. Что происходит под капотом

### Функции — объекты класса Closure

```
int add(int a, int b) => a + b;

Dart VM:
  add → экземпляр _Closure
    - function: pointer to compiled code
    - context: null (top-level, нет захваченных переменных)

var fn = add;  // tear-off → новый _Closure object
               // (или тот же, если компилятор оптимизирует)
```

### Tear-off

```dart
// Tear-off — создание замыкания из метода
var list = [3, 1, 2];
list.sort(compareTo);  // Ошибка
list.sort(Comparable.compare); // Tear-off статического метода

// Instance tear-off
var s = 'hello';
var upper = s.toUpperCase; // Function, не вызов!
print(upper());            // HELLO
```

### Arrow vs block — одинаковый bytecode

```dart
int f1(int x) => x * 2;
int f2(int x) { return x * 2; }

// Компилируются в идентичный bytecode:
// LoadLocal x
// PushInt 2
// Multiply
// Return
```

## 7. Производительность и ресурсы

| Аспект                  | Стоимость                      |
| ----------------------- | ------------------------------ |
| Вызов top-level функции | Прямой call (быстро)           |
| Вызов через переменную  | Indirect call (чуть медленнее) |
| Tear-off                | Аллокация Closure (один раз)   |
| Inline лямбда           | Часто инлайнится компилятором  |
| Рекурсия                | Stack frame на каждый вызов    |

**Dart VM оптимизации:**

- **Inlining** — маленькие функции встраиваются в место вызова.
- **Devirtualization** — если тип известен, вызов становится прямым.
- **Escape analysis** — если Closure не покидает scope, может быть на стеке.

## 8. Частые ошибки и антипаттерны

### ❌ Пропуск типа возврата

```dart
// Плохо: возвращаемый тип — dynamic
add(a, b) => a + b;

// Хорошо: явные типы
int add(int a, int b) => a + b;
```

### ❌ Arrow для побочных эффектов с return

```dart
// Осторожно: arrow возвращает результат выражения
var list = [1, 2, 3];

// Это возвращает bool (результат list.add):
// bool Function(int) bad = (n) => list.add(n); // add возвращает void

// Правильно для побочных эффектов:
void Function(int) good = (n) { list.add(n); };
```

### ❌ Рекурсия без лимита

```dart
// Stack overflow при глубокой рекурсии
int factorial(int n) => n <= 1 ? 1 : n * factorial(n - 1);
// factorial(100000) → StackOverflowError

// Dart не гарантирует TCO (tail call optimization)
// Используйте итерацию для больших N:
int factorialIter(int n) {
  var result = 1;
  for (var i = 2; i <= n; i++) {
    result *= i;
  }
  return result;
}
```

### ❌ Создание лямбды в hot loop

```dart
// Плохо: аллокация замыкания на каждой итерации
for (var i = 0; i < 1000000; i++) {
  process((x) => x + i); // Новый Closure каждый раз
}

// Лучше: вынести, если возможно
var fn = (int x) => x + offset;
for (var i = 0; i < 1000000; i++) {
  process(fn);
}
```

## 9. Сравнение с альтернативами

| Аспект        | Dart      | Java                   | JavaScript   | Python         | Kotlin      |
| ------------- | --------- | ---------------------- | ------------ | -------------- | ----------- |
| First-class   | ✅        | ✅ (lambda)            | ✅           | ✅             | ✅          |
| Top-level     | ✅        | ❌ (всё в классах)     | ✅           | ✅             | ✅          |
| Arrow         | `=> expr` | `-> expr`              | `=> expr`    | `lambda: expr` | `= expr`    |
| Вложенные     | ✅        | ✅ (local)             | ✅           | ✅ (def)       | ✅          |
| Tear-off      | ✅        | `::method`             | `obj.method` | `obj.method`   | `::method`  |
| Named fn type | `typedef` | `@FunctionalInterface` | ❌           | `Callable`     | `typealias` |

Dart ближе всего к Kotlin: top-level функции, arrow-синтаксис, tear-off.

## 10. Когда НЕ стоит использовать

- **Стрелку для сложной логики** — если в теле > 1 выражения, используйте блочный синтаксис.
- **Анонимные функции для длинной логики** — если лямбда > 5 строк, вынесите в именованную функцию.
- **Глубокую рекурсию** — Dart не гарантирует TCO. Предпочитайте итерацию.
- **Top-level функции для всего** — если функция связана с данными, используйте метод класса.

## 11. Краткое резюме

1. **Три формы**: именованная, стрелочная (`=>`), анонимная (лямбда).
2. **First-class objects** — функции можно передавать, хранить, возвращать.
3. **Tear-off** — `obj.method` без `()` создаёт замыкание.
4. **Arrow** `=> expr` — сокращение для `{ return expr; }`. Только одно выражение.
5. **Top-level** — функции вне классов разрешены (в отличие от Java).
6. **Указывайте типы** — возвращаемый тип и типы параметров для safety и документации.
7. **Нет TCO** — избегайте глубокой рекурсии, предпочитайте итерацию.

---

> **Назад:** [Обзор раздела](06_00_overview.md) · **Далее:** [6.2 Параметры](06_02_parameters.md)
