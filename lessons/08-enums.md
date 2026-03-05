# Урок 8. Перечисления

> Охватывает подтемы: 8.1 Базовые enum, 8.2 Enhanced enums (Dart 2.17+)

---

## 1. Формальное определение

`enum` в Dart — **именованный тип с фиксированным набором значений**. Dart поддерживает два вида:

- **Базовый enum** (Dart 2): набор константных значений без данных
- **Enhanced enum** (Dart 2.17+): значения с полями, конструкторами, методами, `implements`/`with`

Все enum в Dart автоматически:
- Наследуют от `Enum` (абстрактный класс)
- Имеют `name: String` (имя значения)
- Имеют `index: int` (порядковый индекс, начиная с 0)
- Имеют статическое поле `values: List<EnumType>`

Уровень: **система типов, синтаксис, объектная модель**.

---

## 2. Зачем это нужно

- **Типобезопасный набор значений**: нельзя передать произвольную строку где ожидается `Status`
- **Exhaustiveness в switch**: компилятор проверяет полноту охвата всех вариантов
- **Enhanced enums** устраняют паттерн «класс-константа» (замена static const объектов)
- **implements в enum** позволяет использовать enum как реализацию интерфейса

---

## 3. Базовый enum

```dart
enum Direction { north, south, east, west }

enum HttpStatus {
  ok,
  created,
  badRequest,
  unauthorized,
  notFound,
  internalServerError,
}

void main() {
  Direction dir = Direction.north;
  
  // Свойства
  print(dir.name);    // 'north'
  print(dir.index);   // 0
  
  // Все значения
  print(Direction.values); // [Direction.north, Direction.south, ...]
  
  // Сравнение — через == (не по индексу!)
  print(dir == Direction.north); // true
  
  // switch с exhaustiveness check
  String label = switch (dir) {
    Direction.north => 'Север',
    Direction.south => 'Юг',
    Direction.east => 'Восток',
    Direction.west => 'Запад',
    // Нет default — компилятор проверяет полноту
  };
  print(label); // 'Север'
  
  // Парсинг из строки
  Direction parsed = Direction.values.byName('south'); // Direction.south
  // Безопасный вариант (не бросает если не найдено):
  Direction? safe = Direction.values
      .cast<Direction?>()
      .firstWhere((d) => d?.name == 'invalid', orElse: () => null);
}
```

---

## 4. Enhanced enums (Dart 2.17+)

Enhanced enum могут иметь:
- Поля (обязательно `final`)
- Конструкторы (обязательно `const`)
- Методы и геттеры
- `implements`, `with` (mixin)

```dart
enum Planet {
  mercury(3.303e+23, 2.4397e6),
  venus(4.869e+24, 6.0518e6),
  earth(5.976e+24, 6.37814e6),
  mars(6.421e+23, 3.3972e6);

  // Поля — всегда final
  final double mass;    // kg
  final double radius;  // m

  // Конструктор — всегда const
  const Planet(this.mass, this.radius);

  // Константы
  static const double G = 6.67430e-11;

  // Вычисляемые геттеры
  double get surfaceGravity => G * mass / (radius * radius);

  double surfaceWeight(double otherMass) => otherMass * surfaceGravity;
}

void main() {
  const earthWeight = 75.0;
  const mass = earthWeight / Planet.earth.surfaceGravity;

  for (final planet in Planet.values) {
    print('${planet.name}: ${planet.surfaceWeight(mass).toStringAsFixed(2)} N');
  }
}
```

### Enhanced enum с implements

```dart
// Интерфейс
abstract interface class Serializable {
  Map<String, dynamic> toJson();
}

enum UserRole implements Serializable {
  guest(permissions: {'read'}),
  user(permissions: {'read', 'write'}),
  admin(permissions: {'read', 'write', 'delete', 'manage'});

  final Set<String> permissions;

  const UserRole({required this.permissions});

  bool can(String action) => permissions.contains(action);

  @override  // Реализуем интерфейс
  Map<String, dynamic> toJson() => {
    'role': name,
    'permissions': permissions.toList(),
  };
}

void main() {
  final role = UserRole.admin;
  
  print(role.can('delete')); // true
  print(UserRole.guest.can('write')); // false
  
  Serializable s = role; // enum как интерфейс
  print(s.toJson()); // {role: admin, permissions: [...]}
  
  // switch с exhaustiveness
  String access = switch (role) {
    UserRole.guest => 'Read-only',
    UserRole.user => 'Standard',
    UserRole.admin => 'Full access',
  };
}
```

### Enhanced enum с mixin

```dart
mixin Describable {
  String get description;
  void describe() => print(description);
}

enum Season with Describable {
  spring(months: 'Mar-May'),
  summer(months: 'Jun-Aug'),
  autumn(months: 'Sep-Nov'),
  winter(months: 'Dec-Feb');

  final String months;
  const Season({required this.months});

  @override
  String get description => '${name[0].toUpperCase()}${name.substring(1)} ($months)';
}

void main() {
  Season.summer.describe(); // Summer (Jun-Aug)
}
```

---

## 5. Минимальный пример

```dart
// Паттерн: enum + extension для добавления методов без enhanced enum
enum Color { red, green, blue, yellow }

extension ColorUtils on Color {
  int get hexValue => switch (this) {
    Color.red => 0xFF0000,
    Color.green => 0x00FF00,
    Color.blue => 0x0000FF,
    Color.yellow => 0xFFFF00,
  };

  Color get complement => switch (this) {
    Color.red => Color.green,
    Color.green => Color.red,
    Color.blue => Color.yellow,
    Color.yellow => Color.blue,
  };
}

void main() {
  print(Color.red.hexValue.toRadixString(16));  // ff0000
  print(Color.red.complement);                  // Color.green
  
  // Enhanced enum для доменных объектов
  print(UserRole.admin.toJson());
  
  // Итерация
  for (final color in Color.values) {
    print('${color.name}: #${color.hexValue.toRadixString(16).padLeft(6, '0')}');
  }
}
```

