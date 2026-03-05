# Урок 7. Функции и замыкания

> Охватывает подтемы: 7.1 Синтаксис функций, 7.2 Параметры, 7.3 Замыкания, 7.4 typedef, 7.5 Генераторы sync*/async*

---

## 1. Формальное определение

В Dart функции — **объекты первого класса**: функцию можно передать как параметр, присвоить переменной, вернуть из другой функции. Типы функции:

- **Именованная функция**: `int add(int a, int b) => a + b;`
- **Анонимная функция** (lambda): `(a, b) => a + b`
- **Стрелочная функция** (сокращение): `=> expression`
- **Замыкание** (closure): функция, захватывающая переменные из окружающей области видимости
- **Генераторы**: `sync*` (Iterable) и `async*` (Stream) — функции, производящие последовательности

Уровень: **синтаксис, объектная модель, runtime**.

---

## 2. Зачем это нужно

- **Функции первого класса** — колбеки, `map`/`filter`/`reduce`, обработчики событий во Flutter
- **Именованные параметры** — читаемые вызовы `Widget(color: red, height: 100)` вместо позиционных
- **Замыкания** — инкапсуляция состояния без классов; основа паттернов вроде factory, builder
- **Генераторы** — ленивые последовательности без явного накопления в List; эффективная обработка больших данных

---

## 3. Синтаксис функций

```dart
// Полная форма
int add(int a, int b) {
  return a + b;
}

// Стрелочная (arrow) — только для одного выражения
int multiply(int a, int b) => a * b;

// Анонимная функция
var sayHello = (String name) => 'Hello, $name!';
print(sayHello('Dart')); // Hello, Dart!

// Функция как значение
int Function(int, int) operation = add;
print(operation(3, 4)); // 7

// Передача функции как аргумента
List<int> numbers = [1, 2, 3, 4, 5];
numbers.forEach(print);                    // передаём функцию по ссылке
List<int> evens = numbers.where((n) => n.isEven).toList(); // анонимная

// Возврат функции из функции
int Function(int) adder(int base) => (n) => base + n;
var addTen = adder(10);
print(addTen(5)); // 15
```

---

## 4. Параметры: позиционные, именованные, опциональные

```dart
// Обязательные позиционные
void greet(String name, int age) {
  print('$name is $age');
}
greet('Alice', 30); // OK
// greet(30, 'Alice'); // Ошибка типов компилятора

// Именованные параметры — в {фигурных скобках}
// По умолчанию опциональные (nullable или с default)
void createUser({
  required String name,    // required — обязателен
  String? email,           // опциональный nullable
  int age = 18,            // опциональный с default
  bool isAdmin = false,
}) {
  // ...
}

createUser(name: 'Alice');                           // OK
createUser(name: 'Bob', email: 'b@example.com', age: 25); // OK
// createUser(); // ОШИБКА: name required

// Опциональные позиционные — в [квадратных скобках]
String format(String text, [String prefix = '', String? suffix]) {
  return '$prefix$text${suffix ?? ''}';
}
format('hello');            // 'hello'
format('hello', '>>> ');   // '>>> hello'
format('hello', '>>> ', '!'); // '>>> hello!'

// Смешивание: позиционные ПЕРЕД именованными
void mixed(int x, int y, {String label = ''}) {
  print('$label: ($x, $y)');
}
mixed(1, 2, label: 'Point');
```

---

## 5. Замыкания

Замыкание — функция, **захватывающая переменные** из лексической области видимости:

```dart
// Простое замыкание
int Function() makeCounter() {
  int count = 0;
  return () {
    count++;
    return count;
  };
}

final counter = makeCounter();
print(counter()); // 1
print(counter()); // 2
print(counter()); // 3

// Каждый вызов makeCounter() создаёт НОВОЕ замыкание с НОВЫМ count
final counter2 = makeCounter();
print(counter2()); // 1 — независимый счётчик

// Ловушка с for-in и замыканиями
List<Function> closures = [];
for (int i = 0; i < 3; i++) {
  closures.add(() => print(i)); // Захватывает ПЕРЕМЕННУЮ i, не значение!
}
// В Dart: i создаётся заново на каждой итерации — каждое замыкание получает свою копию
closures[0](); // 0
closures[1](); // 1
closures[2](); // 2
// В JavaScript (var) все напечатали бы 3 — В Dart поведение правильное!

// Замыкание для инкапсуляции состояния
(void Function(), int Function()) buildCounter(int initial) {
  int _value = initial;
  return (
    () { _value++; },       // increment
    () => _value,            // getValue
  );
}
final (increment, getValue) = buildCounter(0);
increment();
increment();
print(getValue()); // 2
```

