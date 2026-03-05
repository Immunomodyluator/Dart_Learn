# 3.2 Строки и интерполяция

## 1. Формальное определение

**`String`** в Dart — неизменяемая (immutable) последовательность UTF-16 code units. Строки реализуют `Comparable<String>` и `Pattern`. Являются объектами с богатым набором методов.

**Интерполяция** — встраивание выражений в строковый литерал через `$variable` или `${expression}`.

**Уровень:** встроенные типы / runtime.

## 2. Зачем это нужно

- **Immutable** — строки нельзя изменить после создания. Безопасно передавать между потоками, использовать как ключи Map.
- **Интерполяция** — читабельнее конкатенации: `'Hello, $name'` vs `'Hello, ' + name`.
- **UTF-16** — полная поддержка Unicode, включая эмодзи (но с нюансами для символов за пределами BMP).

## 3. Как это работает

### Литералы

```dart
// Одинарные кавычки (предпочтительно)
var s1 = 'Hello, Dart!';

// Двойные кавычки
var s2 = "Hello, Dart!";

// Многострочный литерал
var s3 = '''
Это многострочная
строка в Dart.
''';

var s4 = """
То же самое
с двойными кавычками.
""";

// Raw-строка (без escape-последовательностей)
var regex = r'\d+\.\d+';   // \d+\.\d+ буквально
var path = r'C:\Users\Ivan\Documents';

// Конкатенация литералов (compile-time)
var s5 = 'Hello, '
    'World!';   // → 'Hello, World!' — без оператора +
```

### Интерполяция

```dart
var name = 'Dart';
var version = 3;

// Простая переменная — $
print('$name $version');           // Dart 3

// Выражение — ${}
print('${name.toUpperCase()} ${version + 1}');  // DART 4

// Вложенные кавычки
print("It's a $name string");     // Двойные кавычки внутри одинарных
print('She said: "Hello"');        // Одинарные снаружи

// Escape-последовательности
print('Tab:\t Newline:\n Quote: \' Backslash: \\');
print('Unicode: \u0041');          // A
print('Unicode extended: \u{1F600}'); // 😀
```

### Методы строк

```dart
var s = '  Hello, Dart!  ';

// Обрезка пробелов
s.trim();              // 'Hello, Dart!'
s.trimLeft();          // 'Hello, Dart!  '
s.trimRight();         // '  Hello, Dart!'

// Регистр
'hello'.toUpperCase(); // 'HELLO'
'HELLO'.toLowerCase(); // 'hello'

// Поиск
'Hello'.contains('ell');       // true
'Hello'.startsWith('He');      // true
'Hello'.endsWith('lo');        // true
'Hello'.indexOf('l');          // 2
'Hello'.lastIndexOf('l');      // 3

// Подстрока
'Hello'.substring(1, 4);      // 'ell'

// Разбиение
'a,b,c'.split(',');            // ['a', 'b', 'c']

// Замена
'Hello'.replaceAll('l', 'r');  // 'Herro'
'abc'.replaceFirst('a', 'A');  // 'Abc'
'I love cats'.replaceAllMapped(
  RegExp(r'\b\w'),
  (m) => m[0]!.toUpperCase(),
); // 'I Love Cats'

// Заполнение
'42'.padLeft(5, '0');          // '00042'
'hi'.padRight(10, '.');       // 'hi........'

// Проверки
''.isEmpty;                    // true
'hello'.isNotEmpty;            // true

// Повторение
'ha' * 3;                     // 'hahaha'

// Сравнение
'abc'.compareTo('abd');        // -1
```

### StringBuffer — эффективная конкатенация

```dart
// Плохо для большого количества конкатенаций:
// var result = '';
// for (var i = 0; i < 1000; i++) result += 'item $i, ';

// Хорошо:
final buffer = StringBuffer();
for (var i = 0; i < 1000; i++) {
  buffer.write('item $i');
  if (i < 999) buffer.write(', ');
}
String result = buffer.toString();
```