---

## 6. Практический пример

Состояния сети в приложении:

```dart
import 'dart:convert';

enum NetworkState<T> implements Comparable<NetworkState<dynamic>> {
  idle(order: 0),
  loading(order: 1),
  success(order: 2),
  failure(order: 3);

  final int order;
  const NetworkState({required this.order});

  bool get isTerminal => this == success || this == failure;
  bool get isActive => this == loading;

  @override
  int compareTo(NetworkState<dynamic> other) => order.compareTo(other.order);
}

// Класс для хранения данных состояния (enum только для состояний)
sealed class ApiResult<T> {
  const ApiResult();
}

class ApiSuccess<T> extends ApiResult<T> {
  final T data;
  const ApiSuccess(this.data);
}

class ApiFailure<T> extends ApiResult<T> {
  final String message;
  final int? statusCode;
  const ApiFailure(this.message, {this.statusCode});
}

class ApiLoading<T> extends ApiResult<T> {
  const ApiLoading();
}

// UI обработка с exhaustiveness
Widget buildResult<T>(ApiResult<T> result) => switch (result) {
  ApiLoading() => const CircularProgressIndicator(),
  ApiSuccess(data: final d) => DataWidget(data: d),
  ApiFailure(message: final msg, statusCode: final code) =>
    ErrorWidget(message: '$msg (${code ?? 'unknown'})'),
};
```

---

## 7. Что происходит под капотом

### Компиляция enum

Базовый enum компилируется в:
- **AOT**: константные объекты в глобальном константном пуле (аналог `const` objects)
- `values` — `const List` в статическом поле
- `index` — целочисленная константа

Enhanced enum — полноценные классы (финальные, не наследуемые), реализующие `Enum`.

```dart
// Примерный эквивалент компиляции Direction:
// class Direction implements Enum {
//   static const Direction north = Direction._(0, 'north');
//   static const Direction south = Direction._(1, 'south');
//   static const List<Direction> values = [north, south, ...];
//   final int index;
//   final String name;
//   const Direction._(this.index, this.name);
// }
```

### Exhaustiveness check

Компилятор знает исчерпывающий список значений enum → `switch` без `default` проверяется статически. Если добавить новое значение в enum — все `switch` без `default`/`_` выдадут ошибку компиляции.

---

## 8. Производительность и ресурсы

- Enum-значения — **compile-time constants** → нет аллокации при каждом обращении
- `switch (enumValue)` компилируется эффективно (jump table или inline checks)
- `byName` — O(N) поиск по имени; для частых операций создать `Map<String, MyEnum>`

```dart
// Быстрый lookup
final _byName = Map.fromEntries(
  Direction.values.map((d) => MapEntry(d.name, d))
);
Direction? fromName(String name) => _byName[name]; // O(1)
```

---

## 9. Частые ошибки

**1. Сравнение через `index` вместо `==`:**
```dart
// НЕВЕРНО — хрупко, ломается при переупорядочивании значений
if (status.index == 0) { ... }

// ВЕРНО
if (status == HttpStatus.ok) { ... }
```

**2. Мутируемые поля в enhanced enum:**
```dart
// ОШИБКА компиляции: поля enum должны быть final
enum Bad {
  a;
  int count = 0; // Non-final! Ошибка.
}
```

**3. Использование enum для открытого набора значений:**
```dart
// ПЛОХО: новый тип контента требует изменения enum и перекомпиляции
enum ContentType { text, image, video, audio }

// ЛУЧШЕ для открытых наборов: extension type или constants
```

**4. Забыть обновить switch при добавлении значения:**
```dart
// Именно для этого нужен exhaustive switch БЕЗ default:
// добавление нового값 → ошибка компиляции везде где не обработан
```

---

## 10. Сравнение с альтернативами

| Аспект | Dart | Java | Kotlin | TypeScript |
|---|---|---|---|---|
| Enum с полями | Enhanced enum | Java enum с полями | Sealed class | Const enum / union |
| Методы в enum | Да (enhanced) | Да | N/A | Нет |
| implements | Да | Нет (implements interface) | N/A | Нет |
| Exhaustiveness | Компилятор | Нет | Когда sealed | TS strict mode |
| Итерация | `.values` | `.values()` | `.entries` | N/A |

---

## 11. Когда НЕ стоит использовать enum

- **Открытые наборы**: если значения приходят из API и могут измениться — используйте `String` константы
- **Сложная иерархия с наследованием** — используйте `sealed class`
- **Значения с изменяемым состоянием** — enum всегда immutable; используйте класс
- **Больше ~20 значений** — enum с большим числом вариантов трудно поддерживать

---

## 12. Краткое резюме

1. **Базовый enum** — для фиксированных наборов без данных; `switch` без `default` = exhaustiveness check компилятором.
2. **Enhanced enum** (Dart 2.17+) — поля, методы, `implements` — заменяют паттерн «класс-константа».
3. **Поля enum — только `final`**, конструктор — только `const`; это гарантирует иммутабельность.
4. **`implements`/`with` в enum** — позволяет использовать enum как реализацию интерфейса или mixin.
5. **`values.byName(str)`** — O(N); для частых парсингов кэшировать в `Map`.
6. **Не сравнивать через `index`** — хрупко; всегда `==` с конкретным значением.
7. **Добавление нового значения enum** с exhaustive switch = ошибка компиляции везде где не обработан — это фича, не баг.
