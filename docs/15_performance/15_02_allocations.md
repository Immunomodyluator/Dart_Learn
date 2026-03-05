# 15.2 Оптимизация аллокаций

## 1. Формальное определение

**Аллокация (allocation)** — выделение памяти в куче (heap) для нового объекта. Каждая аллокация увеличивает нагрузку на сборщик мусора (GC). Оптимизация аллокаций — снижение количества создаваемых объектов, особенно короткоживущих.

## 2. Зачем это нужно

- **GC-давление** — чем больше объектов создаётся, тем чаще запускается GC.
- **Паузы** — GC может вызывать кратковременные паузы (jank в UI).
- **Кэш** — меньше объектов = лучше использование CPU-кэша.
- **Пропускная способность** — серверные приложения обрабатывают больше запросов.

## 3. Типичные источники лишних аллокаций

### Конкатенация строк

```dart
// ❌ Плохо — каждый += создаёт новую строку
String buildReport(List<String> lines) {
  var result = '';
  for (final line in lines) {
    result += '$line\n';  // N аллокаций!
  }
  return result;
}

// ✅ Хорошо — одна аллокация в конце
String buildReport(List<String> lines) {
  final sb = StringBuffer();
  for (final line in lines) {
    sb.writeln(line);
  }
  return sb.toString();  // 1 аллокация
}

// ✅ Ещё лучше — join
String buildReport(List<String> lines) => lines.join('\n');
```

### Промежуточные коллекции

```dart
// ❌ Плохо — 3 промежуточных списка
final result = items
    .where((e) => e.isActive)    // новый Iterable
    .map((e) => e.name)          // новый Iterable
    .toList()                    // новый List
    .where((n) => n.isNotEmpty)  // новый Iterable
    .toList();                   // ещё один List

// ✅ Хорошо — ленивые операции, один toList в конце
final result = items
    .where((e) => e.isActive && e.name.isNotEmpty)
    .map((e) => e.name)
    .toList();  // 1 List
```

### Создание объектов в цикле

```dart
// ❌ Плохо — новый Offset на каждой итерации
for (var i = 0; i < 1000; i++) {
  final offset = Offset(i.toDouble(), 0); // 1000 объектов
  canvas.drawCircle(offset, 5, paint);
}

// ✅ Хорошо — переиспользование мутабельного объекта
final offset = MutableOffset(0, 0);
for (var i = 0; i < 1000; i++) {
  offset.x = i.toDouble();
  canvas.drawCircle(offset, 5, paint);
}
```

### Копирование коллекций

```dart
// ❌ Плохо — каждый вызов создаёт копию
class ImmutableList<T> {
  final List<T> _items;
  ImmutableList(this._items);

  // Каждый вызов items создаёт новый List!
  List<T> get items => List.unmodifiable(_items);
}

// ✅ Хорошо — создаём unmodifiable один раз
class ImmutableList<T> {
  final List<T> _items;
  ImmutableList(List<T> items) : _items = List.unmodifiable(items);

  List<T> get items => _items;  // Возвращаем ту же ссылку
}
```

## 4. Техники оптимизации

### const-конструкторы

```dart
// const-объекты не аллоцируются повторно
class Config {
  final int timeout;
  final String host;
  const Config({this.timeout = 30, this.host = 'localhost'});
}

// Один и тот же объект в памяти
const config1 = Config();
const config2 = Config();
identical(config1, config2); // true — нулевые аллокации
```

### Канонизация (intern)

```dart
// Кэширование часто создаваемых объектов
class Color {
  static final _cache = <int, Color>{};

  final int value;

  factory Color(int value) {
    return _cache.putIfAbsent(value, () => Color._(value));
  }

  const Color._(this.value);

  static const red = Color._(0xFFFF0000);
  static const green = Color._(0xFF00FF00);
  static const blue = Color._(0xFF0000FF);
}
```

### Пул объектов

```dart
class ObjectPool<T> {
  final T Function() _create;
  final void Function(T) _reset;
  final List<T> _pool = [];

  ObjectPool({required T Function() create, required void Function(T) reset})
      : _create = create,
        _reset = reset;

  T acquire() {
    if (_pool.isNotEmpty) return _pool.removeLast();
    return _create();
  }

  void release(T obj) {
    _reset(obj);
    _pool.add(obj);
  }
}

// Использование
final bufferPool = ObjectPool<StringBuffer>(
  create: () => StringBuffer(),
  reset: (sb) => sb.clear(),
);

void process() {
  final sb = bufferPool.acquire();
  sb.write('data');
  // ... используем ...
  bufferPool.release(sb);  // Возвращаем в пул
}
```

### Typed data (массивы фиксированного типа)

```dart
import 'dart:typed_data';

// ❌ Плохо — List<double> хранит boxed Double объекты
final positions = <double>[1.0, 2.0, 3.0, 4.0];

// ✅ Хорошо — Float64List хранит сырые double без boxing
final positions = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);

// Для больших массивов данных:
final pixels = Uint8List(width * height * 4);  // RGBA
final vertices = Float32List(vertexCount * 3);  // XYZ
```

## 5. Измерение аллокаций

```dart
// Через DevTools Memory tab:
// 1. Allocation Tracing — показывает какие классы аллоцируются
// 2. Allocation Profile — количество объектов по типам
// 3. Heap Snapshot — полная картина живых объектов

// Программный подсчёт:
import 'dart:developer';

void measureAllocations() {
  // Timeline event для привязки к DevTools
  Timeline.startSync('heavyWork');
  processData();
  Timeline.finishSync();
}
```

## 6. Распространённые ошибки

### ❌ Преждевременная оптимизация

```dart
// Не оптимизируйте аллокации, пока профилировщик
// не показал, что GC — узкое место.

// Часто чистый читаемый код с «лишними» аллокациями
// работает достаточно быстро.
```

### ❌ Большие пулы объектов

```dart
// Пул, который никогда не очищается, сам становится
// утечкой памяти. Ограничивайте размер пула.
class BoundedPool<T> {
  final int maxSize;
  final List<T> _pool = [];

  BoundedPool({this.maxSize = 100});

  void release(T obj) {
    if (_pool.length < maxSize) {
      _pool.add(obj);
    }
    // Иначе просто отпускаем объект для GC
  }
}
```

---

> **Назад:** [15.1 Профайлинг с DevTools](15_01_devtools.md) · **Далее:** [15.3 Асинхронные узкие места](15_03_async_bottlenecks.md)
