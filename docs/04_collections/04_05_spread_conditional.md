# 4.5 Литералы с условиями и spread

## 1. Формальное определение

**Collection if**, **collection for** и **spread-оператор** (`...` / `...?`) — синтаксические конструкции Dart 2.3+, позволяющие строить коллекции декларативно прямо внутри литералов `[]`, `{}` и `{k: v}`.

- **Spread** (`...`) — разворачивает элементы одной коллекции внутрь другой.
- **Null-aware spread** (`...?`) — то же, но безопасно пропускает `null`.
- **Collection if** (`if (cond) element`) — условное включение элемента.
- **Collection for** (`for (var x in iter) element`) — генерация элементов из итерации.

Все три конструкции работают на уровне компилятора и формируют коллекцию за один проход.

## 2. Зачем это нужно

- **Декларативное построение** — описание коллекции «как есть», без императивных `add()`.
- **Flutter** — основа построения виджет-деревьев: `Column(children: [if (show) Widget(), for (var item in items) ListTile(...)])`.
- **Конкатенация коллекций** — `[...a, ...b]` вместо `a + b` или `[...a]..addAll(b)`.
- **Условная логика** — включить элемент в коллекцию только при условии, без `if/add`.
- **const коллекции** — spread и collection if работают в `const` контексте.

## 3. Как это работает

### Spread-оператор

```dart
void main() {
  var first = [1, 2, 3];
  var second = [4, 5, 6];

  // Конкатенация списков
  var combined = [...first, ...second]; // [1, 2, 3, 4, 5, 6]

  // Вставка в середину
  var withMiddle = [0, ...first, 99, ...second, 100];
  // [0, 1, 2, 3, 99, 4, 5, 6, 100]

  // Копирование (shallow clone)
  var copy = [...first]; // Новый список с теми же элементами

  // Spread для Set
  var setA = {1, 2, 3};
  var setB = {3, 4, 5};
  var unionSet = {...setA, ...setB}; // {1, 2, 3, 4, 5}

  // Spread для Map
  var defaults = {'theme': 'light', 'lang': 'ru'};
  var overrides = {'lang': 'en', 'debug': 'true'};
  var config = {...defaults, ...overrides};
  // {theme: light, lang: en, debug: true} — overrides побеждают!
}
```

### Null-aware spread

```dart
void main() {
  List<int>? maybeNull;

  // ...maybeNull  → ошибка компиляции (null нельзя развернуть)
  var safe = [1, 2, ...?maybeNull, 3]; // [1, 2, 3]

  maybeNull = [10, 20];
  var withValues = [1, 2, ...?maybeNull, 3]; // [1, 2, 10, 20, 3]

  // Для Map
  Map<String, int>? extra;
  var map = {'a': 1, ...?extra}; // {a: 1}
}
```

### Collection if

```dart
void main() {
  var isAdmin = true;
  var isLoggedIn = true;

  // Простой if
  var menu = [
    'Главная',
    'Каталог',
    if (isLoggedIn) 'Профиль',
    if (isAdmin) 'Админка',
  ]; // [Главная, Каталог, Профиль, Админка]

  // if-else
  var greeting = [
    if (isLoggedIn) 'Добро пожаловать!' else 'Войдите в систему',
  ];

  // В Map
  var headers = <String, String>{
    'Content-Type': 'application/json',
    if (isLoggedIn) 'Authorization': 'Bearer token123',
  };

  // В Set
  var permissions = <String>{
    'read',
    if (isAdmin) 'write',
    if (isAdmin) 'delete',
  };
}
```

### Collection for

```dart
void main() {
  // Генерация из диапазона
  var squares = [
    for (var i = 1; i <= 5; i++) i * i,
  ]; // [1, 4, 9, 16, 25]

  // Из другого iterable
  var names = ['Алиса', 'Борис', 'Вера'];
  var greetings = [
    for (final name in names) 'Привет, $name!',
  ]; // [Привет, Алиса!, Привет, Борис!, Привет, Вера!]

  // Map из for
  var indexMap = {
    for (var i = 0; i < names.length; i++) i: names[i],
  }; // {0: Алиса, 1: Борис, 2: Вера}

  // Set из for
  var initials = {
    for (final name in names) name[0],
  }; // {А, Б, В}
}
```

### Комбинирование

