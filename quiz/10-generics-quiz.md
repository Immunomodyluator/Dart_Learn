# Квиз: 10. Дженерики и типовая система

> 4 вопроса • Уровень: Junior–Middle • [Урок →](../lessons/10-generics.md)

---

### Вопрос 1 (10.1): Обобщённые классы и методы

Что выведет этот код?

```dart
T first<T>(List<T> items) => items[0];

void main() {
  var result = first([1, 2, 3]);
  print(result.runtimeType);
}
```

- A) `dynamic`
- B) `Object`
- C) `int`
- D) `T`

<details>
<summary>Правильный ответ</summary>

**Ответ: C) `int`**

Dart выводит тип `T` из аргумента: `first([1, 2, 3])` — список имеет тип `List<int>`, поэтому `T = int`. `runtimeType` возвращает реальный тип в runtime, который будет `int`. В Dart generics reified (не стираются как в Java), поэтому тип `T` известен в runtime.
</details>

---

### Вопрос 2 (10.2): Ограничения (bounded generics)

Какое объявление функции позволяет вызвать `.length` на параметре `T`?

- A) `int getLength<T>(T value) => value.length;`
- B) `int getLength<T extends String>(T value) => value.length;`
- C) `int getLength<T: String>(T value) => value.length;`
- D) `int getLength<T is String>(T value) => value.length;`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `int getLength<T extends String>(T value) => value.length;`**

`T extends String` — bounded generic: гарантирует компилятору, что `T` всегда будет `String` или её подтипом. Это позволяет вызывать методы и свойства `String` (включая `.length`) на `value`. Вариант A вызовет ошибку компиляции, т.к. у необограниченного `T` нет `.length`. `T: String` и `T is String` — неверный синтаксис Dart.
</details>

---

### Вопрос 3 (10.3): Ковариантность и контравариантность

Что произойдёт при компиляции?

```dart
List<int> ints = [1, 2, 3];
List<num> nums = ints;  // строка 2
nums.add(1.5);          // строка 3
```

- A) Всё скомпилируется успешно, `ints` будет содержать `[1, 2, 3, 1.5]`
- B) Ошибка компиляции на строке 2: `List<int>` не является подтипом `List<num>`
- C) Скомпилируется, но строка 3 вызовет ошибку в runtime: нельзя добавить `double` в `List<int>`
- D) Ошибка компиляции на строке 3

<details>
<summary>Правильный ответ</summary>

**Ответ: C) Скомпилируется, но строка 3 вызовет ошибку в runtime: нельзя добавить `double` в `List<int>`**

Dart делает `List<T>` ковариантным (как Java arrays), поэтому `List<int>` присваивается `List<num>` без ошибки компиляции. Но в runtime попытка добавить `double` в `List<int>` вызывает `TypeError`. Это известная слабость ковариантных коллекций. Правильное решение — использовать `List<num>` изначально.
</details>

---

### Вопрос 4 (10.4): Type aliases и обновлённый синтаксис typedef

В чём разница между `typedef` и `extension type` при создании псевдонима?

- A) `typedef` создаёт новый несовместимый тип; `extension type` — лишь псевдоним
- B) `typedef` — только псевдоним (совместим с исходным типом); `extension type` — новый тип с нулевой стоимостью, несовместимый с исходным без явного обращения к `.value`
- C) Оба — полные псевдонимы; разница только в синтаксисе
- D) `extension type` нельзя использовать для function types; только `typedef`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `typedef` — только псевдоним (совместим с исходным типом); `extension type` — новый тип с нулевой стоимостью, несовместимый с исходным без явного обращения к `.value`**

`typedef StringList = List<String>` — псевдоним: `StringList` и `List<String>` взаимозаменяемы. `extension type UserId(int value)` — отдельный статический тип: нельзя передать `int` туда, где ожидается `UserId`, без явного `UserId(42)`. Под капотом оба компилируются в исходный тип без аллокации, но extension type обеспечивает типобезопасность.
</details>
