# Урок 6. Управление потоком

> Охватывает подтемы: 6.1 if/else, 6.2 switch statements/expressions, 6.3 Паттерны (Dart 3), 6.4 if-case и guard clauses, 6.5 Циклы, 6.6 assert

---

## 1. Формальное определение

Управление потоком в Dart включает:

- **Условия**: `if`/`else`, тернарный оператор `? :`, `&&`/`||`-цепочки
- **switch statement** (Dart 2): императивное ветвление
- **switch expression** (Dart 3): значение-выражение с exhaustiveness check
- **Patterns** (Dart 3): сопоставление с образцом — деструктуризация, проверка типа и значения
- **if-case** (Dart 3): условие + паттерн за один шаг
- **Циклы**: `for`, `for-in`, `while`, `do-while`
- **assert**: проверки в debug-режиме

Уровень: **синтаксис, система типов (exhaustiveness), runtime**.

---

## 2. Зачем это нужно

- **switch expression** — замена цепочкам `if/else` при работе с enums, sealed classes; компилятор проверяет полноту охвата вариантов
- **Patterns** — устраняют `instanceof` + приведение типа в одну конструкцию; безопасная деструктуризация структур данных
- **if-case** — читаемая условная деструктуризация без вложенных `if`
- **assert** — документирование инвариантов без влияния на продакшн производительность

---

## 3. if/else и тернарный оператор

```dart
int score = 75;

// Классический if/else
if (score >= 90) {
  print('A');
} else if (score >= 75) {
  print('B');
} else {
  print('C');
}

// Тернарный оператор — для простых случаев
String grade = score >= 90 ? 'A' : score >= 75 ? 'B' : 'C';

// && и || как идиоматические условия (но не злоупотреблять)
// Только для простых случаев без side effects
String? name;
String display = name ?? 'Anonymous';   // null-коалесцинг
String? result = score > 50 ? grade : null; // может быть null

// Cascade нотация для условного вызова
final buffer = StringBuffer()
  ..write('Score: $score')
  ..writeIf(score > 80, ' (high)');  // не существует, просто пример
```

---

## 4. switch: statement и expression

### switch statement (Dart 2 стиль — всё ещё работает)

```dart
String day = 'Monday';

switch (day) {
  case 'Monday':
  case 'Tuesday':
    print('Early week');
    break;
  case 'Friday':
    print('TGIF');
    break;
  default:
    print('Other day');
}
```

### switch expression (Dart 3 — предпочтительно)

```dart
// switch expression возвращает значение
String dayType = switch (day) {
  'Saturday' || 'Sunday' => 'Weekend',  // OR pattern
  'Monday' || 'Friday' => 'Boundary',
  _ => 'Weekday',                        // wildcard
};

// Exhaustiveness check с enum
enum Status { pending, active, completed, cancelled }

Status status = Status.active;

// Компилятор ПРОВЕРЯЕТ что все варианты охвачены
String label = switch (status) {
  Status.pending => 'Ожидание',
  Status.active => 'Активен',
  Status.completed => 'Завершён',
  Status.cancelled => 'Отменён',
  // Убери один case — ошибка компиляции!
};

// switch с несколькими паттернами
int x = 15;
String description = switch (x) {
  < 0 => 'negative',
  0 => 'zero',
  > 0 && < 10 => 'small positive',
  >= 10 && < 100 => 'medium',  // x = 15 попадёт сюда
  _ => 'large',
};
```

---

## 5. Паттерны (Dart 3)

Паттерны — способ **сопоставить значение с образцом** и одновременно **деструктурировать** его. Работают в `switch`, `if-case`, и присваивании.

### Виды паттернов

