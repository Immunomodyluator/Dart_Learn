# 6.3 Замыкания и лексическая область

## 1. Формальное определение

**Замыкание** (closure) — функция, которая захватывает переменные из окружающей лексической области видимости (lexical scope) и сохраняет к ним доступ даже после завершения этой области.

**Лексическая область** (lexical scope) — правило, по которому доступность переменной определяется **местом объявления** в исходном коде, а не местом вызова. Каждая пара `{}` создаёт новую область.

В Dart **все функции — замыкания**: даже top-level функции замыкают глобальную область.

## 2. Зачем это нужно

- **Сохранение состояния** — замыкание «помнит» переменные из родительского scope.
- **Фабрики функций** — функция, возвращающая функцию с настроенным поведением.
- **Коллбэки** — обработчики событий захватывают контекст (Flutter: `onPressed`, `Builder`).
- **Частичное применение** — фиксация части аргументов для создания специализированной функции.
- **Инкапсуляция** — приватное состояние без класса.

## 3. Как это работает

### Лексическая область видимости

```dart
var topLevel = 'глобальная';

void main() {
  var mainVar = 'main scope';

  void inner() {
    var innerVar = 'inner scope';
    print(topLevel);  // ✅ Видна
    print(mainVar);   // ✅ Видна
    print(innerVar);  // ✅ Видна
  }

  inner();
  // print(innerVar); // ❌ Ошибка: innerVar не видна здесь
}
```

### Замыкание захватывает переменные

```dart
void main() {
  var counter = 0;

  // Замыкание захватывает counter по ссылке!
  var increment = () {
    counter++;
    print('counter: $counter');
  };

  increment(); // counter: 1
  increment(); // counter: 2
  increment(); // counter: 3

  print(counter); // 3 — оригинал изменён!
}
```

### Фабрика функций

```dart
/// Возвращает функцию, которая добавляет [addend] к своему аргументу
int Function(int) makeAdder(int addend) {
  // addend захвачен замыканием
  return (int x) => x + addend;
}

void main() {
  var add5 = makeAdder(5);
  var add10 = makeAdder(10);

  print(add5(3));   // 8
  print(add10(3));  // 13

  // Каждый вызов makeAdder создаёт НОВОЕ замыкание
  // со своим значением addend
}
```

### Замыкание в цикле

```dart
void main() {
  var closures = <Function>[];

  // for создаёт новую переменную i на каждой итерации!
  for (var i = 0; i < 3; i++) {
    closures.add(() => print(i));
  }

  closures[0](); // 0 (НЕ 3!)
  closures[1](); // 1
  closures[2](); // 2

  // В JS с var было бы 3, 3, 3
  // В Dart каждая итерация for — новый scope для i
}
```

### Замыкание сохраняет ссылку, не значение

```dart
void main() {
  var x = 10;
  var fn = () => print(x); // Захватывает ссылку на x

  x = 20;   // Изменяем x
  fn();      // 20 — видит текущее значение!

  x = 30;
  fn();      // 30
}
```

### Инкапсуляция состояния

```dart
/// Создаёт приватный счётчик — state скрыт в замыкании
({int Function() get, void Function() increment, void Function() reset})
    createCounter({int initial = 0}) {
  var _count = initial;

  return (
    get: () => _count,
    increment: () => _count++,
    reset: () => _count = initial,
  );
}

void main() {
  var counter = createCounter(initial: 10);

  counter.increment();
  counter.increment();
  print(counter.get()); // 12

  counter.reset();
  print(counter.get()); // 10

  // _count недоступен снаружи — инкапсуляция!
}
```

## 4. Минимальный пример

```dart
void main() {
  var greeting = 'Привет';

  // Замыкание захватывает greeting
  var greet = (String name) => '$greeting, $name!';

  print(greet('мир'));     // Привет, мир!

  greeting = 'Здравствуй';
  print(greet('мир'));     // Здравствуй, мир! — видит изменение
}
```

## 5. Практический пример

### Система middleware (цепочка обработчиков)

