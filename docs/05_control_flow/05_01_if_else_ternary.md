# 5.1 if / else и тернарный оператор

## 1. Формальное определение

**`if / else`** — оператор ветвления, выполняющий блок кода при истинности условия типа `bool`. Поддерживает цепочку `else if` и необязательный `else`.

**Тернарный оператор** (`condition ? expr1 : expr2`) — **выражение** (expression), возвращающее значение одной из двух ветвей. В отличие от `if` — это не оператор (statement), а выражение, которое можно использовать внутри присваиваний, аргументов, интерполяции.

Dart 3 добавил **if-case** (`if (value case pattern)`) — комбинацию `if` с pattern matching.

## 2. Зачем это нужно

- **Ветвление логики** — основа любой программы: «если X — делай A, иначе B».
- **Type promotion** — `if (x is String)` автоматически продвигает тип внутри блока.
- **Null check** — `if (x != null)` продвигает `String?` → `String`.
- **Тернарник** — компактная запись для выбора значения.
- **if-case** (Dart 3) — деструктуризация + проверка в одном выражении.

## 3. Как это работает

### Базовый if / else

```dart
void main() {
  var temperature = 25;

  if (temperature > 30) {
    print('Жарко');
  } else if (temperature > 20) {
    print('Тепло');
  } else if (temperature > 10) {
    print('Прохладно');
  } else {
    print('Холодно');
  }
  // Тепло
}
```

### Type promotion

```dart
void greet(Object value) {
  if (value is String) {
    // Компилятор знает: value — String
    print(value.toUpperCase()); // Без каста!
  } else if (value is int) {
    print('Число: ${value.abs()}'); // int API доступен
  }
}

void process(String? name) {
  if (name != null) {
    // name продвинут до String (non-nullable)
    print(name.length);
  }
}
```

### Тернарный оператор

```dart
void main() {
  var age = 20;

  // Выражение — возвращает значение
  var status = age >= 18 ? 'совершеннолетний' : 'несовершеннолетний';

  // Внутри интерполяции
  print('Статус: ${age >= 18 ? "взрослый" : "ребёнок"}');

  // Вложенные (не рекомендуется!)
  var category = age < 13 ? 'ребёнок' : age < 18 ? 'подросток' : 'взрослый';

  // В аргументах
  var list = [1, 2, 3];
  print(list.isEmpty ? 'Пусто' : 'Элементов: ${list.length}');
}
```

### if-case (Dart 3)

```dart
void main() {
  // Деструктуризация + проверка
  var json = {'name': 'Алиса', 'age': 30};

  if (json case {'name': String name, 'age': int age}) {
    print('$name, $age лет'); // Алиса, 30 лет
  }

  // С when guard
  if (json case {'age': int age} when age >= 18) {
    print('Совершеннолетний');
  }

  // Проверка типа с деструктуризацией
  Object value = [1, 2, 3];
  if (value case [int first, _, int last]) {
    print('Первый: $first, последний: $last');
  }
}
```

### Каскадные проверки с логическими операторами

```dart
void main() {
  var x = 15;

  // && — логическое И (short-circuit)
  if (x > 10 && x < 20) {
    print('В диапазоне');
  }

  // || — логическое ИЛИ (short-circuit)
  if (x < 5 || x > 10) {
    print('Вне [5, 10]');
  }

  // Комбинация с null-check
  String? name;
  if (name != null && name.isNotEmpty) {
    // name продвинут до String — безопасно
    print(name);
  }
}
```

## 4. Минимальный пример

```dart
void main() {
  var score = 85;

  if (score >= 90) {
    print('Отлично');
  } else if (score >= 70) {
    print('Хорошо');
  } else {
    print('Нужно подтянуть');
  }

  var grade = score >= 90 ? 'A' : score >= 70 ? 'B' : 'C';
  print('Оценка: $grade');
}
```

## 5. Практический пример

### Валидатор формы

```dart
class ValidationResult {
  final bool isValid;
  final String? error;

  ValidationResult.ok() : isValid = true, error = null;
  ValidationResult.fail(this.error) : isValid = false;
}

class FormValidator {
  static ValidationResult validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return ValidationResult.fail('Email обязателен');
    }

    if (!email.contains('@')) {
      return ValidationResult.fail('Email должен содержать @');
    }

    if (email.length < 5) {
      return ValidationResult.fail('Email слишком короткий');
    }

    return ValidationResult.ok();
  }

  static ValidationResult validateAge(String? input) {
    if (input == null || input.isEmpty) {
      return ValidationResult.fail('Возраст обязателен');
    }

    var age = int.tryParse(input);
    if (age == null) {
      return ValidationResult.fail('Введите число');
    }

    if (age < 0 || age > 150) {
      return ValidationResult.fail('Некорректный возраст');
    }

    return ValidationResult.ok();
  }
}

void main() {
  var emailResult = FormValidator.validateEmail('test@mail.ru');
  print(emailResult.isValid ? 'Email OK' : 'Ошибка: ${emailResult.error}');

  var ageResult = FormValidator.validateAge('25');
  print(ageResult.isValid ? 'Возраст OK' : 'Ошибка: ${ageResult.error}');
}
```

