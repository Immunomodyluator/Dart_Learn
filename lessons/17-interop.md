# Урок 17. Interop: FFI и Web

> Охватывает подтемы: 17.1 Dart FFI (native), 17.2 JS Interop (dart:js_interop), 17.3 Ограничения

---

## 1. Формальное определение

**Interop** — механизмы взаимодействия Dart с нативным кодом и другими платформами:

- **Dart FFI** (`dart:ffi`) — вызов C/C++ функций напрямую без JNI/JNA; доступен на VM (CLI, Flutter mobile/desktop)
- **`dart:js_interop`** — типобезопасное взаимодействие с JavaScript (Dart 3); заменяет устаревший `dart:js`
- **`package:js`** — legacy аннотации для JS interop (устаревает в пользу `dart:js_interop`)
- **Platform Channels** (Flutter) — взаимодействие с Android/iOS через message passing

Уровень: **платформенная интеграция**.

---

## 2. Зачем это нужно

- **FFI**: Использовать нативные библиотеки (OpenSSL, SQLite, libgit2) без написания platform channels
- **JS interop**: Использовать JS библиотеки в Dart Web; интегрировать Dart в существующий JS проект
- Производительность нативного кода при необходимости

---

## 3. Dart FFI (17.1)

```dart
import 'dart:ffi';
import 'dart:io';

// Пример: вызов C функции strlen
// Объявляем C типы
typedef StrlenC = Uint64 Function(Pointer<Utf8>);
typedef StrlenDart = int Function(Pointer<Utf8>);

// Пример: полный сценарий с DynamicLibrary
void ffiExample() {
  // Загружаем библиотеку
  final dylib = switch (Platform.operatingSystem) {
    'windows' => DynamicLibrary.open('libmylib.dll'),
    'macos' => DynamicLibrary.open('libmylib.dylib'),
    _ => DynamicLibrary.open('libmylib.so'),
  };

  // Находим функцию
  final strlen = dylib.lookupFunction<StrlenC, StrlenDart>('strlen');

  // Работа со строками
  final str = 'Hello'.toNativeUtf8();
  try {
    final length = strlen(str);
    print('Length: $length'); // 5
  } finally {
    calloc.free(str); // ОБЯЗАТЕЛЬНО освобождать память
  }
}

// Работа со структурами C
final class Point extends Struct {
  @Double()
  external double x;

  @Double()
  external double y;
}

typedef CreatePointC = Pointer<Point> Function(Double x, Double y);
typedef CreatePointDart = Pointer<Point> Function(double x, double y);

void structExample(DynamicLibrary lib) {
  final createPoint = lib.lookupFunction<CreatePointC, CreatePointDart>('create_point');
  
  final pointPtr = createPoint(3.0, 4.0);
  print('Point: (${pointPtr.ref.x}, ${pointPtr.ref.y})');
  
  calloc.free(pointPtr); // освобождаем
}

// Callback из C в Dart (NativeCallable)
typedef CallbackC = Void Function(Int32 result);

void registerCallback(DynamicLibrary lib) {
  // Создаём Dart callback который C может вызвать
  final callback = NativeCallable<CallbackC>.listener(
    (int result) => print('Callback called with: $result'),
  );
  
  final registerFunc = lib.lookupFunction<
    Void Function(Pointer<NativeFunction<CallbackC>>),
    void Function(Pointer<NativeFunction<CallbackC>>)
  >('register_callback');
  
  registerFunc(callback.nativeFunction);
  // callback.close() когда больше не нужен
}

// Inline C через ffigen
// dart pub add ffigen --dev
// ffigen генерирует Dart bindings из заголовочных файлов .h
```

```yaml
# ffigen.yaml — конфигурация для генерации bindings
name: 'NativeLibrary'
description: 'Bindings for libexample'
output: 'lib/src/native_library.dart'
headers:
  entry-points:
    - 'native/include/example.h'
preamble: |
  // AUTO-GENERATED - DO NOT MODIFY
```

