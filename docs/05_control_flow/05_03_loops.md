# 5.3 Циклы: for, for-in, while

## 1. Формальное определение

**Циклы** — конструкции, повторяющие блок кода до выполнения условия выхода. Dart предоставляет:

- **`for`** (C-style) — с инициализацией, условием и инкрементом.
- **`for-in`** — итерация по `Iterable<E>`.
- **`while`** — цикл с предусловием.
- **`do-while`** — цикл с постусловием (тело выполняется минимум 1 раз).
- **`break`** — выход из цикла.
- **`continue`** — переход к следующей итерации.

Все циклы поддерживают метки (labels) для управления вложенными циклами.

## 2. Зачем это нужно

- **Повторяющиеся операции** — обход коллекций, обработка данных, алгоритмы.
- **`for-in`** — идиоматический обход `List`, `Set`, `Map.entries`, `Runes`, любого `Iterable`.
- **`while`** — когда количество итераций неизвестно заранее (чтение потока, ожидание условия).
- **C-style `for`** — когда нужен индекс, обратный обход или нестандартный шаг.
- **`do-while`** — гарантированное выполнение хотя бы одного раза (меню, retry).

## 3. Как это работает

### C-style for

```dart
void main() {
  // Стандартный
  for (var i = 0; i < 5; i++) {
    print(i); // 0, 1, 2, 3, 4
  }

  // Обратный порядок
  var list = ['a', 'b', 'c'];
  for (var i = list.length - 1; i >= 0; i--) {
    print(list[i]); // c, b, a
  }

  // Шаг 2
  for (var i = 0; i < 10; i += 2) {
    print(i); // 0, 2, 4, 6, 8
  }

  // Несколько переменных
  for (var i = 0, j = 10; i < j; i++, j--) {
    print('$i, $j');
  }
}
```

### for-in

```dart
void main() {
  var fruits = ['яблоко', 'банан', 'вишня'];

  // Обход List
  for (final fruit in fruits) {
    print(fruit);
  }

  // Обход Set
  var unique = {1, 2, 3};
  for (final n in unique) {
    print(n);
  }

  // Обход Map через entries
  var scores = {'Алиса': 95, 'Борис': 87};
  for (final entry in scores.entries) {
    print('${entry.key}: ${entry.value}');
  }

  // Обход Map через keys
  for (final name in scores.keys) {
    print('$name: ${scores[name]}');
  }

  // Обход строки по code points
  for (final rune in 'Hello 😀'.runes) {
    print(String.fromCharCode(rune));
  }
}
```

### while и do-while

```dart
void main() {
  // while — предусловие
  var count = 0;
  while (count < 3) {
    print(count); // 0, 1, 2
    count++;
  }

  // do-while — постусловие (минимум 1 выполнение)
  var input = '';
  do {
    input = readInput(); // Имитация чтения
    print('Получено: $input');
  } while (input != 'exit');
}

String readInput() => 'exit'; // Заглушка
```

### break и continue

```dart
void main() {
  // break — выход из цикла
  for (var i = 0; i < 100; i++) {
    if (i == 5) break;
    print(i); // 0, 1, 2, 3, 4
  }

  // continue — пропуск итерации
  for (var i = 0; i < 10; i++) {
    if (i.isOdd) continue;
    print(i); // 0, 2, 4, 6, 8
  }
}
```

### Метки (labels)

```dart
void main() {
  // Метка для выхода из вложенного цикла
  outer:
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 3; j++) {
      if (i == 1 && j == 1) break outer; // Выход из ОБОИХ
      print('$i, $j');
    }
  }
  // 0,0  0,1  0,2  1,0

  // continue с меткой
  outer:
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 3; j++) {
      if (j == 1) continue outer; // К следующей итерации ВНЕШНЕГО
      print('$i, $j');
    }
  }
  // 0,0  1,0  2,0
}
```

## 4. Минимальный пример

