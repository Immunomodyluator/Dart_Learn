# Урок 4. Встроенные типы и литералы

> Охватывает подтемы: 4.1 Числа, 4.2 Строки, 4.3 bool, 4.4 Runes и Symbols, 4.5 Records (Dart 3)

---

## 1. Формальное определение

Dart имеет богатую систему встроенных типов:

| Тип | Описание |
|---|---|
| `int` | 64-bit целое (Smi/Mint на VM, i32/i64 в Web) |
| `double` | 64-bit IEEE 754 floating point |
| `num` | Общий супертип для int и double |
| `String` | Иммутабельная последовательность UTF-16 кодовых единиц |
| `bool` | `true` / `false` |
| `Runes` | Итерируемая последовательность Unicode code points |
| `Symbol` | Идентификатор (используется в рефлексии и mirrors) |
| Record `(T1, T2, ...)` | Анонимный иммутабельный кортеж (Dart 3+) |

Уровень: **система типов, синтаксис, runtime**.

---

## 2. Зачем это нужно

- **Числа**: два типа вместо десяти (нет byte/short/long/float) — упрощает API и предотвращает ошибки переполнения
- **Строки**: иммутабельность устраняет гонки данных при конкурентном доступе (важно в Isolates)
- **Records**: устраняют boilerplate при возврате нескольких значений из функции — альтернатива созданию одноразовых классов
- **Runes**: корректная работа с Unicode эмодзи и символами за пределами BMP (Basic Multilingual Plane)

---

## 3. Как это работает

### Числа

```dart
// int — целое, без ограничений размера на VM (arbitrary precision через BigInt при необходимости)
int a = 42;
int hex = 0xFF;        // шестнадцатеричный литерал
int binary = 0b1010;   // двоичный литерал
int big = 1_000_000;   // разделитель для читаемости

// double — IEEE 754
double pi = 3.14;
double e = 1.5e3;      // экспоненциальная запись = 1500.0
double nan = double.nan;
double inf = double.infinity;

// num — общий тип
num x = 42;   // int
num y = 3.14; // double

// Преобразования
int i = 3;
double d = i.toDouble();   // 3.0
double d2 = 3.7;
int i2 = d2.toInt();       // 3 (усечение, не округление)
int i3 = d2.round();       // 4

// Полезные методы
print(42.clamp(0, 10));    // 10 — ограничение диапазоном
print((-5).abs());         // 5
print(7.isOdd);            // true
print(8.isEven);           // true
```

### Строки

```dart
// Объявление
String s1 = 'Одинарные кавычки';
String s2 = "Двойные кавычки";
String s3 = '''
Многострочная
  строка
''';
String s4 = r'Raw: \n не является переносом'; // raw string

// Интерполяция
String name = 'Dart';
String version = '3.0';
print('Привет, $name $version!');           // простая
print('Длина: ${name.length} символов');   // выражение

// Конкатенация
// Предпочтительно интерполяцию или StringBuffer для множества операций
String full = '$name ' + '$version';        // OK для двух строк
// Для сотен строк:
final buffer = StringBuffer();
for (int i = 0; i < 1000; i++) {
  buffer.write('item $i, ');
}
String result = buffer.toString();

// Ключевые методы
print('hello'.toUpperCase());   // HELLO
print('  trim me  '.trim());    // 'trim me'
print('a,b,c'.split(','));      // ['a', 'b', 'c']
print('hello world'.contains('world')); // true
print('hello'.replaceAll('l', 'r'));    // 'herro'
print('hello'.substring(1, 3));         // 'el'
print('hello'.indexOf('l'));            // 2
print('abc'.padLeft(5, '0'));           // '00abc'
```

### bool

```dart
bool isValid = true;
bool isEmpty = false;

// В Dart нет truthy/falsy — только строгие bool
// if (1) { }   // ОШИБКА компиляции! Только if (1 != 0) { }
// if ('') { }  // ОШИБКА компиляции!

// Логические операторы
bool a = true, b = false;
print(a && b);   // false — AND
print(a || b);   // true  — OR
print(!a);       // false — NOT
print(a ^ b);    // true  — XOR
```

### Runes — Unicode code points

```dart
// String в Dart — последовательность UTF-16 code units
// Некоторые символы (эмодзи, CJK) занимают 2 code unit (суррогатная пара)
String emoji = '😀';
print(emoji.length);      // 2 — UTF-16 code units, НЕ символы!
print(emoji.runes.length); // 1 — один Unicode code point

// Итерация по символам (не code units)
for (final rune in 'Привет 😀'.runes) {
  print(String.fromCharCode(rune));
}

// characters пакет — ещё более корректная работа с grapheme clusters
// 'pub add characters' затем:
// import 'package:characters/characters.dart';
// print('😀👨‍👩‍👧'.characters.length); // 2 (emoji + family emoji cluster)
```

