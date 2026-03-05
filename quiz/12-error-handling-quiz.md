# Квиз: 12. Обработка ошибок и безопасный код

> 4 вопроса • Уровень: Junior–Middle • [Урок →](../lessons/12-error-handling.md)

---

### Вопрос 1 (12.1): try / catch / finally

Что выведет этот код?

```dart
void main() {
  try {
    throw Exception('oops');
  } catch (e) {
    print('caught: $e');
    return;
  } finally {
    print('finally');
  }
}
```

- A) `caught: Exception: oops`
- B) `caught: Exception: oops`, затем `finally`
- C) `finally`, затем `caught: Exception: oops`
- D) Только `caught: Exception: oops`, блок `finally` пропускается из-за `return`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `caught: Exception: oops`, затем `finally`**

Блок `finally` выполняется **всегда** — независимо от того, было ли исключение, был ли вызван `return`, `break` или `continue`. `return` в `catch` не пропускает `finally`. Это гарантирует выполнение кода очистки (закрытие ресурсов и т.п.).
</details>

---

### Вопрос 2 (12.2): Пользовательские исключения

Что из перечисленного — правильный способ объявить кастомное исключение в Dart?

- A) `class MyException extends Error { ... }`
- B) `class MyException implements Exception { final String message; const MyException(this.message); }`
- C) `exception class MyException { ... }`
- D) `class MyException throws Exception { ... }`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `class MyException implements Exception { final String message; const MyException(this.message); }`**

Конвенция Dart: пользовательские исключения реализуют интерфейс `Exception` (через `implements`). `Error` — для неисправимых ошибок программиста (не для бизнес-логики). Ключевых слов `exception class` и `throws` в Dart нет. `const` конструктор позволяет создавать исключения как константы.
</details>

---

### Вопрос 3 (12.3): Практики ретраев и компенсации

Что означает паттерн `on SocketException catch (e)` в блоке `try`?

- A) Поймать любое исключение и проверить, является ли оно `SocketException`
- B) Поймать только исключения типа `SocketException` (и его подтипов), остальные пройдут дальше
- C) Поймать исключение и автоматически конвертировать его в `SocketException`
- D) Синтаксическая ошибка: `on` нельзя использовать с `catch`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Поймать только исключения типа `SocketException` (и его подтипов), остальные пройдут дальше**

В Dart `on T` — типизированный перехватчик: выполняется только если брошенный объект является экземпляром `T`. Если тип не совпадает, исключение поднимается дальше по стеку. Можно комбинировать: `on SocketException catch (e)` — и типизировать, и получить ссылку.
</details>

---

### Вопрос 4 (12.4): Логирование и мониторинг ошибок

Что делает `runZonedGuarded`?

- A) Запускает код в отдельном Isolate с обработкой ошибок
- B) Оборачивает код в Zone с перехватчиком необработанных ошибок; позволяет глобально ловить ошибки из async-кода, которые иначе были бы потеряны
- C) Аналог `try/catch`, но только для синхронного кода
- D) Перезапускает приложение при любой необработанной ошибке

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Оборачивает код в Zone с перехватчиком необработанных ошибок; позволяет глобально ловить ошибки из async-кода, которые иначе были бы потеряны**

`runZonedGuarded(body, onError)` создаёт Zone — контекст выполнения. Все необработанные ошибки внутри Zone (в т.ч. из async кода, нелог Future) попадают в callback `onError`. Это стандартный способ централизованного логирования ошибок в Dart-сервере или Flutter-приложении.
</details>