```dart
void main() {
  var numbers = [10, 20, 30, 40, 50];

  // for-in
  var sum = 0;
  for (final n in numbers) {
    sum += n;
  }
  print('Сумма: $sum'); // 150

  // while
  var i = numbers.length - 1;
  while (i >= 0) {
    print(numbers[i]);
    i--;
  }
}
```

## 5. Практический пример

### Парсер CSV с обработкой ошибок

```dart
class CsvParser {
  static List<Map<String, String>> parse(String csv) {
    var lines = csv.split('\n');
    if (lines.isEmpty) return [];

    var headers = _splitLine(lines.first);
    var results = <Map<String, String>>[];

    for (var i = 1; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue; // Пропуск пустых строк

      var values = _splitLine(line);
      if (values.length != headers.length) {
        print('Строка ${i + 1}: пропущена (${values.length} полей,'
            ' ожидалось ${headers.length})');
        continue;
      }

      var row = <String, String>{};
      for (var j = 0; j < headers.length; j++) {
        row[headers[j]] = values[j];
      }
      results.add(row);
    }

    return results;
  }

  static List<String> _splitLine(String line) {
    var fields = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    var i = 0;

    while (i < line.length) {
      var ch = line[i];

      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        fields.add(current.toString().trim());
        current.clear();
      } else {
        current.write(ch);
      }
      i++;
    }

    fields.add(current.toString().trim());
    return fields;
  }
}

void main() {
  var csv = '''
name,age,city
Алиса,30,Москва
Борис,25,Питер
,invalid
Вера,28,Казань''';

  var data = CsvParser.parse(csv);
  for (final row in data) {
    print(row);
  }
}
```

### Бинарный поиск

```dart
int binarySearch(List<int> sorted, int target) {
  var low = 0;
  var high = sorted.length - 1;

  while (low <= high) {
    var mid = low + (high - low) ~/ 2; // Защита от overflow

    if (sorted[mid] == target) {
      return mid;
    } else if (sorted[mid] < target) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return -1; // Не найден
}

void main() {
  var data = [2, 5, 8, 12, 16, 23, 38, 56, 72, 91];
  print(binarySearch(data, 23)); // 5
  print(binarySearch(data, 42)); // -1
}
```

## 6. Что происходит под капотом

### for-in — Iterator protocol

```dart
for (final item in collection) { body; }

// Компилируется в:
var _iterator = collection.iterator;
while (_iterator.moveNext()) {
  final item = _iterator.current;
  body;
}
```

`Iterable.iterator` создаёт новый `Iterator` каждый раз → for-in безопасен для повторного обхода.

### C-style for — замыкания

```dart
// Каждая итерация создаёт НОВУЮ переменную!
var closures = <Function>[];
for (var i = 0; i < 3; i++) {
  closures.add(() => print(i));
}
closures.forEach((f) => f()); // 0, 1, 2 (НЕ 3, 3, 3!)

// Dart создаёт новый scope для i на каждой итерации —
// в отличие от JavaScript (var), где было бы 3, 3, 3.
```

### while vs for — оптимизация

```
for (var i = 0; i < n; i++) { ... }
// Компилятор может:
// 1. Развернуть (unroll) для малых n
// 2. Vectorize для числовых операций
// 3. Hoist инвариант (n) из цикла

while (cond) { ... }
// Менее предсказуем — compiler может не оптимизировать агрессивно
```

## 7. Производительность и ресурсы

| Цикл          | Overhead       | Когда использовать                |
| ------------- | -------------- | --------------------------------- |
| C-style `for` | Минимальный    | Нужен индекс, шаг, обратный обход |
| `for-in`      | Iterator alloc | Обход Iterable (idiomatic)        |
| `while`       | Минимальный    | Неизвестное число итераций        |
| `do-while`    | Минимальный    | Гарантия 1 выполнения             |
| `forEach`     | Closure alloc  | Avoid (no break/await)            |

**Рекомендации:**

- `for-in` — идиоматичен, предпочитайте для обходов.
- C-style `for` — для числовых алгоритмов, TypedData, обратного обхода.
- `List.generate()` и `.map()` — функциональная альтернатива, но с аллокацией.