### Symbols

```dart
// Symbol — идентификатор Dart как значение
Symbol s1 = Symbol('toString');
Symbol s2 = #toString;  // Литеральный синтаксис

print(s1 == s2);     // true — символы с одним именем идентичны
print(s1.toString()); // Symbol("toString")

// Используются в:
// - dart:mirrors (рефлексия, редко используется в продакшне)
// - @MirrorsUsed аннотациях
// - noSuchMethod(Invocation) для динамического диспатча
// В обычном прикладном коде символы практически не нужны
```

---

## 4. Records (Dart 3) — анонимные кортежи

Records — **самая значимая новая фича Dart 3**: анонимный, иммутабельный, структурно типизированный составной тип.

### Синтаксис

```dart
// Позиционный record
(String, int) point = ('Alice', 30);
print(point.$1); // 'Alice'
print(point.$2); // 30

// Именованный record
({String name, int age}) person = (name: 'Alice', age: 30);
print(person.name);  // 'Alice'
print(person.age);   // 30

// Смешанный
(int, {double lat, double lng}) location = (42, lat: 55.75, lng: 37.62);
print(location.$1);    // 42
print(location.lat);   // 55.75
```

### Деструктуризация records

```dart
// Присваивание через паттерн
var (name, age) = ('Alice', 30);
print('$name is $age');

// Именованная деструктуризация
var (:name, :age) = (name: 'Bob', age: 25);

// В switch
(String, int) pair = ('hello', 42);
switch (pair) {
  case (String s, int n) when n > 10:
    print('$s with $n > 10');
  case (_, int n):
    print('any string with $n');
}
```

### Возврат нескольких значений из функции

```dart
// ДО Dart 3 — создавали одноразовый класс или List<dynamic>
// ПОСЛЕ Dart 3 — Record
(String, int) parseVersion(String input) {
  final parts = input.split('.');
  return (parts[0], int.parse(parts[1]));
}

void main() {
  final (major, minor) = parseVersion('v3.5');
  print('Major: $major, Minor: $minor');
}

// С именованными полями — более читаемо
({String name, String? error}) tryParse(String json) {
  try {
    return (name: jsonDecode(json)['name'] as String, error: null);
  } catch (e) {
    return (name: '', error: e.toString());
  }
}
```

### Equality у Records

```dart
// Records сравниваются структурно — нет нужды в Equatable
(1, 'a') == (1, 'a');  // true
(1, 'a') == (1, 'b');  // false
({name: 'Alice'}) == ({name: 'Alice'}); // true
```

---

## 5. Минимальный пример

```dart
void main() {
  // Числа
  int score = 95;
  double average = 87.5;
  num result = score * average / 100;
  print('Result: ${result.toStringAsFixed(2)}');

  // Строки
  const greeting = 'Hello, Dart!';
  print(greeting.split(', ').map((s) => s.toUpperCase()).join(' | '));

  // Records — возврат пары значений
  (int, String) classify(int value) => switch (value) {
    < 0 => (value, 'negative'),
    0 => (0, 'zero'),
    _ => (value, 'positive'),
  };

  final (val, label) = classify(-5);
  print('$val is $label');

  // Unicode
  const text = 'Dart 🎯';
  print('Code units: ${text.length}');       // 7 (emoji = 2 units)
  print('Code points: ${text.runes.length}'); // 6
}
```

---

## 6. Практический пример

Парсинг HTTP-ответа с Records:

```dart
import 'dart:convert';

// Без Records — нужен отдельный класс или Map
// С Records — лаконично и типобезопасно
({int statusCode, Map<String, dynamic> body, String? error})
    parseHttpResponse(String rawJson, int statusCode) {
  try {
    final body = jsonDecode(rawJson) as Map<String, dynamic>;
    return (statusCode: statusCode, body: body, error: null);
  } on FormatException catch (e) {
    return (statusCode: statusCode, body: {}, error: e.message);
  }
}

void processResponse(String json, int code) {
  final (:statusCode, :body, :error) = parseHttpResponse(json, code);

  if (error != null) {
    print('Parse error: $error');
    return;
  }

  switch (statusCode) {
    case 200:
      final name = body['name'] as String?;
      print('Success: ${name ?? 'unknown'}');
    case >= 400 && < 500:
      print('Client error $statusCode: ${body['message']}');
    case >= 500:
      print('Server error $statusCode');
  }
}

void main() {
  processResponse('{"name": "Alice"}', 200);
  processResponse('not json', 200);
  processResponse('{"message": "Not found"}', 404);
}
```

---

## 7. Что происходит под капотом

### int на разных платформах