## 6. Что происходит под капотом

### Компиляция if/else

```
if (a > b) {
  doA();
} else {
  doB();
}

Компилируется (Dart VM) в:
  1. Вычислить a > b → bool
  2. JumpIfFalse → label_else
  3. Call doA
  4. Jump → label_end
  label_else:
  5. Call doB
  label_end:
```

### Type promotion — flow analysis

```dart
Object x = 'hello';
if (x is String) {
  x.toUpperCase(); // Flow analysis продвигает тип
}

Компилятор (CFE — Common Front End) отслеживает:
  - Переменная x
  - В ветви true: тип x = String (promoted)
  - В ветви false: тип x = Object (unchanged)

Promotion работает ТОЛЬКО для:
  - Локальных переменных (не полей!)
  - is-проверок и != null
  - Без присваиваний между проверкой и использованием
```

### Тернарный vs if

```
// Тернарный — одно выражение, один результат
var x = cond ? a : b;

// Компилятор может оптимизировать как:
// x = cond ? a : b → CMOV (conditional move) на некоторых платформах
// Без branch prediction penalty
```

## 7. Производительность и ресурсы

| Аспект                | Стоимость                                  |
| --------------------- | ------------------------------------------ |
| `if (bool)`           | 1 сравнение + branch                       |
| `if (x is Type)`      | 1 type check + branch                      |
| Тернарный             | Аналогично if, но может быть CMOV          |
| `if-case`             | Pattern matching O(1) для простых patterns |
| Цепочка `else if` (N) | O(N) worst case                            |

**Рекомендации:**

- Для 3+ ветвей рассмотрите `switch` — компилятор может оптимизировать в jump table.
- `if (x is T)` — такая же скорость, как `dynamic` dispatch, но с type safety.

## 8. Частые ошибки и антипаттерны

### ❌ Не-bool в условии

```dart
var name = 'Dart';
// if (name) { ... } // Ошибка компиляции! String ≠ bool

// Правильно:
if (name.isNotEmpty) { ... }
```

### ❌ Присваивание вместо сравнения

```dart
// В Dart это ошибка компиляции (не bool):
// if (x = 5) { }  // Ошибка!
// Правильно:
if (x == 5) { }
```

### ❌ Promotion не работает для полей

```dart
class MyClass {
  String? name;

  void greet() {
    if (name != null) {
      // print(name.length); // Ошибка! name может измениться
      // Поле может быть переприсвоено другим потоком/setter'ом
    }

    // Правильно:
    final localName = name;
    if (localName != null) {
      print(localName.length); // OK — локальная переменная
    }
  }
}
```

### ❌ Вложенные тернарники

```dart
// Плохо: нечитаемо
var x = a > b ? a > c ? a : c : b > c ? b : c;

// Хорошо: if-else или функция
int maxOfThree(int a, int b, int c) {
  if (a >= b && a >= c) return a;
  if (b >= c) return b;
  return c;
}
```

## 9. Сравнение с альтернативами

| Аспект         | Dart                   | Java             | JavaScript   | Python          |
| -------------- | ---------------------- | ---------------- | ------------ | --------------- |
| Условие        | Только `bool`          | Только `boolean` | Truthy/falsy | Truthy/falsy    |
| Type promotion | ✅ автоматически       | ❌ (нужен каст)  | ❌           | ❌              |
| if-case        | ✅ (Dart 3)            | ❌               | ❌           | `match` (3.10)  |
| Тернарный      | `? :`                  | `? :`            | `? :`        | `x if c else y` |
| Null promotion | `if (x != null)` → `T` | ❌               | ❌           | ❌              |

Dart уникален автоматическим type promotion — не нужен явный каст после `is`-проверки.

## 10. Когда НЕ стоит использовать

- **Много ветвей по одному значению** — используйте `switch` вместо цепочки `else if`.
- **Pattern matching** — `if-case` подходит для одного шаблона, для множественных — `switch expression`.
- **Тернарник для побочных эффектов** — `cond ? doA() : doB()` — антипаттерн; используйте `if/else`.
- **Глубокая вложенность** — более 3 уровней `if` — refactor в отдельные функции или early return.

## 11. Краткое резюме

1. **`if`** принимает только `bool` — нет truthy/falsy.
2. **Type promotion** — `if (x is T)` и `if (x != null)` продвигают тип в ветви. Работает только для локальных переменных.
3. **Тернарный** `? :` — выражение, не оператор. Используйте для простых выборов значения.
4. **`if-case`** (Dart 3) — `if (value case Pattern)` для деструктуризации с проверкой.
5. **Short-circuit** — `&&` и `||` не вычисляют правую часть, если результат уже определён.
6. **Поля не продвигаются** — копируйте в локальную переменную перед null-check.
7. **Early return** — предпочитайте `if (!cond) return;` вместо глубокой вложенности.

---

> **Назад:** [Обзор раздела](05_00_overview.md) · **Далее:** [5.2 switch и сопоставление с образцом](05_02_switch_patterns.md)
