# 4.4 Методы коллекций

## 1. Формальное определение

**Методы коллекций** — набор методов высшего порядка (higher-order methods), определённых на `Iterable<E>` и наследуемых `List`, `Set` и значениями/ключами `Map`. Они принимают функции как аргументы и позволяют трансформировать, фильтровать, агрегировать и проверять коллекции в декларативном стиле.

Ключевые методы: `map`, `where`, `fold`, `reduce`, `any`, `every`, `expand`, `take`, `skip`, `firstWhere`, `singleWhere`, `toList`, `toSet`.

## 2. Зачем это нужно

- **Декларативный код** — описываем _что_ делать, а не _как_. Код читается как спецификация.
- **Цепочки (chaining)** — комбинирование операций: `list.where(...).map(...).toList()`.
- **Ленивые вычисления** — `map`, `where` возвращают ленивые `Iterable`, не создавая промежуточные коллекции.
- **Функциональный стиль** — без мутации, предсказуемо, легко тестируется.
- **Flutter** — построение виджетов из данных: `items.map((e) => ListTile(...)).toList()`.

## 3. Как это работает

### Трансформация

```dart
void main() {
  var numbers = [1, 2, 3, 4, 5];

  // map — преобразовать каждый элемент
  var doubled = numbers.map((n) => n * 2); // Lazy Iterable
  print(doubled.toList()); // [2, 4, 6, 8, 10]

  // expand — один-ко-многим (flatMap)
  var nested = [[1, 2], [3, 4], [5]];
  var flat = nested.expand((list) => list);
  print(flat.toList()); // [1, 2, 3, 4, 5]

  // cast — приведение типов
  List<num> nums = [1, 2.0, 3];
  var ints = nums.cast<int>(); // Ленивый каст (опасно!)
}
```

### Фильтрация

```dart
void main() {
  var numbers = [1, 2, 3, 4, 5, 6, 7, 8];

  // where — фильтр по условию
  var even = numbers.where((n) => n.isEven);
  print(even.toList()); // [2, 4, 6, 8]

  // whereType — фильтр по типу
  var mixed = [1, 'two', 3, 'four', 5];
  var strings = mixed.whereType<String>();
  print(strings.toList()); // [two, four]

  // take / skip — первые N / пропустить N
  print(numbers.take(3).toList());  // [1, 2, 3]
  print(numbers.skip(5).toList());  // [6, 7, 8]

  // takeWhile / skipWhile — до условия
  print(numbers.takeWhile((n) => n < 4).toList()); // [1, 2, 3]
  print(numbers.skipWhile((n) => n < 4).toList()); // [4, 5, 6, 7, 8]
}
```

### Агрегация

```dart
void main() {
  var numbers = [1, 2, 3, 4, 5];

  // reduce — свёртка без начального значения
  var sum = numbers.reduce((a, b) => a + b); // 15
  var max = numbers.reduce((a, b) => a > b ? a : b); // 5

  // fold — свёртка с начальным значением (может менять тип)
  var sumStr = numbers.fold<String>(
    '',
    (prev, n) => prev.isEmpty ? '$n' : '$prev+$n',
  ); // '1+2+3+4+5'

  var product = numbers.fold<int>(1, (prev, n) => prev * n); // 120

  // join — объединить в строку
  print(numbers.join(', ')); // '1, 2, 3, 4, 5'
}
```

### Поиск

```dart
void main() {
  var names = ['Алиса', 'Борис', 'Вера', 'Галина'];

  // firstWhere — первый по условию
  var b = names.firstWhere((n) => n.startsWith('Б')); // Борис
  var z = names.firstWhere(
    (n) => n.startsWith('З'),
    orElse: () => 'Не найден',
  );

  // lastWhere — последний по условию
  var lastA = names.lastWhere((n) => n.contains('а')); // Галина

  // singleWhere — ровно один элемент (иначе StateError)
  var single = names.singleWhere((n) => n == 'Вера');

  // indexOf / indexWhere (только List)
  var list = [10, 20, 30, 40];
  print(list.indexWhere((e) => e > 25)); // 2
}
```

### Проверки

```dart
void main() {
  var numbers = [2, 4, 6, 8];

  print(numbers.any((n) => n > 7));    // true — хотя бы один
  print(numbers.every((n) => n.isEven)); // true — все
  print(numbers.contains(4));          // true
  print(numbers.isEmpty);             // false
  print(numbers.isNotEmpty);          // true
}
```

### Методы Map

