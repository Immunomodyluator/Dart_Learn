# Квиз: 17. Interop: FFI и Web

> 3 вопроса • Уровень: Junior–Middle • [Урок →](../lessons/17-interop.md)

---

### Вопрос 1 (17.1): Dart FFI

Почему при работе с FFI важно использовать `try/finally` вокруг нативных вызовов?

```dart
final ptr = malloc<Int32>();
try {
  ptr.value = 42;
  nativeFunction(ptr);
} finally {
  malloc.free(ptr);
}
```

- A) Это требование компилятора — без `finally` код не компилируется
- B) `malloc.free` должен быть вызван в `finally`, чтобы освободить нативную память даже при исключении: сборщик мусора Dart не управляет нативной памятью
- C) `finally` ускоряет работу с нативным кодом
- D) Это нужно только при работе с Windows API

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `malloc.free` должен быть вызван в `finally`, чтобы освободить нативную память даже при исключении**

GC Dart управляет только Dart-объектами. Память, выделенная через `malloc` (нативная C-память), должна быть освобождена вручную через `malloc.free`. Если нативный вызов бросит исключение без `finally`, память утечёт. Паттерн `try/finally` гарантирует освобождение ресурса в любом исходе.
</details>

---

### Вопрос 2 (17.2): dart:js_interop (Dart 3)

Как правильно объявить привязку к JavaScript-функции в Dart 3 с `dart:js_interop`?

```dart
@JS()
library;

import 'dart:js_interop';

// Как привязать: window.alert('hello')?
```

- A) `external void alert(String message);`
- B) ```dart
@JS('alert')
external void jsAlert(String message);
```
- C) ```dart
extension type Window(JSObject _) implements JSObject {
  external void alert(String message);
}
```
- D) `final alert = js.context['alert'] as Function;`

<details>
<summary>Правильный ответ</summary>

**Ответ: C) `extension type Window(JSObject _) implements JSObject { external void alert(String message); }`**

В Dart 3 с `dart:js_interop` рекомендуемый паттерн — `extension type` над `JSObject` с `external` методами. Это zero-cost абстракция: никакого рантайм-оверхеда, статическая типизация. Старый подход `js.context` из `dart:js` устарел и не работает в Wasm-компиляции.
</details>

---

### Вопрос 3 (17.3): Mirrors и альтернативы

Почему `dart:mirrors` не рекомендуется в продакшн-коде для Flutter/AOT?

- A) `dart:mirrors` работает слишком медленно в debug-режиме
- B) AOT-компилятор не может выполнить tree shaking: `dart:mirrors` требует сохранить весь код в рантайме, что резко увеличивает размер приложения и полностью отключает оптимизацию мёртвого кода
- C) `dart:mirrors` доступен только в Dart VM, но не поддерживается в Dart 3
- D) Mirrors несовместимы с null safety

<details>
<summary>Правильный ответ</summary>

**Ответ: B) AOT-компилятор не может выполнить tree shaking при использовании `dart:mirrors`**

`dart:mirrors` использует рефлексию в рантайме — компилятор не знает заранее, какой код будет вызван, поэтому вынужден включить в бинарnik всё. Это делает tree shaking практически невозможным. Flutter AOT и компиляция в Wasm вовсе не поддерживают `dart:mirrors`. Альтернативы: кодогенерация (`build_runner`, `source_gen`) или `Expando` для хранения метаданных.
</details>
