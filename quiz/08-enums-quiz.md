# Квиз: 08. Перечисления

> 2 вопроса • Уровень: Junior–Middle • [Урок →](../lessons/08-enums.md)

---

### Вопрос 1 (8.1): Базовые enum

Что выведет этот код?

```dart
enum Direction { north, south, east, west }

void main() {
  final d = Direction.east;
  print(d.name);
  print(d.index);
}
```

- A) `Direction.east` и `2`
- B) `east` и `2`
- C) `east` и `3`
- D) `Direction.east` и `3`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `east` и `2`**

`enum.name` возвращает строковое имя значения без префикса типа — просто `'east'`. `enum.index` — порядковый номер, начиная с нуля: `north=0`, `south=1`, `east=2`, `west=3`. Поэтому `d.index == 2`.
</details>

---

### Вопрос 2 (8.2): Enhanced enums (Dart 2.17+)

Какое объявление enhanced enum корректно в Dart 2.17+?

- A)
```dart
enum Planet {
  mars(mass: 6.39e23, radius: 3.39e6);
  final double mass;
  final double radius;
  Planet({required this.mass, required this.radius});
}
```

- B)
```dart
enum Planet {
  mars(6.39e23, 3.39e6);
  final double mass;
  final double radius;
  const Planet(this.mass, this.radius);
}
```

- C)
```dart
enum Planet {
  mars = (mass: 6.39e23, radius: 3.39e6);
  final double mass;
  final double radius;
}
```

- D)
```dart
enum Planet extends Object {
  mars(mass: 6.39e23, radius: 3.39e6);
  double mass = 0;
}
```

<details>
<summary>Правильный ответ</summary>

**Ответ: B)**

В enhanced enum конструктор **обязан** быть `const` (т.к. значения enum — константы времени компиляции). Поля должны быть `final`. Вариант A использует обычный конструктор без `const` — ошибка. Вариант C — неверный синтаксис. Вариант D — `enum` не может `extends`, поля не могут быть изменяемыми.
</details>