---

## 6. typedef — типы функций

```dart
// typedef — псевдоним типа функции
typedef Predicate<T> = bool Function(T value);
typedef Transformer<T, R> = R Function(T input);
typedef VoidCallback = void Function();   // Уже в Flutter SDK

// Использование
bool isPositive(int n) => n > 0;
Predicate<int> check = isPositive;
print(check(-5)); // false

// Generic typedef
Predicate<String> hasContent = (s) => s.isNotEmpty;

// Callbacks в классах
class Button {
  final String label;
  final VoidCallback onPressed;
  
  const Button({required this.label, required this.onPressed});
  
  void click() => onPressed();
}

// typedef для сложных сигнатур
typedef AsyncHandler<T> = Future<T> Function(Map<String, dynamic> params);

// Closure factory
AsyncHandler<String> makeApiHandler(String baseUrl) =>
    (params) async => 'Response from $baseUrl with $params';
```

---

## 7. Генераторы: sync* и async*

Генераторы — специальные функции, **производящие последовательности** элементов лениво.

### sync* — синхронный Iterable

```dart
// sync* возвращает Iterable<T>
// yield добавляет элемент в последовательность
// yield* делегирует другому Iterable
Iterable<int> range(int start, int end) sync* {
  for (int i = start; i < end; i++) {
    yield i; // Элемент доступен сразу (ленивость)
  }
}

// Использование
for (final n in range(1, 6)) {
  print(n); // 1, 2, 3, 4, 5
}

// Ленивость: элементы вычисляются только при итерации
Iterable<int> first3 = range(1, 1000000).take(3); // Не вычисляет миллион!
print(first3.toList()); // [1, 2, 3] — вычислено только 3 элемента

// Рекурсивный генератор с yield*
Iterable<int> flatten(List<dynamic> list) sync* {
  for (final item in list) {
    if (item is List) {
      yield* flatten(item); // делегировать рекурсивно
    } else if (item is int) {
      yield item;
    }
  }
}

print(flatten([1, [2, 3], [4, [5, 6]]]).toList()); // [1, 2, 3, 4, 5, 6]

// Бесконечная последовательность — безопасно в ленивом Iterable
Iterable<int> naturals() sync* {
  int n = 0;
  while (true) yield n++;
}

print(naturals().take(5).toList()); // [0, 1, 2, 3, 4]
```

### async* — асинхронный Stream

```dart
import 'dart:async';

// async* возвращает Stream<T>
Stream<int> countdown(int from) async* {
  for (int i = from; i >= 0; i--) {
    await Future.delayed(const Duration(seconds: 1));
    yield i;
  }
}

// Использование
await for (final count in countdown(5)) {
  print(count); // 5, 4, 3, 2, 1, 0 — по секунде
}

// Реальный пример: стриминг данных из файла
Stream<String> readLines(String path) async* {
  final file = File(path);
  await for (final line in file.openRead().transform(utf8.decoder).transform(LineSplitter())) {
    yield line;
  }
}

// yield* для делегирования другому Stream
Stream<int> mergedStream() async* {
  yield* Stream.fromIterable([1, 2, 3]);
  yield* Stream.fromIterable([4, 5, 6]);
}
```

---

## 8. Минимальный пример

```dart
// Функциональный pipeline с замыканиями
typedef Transform<T, R> = R Function(T);

Transform<T, R> compose<T, R>(
  List<Transform<dynamic, dynamic>> pipeline,
) {
  return (T input) {
    dynamic result = input;
    for (final fn in pipeline) {
      result = fn(result);
    }
    return result as R;
  };
}

void main() {
  final processText = compose<String, String>([
    (s) => s.trim(),
    (s) => s.toLowerCase(),
    (s) => s.replaceAll(' ', '_'),
  ]);
  
  print(processText('  Hello World  ')); // hello_world
  
  // Генератор для чисел Фибоначчи
  Iterable<int> fibonacci() sync* {
    int a = 0, b = 1;
    while (true) {
      yield a;
      (a, b) = (b, a + b); // swap через Record
    }
  }
  
  print(fibonacci().take(10).toList()); // [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
}
```

---

## 9. Практический пример

Middleware-цепочка в стиле Express/Koa для серверного Dart:

