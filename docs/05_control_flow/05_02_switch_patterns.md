# 5.2 switch и сопоставление с образцом

## 1. Формальное определение

**`switch`** — оператор множественного ветвления по значению выражения. В Dart 3 `switch` кардинально обновлён:

- **Switch statement** — классический оператор с `case`/`break`/`default`.
- **Switch expression** — выражение, возвращающее значение. Синтаксис: `switch (expr) { pattern => value, ... }`.
- **Pattern matching** — каждый `case` может содержать паттерн (тип, destructuring, guard `when`).
- **Exhaustiveness checking** — компилятор проверяет, что все варианты покрыты (для sealed classes, enum).

## 2. Зачем это нужно

- **Чистое множественное ветвление** — вместо цепочки `if/else if`.
- **Pattern matching** — деструктурирует значения, проверяет типы и извлекает поля в одном выражении.
- **Exhaustive** — компилятор гарантирует обработку всех случаев (для enum и sealed).
- **Switch expression** — компактная запись для маппинга значений.
- **Flutter** — часто используется: состояния (loading/error/data), маршрутизация, обработка событий.

## 3. Как это работает

### Классический switch statement

```dart
void main() {
  var command = 'open';

  switch (command) {
    case 'open':
      print('Открываем');
      break;
    case 'close':
      print('Закрываем');
      break;
    case 'save':
    case 'export':
      // Объединение case (fall-through без тела)
      print('Сохраняем');
      break;
    default:
      print('Неизвестная команда');
  }
}
```

### Switch expression (Dart 3)

```dart
void main() {
  var status = 200;

  // Switch как выражение — возвращает значение!
  var message = switch (status) {
    200 => 'OK',
    301 => 'Moved Permanently',
    404 => 'Not Found',
    500 => 'Internal Server Error',
    _ => 'Unknown status: $status', // wildcard — аналог default
  };

  print(message); // OK
}
```

### Pattern matching

```dart
void main() {
  Object value = [1, 2, 3];

  switch (value) {
    case int n:
      print('Целое число: $n');
    case String s:
      print('Строка: $s');
    case [int a, int b]:
      print('Пара: $a, $b');
    case [int first, ..., int last]:
      print('Список от $first до $last');
    case {'name': String name}:
      print('Объект с именем: $name');
    default:
      print('Что-то другое');
  }
}
```

### Guard-выражения (when)

```dart
void main() {
  var point = (x: 3, y: 4);

  var quadrant = switch (point) {
    (x: var x, y: var y) when x > 0 && y > 0 => 'I',
    (x: var x, y: var y) when x < 0 && y > 0 => 'II',
    (x: var x, y: var y) when x < 0 && y < 0 => 'III',
    (x: var x, y: var y) when x > 0 && y < 0 => 'IV',
    _ => 'На оси',
  };

  print('Квадрант: $quadrant'); // I
}
```

### Exhaustiveness с enum

```dart
enum TrafficLight { red, yellow, green }

String action(TrafficLight light) {
  // Компилятор проверяет: все варианты покрыты!
  return switch (light) {
    TrafficLight.red => 'Стой',
    TrafficLight.yellow => 'Внимание',
    TrafficLight.green => 'Иди',
    // Без wildcard — компилятор знает, что enum полностью покрыт
  };
}
```

### Exhaustiveness с sealed class

```dart
sealed class Shape {}

class Circle extends Shape {
  final double radius;
  Circle(this.radius);
}

class Rectangle extends Shape {
  final double width, height;
  Rectangle(this.width, this.height);
}

class Triangle extends Shape {
  final double base, height;
  Triangle(this.base, this.height);
}

double area(Shape shape) {
  return switch (shape) {
    Circle(radius: var r) => 3.14159 * r * r,
    Rectangle(width: var w, height: var h) => w * h,
    Triangle(base: var b, height: var h) => 0.5 * b * h,
    // Если добавить новый подкласс Shape — ошибка компиляции!
  };
}
```

### Логические паттерны (Dart 3)

