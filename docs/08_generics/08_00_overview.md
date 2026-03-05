# 8. Дженерики и типовая система — обзор

Dart использует **reified generics** — типовые параметры сохраняются в runtime, в отличие от Java (type erasure). Это позволяет проверять `is List<int>` во время выполнения.

## Что входит в раздел

| #   | Тема                                                           | Файл                                                      |
| --- | -------------------------------------------------------------- | --------------------------------------------------------- |
| 8.1 | [Обобщённые классы и методы](08_01_generic_classes_methods.md) | `class Box<T>`, `T first<T>(List<T>)`, generic extensions |
| 8.2 | [Ограничения (bounded generics)](08_02_bounded_generics.md)    | `<T extends Comparable>`, множественные bounds            |
| 8.3 | [Ковариантность и контравариантность](08_03_variance.md)       | Поведение типов при наследовании, `covariant`             |
| 8.4 | [Type aliases и typedef](08_04_type_aliases.md)                | Generic typedef, non-function typedef                     |

## Ключевые особенности

- **Reified generics** — `<T>` доступен в runtime: `obj is List<int>` работает.
- **Type inference** — компилятор выводит `<T>` из контекста: `var list = [1, 2, 3]` → `List<int>`.
- **Sound type system** — гарантирует type safety как compile-time, так и runtime.
- **Generic всё** — классы, методы, mixins, extensions, typedefs, extension types.

## Связи с другими разделами

- **Раздел 4** (коллекции) → `List<T>`, `Map<K, V>`, `Set<T>` — generic коллекции.
- **Раздел 6** (функции) → `typedef Mapper<T, R> = R Function(T)`.
- **Раздел 7** (ООП) → generic классы, abstract generic interfaces.
- **Раздел 10** (асинхронность) → `Future<T>`, `Stream<T>`.

---

> **Назад:** [7.7 Статические члены и фабричные конструкторы](../07_oop/07_07_static_factory.md) · **Далее:** [8.1 Обобщённые классы и методы](08_01_generic_classes_methods.md)