```dart
void main() {
  var items = ['молоко', 'хлеб', 'сыр'];
  var extras = ['вода', 'сок'];
  var addExtras = true;

  var shoppingList = [
    'Список покупок:',
    for (var i = 0; i < items.length; i++)
      '${i + 1}. ${items[i]}',
    if (addExtras) ...[
      '---',
      for (final extra in extras) '+ $extra',
    ],
  ];

  // [Список покупок:, 1. молоко, 2. хлеб, 3. сыр, ---, + вода, + сок]
}
```

## 4. Минимальный пример

```dart
void main() {
  var showVip = true;
  var guests = ['Анна', 'Борис'];

  var list = [
    'Обычные гости:',
    ...guests,
    if (showVip) 'VIP: Директор',
    for (var i = 1; i <= 3; i++) 'Стол №$i',
  ];

  list.forEach(print);
}
```

## 5. Практический пример

### Построитель навигационного меню

```dart
enum UserRole { guest, user, editor, admin }

class MenuItem {
  final String label;
  final String route;
  final String? icon;

  MenuItem(this.label, this.route, {this.icon});

  @override
  String toString() => '${icon ?? '•'} $label → $route';
}

class MenuBuilder {
  static List<MenuItem> build({
    required UserRole role,
    List<MenuItem>? extraItems,
    bool showDevTools = false,
  }) {
    return [
      // Всегда видны
      MenuItem('Главная', '/', icon: '🏠'),
      MenuItem('О нас', '/about', icon: 'ℹ️'),

      // Только для залогиненных
      if (role != UserRole.guest) ...[
        MenuItem('Профиль', '/profile', icon: '👤'),
        MenuItem('Настройки', '/settings', icon: '⚙️'),
      ],

      // Редакторы и выше
      if (role == UserRole.editor || role == UserRole.admin)
        MenuItem('Редактор', '/editor', icon: '✏️'),

      // Только админы
      if (role == UserRole.admin) ...[
        MenuItem('Пользователи', '/admin/users', icon: '👥'),
        MenuItem('Логи', '/admin/logs', icon: '📋'),
      ],

      // Дополнительные пункты
      ...?extraItems,

      // Dev tools
      if (showDevTools)
        MenuItem('DevTools', '/dev', icon: '🔧'),
    ];
  }
}

void main() {
  var menu = MenuBuilder.build(
    role: UserRole.admin,
    extraItems: [MenuItem('Помощь', '/help', icon: '❓')],
    showDevTools: true,
  );

  for (final item in menu) {
    print(item);
  }
}
```

### Flutter-подобный пример (структура виджетов)

```dart
// Имитация Flutter API
class Widget {
  final String type;
  final List<Widget> children;
  Widget(this.type, {this.children = const []});
}

Widget buildPage({required bool isLoading, required List<String> items}) {
  return Widget('Column', children: [
    Widget('Header'),
    if (isLoading)
      Widget('CircularProgressIndicator')
    else ...[
      for (final item in items)
        Widget('ListTile($item)'),
      if (items.isEmpty)
        Widget('Text("Нет данных")'),
    ],
    Widget('Footer'),
  ]);
}
```

## 6. Что происходит под капотом

### Компиляция spread

```dart
// Исходный код:
var result = [1, ...other, 2];

// Компилятор генерирует (примерно):
var result = <int>[];
result.add(1);
result.addAll(other);
result.add(2);
```

### Компиляция collection if

```dart
// Исходный код:
var list = [1, if (cond) 2, 3];

// Компилятор генерирует:
var list = <int>[];
list.add(1);
if (cond) list.add(2);
list.add(3);
```

### Компиляция collection for

```dart
// Исходный код:
var list = [for (var i = 0; i < 3; i++) i * i];

// Компилятор генерирует:
var list = <int>[];
for (var i = 0; i < 3; i++) {
  list.add(i * i);
}
```

### const контекст

```dart
const a = [1, 2];
const b = [0, ...a, 3]; // [0, 1, 2, 3] — вычислено при компиляции!

const show = true;
const c = [if (show) 'yes']; // ['yes'] — const-вычисление!
```

В `const` контексте все значения, условия и spread-источники тоже должны быть `const`.

## 7. Производительность и ресурсы

| Операция                     | Сложность     | Комментарий                   |
| ---------------------------- | ------------- | ----------------------------- |
| `[...a, ...b]`               | O(n + m)      | n и m — длины a и b           |
| `[...?nullable]`             | O(n) или O(0) | Проверка null + копирование   |
| `[if (c) x]`                 | O(1)          | Одна проверка                 |
| `[for (var i in list) f(i)]` | O(n)          | n итераций                    |
| `{...mapA, ...mapB}`         | O(n + m)      | Поздний spread перезаписывает |
| `const [...a]`               | O(0) runtime  | Всё вычислено при компиляции  |

