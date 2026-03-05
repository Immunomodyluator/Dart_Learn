# Квиз: 11. Асинхронность и конкурентность

> 5 вопросов • Уровень: Junior–Middle • [Урок →](../lessons/11-async.md)

---

### Вопрос 1 (11.1): Futures и обработка результатов

Что выведет этот код?

```dart
void main() {
  Future.value(42).then((v) => print(v));
  print('sync');
}
```

- A) `42`, затем `sync`
- B) `sync`, затем `42`
- C) `42` и `sync` одновременно
- D) Ошибка: `Future.value` требует `await`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `sync`, затем `42`**

`.then()` callback ставится в очередь событий (event queue) и выполняется после завершения текущего синхронного кода. `print('sync')` — синхронный, выполняется немедленно. После него event loop обрабатывает callback `Future.value(42)`, который печатает `42`.
</details>

---

### Вопрос 2 (11.2): async / await

Какой тип у переменной `result` в этом коде?

```dart
Future<String> fetchData() async => 'data';

Future<void> main() async {
  var result = await fetchData();
}
```

- A) `Future<String>`
- B) `String`
- C) `dynamic`
- D) `FutureOr<String>`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `String`**

Оператор `await` «разворачивает» `Future<T>` в `T`. Поскольку `fetchData()` возвращает `Future<String>`, `await fetchData()` имеет тип `String`. Dart выводит тип автоматически: `var result` имеет тип `String`.
</details>

---

### Вопрос 3 (11.3): Streams и реактивные последовательности

Чем `broadcast` Stream отличается от обычного (single-subscription)?

- A) `broadcast` Stream можно ждать через `await`, обычный — нельзя
- B) `broadcast` Stream поддерживает нескольких слушателей одновременно; обычный — только одного
- C) `broadcast` Stream буферизует все события; обычный — нет
- D) `broadcast` Stream работает в отдельном Isolate

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `broadcast` Stream поддерживает нескольких слушателей одновременно; обычный — только одного**

Single-subscription stream генерирует ошибку при попытке подписаться дважды. `broadcast` stream позволяет любому количеству слушателей подписываться и отписываться в любой момент — но не буферизует события: подписчики, пришедшие позже, не получат пропущенные события.
</details>

---

### Вопрос 4 (11.4): Isolates и обмен сообщениями

Почему объекты нельзя напрямую разделять между Isolate'ами в Dart (до Dart 3's shared memory)?

- A) Dart не поддерживает многопоточность вообще
- B) Каждый Isolate имеет отдельную кучу памяти (heap); передача объектов происходит через глубокое копирование по ReceivePort/SendPort
- C) Объекты разделять можно, но только `final`
- D) Изоляты работают на разных процессах ОС

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Каждый Isolate имеет отдельную кучу памяти (heap); передача объектов происходит через глубокое копирование по ReceivePort/SendPort**

Архитектурно Isolate — отдельная куча и стек с собственным GC. Объекты передаются сообщениями, которые сериализуются (или для простых типов — копируются). Это исключает гонки данных (data races). `Isolate.run()` в Dart 2.19+ прозрачно сериализует аргументы и результат.
</details>

---

### Вопрос 5 (11.5): Цикл событий и микрозадачи

В каком порядке выполняются эти print-вызовы?

```dart
void main() {
  Future(() => print('future'));
  Future.microtask(() => print('microtask'));
  print('sync');
}
```

- A) `sync` → `future` → `microtask`
- B) `sync` → `microtask` → `future`
- C) `microtask` → `sync` → `future`
- D) `future` → `microtask` → `sync`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `sync` → `microtask` → `future`**

Event loop Dart имеет два уровня приоритета: синхронный код выполняется первым, затем microtask queue (приоритетная), и только потом event queue (обычные Future). `print('sync')` — синхронный. `Future.microtask` — microtask queue. `Future(() => ...)` — event queue. Порядок: sync → microtask → future.
</details>