- **Dart VM**: `int` = Smi (small integer, 63-bit, без аллокации) или Mint (63+ bit, heap object)
- **Dart Web (JS)**: `int` = JavaScript `number` (53-bit, IEEE 754) — переполнение возможно!
- **Flutter AOT**: нативные 64-bit целые

```dart
// Web-специфика — помнить при работе с большими ID
int id = 9007199254740993; // Корректно на VM, потеря точности на Web
```

### String: UTF-16 vs UTF-8

Внутри VM строки хранятся в оптимизированном формате:
- Строки только из ASCII → `Latin-1` (1 байт на символ)
- Строки с Unicode → UTF-16 (2 байта на code unit)
- Автоматически выбирается при создании

Это отличается от Rust/Go (UTF-8) и Java (UTF-16).

### Records под капотом

Records — **value types** в системе типов Dart, но реализованы как объекты на heap. Компилятор может оптимизировать short-lived records через stack allocation в AOT.

Сравнение Records работает через **structural equality** — автоматически генерируется компилятором.

---

## 8. Производительность и ресурсы

**Числа:**
- `int` Smi-оптимизация: операции над маленькими целыми без аллокации
- `double` — всегда heap object на VM (в отличие от JVM где double — примитив)

**Строки:**
- `StringBuffer` vs `+`: для N конкатенаций `'a' + 'b' + ... + 'z'` создаётся N-1 промежуточных строк; `StringBuffer` — O(N) вместо O(N²)
- Строковая интерполяция компилируется в эффективный код — предпочтительнее `+`

**Records:**
- Легче чем классы (нет методов, нет наследования)
- Структурное равенство без ручного `==` и `hashCode`

---

## 9. Частые ошибки и антипаттерны

**1. `String.length` для подсчёта символов:**
```dart
// НЕВЕРНО для Unicode
print('😀'.length); // 2, а не 1

// ВЕРНО — для подсчёта code points
print('😀'.runes.length); // 1
// Ещё точнее — grapheme clusters через пакет characters
```

**2. int / double преобразование:**
```dart
// НЕВЕРНО — toInt() усекает, не округляет
print(2.9.toInt()); // 2 (не 3!)

// ВЕРНО
print(2.9.round()); // 3
print(2.9.ceil());  // 3
print(2.9.floor()); // 2
```

**3. Использование `List<dynamic>` вместо Record:**
```dart
// НЕВЕРНО — нет типобезопасности
List<dynamic> result = [name, age]; // Что в [0], что в [1]?

// ВЕРНО — Record
(String name, int age) result = ('Alice', 30);
```

**4. Игнорирование Web integer limits:**
```dart
// ПРОБЛЕМА на Web/JS
int id = 9007199254740993; // Потеря точности в JS runtime

// РЕШЕНИЕ для Web — использовать String для больших ID JSON
```

---

## 10. Сравнение с альтернативами

| Аспект | Dart | Kotlin | TypeScript | Python |
|---|---|---|---|---|
| int | 64-bit (VM) / 53-bit (Web) | `Int`, `Long` | `number` (53-bit) | Arbitrary precision |
| String | UTF-16 | UTF-16 | UTF-16 | UTF-8 |
| Кортежи | `(T1, T2)` Records | `Pair`/`Triple` | `[T1, T2]` tuple | `(T1, T2)` |
| bool | Строгий (нет truthy) | Строгий | Нестрогий | Нестрогий |
| Символы | `#name` | Нет | `Symbol` | Нет |

**Преимущество Records** перед Kotlin `Pair`/`Triple`: произвольное количество полей + именованные поля + структурное равенство.

---

## 11. Когда НЕ стоит использовать Records

- **Публичный API** — если тип нужен снаружи модуля, создайте именованный класс (Records анонимны и не читаемы как тип в документации)
- **Более 4–5 полей** — создайте класс с описательными именами
- **Методы и поведение** — Records только данные, логику добавлять нельзя (используйте класс)

---

## 12. Краткое резюме

1. **`int`/`double` вместо примитивов** — Dart упрощает систему числовых типов; помнить о 53-битном ограничении на Web.
2. **`String.length` — UTF-16 code units**, не символы; для Unicode-корректности использовать `runes` или пакет `characters`.
3. **`StringBuffer` для множественной конкатенации** — `+` создаёт O(N²) промежуточных строк.
4. **Records заменяют одноразовые классы** для возврата нескольких значений — типобезопасно и без boilerplate.
5. **Record equality — структурная** (по значениям полей), не по ссылке — не нужен `Equatable`.
6. **`bool` в Dart строгий** — нет truthy/falsy; `if (someString)` — ошибка компиляции.
7. **`Runes`/`Symbol`** — нишевые типы; `Symbol` практически не нужен в прикладном коде, `Runes` — для корректной работы с Unicode.