**Vs альтернативы:**

```dart
// Spread vs addAll — одинаковая производительность
var a = [...list1, ...list2];         // Spread
var b = [...list1]..addAll(list2);     // addAll
// Оба O(n + m), но spread читабельнее

// Spread vs оператор +
var c = list1 + list2;               // Тоже O(n + m), но + создаёт fixed-length List!
```

## 8. Частые ошибки и антипаттерны

### ❌ Spread null без `?`

```dart
List<int>? data;
// var list = [1, ...data]; // Ошибка компиляции!
var list = [1, ...?data];   // OK
```

### ❌ Забыть `...` перед if/for

```dart
var items = ['a', 'b', 'c'];
var extra = ['x', 'y'];

// Плохо: вложенный список!
var wrong = [
  ...items,
  if (true) extra, // → ['a', 'b', 'c', ['x', 'y']]  — List внутри List!
];

// Правильно: spread!
var right = [
  ...items,
  if (true) ...extra, // → ['a', 'b', 'c', 'x', 'y']
];
```

### ❌ Тяжёлые вычисления в collection for

```dart
// Плохо: O(n²) скрыто
var result = [
  for (final item in bigList)
    if (anotherBigList.contains(item)) item, // contains → O(m) на каждый!
];

// Лучше: Set для быстрого поиска
var lookupSet = anotherBigList.toSet();
var result = [
  for (final item in bigList)
    if (lookupSet.contains(item)) item, // O(1)
];
```

### ❌ Мутация spread-источника

```dart
var source = [1, 2, 3];
var copy = [...source]; // Shallow copy!

// source и copy — независимы для примитивов.
// Но для объектов: ссылки общие!
var objects = [SomeObject()];
var copied = [...objects];
// copied[0] == objects[0] — тот же объект!
```

## 9. Сравнение с альтернативами

| Аспект            | Dart            | JavaScript | Python           | Kotlin        |
| ----------------- | --------------- | ---------- | ---------------- | ------------- |
| Spread List       | `[...a]`        | `[...a]`   | `[*a]`           | `listOf(*a)`  |
| Spread Map        | `{...m}`        | `{...m}`   | `{**m}`          | `mapOf() + m` |
| Null-aware spread | `...?`          | ❌         | ❌               | ❌            |
| Collection if     | `[if (c) x]`    | ❌         | `[x for ... if]` | ❌            |
| Collection for    | `[for (...) x]` | ❌         | `[x for ...]`    | ❌            |
| Const spread      | ✅              | ❌         | ❌               | ❌            |

Python имеет list comprehensions (`[x for x in ... if ...]`), но Dart позволяет `if` и `for` **внутри обычного литерала**, а не через отдельный синтаксис.

JavaScript не имеет collection if/for — используются `.filter().map()` или тернарный оператор.

## 10. Когда НЕ стоит использовать

- **Глубоко вложенные if/for** — если литерал занимает 20+ строк с тройной вложенностью, лучше построить коллекцию императивно с `add()`.
- **Побочные эффекты** — collection for не должен содержать побочных эффектов (print, mutation). Компилятор может их оптимизировать.
- **Нужна `break` / `continue`** — collection for не поддерживает их. Используйте обычный `for` + `add`.
- **Performance-critical tight loops** — для числовых вычислений `for` + `List.filled()` может быть быстрее (предвыделение памяти).

## 11. Краткое резюме

1. **`[...a, ...b]`** — конкатенация коллекций. Для Map поздний spread перезаписывает.
2. **`...?`** — null-aware spread. Безопасно пропускает null-коллекции.
3. **`[if (cond) element]`** — условное включение. Поддерживает `if-else`.
4. **`[for (var x in iter) expr]`** — генерация элементов. Работает с C-style и for-in.
5. **Комбинируются** — `if (...) ...spread`, `for (...) if (...) element`.
6. **Работают в const** — все три конструкции допустимы в `const` коллекциях.
7. **Flutter** — основа декларативного построения виджет-деревьев.

---

> **Назад:** [4.4 Методы коллекций](04_04_collection_methods.md) · **Далее:** [5. Управление потоком](../05_control_flow/05_00_overview.md)