---

## 4. JS Interop dart:js_interop (17.2)

```dart
// web/main.dart
import 'dart:js_interop';

// Объявляем внешние JS типы через extension type
@JS()
extension type Window._(JSObject _) implements JSObject {
  external String get location;
  external void alert(String message);
  
  // Работа с localStorage
  external Storage get localStorage;
}

@JS()
extension type Storage._(JSObject _) implements JSObject {
  external void setItem(String key, String value);
  external String? getItem(String key);
  external void removeItem(String key);
}

// Глобальные JS объекты
@JS('window')
external Window get window;

@JS('console')
external Console get jsConsole;

@JS()
extension type Console._(JSObject _) implements JSObject {
  external void log(JSAny? value);
  external void error(JSAny? value);
}

// Вызов JS
void interopExample() {
  window.alert('Hello from Dart!');
  window.localStorage.setItem('key', 'value');
  
  final value = window.localStorage.getItem('key');
  print(value); // 'value'
  
  jsConsole.log('Dart says hi'.toJS); // преобразуем String в JSString
}

// Конвертация типов
void typeConversions() {
  // Dart → JS
  final jsStr = 'hello'.toJS;         // JSString
  final jsNum = 42.toJS;              // JSNumber
  final jsBool = true.toJS;           // JSBoolean
  final jsList = [1, 2, 3].toJS;      // JSArray (нет автоматического)
  
  // JS → Dart
  final dartStr = jsStr.toDart;       // String
  final dartNum = jsNum.toDartInt;    // int
  final dartBool = jsBool.toDart;     // bool
}

// Использование JS библиотек (например, Chart.js)
@JS('Chart')
extension type ChartJS._(JSObject _) implements JSObject {
  external factory ChartJS(JSObject canvas, JSObject config);
  external void destroy();
}

// interop с Promise → Future
@JS('fetch')
external JSPromise<JSResponse> jsFetch(String url);

@JS()
extension type JSResponse._(JSObject _) implements JSObject {
  external JSPromise<JSString> text();
  external JSPromise<JSObject> json();
}

Future<String> dartFetch(String url) async {
  final response = await jsFetch(url).toDart;
  final text = await response.text().toDart;
  return text.toDart;
}
```

---

## 5. Legacy пакет js (устаревает)

```dart
// DEPRECATED для новых проектов — используйте dart:js_interop
@JS()
library interop;

import 'package:js/js.dart';

@JS('window.location.href')
external String get windowLocationHref;

@JS('Date')
class JsDate {
  external JsDate();
  external int getTime();
  external String toISOString();
}

// allowInterop — оборачивает Dart callback для передачи в JS
import 'dart:js_util';

void legacyCallback() {
  final jsCallback = allowInterop((int n) => print('Got: $n'));
}
```

---

## 6. Platform Channels (Flutter-специфика)

```dart
// Dart сторона
import 'package:flutter/services.dart';

class BatteryLevel {
  static const _channel = MethodChannel('com.example/battery');

  static Future<int> getBatteryLevel() async {
    try {
      final level = await _channel.invokeMethod<int>('getBatteryLevel');
      return level ?? -1;
    } on PlatformException catch (e) {
      throw Exception('Platform error: ${e.message}');
    }
  }
}

// Kotlin сторона (Android) — отдельный файл
// MethodChannel("com.example/battery").setMethodCallHandler { call, result ->
//   when (call.method) {
//     "getBatteryLevel" -> result.success(getBatteryLevel())
//     else -> result.notImplemented()
//   }
// }
```

---

## 7. Минимальный пример FFI: SQLite