```dart
import 'dart:io';

typedef Handler = Future<void> Function(HttpRequest request);
typedef Middleware = Handler Function(Handler next);

// Middleware factory через замыкания
Middleware logger() => (next) => (request) async {
  final start = DateTime.now();
  print('[${start.toIso8601String()}] ${request.method} ${request.uri.path}');
  await next(request);
  final elapsed = DateTime.now().difference(start);
  print('Completed in ${elapsed.inMilliseconds}ms');
};

Middleware auth(Set<String> publicPaths) => (next) => (request) async {
  if (publicPaths.contains(request.uri.path)) {
    return next(request);
  }
  final token = request.headers.value('Authorization');
  if (token == null || !token.startsWith('Bearer ')) {
    request.response
      ..statusCode = 401
      ..write('Unauthorized')
      ..close();
    return;
  }
  await next(request);
};

// Компоновка middleware
Handler compose(List<Middleware> middlewares, Handler core) =>
    middlewares.reversed.fold(core, (handler, mw) => mw(handler));

Handler coreHandler(HttpRequest request) async {
  request.response
    ..statusCode = 200
    ..write('Hello!')
    ..close();
}

void main() async {
  final handler = compose([
    logger(),
    auth({'/health', '/'}),
  ], coreHandler);
  
  final server = await HttpServer.bind('localhost', 8080);
  await for (final request in server) {
    handler(request);
  }
}
```

**Архитектурная корректность:** каждый middleware — pure closure, не класс. Компоновка через `fold` — идиоматический функциональный паттерн.

---

## 10. Что происходит под капотом

### Функции как объекты

Каждая функция в Dart — экземпляр класса `Function`. Анонимная функция создаёт объект на heap. В горячих путях это источник GC pressure.

### Замыкание: heap allocation

Когда функция захватывает переменные, они **аллоцируются в heap** (не stack), чтобы пережить выход из функции-создателя. Это Context object в Dart VM.

### sync* под капотом

Генератор компилируется в **state machine** (аналогично async/await):
1. Первый вызов `moveNext()` запускает тело до первого `yield`
2. Следующий `moveNext()` возобновляет с точки после `yield`
3. Состояние сохраняется между вызовами

Это эффективнее `List` для больших последовательностей — нет предварительной аллокации всего списка.

---

## 11. Производительность и ресурсы

**Эффективно:**
- Передача функции по ссылке (без копий)
- `sync*` для ленивой генерации больших последовательностей
- Arrow-функции компилируются идентично полным функциям

**Узкие места:**
- Создание замыканий в hot loop — GC pressure от context objects
- `async*` с частым `yield` — накладные расходы на планировщик событий
- Длинные цепочки замыканий — сложнее для AOT inline-оптимизации

---

## 12. Частые ошибки

**1. `required` vs nullable:**
```dart
// Путаница: required и ? несовместимы семантически
void f({required String? name}) {} // OK, но strange — зачем required если может быть null?
void f({String? name}) {}          // Лучше: опциональный nullable с implicit null
```

**2. Позиционные и именованные смешаны неправильно:**
```dart
// ОШИБКА: опциональные позиционные нельзя смешивать с именованными
void bad([int x = 0], {String name = ''}) {} // Ошибка компиляции
// ВЕРНО: либо то, либо другое (или позиционные obligatory + именованные)
void good(int x, {String name = ''}) {}
```

**3. Злоупотребление функциями вместо классов:**
```dart
// НЕВЕРНО для сложного состояния
(void Function(), void Function(int)) buildComplex() {
  // Сложная логика с 10+ переменными
}
// ВЕРНО — использовать класс
```

---

## 13. Сравнение с альтернативами

| Аспект | Dart | Kotlin | TypeScript | Java |
|---|---|---|---|---|
| Именованные параметры | `{name: value}` | `name = value` | `{name: value}` | Нет |
| Default значения | Да | Да | Да | Нет (перегрузки) |
| `required` | `required` | Нет nullable default | `!` или `Required<>` | Нет |
| Генераторы | `sync*` / `async*` | `sequence {}` / `flow {}` | `function*` / `async function*` | Нет встроенных |
| Closures | Heap context | Heap context | JS closures | Lambda (since Java 8) |

---

## 14. Краткое резюме

1. **Именованные параметры** (`{required name}`) — предпочтительны для функций с 3+ параметрами; обязательны для Flutter widget-ов.
2. **Стрелочные функции** `=>` — только для одного выражения; не использовать с `{}` внутри (это анонимный Set!).
3. **Замыкания захватывают переменные** (reference), не значения — переменная в heap; помнить при создании замыканий в циклах.
4. **`typedef`** улучшает читаемость сложных типов функций; особенно важен для колбеков в публичном API.
5. **`sync*` для ленивых Iterable** — эффективнее `List` для больших/бесконечных последовательностей.
6. **`async*` для Stream** — декларативный способ создания потоков данных; альтернатива `StreamController`.
7. **`yield*` делегирует** в другой Iterable/Stream — аналог `flatMap` + автоматическое завершение.
