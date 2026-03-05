# Урок 5. Коллекции

> Охватывает подтемы: 5.1 List, 5.2 Set, 5.3 Map, 5.4 Методы высшего порядка, 5.5 Литералы с условиями и spread

---

## 1. Формальное определение

Dart предоставляет три встроенных коллекции:

| Тип | Описание | Упорядоченность | Дубликаты |
|---|---|---|---|
| `List<E>` | Индексируемая последовательность | Да | Да |
| `Set<E>` | Множество уникальных элементов | Нет (LinkedHashSet — да) | Нет |
| `Map<K, V>` | Ключ-значение | Нет (LinkedHashMap — да) | Ключи уникальны |

Все три — **параметризованные** (generic) типы. Реализации по умолчанию:
- `[]` → `GrowableList`
- `{}` с элементами без `:` → `LinkedHashSet` (insertion-ordered)
- `{}` с ключами `:` значение → `LinkedHashMap` (insertion-ordered)

Уровень: **коллекции, типизация, функциональное программирование**.

---

## 2. Зачем это нужно

- **List** — основа UI в Flutter: `ListView` строится из `List<Widget>`
- **Set** — быстрая проверка наличия элемента O(1), дедупликация
- **Map** — конфигурации, кэши, JSON-данные, HTTP-заголовки
- **Методы высшего порядка** (`map`, `where`, `fold`) — декларативная обработка данных без мутируемых циклов
- **Spread / if / for в литералах** — условное построение UI-деревьев во Flutter

---

## 3. Как это работает

### List

```dart
// Создание
List<int> numbers = [1, 2, 3, 4, 5];
var mixed = <Object>[1, 'two', 3.0];  // явный тип элемента
List<String> empty = [];              // пустой список
List<int> filled = List.filled(5, 0); // [0, 0, 0, 0, 0] — фиксированная длина!
List<int> generated = List.generate(5, (i) => i * i); // [0, 1, 4, 9, 16]

// Immutable
List<int> immutable = List.unmodifiable([1, 2, 3]); // бросает при попытке изменить
const List<int> compileTimeConst = [1, 2, 3];

// Основные операции
numbers.add(6);           // [1, 2, 3, 4, 5, 6]
numbers.addAll([7, 8]);   // добавить несколько
numbers.insert(0, 0);     // вставить по индексу
numbers.remove(4);        // удалить первое вхождение значения
numbers.removeAt(0);      // удалить по индексу
numbers.removeLast();     // удалить последний

// Доступ
print(numbers[0]);        // первый элемент
print(numbers.first);     // первый
print(numbers.last);      // последний
print(numbers.length);    // длина
print(numbers.isEmpty);   // проверка на пустоту
print(numbers.sublist(1, 3)); // подсписок [1..3)

// Сортировка
numbers.sort();                    // in-place сортировка
numbers.sort((a, b) => b - a);    // обратный порядок
final sorted = [...numbers]..sort(); // новый список — оригинал не изменяется
```

### Set

```dart
// Создание
Set<String> fruits = {'apple', 'banana', 'orange'};
Set<int> empty = <int>{};      // Нельзя просто {} — это Map!
Set<int> fromList = {1, 2, 3, 2, 1}; // {1, 2, 3} — дубликаты убраны

// Операции
fruits.add('grape');      // добавить
fruits.remove('banana');  // удалить
fruits.contains('apple'); // O(1) проверка

// Теоретико-множественные операции
Set<int> a = {1, 2, 3, 4};
Set<int> b = {3, 4, 5, 6};

print(a.union(b));        // {1, 2, 3, 4, 5, 6}
print(a.intersection(b)); // {3, 4}
print(a.difference(b));   // {1, 2}

// Конвертация
List<int> list = a.toList();
Set<int> back = list.toSet();
```

### Map