```dart
// Упрощённый пример связи с SQLite через FFI
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart'; // helper пакет для calloc, Utf8, etc.

// В реальности используют sqlite3 пакет, который уже делает это за вас
void sqliteExample() {
  final sqlite = DynamicLibrary.open(
    Platform.isWindows ? 'sqlite3.dll' : 
    Platform.isMacOS ? '/usr/lib/libsqlite3.dylib' : 'libsqlite3.so',
  );

  // Находим sqlite3_libversion
  final versionFunc = sqlite.lookupFunction<
    Pointer<Utf8> Function(),
    Pointer<Utf8> Function()
  >('sqlite3_libversion');

  final version = versionFunc().toDartString();
  print('SQLite version: $version');
}
```

---

## 8. Под капотом

### FFI механизм

- **AOT**: вызов C функции — прямой machine-code call; нет VM overhead
- **JIT**: небольшой overhead на первый вызов (JIT-компиляция FFI call stub)
- **Memory**: FFI не использует GC для нативной памяти → ручное управление через `calloc`/`malloc`/`free`
- Структуры (`Struct`, `Union`) маппятся напрямую на C memory layout

### dart2js и JS interop

- `dart:js_interop` компилируется dart2js/Wasm в нативные JS вызовы без overhead
- Extension types ≡ zero-cost → нет дополнительных объектов

---

## 9. Производительность

- **FFI** — нативная скорость; overhead только на Dart→C→Dart переход (~несколько ns)
- **JS interop** — нативные JS операции; не через eval или медленные bridges
- **Аллокация нативной памяти** через `calloc` — больше накладных расходов чем GC память
- **`Isolate.run`** + FFI — CPU-intensive нативный код не блокирует UI Isolate

---

## 10. Частые ошибки

**1. Утечка нативной памяти:**
```dart
// НЕВЕРНО
final ptr = calloc<Int32>(); // выделили
ptr.value = 42;
// calloc.free(ptr) — ЗАБЫЛИ! Утечка памяти

// ВЕРНО
final ptr = calloc<Int32>();
try {
  ptr.value = 42;
  useValue(ptr.value);
} finally {
  calloc.free(ptr); // ВСЕГДА в finally
}
```

**2. Передача Dart String напрямую в C:**
```dart
// НЕВЕРНО — String в Dart не null-terminated C string
strlen(str.toNativeUtf8()); // правильно
strlen('hello'); // ОШИБКА типа

// ВЕРНО — преобразовать в Utf8/Latin1
final nativeStr = str.toNativeUtf8();
try {
  return strlen(nativeStr);
} finally {
  calloc.free(nativeStr);
}
```

**3. Использование `dart:js` вместо `dart:js_interop`:**
```dart
// Устаревшее (не работает с Wasm target)
import 'dart:js'; // deprecated

// Верно для Dart 3+
import 'dart:js_interop'; // поддерживает и JS и Wasm
```

---

## 11. Ограничения (17.3)

| Аспект | FFI | JS Interop |
|---|---|---|
| Платформы | VM (CLI, Flutter mobile/desktop) | Только Web |
| Flutter Web | ❌ | ✓ |
| GC | Нативная память — вручную | Управляет JS GC |
| Thread safety | Осторожно с Isolates | Single-threaded JS |
| Debug | Сложнее | DevTools |
| Абстракция | Низкая (C ABI) | Средняя |

---

## 12. Краткое резюме

1. **Dart FFI** (`dart:ffi`) — прямой вызов C/C++ функций; нативная скорость; ручное управление памятью
2. **`ffigen`** — генерирует Dart bindings из `.h` заголовочных файлов автоматически
3. **`calloc.free(ptr)`** в `finally` — обязательно; иначе утечка нативной памяти
4. **`dart:js_interop`** (Dart 3) — типобезопасный JS interop; работает с Wasm; использует extension types
5. **`dart:js`** устарел — мигрируйте на `dart:js_interop`
6. **`JSPromise.toDart`** конвертирует JS Promise в Dart Future
7. **Flutter Platform Channels** — для взаимодействия Dart/Kotlin/Swift в мобильных приложениях