```dart
typedef Handler = String Function(String request);
typedef Middleware = Handler Function(Handler next);

/// Middleware: логирование
Middleware logging(String tag) {
  return (Handler next) {
    return (String request) {
      print('[$tag] → $request');
      var response = next(request);
      print('[$tag] ← $response');
      return response;
    };
  };
}

/// Middleware: кеширование
Middleware caching() {
  var cache = <String, String>{}; // Захвачен замыканием!

  return (Handler next) {
    return (String request) {
      if (cache.containsKey(request)) {
        print('[CACHE HIT] $request');
        return cache[request]!;
      }
      var response = next(request);
      cache[request] = response;
      return response;
    };
  };
}

/// Middleware: аутентификация
Middleware auth(Set<String> validTokens) {
  return (Handler next) {
    return (String request) {
      if (!validTokens.contains(request.split(':').first)) {
        return 'ERROR: Unauthorized';
      }
      return next(request);
    };
  };
}

/// Применить цепочку middleware
Handler applyMiddleware(Handler handler, List<Middleware> middlewares) {
  var result = handler;
  // Применяем в обратном порядке (последний оборачивает первый)
  for (final mw in middlewares.reversed) {
    result = mw(result);
  }
  return result;
}

void main() {
  // Базовый обработчик
  Handler baseHandler = (request) => 'Response to: $request';

  // Собираем pipeline
  var pipeline = applyMiddleware(baseHandler, [
    logging('HTTP'),
    caching(),
    auth({'token123', 'admin'}),
  ]);

  print(pipeline('token123:getData'));
  print('---');
  print(pipeline('token123:getData')); // Cache hit!
  print('---');
  print(pipeline('invalid:getData')); // Unauthorized
}
```

### Мемоизация через замыкание

```dart
/// Мемоизирует любую функцию с одним аргументом
R Function(T) memoize<T, R>(R Function(T) fn) {
  var cache = <T, R>{};
  return (T arg) {
    return cache.putIfAbsent(arg, () => fn(arg));
  };
}

int fibonacci(int n) {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

void main() {
  // Обычный: O(2^n)
  // print(fibonacci(40)); // Медленно!

  // Мемоизированный:
  late int Function(int) fib;
  fib = memoize((int n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);
  });

  print(fib(40)); // 102334155 — мгновенно!
}
```

## 6. Что происходит под капотом

### Context object

```
var x = 10;
var fn = () => x + 1;

Dart VM создаёт:

Closure (fn):
  ┌─────────────┐
  │ code: [→]   │──→ compiled function body
  │ context: [→]│──→ Context object
  └─────────────┘     ┌──────────┐
                      │ x: 10    │ ← захваченная переменная
                      └──────────┘

При x = 20 → Context.x = 20
fn() → читает Context.x → 20
```

### Цепочка контекстов (nested scopes)

```dart
void outer() {
  var a = 1;
  void middle() {
    var b = 2;
    void inner() {
      print(a + b); // Доступ к обоим!
    }
    inner();
  }
  middle();
}

// Context chain:
// inner.context → { b: 2, parent: → }
//                                    │
//                     middle.context → { a: 1 }
```

### Захват по ссылке, не по значению

```
var x = 10;
var fn = () => x;  // Захватывает ЯЧЕЙКУ x, не значение 10

x = 20;
fn(); // → 20

Это потому что Context хранит ссылку на переменную,
а не копию значения.

Это отличает замыкания от, например, C++ capture by value [=].
```

### GC и lifetime

```
Замыкание удерживает Context → GC не соберёт захваченные переменные,
пока замыкание живо.

Если замыкание хранится в долгоживущем объекте (static, global, stream listener),
захваченные объекты тоже живут долго → потенциальная утечка памяти.
```

## 7. Производительность и ресурсы

| Аспект                          | Стоимость                                       |
| ------------------------------- | ----------------------------------------------- |
| Создание замыкания              | Аллокация Closure + Context object              |
| Доступ к захваченной переменной | Indirect через Context (чуть дороже локальной)  |
| Вложенные замыкания             | Chain of Context objects                        |
| GC                              | Замыкание → Context → захваченные объекты живут |

**Рекомендации:**