## 4. Минимальный пример

```dart
void main() {
  // Интерполяция
  var language = 'Dart';
  var year = 2011;
  print('$language создан в $year, ему ${DateTime.now().year - year} лет');

  // Многострочный
  var json = '''
  {
    "name": "$language",
    "year": $year
  }
  ''';
  print(json);

  // StringBuffer
  var csv = StringBuffer();
  csv.writeln('name,age');
  csv.writeln('Alice,30');
  csv.writeln('Bob,25');
  print(csv);
}
```

## 5. Практический пример

### Шаблонный генератор с безопасной интерполяцией

```dart
class EmailTemplate {
  final String subject;
  final String body;

  const EmailTemplate({required this.subject, required this.body});

  String render(Map<String, String> variables) {
    var result = body;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', _sanitize(entry.value));
    }
    return result;
  }

  /// Базовая санитизация для предотвращения инъекций
  static String _sanitize(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}

void main() {
  const template = EmailTemplate(
    subject: 'Добро пожаловать!',
    body: '''
Здравствуйте, {{name}}!

Ваш аккаунт ({{email}}) успешно создан.
Дата регистрации: {{date}}.

С уважением,
Команда {{company}}
''',
  );

  final email = template.render({
    'name': 'Иван',
    'email': 'ivan@example.com',
    'date': '2026-03-05',
    'company': 'Acme Corp',
  });

  print(email);
}
```

## 6. Что происходит под капотом

### Строки в памяти

```
Dart VM хранит строки в двух форматах:

OneByteString (Latin-1):
┌────────────────────────────────────────┐
│ hash | length | byte byte byte byte ...│
└────────────────────────────────────────┘
  4B     4B       1 byte per code unit

TwoByteString (UTF-16):
┌────────────────────────────────────────────┐
│ hash | length | unit unit unit unit ...    │
└────────────────────────────────────────────┘
  4B     4B       2 bytes per code unit
```

VM автоматически выбирает компактный формат: если все символы ≤ 0xFF (Latin-1), используется `OneByteString` (1 байт на символ). Иначе — `TwoByteString` (2 байта).

### Immutability

Каждая операция (конкатенация, замена, trim) создаёт **новый** объект String:

```dart
var s = 'Hello';
var s2 = s + ' World';  // Новый объект. s не изменён.
```

Это значит: цикл из N конкатенаций создаёт N промежуточных строк → O(N²) по памяти. `StringBuffer` решает проблему: O(N).

### Интерполяция vs конкатенация

```dart
// Интерполяция:
'Hello, $name!'
// Компилятор преобразует в:
// StringBuffer()..write('Hello, ')..write(name)..write('!')..toString()

// Конкатенация литералов (compile-time):
'Hello, ' 'World'
// Склеивается компилятором в один литерал: 'Hello, World'
```

### UTF-16 и суррогатные пары

```dart
var emoji = '😀';
print(emoji.length);              // 2 (два UTF-16 code units!)
print(emoji.codeUnits);           // [55357, 56832] — surrogate pair
print(emoji.runes.length);        // 1 (один Unicode code point)
print(emoji.runes.first);         // 128512 (U+1F600)

// Для корректной работы с Unicode — используйте package:characters
import 'package:characters/characters.dart';
print('Hi 👋🏽'.characters.length);  // 3 (а не 5!)
```

## 7. Производительность и ресурсы

| Операция               | Сложность      | Примечание                       |
| ---------------------- | -------------- | -------------------------------- |
| `s.length`             | O(1)           | Хранится в заголовке             |
| `s[i]`                 | O(1)           | Прямой доступ по индексу         |
| `s1 + s2`              | O(n+m)         | Создаёт новую строку             |
| `s.contains(p)`        | O(n)           | Линейный поиск                   |
| `s.replaceAll()`       | O(n)           | Создаёт новую строку             |
| `StringBuffer.write()` | Amortized O(1) | Внутренний буфер с удвоением     |
| `List.join()`          | O(n)           | Эффективнее цикла + конкатенации |

