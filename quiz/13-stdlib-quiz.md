# Квиз: 13. Стандартная библиотека Dart

> 5 вопросов • Уровень: Junior–Middle • [Урок →](../lessons/13-stdlib.md)

---

### Вопрос 1 (13.1): dart:core и dart:collection

Что выведет этот код?

```dart
import 'dart:collection';

void main() {
  final map = LinkedHashMap<String, int>();
  map['c'] = 3;
  map['a'] = 1;
  map['b'] = 2;
  print(map.keys.toList());
}
```

- A) `[a, b, c]` — `LinkedHashMap` сортирует ключи
- B) `[c, a, b]` — `LinkedHashMap` сохраняет порядок вставки
- C) `[b, a, c]` — порядок непредсказуем
- D) `[1, 2, 3]` — выводятся значения, а не ключи

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `[c, a, b]` — `LinkedHashMap` сохраняет порядок вставки**

`LinkedHashMap` гарантирует итерацию в порядке вставки ключей. Первым вставлено `'c'`, затем `'a'`, затем `'b'`. Обычный `HashMap` (по умолчанию `{}`) не гарантирует порядок. Для сортировки нужен `SplayTreeMap`.
</details>

---

### Вопрос 2 (13.2): dart:convert

Что выведет этот код?

```dart
import 'dart:convert';

void main() {
  final json = '{"name": "Alice", "age": 30}';
  final map = jsonDecode(json);
  print(map['name'].runtimeType);
}
```

- A) `String`
- B) `dynamic`
- C) `Object`
- D) `JsonString`

<details>
<summary>Правильный ответ</summary>

**Ответ: A) `String`**

`jsonDecode` возвращает `dynamic`, но реальный тип значения `'Alice'` в runtime — `String`. `.runtimeType` возвращает именно runtime-тип объекта, а не статически объявленный. Строковые значения JSON декодируются как `String`, числа — как `int` или `double`, булево — как `bool`.
</details>

---

### Вопрос 3 (13.3): dart:math

Почему для генерации токенов безопасности нельзя использовать `Random()`?

- A) `Random()` генерирует только числа от 0 до 100
- B) `Random()` — псевдослучайный генератор с предсказуемым выводом при известном seed; для безопасности нужен `Random.secure()` на основе ОС CSPRNG
- C) `Random()` недоступен в продакшн AOT-сборках
- D) `Random()` возвращает `double`, а не `int`, поэтому необработанные байты невозможно получить

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `Random()` — псевдослучайный генератор с предсказуемым выводом при известном seed; для безопасности нужен `Random.secure()` на основе ОС CSPRNG**

`Random()` использует seed (по умолчанию — текущее время), что делает последовательность предсказуемой при знании seed. `Random.secure()` делегирует генерацию к OAuth-безопасному источнику ОС (`/dev/urandom` на Linux, `CryptGenRandom` на Windows), обеспечивая криптографическую стойкость.
</details>

---

### Вопрос 4 (13.4): dart:io

Что произойдёт при вызове `File('data.txt').readAsStringSync()` в обработчике HTTP-запроса на сервере?

- A) Файл прочитается асинхронно в фоне, сервер продолжит обрабатывать запросы
- B) Вызов заблокирует event loop на время чтения файла, сервер перестанет обрабатывать другие запросы
- C) Сгенерируется исключение: sync I/O запрещён в Dart
- D) Файл кэшируется, последующие вызовы не блокируют

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Вызов заблокирует event loop на время чтения файла, сервер перестанет обрабатывать другие запросы**

Dart — однопоточный: синхронные I/O операции блокируют весь event loop. Пока файл читается, сервер не может обработать ни один входящий запрос. В серверном коде обязательно использовать `await file.readAsString()` — асинхронный вариант, который не блокирует event loop.
</details>

---

### Вопрос 5 (13.5): dart:async — утилиты

Для чего нужен `Completer<T>`?

- A) Для создания периодических таймеров
- B) Для превращения callback-based API в Future API: позволяет вручную завершить Future снаружи async функции
- C) Для ограничения количества параллельных Future
- D) Для мониторинга состояния Zone

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Для превращения callback-based API в Future API: позволяет вручную завершить Future снаружи async функции**

`Completer` даёт доступ к `Future` и методам `complete(value)` / `completeError(error)`. Это позволяет «построить мост» между старым callback-based кодом и современным async/await: создаёшь `Completer`, передаёшь `completer.future` вызывающему, а при получении callback вызываешь `completer.complete(result)`.
</details>
