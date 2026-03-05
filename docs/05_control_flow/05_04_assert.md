# 5.4 assert и отладочные проверки

## 1. Формальное определение

**`assert`** — оператор отладочной проверки, который прерывает выполнение программы, если условие ложно. Assert активен **только в debug-режиме** (JIT, `dart run`, Flutter debug) и полностью **удаляется** при release-сборке (AOT, `dart compile`, Flutter release).

**Синтаксис:**

```dart
assert(condition);                    // Без сообщения
assert(condition, 'Сообщение');       // С пояснением
```

Если `condition == false` → бросается `AssertionError`. В release — assert не существует, нет runtime-cost.

## 2. Зачем это нужно

- **Контракты** — проверить предусловия/постусловия функции на этапе разработки.
- **Документация через код** — assert описывает ожидания: «этот параметр не может быть отрицательным».
- **Раннее обнаружение багов** — ошибка обнаруживается в момент нарушения, а не позже в неочевидном месте.
- **Нулевая стоимость в production** — полностью удаляется при компиляции.
- **Flutter** — `assert` повсеместно: проверка виджетов, constraints, инварианты.

## 3. Как это работает

### Базовое использование

```dart
void main() {
  var age = 25;

  assert(age >= 0);                          // OK
  assert(age >= 0, 'Возраст не может быть отрицательным');

  // С вычисляемым условием
  var list = [1, 2, 3];
  assert(list.isNotEmpty, 'Список не должен быть пустым');

  // Сложное условие
  assert(age >= 0 && age <= 150, 'Возраст вне допустимого диапазона: $age');
}
```

### Предусловия (preconditions)

```dart
double divide(double a, double b) {
  assert(b != 0, 'Делитель не может быть нулём');
  return a / b;
}

void setPercentage(int value) {
  assert(value >= 0 && value <= 100,
      'Процент должен быть 0-100, получено: $value');
  // ...
}
```

### Инварианты класса

```dart
class BankAccount {
  final String owner;
  double _balance;

  BankAccount(this.owner, this._balance) {
    assert(_balance >= 0, 'Начальный баланс не может быть отрицательным');
    assert(owner.isNotEmpty, 'Владелец обязателен');
  }

  void withdraw(double amount) {
    assert(amount > 0, 'Сумма снятия должна быть положительной');
    assert(amount <= _balance, 'Недостаточно средств');
    _balance -= amount;
    assert(_balance >= 0); // Постусловие
  }

  void deposit(double amount) {
    assert(amount > 0, 'Сумма пополнения должна быть положительной');
    _balance += amount;
  }

  double get balance => _balance;
}
```

### Assert в конструкторах (Flutter-стиль)

```dart
class Padding {
  final double left, top, right, bottom;

  Padding({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  })  : assert(left >= 0, 'left must be non-negative'),
        assert(top >= 0, 'top must be non-negative'),
        assert(right >= 0, 'right must be non-negative'),
        assert(bottom >= 0, 'bottom must be non-negative');

  // assert в initializer list — выполняется до тела конструктора!
}
```

### Assert vs throw

```dart
class Temperature {
  final double celsius;

  // assert — только в debug (контракт для РАЗРАБОТЧИКА)
  Temperature(this.celsius)
      : assert(celsius >= -273.15, 'Ниже абсолютного нуля невозможно');

  // throw — в production (защита от ВНЕШНИХ данных)
  factory Temperature.fromInput(String input) {
    var value = double.tryParse(input);
    if (value == null) {
      throw FormatException('Некорректное число: $input');
    }
    if (value < -273.15) {
      throw ArgumentError.value(value, 'celsius', 'Ниже абсолютного нуля');
    }
    return Temperature(value);
  }
}
```

## 4. Минимальный пример

```dart
void main() {
  var items = ['a', 'b', 'c'];

  assert(items.isNotEmpty);
  assert(items.length <= 10, 'Слишком много элементов: ${items.length}');

  var index = 1;
  assert(index >= 0 && index < items.length);

  print(items[index]); // b
}
```