```dart
// Создание
Map<String, int> ages = {
  'Alice': 30,
  'Bob': 25,
  'Carol': 35,
};
Map<String, dynamic> config = {};  // пустой

// Доступ
print(ages['Alice']);      // 30
print(ages['Unknown']);    // null — нет KeyNotFoundException!
print(ages['Unknown'] ?? 0); // безопасный default

// Изменение
ages['Dave'] = 28;        // добавить или обновить
ages.putIfAbsent('Eve', () => 40); // добавить только если нет

// Проверка
ages.containsKey('Alice');   // true O(1)
ages.containsValue(30);      // true O(N)

// Удаление
ages.remove('Bob');

// Итерация
ages.forEach((name, age) => print('$name: $age'));
for (final entry in ages.entries) {
  print('${entry.key}: ${entry.value}');
}
print(ages.keys.toList());    // список ключей
print(ages.values.toList());  // список значений

// Трансформация
Map<String, int> doubled = ages.map((k, v) => MapEntry(k, v * 2));
```

---

## 4. Методы высшего порядка

Все коллекции наследуют от `Iterable<E>` — богатый функциональный API:

```dart
List<int> numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

// map — трансформация каждого элемента (ленивая!)
Iterable<int> squares = numbers.map((n) => n * n);
List<String> asStrings = numbers.map((n) => '$n').toList();

// where — фильтрация (ленивая!)
Iterable<int> evens = numbers.where((n) => n.isEven);
// [2, 4, 6, 8, 10]

// Цепочка — вычисляется только при materialization (toList, forEach, итерации)
List<int> result = numbers
    .where((n) => n.isOdd)       // [1, 3, 5, 7, 9]
    .map((n) => n * n)           // [1, 9, 25, 49, 81]
    .where((n) => n > 10)        // [25, 49, 81]
    .toList();                    // Materialization здесь

// reduce — агрегация (бросает если список пустой)
int sum = numbers.reduce((acc, n) => acc + n); // 55

// fold — агрегация с начальным значением (безопасно для пустых списков)
int sumFold = numbers.fold(0, (acc, n) => acc + n); // 55
int product = numbers.fold(1, (acc, n) => acc * n); // 3628800

// any / every — предикаты
print(numbers.any((n) => n > 8));   // true
print(numbers.every((n) => n > 0)); // true

// firstWhere / lastWhere
int firstEven = numbers.firstWhere((n) => n.isEven);         // 2
int? maybeEven = numbers.firstWhereOrNull((n) => n > 100);   // null (пакет collection)

// expand (flatMap)
List<List<int>> nested = [[1, 2], [3, 4], [5]];
List<int> flat = nested.expand((list) => list).toList(); // [1, 2, 3, 4, 5]

// take / skip
List<int> first3 = numbers.take(3).toList();  // [1, 2, 3]
List<int> after3 = numbers.skip(3).toList();  // [4, 5, 6, 7, 8, 9, 10]

// toSet — дедупликация
List<int> withDupes = [1, 2, 2, 3, 3, 3];
Set<int> unique = withDupes.toSet(); // {1, 2, 3}
```

---

## 5. Литералы с условиями и spread (Dart 2.3+)

Мощный синтаксис для построения коллекций **декларативно**:

```dart
bool isLoggedIn = true;
bool isAdmin = false;
List<String> extraItems = ['report', 'export'];

// if в литерале
List<String> menuItems = [
  'home',
  'profile',
  if (isLoggedIn) 'logout',    // добавить только если условие true
  if (!isLoggedIn) 'login',
  if (isAdmin) ...['users', 'settings'], // spread с условием
];

// for в литерале
List<int> squares = [for (int i = 1; i <= 5; i++) i * i]; // [1, 4, 9, 16, 25]

// spread (...)
List<int> a = [1, 2, 3];
List<int> b = [4, 5, 6];
List<int> combined = [...a, ...b];          // [1, 2, 3, 4, 5, 6]

List<int>? nullable;
List<int> safe = [...?nullable, 7, 8];  // [...?null] = [] — безопасно

// Применение во Flutter (псевдокод)
Widget buildAppBar(BuildContext context, bool hasSearch) {
  return AppBar(
    actions: [
      if (hasSearch) const SearchButton(),
      const NotificationsButton(),
      if (isLoggedIn) const ProfileButton(),
    ],
  );
}

// Map и Set тоже поддерживают
Map<String, String> headers = {
  'Content-Type': 'application/json',
  if (token != null) 'Authorization': 'Bearer $token',
  ...extraHeaders,
};
```