```dart
// 1. Literal pattern — проверка конкретного значения
switch (42) {
  case 42: print('exactly 42');
}

// 2. Variable pattern — привязка к переменной
switch ('hello') {
  case String s: print('String: $s'); // s = 'hello'
}

// 3. Wildcard — игнорировать значение
switch ((1, 2, 3)) {
  case (_, int y, _): print('Middle: $y'); // y = 2
}

// 4. Logical OR/AND паттерны
switch (x) {
  case 1 || 2 || 3: print('one, two or three');
  case > 0 && < 100: print('positive double-digit');
}

// 5. Relational pattern
switch (score) {
  case >= 90: print('A');
  case >= 75: print('B');
  case >= 60: print('C');
  case _: print('F');
}

// 6. Type check pattern (как instanceof + cast)
Object value = 'hello world';
switch (value) {
  case String s when s.length > 5:      // type check + guard
    print('Long string: $s');
  case int n:
    print('Integer: $n');
  case _:
    print('Other: $value');
}

// 7. Record pattern — деструктуризация Record
(String, int) point = ('Alice', 30);
switch (point) {
  case (String name, int age) when age >= 18:
    print('Adult: $name');
  case (String name, _):
    print('Minor: $name');
}

// 8. List pattern
List<int> list = [1, 2, 3];
switch (list) {
  case [int first, ...List<int> rest]:
    print('First: $first, Rest: $rest');
  case []:
    print('Empty');
}

// 9. Map pattern
Map<String, dynamic> json = {'type': 'user', 'name': 'Alice', 'age': 30};
switch (json) {
  case {'type': 'user', 'name': String name, 'age': int age}:
    print('User $name, age $age');
  case {'type': 'admin', 'name': String name}:
    print('Admin $name');
}

// 10. Object pattern — деструктуризация объектов по геттерам
class Point {
  final double x, y;
  const Point(this.x, this.y);
}

var p = Point(1.0, 2.0);
switch (p) {
  case Point(x: var px, y: var py) when px == py:
    print('Diagonal point at $px');
  case Point(x: var px, y: var py):
    print('Point at ($px, $py)');
}
```

---

## 6. if-case и guard clauses

`if-case` — применение паттерна в условии `if` без полного `switch`:

```dart
Object response = fetchData();

// if-case — деструктурация + условие за один шаг
if (response case {'status': 200, 'data': Map<String, dynamic> data}) {
  print('Success: ${data['name']}');
} else {
  print('Error response');
}

// Null-pattern в if-case
String? maybeValue = computeValue();
if (maybeValue case final String value) {
  // value — String (non-nullable) внутри блока
  print(value.toUpperCase());
}

// Guard clause (when) в switch — дополнительное условие
List<int> nums = [1, 2, 3];
switch (nums) {
  case [int head, ...] when head > 0:
    print('Starts positive: $head');
  case [int head, ...]:
    print('Starts with: $head');
  case []:
    print('Empty');
}

// Деструктуризация в присваивании (не только switch/if-case)
var (a, b) = (1, 2);              // a=1, b=2
var [first, second, ...rest] = [1, 2, 3, 4, 5];
var (:name, :age) = (name: 'Alice', age: 30);

// Swap через Records
(a, b) = (b, a); // обмен без временной переменной
```

---

## 7. Минимальный пример

```dart
sealed class Shape {}
class Circle extends Shape {
  final double radius;
  const Circle(this.radius);
}
class Rectangle extends Shape {
  final double width, height;
  const Rectangle(this.width, this.height);
}
class Triangle extends Shape {
  final double base, height;
  const Triangle(this.base, this.height);
}

// switch expression + exhaustiveness (компилятор ГАРАНТИРУЕТ полноту)
double area(Shape shape) => switch (shape) {
  Circle(:final radius) => 3.14159 * radius * radius,
  Rectangle(:final width, :final height) => width * height,
  Triangle(:final base, :final height) => 0.5 * base * height,
  // Убери один case — ошибка компиляции! Добавь новый Shape — ошибка компиляции!
};

void main() {
  final shapes = [Circle(5), Rectangle(3, 4), Triangle(6, 8)];
  for (final s in shapes) {
    print('${s.runtimeType}: area = ${area(s).toStringAsFixed(2)}');
  }
}
```

---

## 8. Циклы

```dart
// for — классический
for (int i = 0; i < 5; i++) {
  if (i == 3) continue; // пропустить
  if (i == 4) break;    // прервать
  print(i); // 0, 1, 2
}

// for-in — итерация по Iterable
for (final item in ['a', 'b', 'c']) {
  print(item);
}

// С индексом — через indexed из dart:collection или вручную
final list = ['a', 'b', 'c'];
for (int i = 0; i < list.length; i++) {
  print('$i: ${list[i]}');
}
// Или через asMap
list.asMap().forEach((i, v) => print('$i: $v'));

// while — пока условие true
int n = 1;
while (n < 100) {
  n *= 2;
}

// do-while — хотя бы одно выполнение
do {
  print('at least once');
} while (false);

// Labeled break/continue — для вложенных циклов
outer:
for (int i = 0; i < 3; i++) {
  for (int j = 0; j < 3; j++) {
    if (i == 1 && j == 1) break outer; // Выйти из внешнего цикла
    print('$i,$j');
  }
}
```

---

## 9. assert

