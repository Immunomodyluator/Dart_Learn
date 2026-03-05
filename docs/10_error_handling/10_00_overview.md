# 10. Обработка ошибок и безопасный код — обзор

## О чём этот раздел

Dart разделяет ошибки на **Exception** (восстановимые: сеть, формат, бизнес-логика) и **Error** (программистские баги: null access, range, assertion). Правильная стратегия обработки ошибок — ключ к надёжному production-коду.

## Ключевые темы

| Тема                           | Файл                                                       | Описание                                                 |
| ------------------------------ | ---------------------------------------------------------- | -------------------------------------------------------- |
| try / catch / finally          | [10_01_try_catch.md](10_01_try_catch.md)                   | Блоки обработки, `on`, `rethrow`, `Error` vs `Exception` |
| Пользовательские исключения    | [10_02_custom_exceptions.md](10_02_custom_exceptions.md)   | Создание собственных типов ошибок                        |
| Практики ретраев и компенсации | [10_03_retry_compensation.md](10_03_retry_compensation.md) | Повторные попытки, circuit breaker, откат                |
| Логирование и мониторинг       | [10_04_logging.md](10_04_logging.md)                       | Сбор, структурирование и отправка ошибок                 |

## Иерархия ошибок в Dart

```
Object
├── Exception (восстановимые)
│   ├── FormatException
│   ├── IOException
│   │   ├── FileSystemException
│   │   ├── HttpException
│   │   └── SocketException
│   ├── TimeoutException
│   ├── IntegerDivisionByZeroException
│   └── StateError? ← на самом деле Error!
│
└── Error (программистские баги)
    ├── TypeError
    ├── ArgumentError
    │   └── RangeError
    ├── StateError
    ├── UnsupportedError
    ├── UnimplementedError
    ├── AssertionError
    ├── ConcurrentModificationError
    ├── StackOverflowError
    └── OutOfMemoryError
```

### Правило

- **Exception** → ловите и обрабатывайте (`try/catch`).
- **Error** → исправляйте код; обычно не ловите.

### Быстрый пример

```dart
void main() {
  // Exception — восстановимая ситуация
  try {
    final number = int.parse('abc');
  } on FormatException catch (e) {
    print('Неверный формат: $e');
    // Можно восстановиться: показать ошибку пользователю
  }

  // Error — баг в коде
  try {
    final list = [1, 2, 3];
    print(list[10]); // RangeError
  } on RangeError catch (e) {
    print('Баг: $e');
    // Исправьте код, а не ловите Error
  }
}
```

## Стратегии обработки ошибок

| Стратегия         | Когда                     | Пример                               |
| ----------------- | ------------------------- | ------------------------------------ |
| Catch & recover   | Ожидаемые ошибки          | Файл не найден → default config      |
| Catch & rethrow   | Логирование + propagation | Логируем ошибку, пробрасываем выше   |
| Catch & transform | Смена типа ошибки         | IOException → AppException           |
| Let it crash      | Баги (Error)              | AssertionError → fix the code        |
| Retry             | Transient ошибки          | Сетевой таймаут → retry 3 раза       |
| Fallback          | Деградация                | API недоступно → кешированные данные |

## Порядок изучения

1. **try/catch/finally** → базовая механика.
2. **Пользовательские исключения** → типизированные ошибки.
3. **Retry и компенсация** → паттерны устойчивости.
4. **Логирование** → мониторинг в production.

---

> **Назад:** [9.5 Цикл событий и микрозадачи](../09_async/09_05_event_loop.md) · **Далее:** [10.1 try / catch / finally](10_01_try_catch.md)