---

## 6. Минимальный пример

```dart
void main() {
  // Обработка данных декларативно
  final orders = [
    {'id': 1, 'total': 150.0, 'status': 'completed'},
    {'id': 2, 'total': 75.0,  'status': 'pending'},
    {'id': 3, 'total': 200.0, 'status': 'completed'},
    {'id': 4, 'total': 50.0,  'status': 'cancelled'},
  ];

  // Сумма только завершённых заказов
  final completedTotal = orders
      .where((o) => o['status'] == 'completed')
      .map((o) => o['total'] as double)
      .fold(0.0, (sum, total) => sum + total);

  print('Completed total: \$${completedTotal.toStringAsFixed(2)}'); // $350.00

  // Группировка по статусу
  final byStatus = <String, List<Map>>{}; 
  for (final order in orders) {
    final status = order['status'] as String;
    (byStatus[status] ??= []).add(order);
  }
  print(byStatus.keys.toList()); // [completed, pending, cancelled]
}
```

---

## 7. Практический пример

Сервис для работы с коллекцией пользователей:

```dart
class User {
  final int id;
  final String name;
  final String role;
  final double salary;
  const User(this.id, this.name, this.role, this.salary);
}

class UserRepository {
  final List<User> _users;
  const UserRepository(this._users);

  // Фильтрация
  Iterable<User> byRole(String role) =>
      _users.where((u) => u.role == role);

  // Агрегация
  double averageSalary() =>
      _users.isEmpty ? 0 : _users.map((u) => u.salary).reduce((a, b) => a + b) / _users.length;

  // Трансформация в Map для O(1) поиска
  Map<int, User> get byId =>
      Map.fromEntries(_users.map((u) => MapEntry(u.id, u)));

  // Уникальные роли
  Set<String> get roles => _users.map((u) => u.role).toSet();

  // Топ-N по зарплате
  List<User> topByPay(int n) =>
      ([..._users]..sort((a, b) => b.salary.compareTo(a.salary))).take(n).toList();
}

void main() {
  final repo = UserRepository([
    const User(1, 'Alice', 'dev', 120000),
    const User(2, 'Bob', 'qa', 90000),
    const User(3, 'Carol', 'dev', 130000),
    const User(4, 'Dave', 'manager', 150000),
  ]);

  print(repo.roles);           // {dev, qa, manager}
  print(repo.averageSalary()); // 122500.0
  print(repo.topByPay(2).map((u) => u.name).toList()); // [Dave, Carol]
  
  final devs = repo.byRole('dev').toList();
  print(devs.map((u) => u.name).toList()); // [Alice, Carol]
}
```

---

## 8. Что происходит под капотом

### Ленивость Iterable

`map`, `where`, `skip`, `take` возвращают **ленивые Iterable** — нет вычислений до материализации:

```dart
// Ленивый pipeline — вычисляется только элементы нужные для первого результата
var result = [1, 2, 3, 4, 5]
    .map((x) { print('map $x'); return x * 2; })
    .where((x) { print('where $x'); return x > 4; })
    .first; // Вычисляет до первого совпадения, НЕ весь список
```

### GrowableList — амортизированное добавление

`List.add()` аналогично ArrayDeque в Java — при переполнении capacity удваивается. Амортизированная стоимость O(1).

### LinkedHashMap — insertion order

По умолчанию `{}` создаёт `LinkedHashMap` — итерация в порядке вставки. В отличие от JavaScript до ES2015, это **гарантировано** спецификацией Dart.

