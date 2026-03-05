# 3.1 Числа и операции

## 1. Формальное определение

В Dart числа представлены двумя типами, наследующими от абстрактного `num`:

- **`int`** — целые числа произвольной точности (на VM) или 64-bit (на web). Нет беззнаковых целых.
- **`double`** — 64-bit числа с плавающей точкой (IEEE 754).

```
     num
    /   \
  int   double
```

**Уровень:** встроенные типы / runtime.

## 2. Зачем это нужно

- **`int`** — счётчики, индексы, ID, битовые операции, криптография.
- **`double`** — координаты, финансовые расчёты (с оговорками), физика, UI-размеры.
- **`num`** — когда функция принимает и int, и double.

## 3. Как это работает

### Литералы

```dart
// int
var decimal = 42;
var hex = 0xFF;             // 255
var binary = 0b1010;        // 10 (Dart 3+)
var big = 1_000_000;        // Разделители разрядов (Dart 2.17+)

// double
var pi = 3.14159;
var exp = 1.2e10;           // 12000000000.0
var tiny = 5.0e-3;          // 0.005

// num
num flexible = 42;          // int
flexible = 3.14;            // теперь double — OK, num принимает оба
```

### Арифметические операции

```dart
int a = 10, b = 3;

print(a + b);    // 13    — сложение
print(a - b);    // 7     — вычитание
print(a * b);    // 30    — умножение
print(a / b);    // 3.333 — деление (всегда double!)
print(a ~/ b);   // 3     — целочисленное деление
print(a % b);    // 1     — остаток от деления
print(-a);       // -10   — унарный минус
```

**Важно:** оператор `/` в Dart **всегда возвращает `double`**, даже для `int / int`. Для целочисленного деления — `~/`.

### Преобразования

```dart
// int ↔ double
int i = 42;
double d = i.toDouble();     // 42.0
int back = d.toInt();         // 42 (отбрасывает дробную часть)
int rounded = d.round();      // 42 (округление)
int ceiled = 3.2.ceil();      // 4
int floored = 3.9.floor();    // 3

// String → num
int parsed = int.parse('42');
double parsed2 = double.parse('3.14');
int? safe = int.tryParse('abc');  // null (без исключения)

// num → String
String s = 42.toString();
String f = 3.14159.toStringAsFixed(2);   // '3.14'
String e = 12345.toStringAsExponential(); // '1.2345e+4'
```

### Методы и свойства

```dart
var n = -42;
print(n.abs());         // 42
print(n.sign);          // -1 (знак: -1, 0 или 1)
print(n.isNegative);    // true
print(n.isEven);        // true
print(n.isOdd);         // false
print(42.gcd(18));      // 6 (НОД)
print(42.toRadixString(16)); // '2a' (hex)

var d = 3.14;
print(d.isFinite);      // true
print(d.isNaN);         // false
print(d.isInfinite);    // false
print(double.infinity); // Infinity
print(double.nan);      // NaN
```

### Битовые операции (только int)

```dart
int a = 0xFF;   // 255 = 11111111
int b = 0x0F;   // 15  = 00001111

print(a & b);   // 15  — AND
print(a | b);   // 255 — OR
print(a ^ b);   // 240 — XOR
print(~a);      // -256 — NOT (two's complement)
print(b << 4);  // 240 — сдвиг влево
print(a >> 4);  // 15  — арифметический сдвиг вправо
print(a >>> 4); // 15  — логический сдвиг вправо (всегда unsigned)
```

## 4. Минимальный пример

```dart
void main() {
  // Целочисленная арифметика
  int total = 100;
  int discount = total ~/ 3;  // 33 (целочисленное деление)
  int remainder = total % 3;   // 1

  // Вещественная арифметика
  double price = 19.99;
  double tax = price * 0.2;
  double finalPrice = price + tax;

  print('Цена: ${finalPrice.toStringAsFixed(2)} руб.'); // 23.99 руб.

  // Безопасный парсинг
  int? count = int.tryParse('not_a_number');
  print(count ?? 0); // 0
}
```

## 5. Практический пример

### Калькулятор расстояний с валидацией

```dart
import 'dart:math';

class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint(this.latitude, this.longitude);

  /// Расстояние по формуле Haversine (в км)
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371.0; // км

    final dLat = _toRadians(other.latitude - latitude);
    final dLon = _toRadians(other.longitude - longitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(latitude)) *
            cos(_toRadians(other.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;
}

void main() {
  const moscow = GeoPoint(55.7558, 37.6173);
  const spb = GeoPoint(59.9343, 30.3351);

  final distance = moscow.distanceTo(spb);
  print('Москва → СПб: ${distance.toStringAsFixed(1)} км');
  // ~634.4 км
}
```

## 6. Что происходит под капотом

### int на разных платформах

```
Dart VM (native):
  int → произвольная точность (как BigInteger в Java)
  Малые числа → SMI (Small Integer, tagged pointer, 63 бита)
  Большие числа → Mint/Bigint (аллоцируются в heap)

Dart Web (dart2js / dart2wasm):
  int → JavaScript Number (53-bit integer precision)
  Операции > 2^53 могут терять точность!
```