```dart
void main() {
  var code = 404;

  var kind = switch (code) {
    >= 200 && < 300 => 'Успех',
    >= 300 && < 400 => 'Редирект',
    >= 400 && < 500 => 'Ошибка клиента',
    >= 500 && < 600 => 'Ошибка сервера',
    _ => 'Неизвестно',
  };

  print(kind); // Ошибка клиента
}
```

## 4. Минимальный пример

```dart
enum Season { spring, summer, autumn, winter }

void main() {
  var season = Season.autumn;

  var emoji = switch (season) {
    Season.spring => '🌸',
    Season.summer => '☀️',
    Season.autumn => '🍂',
    Season.winter => '❄️',
  };

  print('Сезон: $emoji');
}
```

## 5. Практический пример

### Парсер JSON-ответа API

```dart
sealed class ApiResponse {}

class Success extends ApiResponse {
  final Map<String, dynamic> data;
  Success(this.data);
}

class ApiError extends ApiResponse {
  final int code;
  final String message;
  ApiError(this.code, this.message);
}

class Loading extends ApiResponse {}

class Unauthorized extends ApiResponse {}

class UiState {
  final String title;
  final String body;
  final bool showRetry;

  UiState({required this.title, required this.body, this.showRetry = false});

  @override
  String toString() => '[$title] $body (retry: $showRetry)';
}

UiState mapToUi(ApiResponse response) {
  return switch (response) {
    Success(data: {'users': List users}) => UiState(
        title: 'Пользователи',
        body: 'Найдено: ${users.length}',
      ),
    Success(data: var data) => UiState(
        title: 'Данные',
        body: 'Ключей: ${data.length}',
      ),
    ApiError(code: 404, message: var msg) => UiState(
        title: 'Не найдено',
        body: msg,
      ),
    ApiError(code: >= 500, message: var msg) => UiState(
        title: 'Ошибка сервера',
        body: msg,
        showRetry: true,
      ),
    ApiError(code: var c, message: var msg) => UiState(
        title: 'Ошибка $c',
        body: msg,
      ),
    Loading() => UiState(
        title: 'Загрузка',
        body: 'Пожалуйста, подождите...',
      ),
    Unauthorized() => UiState(
        title: 'Авторизация',
        body: 'Войдите в систему',
      ),
  };
}

void main() {
  var responses = <ApiResponse>[
    Success({'users': ['Алиса', 'Борис']}),
    ApiError(404, 'Страница не найдена'),
    ApiError(503, 'Сервис недоступен'),
    Loading(),
    Unauthorized(),
  ];

  for (final response in responses) {
    print(mapToUi(response));
  }
}
```

## 6. Что происходит под капотом

### Switch statement — jump table

```
switch (x) {        // x — int или String
  case 0: ...
  case 1: ...
  case 2: ...
}

Для последовательных int-значений компилятор создаёт jump table:
  JumpTable[x]:
    0 → addr_case_0
    1 → addr_case_1
    2 → addr_case_2
  → O(1) переход вместо O(n) сравнений!

Для String — хеш + сравнение.
```

### Switch expression — вычисление

```dart
var x = switch (val) {
  pattern1 => expr1,
  pattern2 => expr2,
  _ => defaultExpr,
};

// Компилируется как цепочка if-else:
TEMP result;
if (val matches pattern1) {
  result = expr1;
} else if (val matches pattern2) {
  result = expr2;
} else {
  result = defaultExpr;
}
x = result;
```

### Exhaustiveness checking

```
sealed class A {}
class B extends A {}
class C extends A {}

switch (a) {
  B() => ...,
  C() => ...,
}

Компилятор (CFE) строит дерево подтипов:
  A → {B, C}
  Покрыты: {B, C}
  Непокрытые: ∅ → OK!

Если добавить class D extends A {} → ошибка:
  Непокрытые: {D} → compile error!
```

## 7. Производительность и ресурсы