```dart
void main() {
  var scores = {'Алиса': 95, 'Борис': 87, 'Вера': 92};

  // forEach
  scores.forEach((name, score) => print('$name: $score'));

  // map — трансформация в новый Map
  var grades = scores.map((name, score) =>
      MapEntry(name, score >= 90 ? 'A' : 'B'));
  print(grades); // {Алиса: A, Борис: B, Вера: A}

  // entries — как Iterable<MapEntry>
  var top = scores.entries
      .where((e) => e.value >= 90)
      .map((e) => e.key)
      .toList();
  print(top); // [Алиса, Вера]

  // keys / values
  print(scores.keys.toList());   // [Алиса, Борис, Вера]
  print(scores.values.reduce((a, b) => a + b)); // 274
}
```

## 4. Минимальный пример

```dart
void main() {
  var prices = [120.0, 45.5, 200.0, 89.9, 15.0];

  var expensive = prices
      .where((p) => p > 50)
      .map((p) => p * 1.2) // +20% наценка
      .toList();

  print(expensive); // [144.0, 240.0, 107.88]
  print('Итого: ${expensive.fold<double>(0, (s, p) => s + p)}');
}
```

## 5. Практический пример

### Аналитика продаж

```dart
class Sale {
  final String product;
  final String category;
  final double amount;
  final DateTime date;

  Sale(this.product, this.category, this.amount, this.date);
}

class SalesAnalytics {
  final List<Sale> sales;

  SalesAnalytics(this.sales);

  /// Топ-N продуктов по выручке
  List<MapEntry<String, double>> topProducts(int n) {
    final totals = <String, double>{};
    for (final sale in sales) {
      totals.update(sale.product, (v) => v + sale.amount,
          ifAbsent: () => sale.amount);
    }
    return totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..length = n.clamp(0, totals.length);
  }

  /// Выручка по категориям
  Map<String, double> revenueByCategory() {
    final result = <String, double>{};
    for (final sale in sales) {
      result.update(sale.category, (v) => v + sale.amount,
          ifAbsent: () => sale.amount);
    }
    return result;
  }

  /// Средний чек
  double get averageAmount =>
      sales.isEmpty ? 0 : sales.map((s) => s.amount).reduce((a, b) => a + b) / sales.length;

  /// Все уникальные категории
  Set<String> get categories => sales.map((s) => s.category).toSet();

  /// Продажи за период
  List<Sale> salesBetween(DateTime from, DateTime to) =>
      sales.where((s) => s.date.isAfter(from) && s.date.isBefore(to)).toList();
}

void main() {
  final sales = [
    Sale('Ноутбук', 'Электроника', 75000, DateTime(2024, 1, 15)),
    Sale('Телефон', 'Электроника', 45000, DateTime(2024, 1, 20)),
    Sale('Книга', 'Книги', 800, DateTime(2024, 2, 1)),
    Sale('Наушники', 'Электроника', 5000, DateTime(2024, 2, 5)),
    Sale('Книга', 'Книги', 1200, DateTime(2024, 2, 10)),
  ];

  final analytics = SalesAnalytics(sales);

  print('Средний чек: ${analytics.averageAmount}');
  print('Категории: ${analytics.categories}');
  print('Топ-2 продукта:');
  for (final entry in analytics.topProducts(2)) {
    print('  ${entry.key}: ${entry.value}');
  }
  print('Выручка по категориям: ${analytics.revenueByCategory()}');
}
```

## 6. Что происходит под капотом

### Ленивые vs жадные (lazy vs eager)

```
Ленивые (возвращают Iterable):      Жадные (выполняются сразу):
  map()                               toList()
  where()                             toSet()
  expand()                            fold()
  take() / skip()                     reduce()
  takeWhile() / skipWhile()           forEach()
  whereType()                         any() / every()
  cast()                              join()
                                      first / last / single
                                      length (на lazy — итерирует!)
```

### Пример ленивости

```dart
var result = [1, 2, 3, 4, 5]
    .map((n) {
      print('map: $n');    // НЕ вызывается сразу!
      return n * 2;
    })
    .where((n) {
      print('where: $n');  // НЕ вызывается сразу!
      return n > 4;
    });

// Ничего не напечатано!

// Только при материализации:
print(result.toList()); // Теперь все print сработают:
// map: 1, where: 2
// map: 2, where: 4
// map: 3, where: 6
// map: 4, where: 8
// map: 5, where: 10
// [6, 8, 10]
```

Элементы обрабатываются **по одному** через всю цепочку, а не все сразу через каждый шаг.

### Внутренняя реализация

```dart
// Упрощённо map() внутри:
class MappedIterable<S, T> extends Iterable<T> {
  final Iterable<S> _source;
  final T Function(S) _transform;

  MappedIterable(this._source, this._transform);

  @override
  Iterator<T> get iterator =>
      MappedIterator(_source.iterator, _transform);
}

// Каждый вызов .iterator создаёт НОВЫЙ итератор!
// Поэтому ленивые Iterable можно итерировать повторно.
```

## 7. Производительность и ресурсы