### SMI (Small Integer) оптимизация

```
64-bit pointer: [63-bit integer value][1-bit tag]
                                            │
                                            └─ 1 = SMI (not a heap pointer)

Если tag == 1: значение — число, хранится прямо в указателе.
Никакой аллокации в heap. Никакого GC.
```

Для чисел в диапазоне `-2^62 .. 2^62 - 1` (на 64-bit) Dart VM не аллоцирует объект в heap. Операции с SMI — такие же быстрые, как с native `int64_t` в C.

### double — IEEE 754

Dart `double` — стандартный IEEE 754 binary64:

- 1 бит — знак
- 11 бит — экспонента
- 52 бита — мантисса

**Следствия:**

- `0.1 + 0.2 != 0.3` (как в любом языке с IEEE 754)
- Специальные значения: `double.nan`, `double.infinity`, `-double.infinity`
- `NaN != NaN` (по стандарту)

## 7. Производительность и ресурсы

| Операция                    | Стоимость              |
| --------------------------- | ---------------------- |
| int + int (SMI)             | 1 инструкция CPU       |
| int + int (overflow → Mint) | Аллокация + арифметика |
| double + double             | 1 FP-инструкция CPU    |
| int.parse()                 | O(n) по длине строки   |
| pow(x, y)                   | O(log y)               |

**Рекомендации:**

- Для финансовых расчётов **не используйте `double`** — используйте `int` в минимальных единицах (копейки, центы) или пакет `decimal`.
- `~/` быстрее, чем `(a / b).toInt()` — одна операция вместо двух.
- Для побитовых операций на web помните: числа ограничены 53-bit precision.

## 8. Частые ошибки и антипаттерны

### ❌ double для денег

```dart
// Плохо: потеря точности
double price = 0.1 + 0.2;
print(price);        // 0.30000000000000004
print(price == 0.3); // false!

// Хорошо: int в копейках
int priceInCents = 10 + 20;  // 30 центов
print(priceInCents / 100);    // 0.3 (для отображения)
```

### ❌ Деление int / int → ожидание int

```dart
int a = 10, b = 3;
// var result = a / b;  // Тип: double! Не int!
int result = a ~/ b;    // 3 (целочисленное деление)
```

### ❌ NaN-ловушки

```dart
double value = 0.0 / 0.0;  // NaN
print(value == double.nan); // false! NaN != NaN

// Правильно:
print(value.isNaN);         // true
```

### ❌ int overflow на web

```dart
// На VM (native): OK — произвольная точность
int big = 9007199254740993;  // 2^53 + 1
print(big);  // 9007199254740993 ✓

// На web (dart2js): НЕПРАВИЛЬНО
// big == 9007199254740992  (потеря точности!)
```

## 9. Сравнение с альтернативами

| Аспект       | Dart               | Java                        | Kotlin                       | JavaScript        |
| ------------ | ------------------ | --------------------------- | ---------------------------- | ----------------- |
| Целые        | `int` (arbitrary)  | `int` (32), `long` (64)     | `Int` (32), `Long` (64)      | `Number` (53-bit) |
| Вещественные | `double` (64-bit)  | `float` (32), `double` (64) | `Float`, `Double`            | `Number` (64-bit) |
| / для int    | → double           | → int                       | → Int (Kotlin), → Double (/) | → Number          |
| BigInteger   | Встроен (VM)       | `BigInteger`                | `BigInteger`                 | `BigInt`          |
| Примитивы    | Нет (всё — объект) | Да (`int`, `float`)         | Нет                          | Нет               |

**Преимущество Dart**: `int` на VM — автоматический BigInt без явного преобразования. `42.isEven` — можно вызывать методы на числах.

## 10. Когда НЕ стоит использовать

- **`double` для точных финансовых расчётов** — IEEE 754 не гарантирует точность. Используйте `int` в минимальных единицах.
- **`num` как тип параметра** — теряется информация. Если функция работает только с `int`, указывайте `int`.
- **Побитовые операции на web** — ограничение 32-bit signed integer для `<<`, `>>`, `&`, `|` в dart2js.

## 11. Краткое резюме

1. **`int`** и **`double`** — два числовых типа, оба наследуют от `num`. Оба — объекты с методами.
2. **`/` всегда возвращает `double`**. Для целочисленного деления — `~/`.
3. **SMI-оптимизация** — малые int (до 62 бит) хранятся прямо в указателе, без аллокации в heap.
4. **`double` ≠ точный** — `0.1 + 0.2 != 0.3`. Для денег используйте `int` в минимальных единицах.
5. **`int.tryParse()`** — безопасный парсинг без исключений. Возвращает `null` при ошибке.
6. **int на VM** — произвольная точность. **int на web** — 53-bit precision (ограничение JS).
7. **`toStringAsFixed(n)`** — контроль количества десятичных знаков при форматировании.

---

> **Следующий:** [3.2 Строки и интерполяция](03_02_strings.md)
