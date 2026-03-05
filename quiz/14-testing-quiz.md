# Квиз: 14. Тестирование

> 4 вопроса • Уровень: Junior–Middle • [Урок →](../lessons/14-testing.md)

---

### Вопрос 1 (14.1): Unit-тесты с пакетом test

Как правильно тестировать асинхронный код в `package:test`?

```dart
test('fetches user', /* ??? */ () /* ??? */ {
  final user = await fetchUser(1);
  expect(user.id, equals(1));
});
```

- A) Тест нужно пометить как `async` и передать `Future`, тогда `test()` автоматически его дождётся: `test('...', () async { ... })`
- B) Использовать `expectAsync1` для оборачивания каждого `await`
- C) Асинхронные тесты невозможны в `package:test`; нужен отдельный пакет
- D) Достаточно вернуть `Future` без `async/await`: `test('...', () => fetchUser(1))`

<details>
<summary>Правильный ответ</summary>

**Ответ: A) `test('...', () async { ... })`**

`test()` в `package:test` принимает `FutureOr<void>`. Если callback возвращает `Future`, фреймворк автоматически ждёт его завершения перед проверкой результата. Пометить функцию как `async` — стандартный и читаемый способ тестировать async код.
</details>

---

### Вопрос 2 (14.2): Mocking и stubbing

В чём главное преимущество `mocktail` перед `mockito` для Dart-проектов без Flutter?

- A) `mocktail` работает быстрее в runtime
- B) `mocktail` не требует кодогенерации (`build_runner`): моки создаются напрямую через `class MockFoo extends Mock implements Foo`
- C) `mocktail` поддерживает больше типов матчеров
- D) `mockito` устарел и не поддерживается

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `mocktail` не требует кодогенерации**

`mockito` в null-safe Dart требует аннотации `@GenerateMocks` и запуска `build_runner` для генерации классов мока. `mocktail` использует рефлексию через `noSuchMethod` паттерн — мок создаётся немедленно без генерации кода. Это ускоряет итерацию разработки, но не работает с некоторыми edge cases (например, top-level функции).
</details>

---

### Вопрос 3 (14.3): Интеграционные и E2E тесты

Чем интеграционный тест отличается от unit-теста в контексте Dart-проекта?

- A) Интеграционные тесты пишутся на другом языке (bash/Python)
- B) Unit-тест тестирует изолированную единицу с мок-зависимостями; интеграционный тест проверяет взаимодействие нескольких компонентов или с реальными внешними сервисами (БД, HTTP)
- C) Интеграционные тесты работают только с Flutter
- D) Разница только в скорости: интеграционные тесты просто медленнее

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Unit-тест тестирует изолированную единицу с мок-зависимостями; интеграционный тест проверяет взаимодействие нескольких компонентов или с реальными внешними сервисами (БД, HTTP)**

Unit-тест изолирует компонент через моки и стабы — нет реальной БД, нет HTTP. Интеграционный тест проверяет, что компоненты работают вместе: реальный HTTP-сервер + реальный клиент, или слой репозитория с настоящей тестовой базой данных. Эти тесты медленнее, но ловят проблемы на стыках компонентов.
</details>

---

### Вопрос 4 (14.4): Покрытие кода и CI-интеграция

Какая команда генерирует отчёт покрытия в формате LCOV для Dart-проекта?

- A) `dart coverage .`
- B) `dart test --coverage=coverage` + `dart pub global run coverage:format_coverage --lcov -i coverage -o coverage/lcov.info`
- C) `dart analyze --coverage`
- D) `dart compile --with-coverage`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `dart test --coverage=coverage` + `dart pub global run coverage:format_coverage --lcov -i coverage -o coverage/lcov.info`**

Процесс двухэтапный: сначала `dart test --coverage=coverage` запускает тесты и сохраняет сырые данные покрытия в JSON-формате в папку `coverage/`. Затем утилита `coverage:format_coverage` из пакета `coverage` конвертирует их в LCOV-формат, понятный инструментам типа Codecov или lcov HTML report.
</details>
