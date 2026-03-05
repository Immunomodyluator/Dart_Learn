# 3.4 Runes и Symbols

## 1. Формальное определение

**Runes** — представление Unicode code points строки. Строки Dart хранят UTF-16 code units, но symbol может занимать 1 или 2 code units (surrogate pair). `Runes` (`String.runes`) даёт доступ к Unicode code points, каждый из которых — один символ Unicode.

**Symbol** (`Symbol`) — объект, представляющий оператор или идентификатор, объявленный в программе. Используется для рефлексии (mirrors API) и в качестве ключей Map, не подверженных минификации.

**Уровень:** встроенные типы / Unicode / метапрограммирование.

## 2. Зачем это нужно

### Runes

- **Правильная работа с Unicode** — `'😀'.length == 2` (UTF-16 code units), но `'😀'.runes.length == 1` (один символ).
- **Эмодзи, иероглифы, математические символы** — символы за пределами Basic Multilingual Plane (BMP, U+0000–U+FFFF) требуют surrogate pairs.

### Symbol

- **Рефлексия** — `#methodName` используется в mirrors API для обращения к членам класса по имени.
- **Минификация-safe ключи** — `Symbol` сохраняется при dart2js-минификации, в отличие от строковых имён.
- **На практике**: редко используется в повседневной разработке. С отказом от `dart:mirrors` (недоступен в AOT и Flutter) значимость `Symbol` снизилась.

## 3. Как это работает

### Runes

```dart
void main() {
  var emoji = '😀';

  // UTF-16 code units
  print(emoji.length);        // 2 (surrogate pair)
  print(emoji.codeUnits);     // [55357, 56832]

  // Unicode code points (Runes)
  print(emoji.runes.length);  // 1
  print(emoji.runes.first);   // 128512 (0x1F600)

  // Создание строки из code points
  var smiley = String.fromCharCode(0x1F600);
  print(smiley);              // 😀

  var multiple = String.fromCharCodes([0x1F600, 0x1F601, 0x1F602]);
  print(multiple);            // 😀😁😂

  // Итерация по code points
  var text = 'A😀B';
  for (final rune in text.runes) {
    print('U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}: '
        '${String.fromCharCode(rune)}');
  }
  // U+0041: A
  // U+1F600: 😀
  // U+0042: B
}
```

### Grapheme clusters (пакет characters)

```dart
// Runes недостаточно для сложных символов!
var family = '👨‍👩‍👧‍👦';
print(family.length);              // 11 (UTF-16 code units)
print(family.runes.length);        // 7 (code points: 4 человека + 3 ZWJ)
// Визуально: 1 символ!

// Для правильного подсчёта используйте package:characters
import 'package:characters/characters.dart';
print(family.characters.length);   // 1 (grapheme cluster)
```

### Symbol

```dart
// Symbol-литерал
var s1 = #myIdentifier;
var s2 = #myMethod;
var s3 = Symbol('myIdentifier');

// Сравнение
print(s1 == s3);              // true
print(identical(#foo, #foo)); // true (каноникализация)

// Использование как ключ Map
var metadata = <Symbol, dynamic>{
  #name: 'Alice',
  #age: 30,
  #isActive: true,
};

print(metadata[#name]);       // Alice
```

### Symbol и noSuchMethod

```dart
class DynamicProxy {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // invocation.memberName — это Symbol
    print('Вызван: ${invocation.memberName}');
    print('Аргументы: ${invocation.positionalArguments}');
    return null;
  }
}

void main() {
  dynamic proxy = DynamicProxy();
  proxy.hello('world');
  // Вызван: Symbol("hello")
  // Аргументы: [world]
}
```

## 4. Минимальный пример

```dart
void main() {
  // Runes
  var text = 'Привет 🌍!';
  print('Code units: ${text.length}');     // 10
  print('Code points: ${text.runes.length}'); // 9
  print('Содержит 🌍: ${text.contains('🌍')}'); // true

  // Символ из code point
  var star = String.fromCharCode(0x2605); // ★
  print(star);

  // Symbol
  var sym = #myVariable;
  print(sym); // Symbol("myVariable")
}
```

## 5. Практический пример

### Unicode-aware текстовый процессор

```dart
class TextAnalyzer {
  final String text;

  TextAnalyzer(this.text);

  /// Подсчитать Unicode code points (не UTF-16 units!)
  int get codePointCount => text.runes.length;

  /// Проверить, содержит ли текст эмодзи
  bool get hasEmoji {
    for (final rune in text.runes) {
      if (rune > 0xFFFF || // Символы за пределами BMP
          (rune >= 0x2600 && rune <= 0x27BF) || // Misc symbols
          (rune >= 0xFE00 && rune <= 0xFE0F)) { // Variation selectors
        return true;
      }
    }
    return false;
  }

  /// Безопасная обрезка до N code points
  String truncate(int maxCodePoints) {
    final runes = text.runes.toList();
    if (runes.length <= maxCodePoints) return text;
    return String.fromCharCodes(runes.take(maxCodePoints)) + '…';
  }

  /// Частотный анализ символов (по code points)
  Map<String, int> characterFrequency() {
    final freq = <String, int>{};
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      freq[char] = (freq[char] ?? 0) + 1;
    }
    return freq;
  }
}

void main() {
  final analyzer = TextAnalyzer('Hello 😀 мир 🌍!');

  print('Code points: ${analyzer.codePointCount}');
  print('Has emoji: ${analyzer.hasEmoji}');
  print('Truncated: ${analyzer.truncate(8)}');
  print('Frequency: ${analyzer.characterFrequency()}');
}
```