---

## 9. Производительность и ресурсы

**Эффективно:**
- `Set.contains()` — O(1) по сравнению с `List.contains()` O(N)
- Ленивые `map`/`where` без `toList()` не аллоцируют промежуточные коллекции
- `Map.putIfAbsent` для мемоизации

**Узкие места:**
- `List.insert(0, ...)` — O(N) сдвиг всех элементов (используйте `Queue` из `dart:collection`)
- Многократный `.toList()` в середине цепочки — лишние аллокации
- `List.contains()` на больших списках — используйте `Set`

---

## 10. Частые ошибки и антипаттерны

**1. `<int>{}` vs `{}`:**
```dart
var emptySet = {};      // Map<dynamic, dynamic>! НЕ Set!
var emptySet2 = <int>{};  // Set<int> — правильно
Set<int> emptySet3 = {};  // Тоже правильно — тип выводится из аннотации
```

**2. Мутация во время итерации:**
```dart
var list = [1, 2, 3, 4, 5];
// ОШИБКА в runtime: Concurrent modification during iteration
for (var item in list) {
  if (item.isEven) list.remove(item);
}
// ВЕРНО — создать новый список
list = list.where((n) => n.isOdd).toList();
```

**3. `List.filled` с мутируемыми объектами:**
```dart
// ЛОВУШКА: все элементы — один и тот же объект!
var matrix = List.filled(3, <int>[]);
matrix[0].add(1); // Изменяет все строки матрицы!

// ВЕРНО
var matrix = List.generate(3, (_) => <int>[]);
```

**4. `reduce` на пустом списке:**
```dart
// Бросает исключение если список пуст
[].reduce((a, b) => a + b); // Bad state: No element

// Безопасно
[].fold(0, (a, b) => a + b); // 0
```

---

## 11. Сравнение с альтернативами

| Аспект | Dart | Java | Kotlin | TypeScript |
|---|---|---|---|---|
| Ленивые операции | `map`/`where` (Iterable) | Stream API | Sequences | Array методы (eager) |
| Spread | `[...list]` | `Stream.concat` | `listOf(*arr)` | `[...arr]` |
| Условный элемент | `if (cond) item` (в литерале) | Нет | Нет (через filter) | Нет (через filter) |
| Тип по умолчанию | LinkedHashMap/LinkedHashSet | HashMap | LinkedHashMap | Object/Map |
| Immutable | `List.unmodifiable`, `const` | `List.of`, `Collections.unmodifiable` | `listOf` (read-only view) | `readonly` |

---

## 12. Когда НЕ стоит использовать стандартные коллекции

- **Очередь FIFO** — `Queue` из `dart:collection` вместо `List` (O(1) removeFirst)
- **Двусвязный список** — `LinkedList` из `dart:collection`
- **Отсортированные данные** — `SplayTreeSet`/`SplayTreeMap` из `dart:collection`
- **Большой int-массив** — `Int32List`/`Uint8List` из `dart:typed_data` (нет boxing overhead)

---

## 13. Краткое резюме

1. **`List` — основа**, `Set` — для уникальности и быстрой проверки O(1), `Map` — для ключ-значение; знать разницу.
2. **`map`/`where`/`fold` — ленивые**, не вычисляют лишнего; `toList()` материализует.
3. **Spread `...` и `if`/`for` в литералах** — декларативное построение коллекций без мутации (ключевой паттерн Flutter).
4. **`<int>{}` — Set, `{}` — Map** — пустые литералы ведут себя по-разному.
5. **`List.filled()` с объектами — ловушка**: все элементы ссылаются на один объект; использовать `List.generate`.
6. **`reduce` бросает на пустом списке**: предпочитать `fold` с начальным значением.
7. **`dart:collection` для специализированных структур**: `Queue`, `LinkedList`, `SplayTree`, `Uint8List` (typed data).
