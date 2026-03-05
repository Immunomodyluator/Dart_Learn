# 14.2 JS interop для веба

## 1. Формальное определение

**JS interop** — механизм взаимодействия Dart-кода с JavaScript в браузерных и серверных JS-средах. Начиная с Dart 3.3, рекомендуется использовать `dart:js_interop` — новый, типобезопасный API, совместимый как с dart2js, так и с dart2wasm.

## 2. Зачем это нужно

- **Web API** — доступ к DOM, Fetch, WebSocket, Canvas и другим браузерным API.
- **JS-библиотеки** — использование npm-пакетов и существующих JS-решений.
- **Миграция** — постепенный переход с JavaScript на Dart.
- **dart2wasm** — новый компилятор требует `dart:js_interop` (старый `dart:js` не поддерживается).

## 3. Как это работает

### Новый API: dart:js_interop (Dart 3.3+)

```dart
import 'dart:js_interop';

// Привязка к глобальной JS-функции
@JS('console.log')
external void consoleLog(JSString message);

// Привязка к глобальному объекту
@JS('JSON')
external JSObject get jsonObject;

// Вызов
void main() {
  consoleLog('Hello from Dart!'.toJS);
}
```

### Привязка к JS-классу

```javascript
// JavaScript (подключён через <script>)
class Calculator {
  constructor(initialValue) {
    this.value = initialValue;
  }
  add(n) {
    this.value += n;
    return this;
  }
  result() {
    return this.value;
  }
}
```

```dart
import 'dart:js_interop';

@JS()
extension type Calculator(JSObject _) implements JSObject {
  external Calculator(int initialValue);
  external Calculator add(int n);
  external int result();
  external int value;
}

void main() {
  final calc = Calculator(10);
  calc.add(5).add(3);
  print(calc.result()); // 18
}
```

### Extension types для JS-объектов

```dart
import 'dart:js_interop';

// Описание JS-объекта через extension type
@JS()
extension type User._(JSObject _) implements JSObject {
  external String get name;
  external int get age;
  external String? get email;

  // Фабричный конструктор из JS Object literal
  external factory User({
    required String name,
    required int age,
    String? email,
  });
}

void main() {
  final user = User(name: 'Alice', age: 30);
  print(user.name); // Alice
}
```

### Работа с DOM (package:web)

```yaml
# pubspec.yaml
dependencies:
  web: ^1.0.0
```

```dart
import 'package:web/web.dart';

void main() {
  // Доступ к document
  final heading = document.createElement('h1') as HTMLHeadingElement;
  heading.textContent = 'Hello from Dart!';
  document.body?.appendChild(heading);

  // Обработка событий
  final button = document.querySelector('#myButton') as HTMLButtonElement;
  button.onClick.listen((event) {
    print('Button clicked!');
  });

  // Fetch API
  fetchData();
}

Future<void> fetchData() async {
  final response = await window.fetch('https://api.example.com/data'.toJS).toDart;
  final text = await response.text().toDart;
  print(text);
}
```

### Конверсия типов

```dart
import 'dart:js_interop';

void conversions() {
  // Dart → JS
  final jsString = 'hello'.toJS;           // JSString
  final jsNumber = 42.toJS;                // JSNumber
  final jsBool = true.toJS;                // JSBoolean
  final jsArray = <JSAny?>[1.toJS, 2.toJS, 3.toJS].toJS;  // JSArray

  // JS → Dart
  final dartString = jsString.toDart;      // String
  final dartNumber = jsNumber.toDartInt;   // int
  final dartBool = jsBool.toDart;          // bool
  final dartList = jsArray.toDart;         // List<JSAny?>
}
```

### Промисы и async

```dart
import 'dart:js_interop';

@JS('fetch')
external JSPromise<Response> _fetch(JSString url);

Future<String> fetchText(String url) async {
  final response = await _fetch(url.toJS).toDart;
  final text = await response.text().toDart;
  return text.toDart;
}
```

## 4. Старый API (deprecated)

```dart
// ⚠️ Старый подход — НЕ работает с dart2wasm
// import 'dart:js';       — deprecated
// import 'dart:js_util';  — deprecated
// import 'package:js/js.dart';  — заменён dart:js_interop

// Миграция:
// @JS()              → @JS()  (из dart:js_interop)
// @anonymous          → extension type с factory
// allowInterop()      → .toJS на Function
// promiseToFuture()   → JSPromise.toDart
```

## 5. Условный импорт (платформенный код)

```dart
// Код, работающий и на Web, и на Native

// lib/http_client.dart
export 'http_client_stub.dart'
    if (dart.library.io) 'http_client_native.dart'
    if (dart.library.js_interop) 'http_client_web.dart';
```

```dart
// lib/http_client_native.dart
import 'dart:io';
String fetchSync(String url) => HttpClient()...;
```

```dart
// lib/http_client_web.dart
import 'dart:js_interop';
import 'package:web/web.dart';
String fetchSync(String url) => ...; // Web реализация
```

## 6. Распространённые ошибки

### ❌ Использование dart:js с dart2wasm

```dart
// Плохо — dart:js не поддерживается в wasm
import 'dart:js';

// Хорошо — dart:js_interop работает везде на Web
import 'dart:js_interop';
```

### ❌ Забытая конверсия типов

```dart
// Плохо — передаём Dart String напрямую
consoleLog('hello');  // Ошибка типов!

// Хорошо — конвертируем в JS-тип
consoleLog('hello'.toJS);
```

### ❌ Не подключён JS-скрипт

```html
<!-- index.html — JS-библиотека должна быть загружена ДО Dart -->
<script src="calculator.js"></script>
<script src="main.dart.js" defer></script>
```

---

> **Назад:** [14.1 Dart FFI](14_01_ffi.md) · **Далее:** [14.3 Ограничения рефлексии](14_03_reflection.md)
