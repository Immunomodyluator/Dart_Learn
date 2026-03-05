# 3.3 Булевы значения

## 1. Формальное определение

**`bool`** — тип с двумя значениями: `true` и `false`. В Dart `bool` — полноценный класс, наследующий от `Object`. В отличие от JavaScript, **только `true` является истинным**, а **только `false` — ложным**. Нет truthy/falsy-значений: `0`, `''`, `null`, `[]` **не являются false**.

**Уровень:** встроенные типы / синтаксис.

## 2. Зачем это нужно

- **Строгая типизация условий** — `if (value)` работает только если `value` — `bool`. Нет неявных преобразований → нет багов с truthy/falsy.
- **Предсказуемость** — в JS `if (0)` — false, `if ([])` — true. В Dart такого нет: только `bool` в условиях.

## 3. Как это работает

### Литералы и объявление

```dart
bool isActive = true;
bool isDeleted = false;
var isVisible = true;          // Тип: bool (inferred)
```

### Логические операторы

```dart
bool a = true, b = false;

print(a && b);    // false — логическое И (short-circuit)
print(a || b);    // true  — логическое ИЛИ (short-circuit)
print(!a);        // false — логическое НЕ

// Short-circuit evaluation:
// a || expensiveCheck() — если a == true, expensiveCheck() НЕ вызывается
// a && expensiveCheck() — если a == false, expensiveCheck() НЕ вызывается
```

### Сравнения → bool

```dart
print(42 > 0);       // true
print(42 == 42);     // true
print(42 != 0);      // true
print('abc' == 'abc'); // true (сравнение значений)

// Identical (ссылочное сравнение)
print(identical(const [1], const [1])); // true (каноникализация)
```

### bool в условиях — только bool!

```dart
// ✅ Dart: только bool
if (list.isNotEmpty) { ... }
if (value != null) { ... }
if (count > 0) { ... }

// ❌ В JavaScript работает, в Dart — ОШИБКА компиляции:
// if (list) { ... }      // List — не bool
// if (value) { ... }     // Object? — не bool
// if (count) { ... }     // int — не bool
```

### Методы

```dart
bool value = true;

print(value.toString());   // 'true'
print(bool.parse('true')); // true (Dart 3.x)
print(bool.tryParse('yes')); // null

// Побитовые логические операции (НЕ short-circuit!)
print(true & false);        // false — оба операнда evaluateятся
print(true | false);        // true — оба операнда evaluateятся
print(true ^ false);        // true — XOR
```

## 4. Минимальный пример

```dart
void main() {
  var temperature = 36.6;
  var hasFever = temperature > 37.0;       // bool
  var isNormal = temperature >= 36.0 && temperature <= 37.0;

  print('Температура: $temperature');
  print('Лихорадка: $hasFever');    // false
  print('Норма: $isNormal');         // true

  // Тернарный оператор
  var status = hasFever ? 'Болен' : 'Здоров';
  print(status);  // Здоров
}
```

## 5. Практический пример

### Валидация формы с булевой логикой

```dart
class FormValidator {
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$').hasMatch(email);
  }

  static bool isValidPassword(String password) {
    final hasMinLength = password.length >= 8;
    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'\d'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*]'));

    return hasMinLength && hasUpperCase && hasDigit && hasSpecial;
  }

  static List<String> validateRegistration({
    required String email,
    required String password,
    required String confirmPassword,
    required bool acceptedTerms,
  }) {
    final errors = <String>[];

    if (!isValidEmail(email)) {
      errors.add('Некорректный email');
    }
    if (!isValidPassword(password)) {
      errors.add('Пароль: мин. 8 символов, заглавная, цифра, спецсимвол');
    }
    if (password != confirmPassword) {
      errors.add('Пароли не совпадают');
    }
    if (!acceptedTerms) {
      errors.add('Необходимо принять условия');
    }

    return errors;
  }
}

void main() {
  final errors = FormValidator.validateRegistration(
    email: 'user@example.com',
    password: 'Str0ng!Pass',
    confirmPassword: 'Str0ng!Pass',
    acceptedTerms: true,
  );

  if (errors.isEmpty) {
    print('Регистрация успешна');
  } else {
    print('Ошибки: ${errors.join(", ")}');
  }
}
```

## 6. Что происходит под капотом

### bool в Dart VM

```
bool → два предопределённых singleton-объекта в VM:

true  → объект по фиксированному адресу (canonical)
false → объект по фиксированному адресу (canonical)

Проверка: if (x) → простое сравнение указателя с адресом true
```

`bool` не аллоцируется в heap динамически. `true` и `false` — compile-time constants, занимающие фиксированные адреса в памяти VM.