## 5. Практический пример

### Матричная библиотека с assert-контрактами

```dart
class Matrix {
  final List<List<double>> _data;
  final int rows;
  final int cols;

  Matrix(this._data)
      : rows = _data.length,
        cols = _data.isEmpty ? 0 : _data.first.length {
    assert(_data.isNotEmpty, 'Матрица не может быть пустой');
    assert(
      _data.every((row) => row.length == cols),
      'Все строки должны иметь одинаковую длину',
    );
  }

  factory Matrix.zero(int rows, int cols) {
    assert(rows > 0 && cols > 0, 'Размеры должны быть положительными');
    return Matrix(
      List.generate(rows, (_) => List.filled(cols, 0.0)),
    );
  }

  factory Matrix.identity(int size) {
    assert(size > 0, 'Размер должен быть положительным');
    return Matrix(
      List.generate(size, (i) =>
          List.generate(size, (j) => i == j ? 1.0 : 0.0)),
    );
  }

  double operator [](({int row, int col}) pos) {
    assert(pos.row >= 0 && pos.row < rows,
        'Строка ${pos.row} вне диапазона [0, $rows)');
    assert(pos.col >= 0 && pos.col < cols,
        'Столбец ${pos.col} вне диапазона [0, $cols)');
    return _data[pos.row][pos.col];
  }

  Matrix operator +(Matrix other) {
    assert(rows == other.rows && cols == other.cols,
        'Размеры матриц не совпадают: ($rows×$cols) vs (${other.rows}×${other.cols})');

    return Matrix(
      List.generate(rows, (i) =>
          List.generate(cols, (j) => _data[i][j] + other._data[i][j])),
    );
  }

  Matrix operator *(Matrix other) {
    assert(cols == other.rows,
        'Невозможно умножить ($rows×$cols) на (${other.rows}×${other.cols})');

    return Matrix(
      List.generate(rows, (i) =>
          List.generate(other.cols, (j) {
            var sum = 0.0;
            for (var k = 0; k < cols; k++) {
              sum += _data[i][k] * other._data[k][j];
            }
            return sum;
          })),
    );
  }

  @override
  String toString() =>
      _data.map((row) => row.map((v) => v.toStringAsFixed(1)).join('\t')).join('\n');
}

void main() {
  var a = Matrix.identity(3);
  var b = Matrix.zero(3, 3);
  var c = a + b;
  print(c);
}
```

## 6. Что происходит под капотом

### Компиляция

```
// Debug (JIT, dart run):
assert(x > 0, 'x must be positive');

→ if (!(x > 0)) throw AssertionError('x must be positive');

// Release (AOT, dart compile exe):
assert(x > 0, 'x must be positive');

→ (полностью удалено — нет инструкций вообще)
```

### Ленивое вычисление сообщения

```dart
// Сообщение вычисляется ТОЛЬКО если assert фейлится:
assert(list.isNotEmpty, 'Список пуст: ${expensiveDebugInfo()}');

// Если list.isNotEmpty == true → expensiveDebugInfo() НЕ вызывается
// Если list.isNotEmpty == false → вызывается, формирует сообщение
```

### Assert в initializer list

```dart
class Foo {
  final int x;
  Foo(this.x)
      : assert(x > 0)  // Выполняется ДО тела конструктора
  {
    print('Body');       // Выполняется ПОСЛЕ
  }
}

// Порядок:
// 1. Field initializers (this.x)
// 2. Initializer list (assert, super, redirecting)
// 3. Constructor body
```

## 7. Производительность и ресурсы

| Режим                | Стоимость assert               |
| -------------------- | ------------------------------ |
| Debug (JIT)          | O(condition) — вычисляется     |
| Release (AOT)        | **0** — полностью удалён       |
| dart2js (production) | **0** — удалён tree-shaking'ом |
| Flutter debug        | O(condition)                   |
| Flutter release      | **0**                          |

**Можно использовать дорогие проверки:**