**Правила:**

- Для 2–3 конкатенаций — интерполяция (`'$a $b $c'`).
- Для циклов — `StringBuffer` или `List<String>.join()`.
- `'a' * 1000` — создаёт одну строку за O(n), эффективнее цикла.

## 8. Частые ошибки и антипаттерны

### ❌ Конкатенация в цикле

```dart
// Плохо: O(n²) по времени и памяти
var result = '';
for (var i = 0; i < 10000; i++) {
  result += '$i, ';  // Каждый раз новая строка!
}

// Хорошо: O(n)
final parts = <String>[];
for (var i = 0; i < 10000; i++) {
  parts.add('$i');
}
final result = parts.join(', ');
```

### ❌ .length для количества символов

```dart
var emoji = '👨‍👩‍👧‍👦';
print(emoji.length);            // 11 (UTF-16 code units!)
// Это один видимый символ (grapheme cluster)

// Используйте package:characters для правильного подсчёта
```

### ❌ toString() в интерполяции

```dart
// Лишнее: toString() вызывается автоматически
print('Value: ${value.toString()}');

// Правильно:
print('Value: $value');
```

### ❌ RegExp без raw-строки

```dart
// Плохо: двойное экранирование
var pattern = '\\d+\\.\\d+';

// Хорошо: raw-строка
var pattern = r'\d+\.\d+';
```

## 9. Сравнение с альтернативами

| Аспект        | Dart               | Java                | Kotlin             | JavaScript         |
| ------------- | ------------------ | ------------------- | ------------------ | ------------------ |
| Immutable     | ✅                 | ✅                  | ✅                 | ✅                 |
| Кодировка     | UTF-16             | UTF-16              | UTF-16             | UTF-16             |
| Интерполяция  | `'$x'`             | ❌ (concat)         | `"$x"`             | `` `${x}` ``       |
| Многострочный | `'''...'''`        | ❌ (Java 13+ `"""`) | `"""..."""`        | `` `...` ``        |
| Raw-строка    | `r'...'`           | ❌                  | ❌                 | `String.raw`       |
| `==`          | Сравнение значений | Сравнение ссылок    | Сравнение значений | Сравнение значений |
| StringBuffer  | ✅                 | `StringBuilder`     | `StringBuilder`    | Array.join         |

**Уникальность Dart:** `==` для строк сравнивает **значения** (не ссылки, как в Java). `'abc' == 'abc'` → `true` всегда.

## 10. Когда НЕ стоит использовать

- **Строки как структурированные данные** — не парсите JSON вручную через `split()` и `substring()`. Используйте `dart:convert` или пакеты сериализации.
- **Строки для бинарных данных** — используйте `Uint8List` из `dart:typed_data`.
- **Конкатенация для SQL/HTML** — никогда не формируйте SQL/HTML через строковую интерполяцию. Это путь к injection-атакам. Используйте параметризованные запросы.

## 11. Краткое резюме

1. **String — immutable** UTF-16 последовательность. Каждая модификация создаёт новый объект.
2. **Интерполяция `$x` / `${expr}`** — предпочтительнее конкатенации `+`. Читабельнее и не менее эффективна.
3. **`StringBuffer`** или **`List.join()`** для множественных конкатенаций — O(n) вместо O(n²).
4. **`r'...'` (raw strings)** — для регулярных выражений и путей (без escape-обработки).
5. **`.length` — UTF-16 code units**, не символы. Для grapheme clusters используйте `package:characters`.
6. **`==` сравнивает значения**, не ссылки (в отличие от Java).
7. **Многострочные `'''...'''`** — для шаблонов, SQL, JSON. Отступы включаются в строку.

---

> **Следующий:** [3.3 Булевы значения](03_03_booleans.md)