```dart
// assert(condition, [message]) — работает только в debug (dart run, тесты)
// В AOT-продакшне полностью убирается — ноль накладных расходов!

void processAge(int age) {
  assert(age >= 0, 'Age cannot be negative: $age');
  assert(age <= 150, 'Age $age seems unrealistic');
  // ...
}

// В конструкторах — проверка инвариантов
class Circle {
  final double radius;
  Circle(this.radius) : assert(radius > 0, 'Radius must be positive');
}

// Отключение в тестах: dart test --no-debug
// В Flutter: flutter run --release  — assert-ы убраны
```

---

## 10. Практический пример

Обработка событий пользовательского интерфейса:

```dart
sealed class AppEvent {}
class LoginEvent extends AppEvent {
  final String email, password;
  const LoginEvent(this.email, this.password);
}
class LogoutEvent extends AppEvent {}
class UpdateProfileEvent extends AppEvent {
  final Map<String, String> fields;
  const UpdateProfileEvent(this.fields);
}

// Exhaustive switch — добавление нового Event = ошибка компиляции
Future<void> handleEvent(AppEvent event) async => switch (event) {
  LoginEvent(:final email, :final password) when email.contains('@') =>
    _login(email, password),
  LoginEvent(:final email) =>
    throw FormatException('Invalid email: $email'),
  LogoutEvent() =>
    _logout(),
  UpdateProfileEvent(:final fields) when fields.isNotEmpty =>
    _updateProfile(fields),
  UpdateProfileEvent() =>
    print('Nothing to update'),
};

Future<void> _login(String email, String password) async {
  print('Logging in: $email');
}
Future<void> _logout() async => print('Logged out');
Future<void> _updateProfile(Map<String, String> fields) async {
  print('Updating: $fields');
}

void main() async {
  await handleEvent(const LoginEvent('user@example.com', 'pass123'));
  await handleEvent(const UpdateProfileEvent({'name': 'Alice'}));
  await handleEvent(const LogoutEvent());
}
```

---

## 11. Что происходит под капотом

### Exhaustiveness checking

Dart-анализатор выполняет статический анализ **coverage** для `switch`:
- Для `enum` — проверяет все значения
- Для `sealed class` — проверяет все прямые подклассы
- Для `bool` — должны быть `true` и `false`
- Для других типов — нужен `_` (wildcard) или `default`

Это compile-time, не runtime проверка.

### Pattern matching компиляция

Object pattern `Point(:final x, :final y)` компилируется в:
1. `is Point` type check
2. Вызов геттеров `x` и `y`
3. Привязка к переменным

Нет рефлексии — чистые вызовы геттеров с inline-оптимизацией в AOT.

### assert в AOT

AOT-компилятор полностью **удаляет** `assert` блоки — они не попадают в финальный бинарник. Это безопасная форма документирования предусловий без runtime стоимости.

---

## 12. Производительность и ресурсы

**switch expression** не быстрее `if-else` — это compile-time удобство, не jump table (в отличие от C/Java `switch int`). Dart switch компилируется в цепочку проверок.

**Pattern matching** — нет рефлексии. Type pattern компилируется в `is` check + cast, что оптимизируется в AOT.

---

## 13. Частые ошибки

**1. switch без default для не-sealed типов:**
```dart
// ПРЕДУПРЕЖДЕНИЕ: non-exhaustive switch (если String не sealed)
String s = getSomeString();
switch (s) { // нет default — warning
  case 'a': ...
}
// Всегда добавлять _ => ... для открытых типов
```

**2. Мутация переменной в if-case:**
```dart
// Переменная из паттерна — это новая переменная в scope if-блока
String? x = 'hello';
if (x case final String value) {
  // value — новая переменная, не x
  // Не путать с reassignment
}
```

---

## 14. Краткое резюме

1. **switch expression** (Dart 3) возвращает значение и проверяет exhaustiveness — предпочтительнее `if-else` цепочек для enum и sealed types.
2. **Паттерны** = type check + destructuring + binding за один шаг; устраняют verbose `instanceof`/`as` + отдельные переменные.
3. **Sealed classes + switch = алгебраические типы**: добавление нового подкласса без обновления всех switch — ошибка компиляции.
4. **if-case** — компактная альтернатива switch для одного паттерна с destructuring в условии.
5. **Guard clauses `when`** — дополнительное условие после паттерна; паттерн без `when` = только структурная проверка.
6. **assert** — zero-cost в продакшне; используйте для документирования предусловий и инвариантов.
7. **Labeled break/continue** — для выхода из вложенных циклов; не злоупотреблять (признак сложной логики).