### Short-circuit evaluation

```dart
bool result = a() || b();

// Генерируемый код:
// temp = a();
// if (temp == true) goto done;
// temp = b();
// done:
// result = temp;
```

При `||` — если `a()` вернула `true`, `b()` не вызывается. При `&&` — если `a()` вернула `false`, `b()` не вызывается. Это **гарантия языка**, а не оптимизация компилятора.

### Отсутствие truthy/falsy

В Dart VM нет таблицы «truthiness». Условия принимают **только** `bool`. Компилятор проверяет тип на этапе анализа:

```dart
if (0) { }       // Static error: type 'int' can't be used as bool
if (null) { }    // Static error: type 'Null' can't be used as bool
if ('') { }      // Static error: type 'String' can't be used as bool
```

## 7. Производительность и ресурсы

| Операция       | Стоимость            |
| -------------- | -------------------- | --- | ---------------------------- |
| `if (boolVar)` | 1 compare + branch   |
| `&&` / `       |                      | `   | 1–2 compares (short-circuit) |
| `!`            | 1 XOR instruction    |
| `bool.parse()` | O(n) по длине строки |

`bool` — наиболее «лёгкий» тип. Нет аллокаций, нет GC-давления. Все операции — единичные инструкции CPU.

## 8. Частые ошибки и антипаттерны

### ❌ Сравнение с true/false

```dart
// Плохо: избыточно
if (isActive == true) { ... }
if (isDeleted == false) { ... }

// Хорошо:
if (isActive) { ... }
if (!isDeleted) { ... }

// Исключение: nullable bool
bool? isReady;
if (isReady == true) { ... }  // OK — isReady может быть null
```

### ❌ JavaScript-привычки

```dart
// Не работает в Dart:
// if (list.length) { ... }    // int — не bool
// if (name) { ... }           // String? — не bool

// Правильно:
if (list.isNotEmpty) { ... }
if (name != null && name.isNotEmpty) { ... }
```

### ❌ & вместо && (без short-circuit)

```dart
// Опасно: оба операнда evaluateятся всегда!
if (user != null & user.isActive) { ... }  // NPE если user == null!

// Безопасно: short-circuit
if (user != null && user.isActive) { ... }
```

## 9. Сравнение с альтернативами

| Аспект          | Dart                 | Java                     | JavaScript               | Python                    |
| --------------- | -------------------- | ------------------------ | ------------------------ | ------------------------- | --- |
| Truthy/falsy    | ❌ (только bool)     | ❌ (только boolean)      | ✅ (0, '', null = falsy) | ✅ (0, '', [] = falsy)    |
| Bool в условиях | Строго bool          | Строго boolean           | Любое значение           | Любое значение            |
| `&` / `         | ` (не-short-circuit) | ✅                       | ✅                       | ❌ (всегда short-circuit) | ❌  |
| `bool.parse()`  | ✅                   | `Boolean.parseBoolean()` | ❌                       | ❌                        |

**Преимущество Dart/Java**: отсутствие truthy/falsy исключает целый класс багов (`if (0)`, `if ('')`, `if ([])`).

## 10. Когда НЕ стоит использовать

- **bool для состояний с 3+ вариантами** — если нужно `loading`, `success`, `error`, используйте `enum`, а не `bool isLoading` + `bool hasError`.
- **Флаги-параметры** — `doSomething(true, false, true)` нечитабельно. Используйте именованные параметры или enum.

```dart
// Плохо:
void configure(bool debug, bool verbose, bool strictMode) {}
configure(true, false, true);  // Что есть что?

// Хорошо:
void configure({bool debug = false, bool verbose = false, bool strictMode = false}) {}
configure(debug: true, strictMode: true);
```

## 11. Краткое резюме

1. **`bool`** — только `true` и `false`. Нет truthy/falsy (в отличие от JS/Python).
2. **В условиях** (`if`, `while`, `?:`) допускается **только `bool`**. `if (0)` — ошибка компиляции.
3. **`&&` и `||`** — short-circuit: правый операнд не вычисляется, если результат известен по левому.
4. **`&` и `|`** — **без** short-circuit. Оба операнда вычисляются всегда. Используйте редко и осознанно.
5. **Не сравнивайте с `true`/`false`**: `if (isActive)`, не `if (isActive == true)`. Исключение — `bool?`.
6. **Для множественных состояний** используйте `enum`, а не набор `bool`-флагов.
7. **`true` и `false` — canonical singletons** в VM. Zero-allocation, zero-GC.

---

> **Следующий:** [3.4 Runes и Symbols](03_04_runes_symbols.md)
