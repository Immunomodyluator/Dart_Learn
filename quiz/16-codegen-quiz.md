# Квиз: 16. Генерация кода

> 3 вопроса • Уровень: Junior–Middle • [Урок →](../lessons/16-codegen.md)

---

### Вопрос 1 (16.1): build_runner

Какая команда запускает генерацию кода и автоматически разрешает конфликты выходных файлов?

- A) `dart run build_runner build`
- B) `dart run build_runner build --delete-conflicting-outputs`
- C) `dart pub run codegen`
- D) `dart generate --watch`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `dart run build_runner build --delete-conflicting-outputs`**

`build_runner build` генерирует файлы вида `*.g.dart`. Флаг `--delete-conflicting-outputs` автоматически удаляет устаревшие сгенерированные файлы при конфликтах версий, избегая ошибки «файл уже существует». Без этого флага билд прерывается при наличии конфликтов и требует ручного удаления файлов.
</details>

---

### Вопрос 2 (16.2): json_serializable и freezed

Что генерирует аннотация `@freezed` для класса в Dart?

```dart
@freezed
class User with _$User {
  const factory User({
    required String name,
    required int age,
  }) = _User;
}
```

- A) Только JSON-сериализацию (`fromJson`/`toJson`)
- B) `copyWith`, `==`, `hashCode`, `toString`, pattern matching через `when`/`map`, опционально `fromJson`/`toJson`
- C) Только иммутабельный класс без дополнительных методов
- D) Абстрактный класс sealed hierarchy

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `copyWith`, `==`, `hashCode`, `toString`, pattern matching через `when`/`map`, опционально `fromJson`/`toJson`**

`@freezed` — это мощный генератор, создающий полноценные value objects. Он генерирует структурное равенство (`==` и `hashCode`), иммутабельный `copyWith`, читаемый `toString`, методы `when`/`map`/`maybeWhen` для pattern matching. При добавлении `@JsonSerializable` также создаёт `fromJson`/`toJson`.
</details>

---

### Вопрос 3 (16.3): Создание собственного генератора

Какой базовый класс нужно расширить для создания генератора кода, работающего с конкретной аннотацией?

```dart
class MyGenerator extends ??? <MyAnnotation> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    // генерация кода
  }
}
```

- A) `Builder`
- B) `GeneratorForAnnotation<T>` из пакета `source_gen`
- C) `CodeGenerator<T>` из пакета `build`
- D) `AnnotationProcessor<T>` из пакета `analyzer`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `GeneratorForAnnotation<T>` из пакета `source_gen`**

`GeneratorForAnnotation<T>` из пакета `source_gen` — абстрактный класс, который автоматически находит все элементы с аннотацией `T` и вызывает `generateForAnnotatedElement` для каждого. Это стандартный способ создания генераторов в экосистеме Dart. Низкоуровневый `Builder` из пакета `build` требует больше кода для той же задачи.
</details>