| Конструкция                | Сложность                         |
| -------------------------- | --------------------------------- |
| Switch (int, sequential)   | O(1) — jump table                 |
| Switch (String)            | O(1) avg — hash                   |
| Switch (enum)              | O(1) — index                      |
| Switch (patterns, N cases) | O(N) — sequential matching        |
| if-else chain (N)          | O(N)                              |
| Exhaustiveness check       | Compile-time only, 0 runtime cost |

**Switch expression vs тернарный:**

- 2 варианта — тернарный оператор компактнее.
- 3+ варианта — switch expression выигрывает в читаемости и поддержке.

## 8. Частые ошибки и антипаттерны

### ❌ Забытый break (до Dart 3)

```dart
// В Dart fall-through запрещён (если case имеет тело)!
switch (x) {
  case 1:
    print('один');
    // break; // В Dart 3 break не нужен — implicit break
  case 2:
    print('два');
}
```

### ❌ Отсутствие exhaustiveness

```dart
enum Color { red, green, blue }

// С wildcard — потеряете предупреждение при добавлении нового значения!
var name = switch (color) {
  Color.red => 'красный',
  Color.green => 'зелёный',
  _ => 'другой', // Если добавят Color.yellow — тут тихо подхватится
};

// Лучше: перечислить все варианты
var name = switch (color) {
  Color.red => 'красный',
  Color.green => 'зелёный',
  Color.blue => 'синий',
  // Добавление Color.yellow → ошибка компиляции!
};
```

### ❌ Сложная логика в switch expression

```dart
// Плохо: длинные тела
var result = switch (x) {
  0 => () {
    var a = compute();
    var b = transform(a);
    return format(b);
  }(),
  // ...
};

// Хорошо: вынести в функции
var result = switch (x) {
  0 => processZero(),
  1 => processOne(),
  _ => processDefault(x),
};
```

## 9. Сравнение с альтернативами

| Аспект        | Dart 3 switch    | Java switch     | JS switch    | Kotlin when   | Rust match |
| ------------- | ---------------- | --------------- | ------------ | ------------- | ---------- |
| Expression    | ✅               | ✅ (14+)        | ❌           | ✅            | ✅         |
| Patterns      | ✅               | ✅ (21+)        | ❌           | Destructuring | ✅         |
| Exhaustive    | ✅ (sealed/enum) | ✅ (sealed 17+) | ❌           | ✅            | ✅         |
| Guards (when) | ✅               | ✅              | ❌           | ✅            | ✅         |
| Fall-through  | Запрещён         | По умолчанию    | По умолчанию | ❌            | ❌         |
| Range         | `>= 0 && < 10`   | ❌              | ❌           | `in 0..9`     | `0..9`     |

Dart 3 switch — один из самых мощных среди mainstream-языков, сравнимый с Rust `match`.

## 10. Когда НЕ стоит использовать

- **Булев выбор** — `if/else` для `true/false` проще, чем `switch`.
- **Динамические условия** — switch patterns статичны. Для `value > computedThreshold()` — `if`.
- **2 варианта** — тернарный оператор компактнее switch expression.
- **Side-effect-heavy cases** — если каждый case содержит 10+ строк, используйте switch statement или выносите в функции.

## 11. Краткое резюме

1. **Switch expression** (`switch (x) { p => v }`) — возвращает значение. Предпочитайте для маппингов.
2. **Pattern matching** — `case Type(field: var x)` деструктурирует объекты.
3. **Exhaustiveness** — для `enum` и `sealed class` компилятор проверяет полноту.
4. **`when` guards** — дополнительное условие после паттерна.
5. **Нет fall-through** — каждый case в Dart изолирован (implicit break).
6. **Логические паттерны** — `>= 0 && < 100`, `'a' || 'b'`.
7. **`_` (wildcard)** — аналог default. Используйте осторожно с enum/sealed — теряете exhaustiveness.

---

> **Назад:** [5.1 if / else](05_01_if_else_ternary.md) · **Далее:** [5.3 Циклы](05_03_loops.md)