## 6. Что происходит под капотом

### UTF-16 и surrogate pairs

```
BMP (U+0000 – U+FFFF):
  Символ → 1 UTF-16 code unit (2 байта)
  Пример: 'A' = U+0041 → [0x0041]

SMP и выше (U+10000 – U+10FFFF):
  Символ → 2 UTF-16 code units (surrogate pair)
  Пример: '😀' = U+1F600
  Формула:
    high = 0xD800 + ((0x1F600 - 0x10000) >> 10)  = 0xD83D
    low  = 0xDC00 + ((0x1F600 - 0x10000) & 0x3FF) = 0xDE00
  → [0xD83D, 0xDE00]
```

### Runes — ленивый итератор

`String.runes` возвращает `Runes` — ленивый `Iterable<int>`. При итерации он автоматически объединяет surrogate pairs в code points:

```
'A😀B'.runes:
  [0x0041] → code point 0x0041 (A)
  [0xD83D, 0xDE00] → code point 0x1F600 (😀)
  [0x0042] → code point 0x0042 (B)
```

### Symbol — canonical interning

```
#foo → Symbol('foo')

Все литералы #foo ссылаются на один объект в памяти (canonical table).
Symbol('foo') создаёт через конструктор, но identical(#foo, Symbol('foo')) == true
потому что конструктор Symbol() тоже использует interning.
```

При AOT-компиляции (dart2js, Flutter) `Symbol` сохраняет имя, но `dart:mirrors` недоступен, что ограничивает рефлексию.

## 7. Производительность и ресурсы

| Операция                     | Сложность                 |
| ---------------------------- | ------------------------- |
| `text.length`                | O(1) — хранится           |
| `text.runes.length`          | O(n) — нужна итерация     |
| `text.runes.first`           | O(1)                      |
| `String.fromCharCode()`      | O(1)                      |
| `String.fromCharCodes(list)` | O(n)                      |
| `#symbol`                    | O(1) — из canonical table |

**Нюансы:**

- Итерация по `runes` — дороже, чем по `codeUnits`. Если текст ASCII-only — `codeUnits` быстрее.
- `package:characters` для grapheme clusters — ещё дороже (но корректнее для UI).

## 8. Частые ошибки и антипаттерны

### ❌ s[i] для emoji

```dart
var text = '😀Hello';
// print(text[0]);  // '?' или мусор — первый surrogate без пары!
// Правильно:
print(String.fromCharCode(text.runes.first)); // 😀
```

### ❌ substring() разрезает surrogate pair

```dart
var text = 'A😀B';
// text.substring(0, 2) → 'A' + half of 😀 → битый символ!
// Правильно: работать через runes
```

### ❌ Symbol для строковых ключей

```dart
// Плохо: Symbol бесполезен без dart:mirrors
var config = <Symbol, String>{#apiUrl: 'https://...'};

// Хорошо: String-ключи
var config = <String, String>{'apiUrl': 'https://...'};
```

## 9. Сравнение с альтернативами

| Аспект              | Dart                 | Java                  | JavaScript       | Python         |
| ------------------- | -------------------- | --------------------- | ---------------- | -------------- |
| Строковая кодировка | UTF-16               | UTF-16                | UTF-16           | UTF-8 (внутри) |
| Code points API     | `String.runes`       | `String.codePoints()` | `[...str]`       | `ord(ch)`      |
| Grapheme clusters   | `package:characters` | `BreakIterator`       | `Intl.Segmenter` | `grapheme`     |
| Symbol-тип          | `Symbol` / `#name`   | ❌                    | `Symbol()`       | ❌             |

Python хранит строки внутри как Unicode code points (не UTF-16), что упрощает работу с BMP-символами.

## 10. Когда НЕ стоит использовать

- **Runes для UI-текста** — используйте `package:characters` для grapheme clusters. Runes не обрабатывают ZWJ-последовательности (составные эмодзи типа 👨‍👩‍👧).
- **Symbol в Flutter/AOT** — `dart:mirrors` недоступен. Symbol бесполезен без рефлексии. Используйте строки или enum.
- **Ручной Unicode-парсинг** — для i18n/l10n используйте `package:intl`. Для нормализации — `package:unicode`.

## 11. Краткое резюме

1. **`String.runes`** — доступ к Unicode code points. `'😀'.runes.length == 1`, а `'😀'.length == 2`.
2. **Surrogate pairs** — символы за пределами BMP (U+10000+) кодируются двумя UTF-16 units. `s[i]` может вернуть половину символа.
3. **`package:characters`** — единственный корректный способ работать с grapheme clusters (составные символы, эмодзи с модификаторами).
4. **Symbol (`#name`)** — canonical объект-идентификатор. Полезен для рефлексии (`dart:mirrors`), но mirrors недоступны в AOT/Flutter.
5. **`String.fromCharCode()`** / **`String.fromCharCodes()`** — создание строк из code points.
6. **На практике** Runes нужны редко — для большинства задач достаточно обычных String-методов. Для сложного Unicode — `package:characters`.
7. **Symbol практически устарел** в контексте Flutter и AOT. Используйте строки или enum для динамических ключей.

---

> **Назад:** [Обзор раздела](03_00_overview.md) · **Далее:** [4. Коллекции](../04_collections/04_00_overview.md)