```dart
// В release — нулевая стоимость:
assert(() {
  // Сложная проверка — выполняется только в debug
  for (var i = 0; i < list.length - 1; i++) {
    if (list[i] > list[i + 1]) return false; // Не отсортирован!
  }
  return true;
}(), 'Список должен быть отсортирован');
```

Замыкание `() { ... }()` позволяет выполнить произвольный код внутри assert.

## 8. Частые ошибки и антипаттерны

### ❌ Assert для валидации пользовательского ввода

```dart
// ПЛОХО: в release assert удалён — невалидные данные пройдут!
void processUserInput(String email) {
  assert(email.contains('@')); // Удалён в production!
  saveToDb(email); // Невалидный email попадёт в БД
}

// ПРАВИЛЬНО: throw для внешних данных
void processUserInput(String email) {
  if (!email.contains('@')) {
    throw ArgumentError('Невалидный email: $email');
  }
  saveToDb(email);
}
```

### ❌ Побочные эффекты в assert

```dart
// ПЛОХО: побочный эффект выполняется только в debug!
assert(list.remove(item)); // В release — remove не вызовется!

// ПРАВИЛЬНО:
var removed = list.remove(item);
assert(removed, 'Элемент не был в списке');
```

### ❌ Assert вместо null-check

```dart
// ПЛОХО: в release crashнет на null
void process(String? name) {
  assert(name != null);
  print(name!.length); // В release name может быть null!
}

// ПРАВИЛЬНО: реальная проверка
void process(String? name) {
  if (name == null) throw ArgumentError.notNull('name');
  print(name.length); // Type promotion
}
```

## 9. Сравнение с альтернативами

| Аспект             | Dart `assert`    | Java `assert`    | C/C++ `assert` | Python `assert`  |
| ------------------ | ---------------- | ---------------- | -------------- | ---------------- |
| Удалён в release   | ✅               | ✅ (`-ea` флаг)  | ✅ (`NDEBUG`)  | ✅ (`-O` флаг)   |
| Сообщение          | ✅               | ✅               | ❌ (макрос)    | ✅               |
| В initializer list | ✅               | ❌               | ❌             | ❌               |
| Ленивое сообщение  | ✅               | ❌               | ❌             | ❌               |
| Тип ошибки         | `AssertionError` | `AssertionError` | `abort()`      | `AssertionError` |

Dart `assert` — один из самых удобных: работает в initializer list, ленивые сообщения, интеграция с Flutter.

## 10. Когда НЕ стоит использовать

| Сценарий                             | Вместо assert используйте                                   |
| ------------------------------------ | ----------------------------------------------------------- |
| Валидация ввода пользователя         | `throw ArgumentError` / `FormatException`                   |
| Проверка внешних данных (API, файлы) | `throw` / `try-catch`                                       |
| Критичный инвариант в production     | `if (!cond) throw StateError(...)`                          |
| Побочные эффекты                     | Обычный код + отдельный assert                              |
| Null-safety на границе API           | `required`, non-nullable типы, `ArgumentError.checkNotNull` |

**Правило:** assert — для **разработчика** (проверка контрактов). throw — для **пользователя** (защита от невалидных данных).

## 11. Краткое резюме

1. **`assert(condition)`** — отладочная проверка. Удаляется в release → 0 cost.
2. **`assert(cond, 'message')`** — сообщение вычисляется лениво, только при fail.
3. **Initializer list** — `Class(this.x) : assert(x > 0)` — проверка до тела конструктора.
4. **Не для валидации ввода!** — в release assert нет. Используйте `throw`.
5. **Нет побочных эффектов** — внутри assert только чистые проверки.
6. **Замыкание для сложных проверок** — `assert(() { ... }(), 'msg')`.
7. **Flutter** — широко использует assert в конструкторах виджетов для контрактов.

---

> **Назад:** [5.3 Циклы](05_03_loops.md) · **Далее:** [6. Функции и замыкания](../06_functions/06_00_overview.md)