| Метод               | Сложность     | Lazy? | Аллокация    |
| ------------------- | ------------- | ----- | ------------ |
| `map()`             | O(1) создание | ✅    | Обёртка      |
| `where()`           | O(1) создание | ✅    | Обёртка      |
| `toList()`          | O(n)          | ❌    | Новый List   |
| `toSet()`           | O(n)          | ❌    | Новый Set    |
| `fold()`            | O(n)          | ❌    | Нет          |
| `reduce()`          | O(n)          | ❌    | Нет          |
| `any()` / `every()` | O(n) worst    | ❌    | Нет          |
| `firstWhere()`      | O(n) worst    | ❌    | Нет          |
| `expand()`          | O(1) создание | ✅    | Обёртка      |
| `join()`            | O(n)          | ❌    | StringBuffer |

**Рекомендации:**

- Цепочка ленивых операций (`map().where()`) — 0 промежуточных аллокаций.
- `toList()` в конце — одна аллокация.
- Не вызывайте `.length` на ленивом Iterable в цикле — это O(n) каждый раз.

## 8. Частые ошибки и антипаттерны

### ❌ Повторная материализация ленивого Iterable

```dart
var lazy = numbers.where((n) => n > 0).map((n) => expensiveCalc(n));

// Плохо: каждый вызов re-итерирует!
print(lazy.length); // O(n) + вычисления
print(lazy.first);  // Ещё раз!

// Хорошо: материализовать один раз
var result = lazy.toList();
print(result.length); // O(1)
print(result.first);  // O(1)
```

### ❌ reduce на пустом списке

```dart
var empty = <int>[];
// empty.reduce((a, b) => a + b); // StateError!

// Хорошо: fold с начальным значением
var sum = empty.fold<int>(0, (a, b) => a + b); // 0
```

### ❌ forEach вместо for-in для побочных эффектов

```dart
// forEach не поддерживает break, continue, return, async/await
items.forEach((item) {
  // await something; // Ошибка! forEach не async
  // if (cond) break; // Ошибка! Нет break
});

// Хорошо: for-in
for (final item in items) {
  await something;
  if (cond) break;
}
```

### ❌ map() только ради побочного эффекта

```dart
// Плохо: map ленивый — может не выполниться!
items.map((item) => print(item)); // Ничего не происходит!

// Хорошо:
for (final item in items) {
  print(item);
}
```

## 9. Сравнение с альтернативами

| Метод     | Dart                  | Java Stream                   | JS Array               | Python                 |
| --------- | --------------------- | ----------------------------- | ---------------------- | ---------------------- |
| Transform | `.map()`              | `.map()`                      | `.map()`               | `map()` / list comp    |
| Filter    | `.where()`            | `.filter()`                   | `.filter()`            | `filter()` / list comp |
| FlatMap   | `.expand()`           | `.flatMap()`                  | `.flatMap()`           | nested comp            |
| Reduce    | `.reduce()`           | `.reduce()`                   | `.reduce()`            | `reduce()`             |
| Fold      | `.fold()`             | `.reduce(id, ...)`            | `.reduce()`            | `reduce()`             |
| Any/All   | `.any()` / `.every()` | `.anyMatch()` / `.allMatch()` | `.some()` / `.every()` | `any()` / `all()`      |
| Lazy      | ✅                    | ✅                            | ❌                     | ✅ (генераторы)        |

Dart и Java Stream — ленивые. JS Array методы — жадные (каждый создаёт новый массив).

## 10. Когда НЕ стоит использовать

- **Сложная логика с состоянием** — если преобразование требует мутабельного состояния между элементами, обычный `for` читабельнее.
- **Единственная простая операция** — `for (final item in list) print(item)` лучше, чем `list.forEach(print)`.
- **Нужен index** — `map` не даёт индексов. Используйте `list.asMap().entries.map((e) => ...)` или `for (var i = 0; ...; i++)`.
- **async внутри** — `forEach` не работает с async. Используйте `for-in` + `await`.

## 11. Краткое резюме

1. **`map`, `where`** — ленивые, возвращают `Iterable`. Нужен `toList()` для материализации.
2. **`fold` > `reduce`** — fold безопасен на пустых коллекциях и может менять тип.
3. **Цепочки** `where(...).map(...).toList()` — только одна аллокация (на `toList()`).
4. **`expand`** — flatMap. Разворачивает вложенные коллекции.
5. **`any` / `every`** — short-circuit проверки. Останавливаются на первом результате.
6. **Не вызывайте `.length` на lazy Iterable** — это O(n) каждый раз.
7. **`forEach` не поддерживает break/await** — используйте `for-in`.

---

> **Назад:** [4.3 Map — карты](04_03_map.md) · **Далее:** [4.5 Литералы с условиями и spread](04_05_spread_conditional.md)