### for-in vs индексный доступ

```dart
// for-in — один Iterator, O(n):
for (final item in list) { ... }

// Индексный — O(n) для List, но O(n²) для LinkedList!
for (var i = 0; i < list.length; i++) { list[i]; } // OK для List

// for-in безопаснее: работает с любым Iterable за O(n)
```

## 8. Частые ошибки и антипаттерны

### ❌ Модификация коллекции при for-in

```dart
var list = [1, 2, 3, 4, 5];
// for (final item in list) {
//   if (item.isEven) list.remove(item); // ConcurrentModificationError!
// }

// Правильно:
list.removeWhere((item) => item.isEven);
// Или:
var filtered = [for (final item in list) if (item.isOdd) item];
```

### ❌ Бесконечный цикл без выхода

```dart
// Опасно:
while (true) {
  // Если забыть break — зависание!
}

// Безопаснее: максимум итераций
var attempts = 0;
while (attempts < 100) {
  if (success) break;
  attempts++;
}
```

### ❌ Использование forEach с async

```dart
var urls = ['url1', 'url2', 'url3'];

// Плохо: forEach не ждёт!
urls.forEach((url) async {
  await fetch(url); // Fire-and-forget! Не дождётся завершения
});

// Правильно:
for (final url in urls) {
  await fetch(url); // Последовательно
}

// Или параллельно:
await Future.wait(urls.map((url) => fetch(url)));
```

### ❌ Лишний toList() перед for-in

```dart
// Плохо: ненужная аллокация
for (final item in list.where((e) => e > 0).toList()) { ... }

// Хорошо: for-in работает с lazy Iterable
for (final item in list.where((e) => e > 0)) { ... }
```

## 9. Сравнение с альтернативами

| Аспект       | Dart                  | Java                 | JavaScript              | Python           |
| ------------ | --------------------- | -------------------- | ----------------------- | ---------------- |
| for-in       | `for (var x in iter)` | `for (var x : iter)` | `for (const x of iter)` | `for x in iter:` |
| C-style for  | `for (i=0;...)`       | `for (i=0;...)`      | `for (let i=0;...)`     | ❌ (range)       |
| for closures | Новая var каждый раз  | Нет capture var      | `let` — да, `var` — нет | Новая var        |
| break label  | `break label;`        | `break label;`       | `break label;`          | ❌               |
| List comp    | `[for (...) x]`       | ❌                   | ❌                      | `[x for ...]`    |

Dart уникален поддержкой `for` внутри литералов коллекций (collection for).

## 10. Когда НЕ стоит использовать

- **Простая трансформация** — `list.map((e) => e * 2).toList()` вместо `for` + `add`.
- **Фильтрация** — `list.where((e) => e > 0)` вместо `for` + `if` + `add`.
- **Агрегация** — `list.fold(0, (s, e) => s + e)` вместо `for` + `sum += e`.
- **Бесконечный polling** — используйте `Stream.periodic` или `Timer`.
- **Рекурсия** — для древовидных структур рекурсия часто читабельнее цикла.

## 11. Краткое резюме

1. **`for-in`** — идиоматический обход Iterable. Внутри используется Iterator protocol.
2. **C-style `for`** — для индексного доступа, обратного обхода, нестандартного шага.
3. **Новая переменная на каждой итерации** — замыкания в `for` безопасны (не как JS `var`).
4. **`break` / `continue`** — управление потоком. С метками — для вложенных циклов.
5. **Не модифицируйте коллекцию** при `for-in` — `ConcurrentModificationError`.
6. **`forEach` не поддерживает** `break`, `continue`, `await` — используйте `for-in`.
7. **Collection for** — `[for (var x in iter) expr]` — генерация прямо в литерале.

---

> **Назад:** [5.2 switch и сопоставление](05_02_switch_patterns.md) · **Далее:** [5.4 assert](05_04_assert.md)