- Не захватывайте большие объекты без необходимости — копируйте нужное поле.
- Для hot loops предпочитайте top-level функции (нет Context overhead).
- Dart VM часто оптимизирует: escape analysis может разместить Context на стеке.

## 8. Частые ошибки и антипаттерны

### ❌ Неожиданный захват по ссылке

```dart
void main() {
  var callbacks = <void Function()>[];
  var value = 'before';

  callbacks.add(() => print(value));

  value = 'after'; // Изменили!

  callbacks[0](); // 'after' — не 'before'!

  // Если нужно зафиксировать значение:
  var captured = value; // Копия
  callbacks.add(() => print(captured));
}
```

### ❌ Утечка памяти через замыкание

```dart
class HeavyObject {
  final data = List.filled(1000000, 0); // 1M элементов
}

void main() {
  Function? leakyCallback;

  void setup() {
    var heavy = HeavyObject();
    // Замыкание захватывает heavy — он НЕ будет собран GC!
    leakyCallback = () => print(heavy.data.length);
  }

  setup(); // heavy должен был бы умереть, но...
  // leakyCallback удерживает heavy через Context

  // Решение: обнулить callback или захватить только нужное
  leakyCallback = null; // Теперь heavy может быть собран
}
```

### ❌ Замыкание в forEach с async

```dart
var items = [1, 2, 3];

// ПЛОХО: forEach + async closure = fire-and-forget!
items.forEach((item) async {
  await Future.delayed(Duration(seconds: 1));
  print(item); // Выполнится, но никто не ждёт!
});

// ПРАВИЛЬНО:
for (final item in items) {
  await Future.delayed(Duration(seconds: 1));
  print(item); // Последовательно, с ожиданием
}
```

### ❌ this в замыкании долгоживущего объекта

```dart
class Widget {
  var data = 'sensitive';

  void registerCallback(void Function(Function) register) {
    // this захвачен! Widget не будет GC'd пока callback жив
    register(() => print(data));
  }

  // Решение: слабые ссылки или отписка
}
```

## 9. Сравнение с альтернативами

| Аспект              | Dart              | Java                            | JavaScript                  | Python        | C++                       |
| ------------------- | ----------------- | ------------------------------- | --------------------------- | ------------- | ------------------------- |
| Замыкания           | ✅ (все функции)  | ✅ (lambda, effectively final)  | ✅                          | ✅            | ✅ (explicit capture)     |
| Захват              | По ссылке         | По значению (effectively final) | По ссылке                   | По ссылке     | `[=]` / `[&]` выбор       |
| Мутация захваченных | ✅                | ❌ (must be final)              | ✅                          | ✅ (nonlocal) | `[&]` — ✅                |
| for-переменная      | Новая на итерацию | Новая (enhanced for)            | `let` — новая, `var` — одна | Новая         | Новая                     |
| GC удержание        | ✅                | ✅                              | ✅                          | ✅            | Нет GC (life-time issues) |

В Java замыкания не могут мутировать захваченные переменные (must be effectively final). Dart позволяет мутацию.

## 10. Когда НЕ стоит использовать

- **Простые операции без захвата** — вместо замыкания используйте top-level или static функцию.
- **Долгоживущие замыкания с большим контекстом** — копируйте только нужные поля.
- **Замена классу с состоянием** — для сложного состояния класс читабельнее замыкания.
- **Мутация capture в разных потоках/isolates** — замыкания не пересекают границы изолятов.

## 11. Краткое резюме

1. **Все функции в Dart — замыкания** — захватывают переменные из лексической области.
2. **Захват по ссылке** — изменения в оригинале видны в замыкании (и наоборот).
3. **Новая переменная в for** — каждая итерация C-style `for` создаёт свой scope.
4. **Фабрики функций** — `makeAdder(5)` возвращает функцию с зафиксированным состоянием.
5. **Context object** — Dart VM создаёт heap-объект для захваченных переменных.
6. **Утечки памяти** — замыкание удерживает Context и все захваченные объекты.
7. **Мемоизация** — замыкание + Map = кеширование результатов вычислений.

---

> **Назад:** [6.2 Параметры](06_02_parameters.md) · **Далее:** [6.4 Типы функций и typedef](06_04_typedefs.md)
