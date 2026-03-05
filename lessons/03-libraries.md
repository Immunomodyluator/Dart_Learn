# Урок 3. Библиотеки и импорты

> Охватывает подтемы: 3.1 import/export/show/hide, 3.2 Deferred imports, 3.3 part/part of/library

---

## 1. Формальное определение

В Dart **библиотека** — основная единица инкапсуляции и распространения кода. Каждый `.dart`-файл является библиотекой по умолчанию. Система библиотек определяет:

- **Видимость**: идентификаторы, начинающиеся с `_`, приватны в пределах библиотеки (не класса!)
- **Импорт**: `import` подключает внешние библиотеки
- **Экспорт**: `export` переэкспортирует идентификаторы из других файлов
- **Deferred loading**: ленивая загрузка для оптимизации первоначального размера

Уровень: **модульная система, видимость, организация кода**.

---

## 2. Зачем это нужно

**Проблемы, которые решает система библиотек:**

- **Инкапсуляция**: `_privateField` недоступен за пределами файла/библиотеки — никаких `private`/`protected` ключевых слов
- **Пространства имён**: два пакета могут экспортировать `Client` — `as` разрешает конфликты
- **Структурирование**: `export` в одном публичном файле скрывает внутреннюю структуру пакета
- **Deferred loading**: Flutter web загружает редко используемые модули только при необходимости

**Сценарии:**
- **Пакет** — один `lib/my_package.dart` экспортирует всё, внутренние файлы скрыты
- **Flutter**: ленивая загрузка экранов/фич для уменьшения First Contentful Paint
- **Серверный Dart**: изоляция модулей по функциональности

---

## 3. Как это работает

### import

```dart
// Встроенные библиотеки Dart — схема dart:
import 'dart:math';
import 'dart:io';
import 'dart:collection';

// Пакеты из pub.dev — схема package:
import 'package:http/http.dart';
import 'package:path/path.dart';

// Относительные пути — для файлов внутри проекта
import '../models/user.dart';
import 'utils/validator.dart';
```

### show и hide — контроль видимости

```dart
// show — импортировать только указанные идентификаторы
import 'dart:math' show Random, pi, cos;

// hide — импортировать всё кроме указанных
import 'dart:convert' hide Codec;

// as — псевдоним для разрешения конфликтов
import 'package:http/http.dart' as http;
import 'dart:html' as html;  // Для web-приложений

void main() {
  var rng = Random();
  http.get(Uri.parse('https://example.com'));
}
```

### export — публичный API пакета

Конвенция: один файл `lib/my_package.dart` реэкспортирует публичные части:

```dart
// lib/my_package.dart — публичный фасад пакета
export 'src/client.dart';
export 'src/models.dart' show User, Product;       // только эти классы
export 'src/exceptions.dart' hide InternalError;   // всё кроме InternalError
```

Пользователю пакета достаточно одного `import 'package:my_package/my_package.dart'` — внутренняя структура `src/` для него скрыта.

### Приватность через `_`

```dart
// user.dart
class User {
  final String name;
  String _passwordHash;  // Приватно для ФАЙЛА user.dart, не для класса

  User(this.name, String password)
      : _passwordHash = _hash(password);

  static String _hash(String input) => /* ... */;  // Приватная функция файла
}

// Другой файл в той же библиотеке (через part) может видеть _hash
// Другой файл вне библиотеки — нет
```

---

## 4. Минимальный пример

```dart
// lib/src/math_utils.dart
double _square(double x) => x * x;  // приватная для файла

double hypotenuse(double a, double b) => 
    import 'dart:math'; // нельзя внутри файла — import всегда вверху

// Правильно:
import 'dart:math';

double hypotenuse(double a, double b) => sqrt(_square(a) + _square(b));
```

```dart
// bin/main.dart
import 'dart:math' show sqrt, pi;
import 'package:my_package/my_package.dart' as pkg;

void main() {
  print(sqrt(16));          // 4.0 — из dart:math
  print(pi.toStringAsFixed(5)); // 3.14159
  pkg.hypotenuse(3, 4);    // 5.0 — через псевдоним
}
```

---

## 5. Практический пример

Структура пакета с правильной организацией публичного API:

```
lib/
├── my_http_client.dart      ← публичный фасад
└── src/
    ├── client.dart          ← основной клиент
    ├── request.dart         ← модели запросов
    ├── response.dart        ← модели ответов
    └── _internal/           ← вообще не экспортировать
        └── retry_logic.dart
```

```dart
// lib/my_http_client.dart — ПУБЛИЧНЫЙ API
library my_http_client;  // Опциональное имя библиотеки (метаданные)

export 'src/client.dart';
export 'src/request.dart' show Request, RequestBuilder;
export 'src/response.dart' show Response, StatusCode;
// src/_internal/ НЕ экспортируется — детали реализации
```

```dart
// lib/src/client.dart
import 'dart:io';
import 'package:my_http_client/src/request.dart';  // Относительный — можно

class HttpClient {
  final Duration _timeout;  // Приватно — не утекает в публичный API

  const HttpClient({Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 30);

  Future<Response> send(Request request) async {
    // ...
  }
}
```

```dart
// Пользователь пакета
import 'package:my_http_client/my_http_client.dart';  // Один импорт — всё доступно

void main() async {
  final client = HttpClient();
  final response = await client.send(Request.get('https://api.example.com'));
}
```

**Архитектурная корректность:** пользователь пакета не зависит от внутренней структуры `src/`. Изменение структуры файлов внутри `src/` не ломает API.

---

## 6. Deferred imports (ленивая загрузка)

Актуально для **Dart web** и Flutter web — уменьшает начальный размер JavaScript-бандла:

```dart
import 'dart:collection';  // Обычный — загружается сразу

// deferred as — загружается при первом вызове loadLibrary()
import 'package:heavy_chart_library/charts.dart' deferred as charts;

Future<void> showChart(List<double> data) async {
  await charts.loadLibrary(); // Реальная загрузка происходит здесь
  charts.render(data);        // Теперь доступно
}
```

**Ограничения deferred:**
- Нельзя использовать типы из deferred-библиотеки в аннотациях до `loadLibrary()`
- В мобильном Flutter — нет эффекта (весь код компилируется в AOT)
- `loadLibrary()` можно вызывать многократно — загружается только один раз

---

## 7. part и part of — разбиение библиотеки

`part`/`part of` позволяет разбить одну библиотеку на несколько файлов с общей приватностью:

```dart
// lib/src/complex_module.dart — головной файл библиотеки
library complex_module;

part 'complex_module_io.dart';   // файл становится частью этой библиотеки
part 'complex_module_math.dart';

class PublicClass {
  final _InternalHelper _helper = _InternalHelper(); // _InternalHelper из part-файла
}
```

```dart
// lib/src/complex_module_io.dart
part of 'complex_module.dart';  // Указываем родителя (с Dart 2 — путь, не имя)

class _InternalHelper {
  // Виден для PublicClass в complex_module.dart и complex_module_math.dart
}
```

**Важно:** `part`/`part of` — **устаревший паттерн** для ручного кода. Сейчас используется **только в кодогенерации** (`build_runner`, `freezed`, `json_serializable` генерируют `.g.dart` файлы через `part`). Для ручной организации кода предпочтительнее обычные `import`/`export`.

---

## 8. Что происходит под капотом

### Compilation units

Dart компилирует каждую библиотеку как отдельную **compilation unit**. При `import` компилятор:
1. Находит файл по URI
2. Компилирует это в Kernel IR (`.dill`)
3. Линкует в общее дерево

### Canonicalization идентификаторов

```dart
import 'package:foo/foo.dart' as a;
import 'package:foo/foo.dart' as b;
// a.MyClass и b.MyClass — одно и то же: идентичные объекты-классы
print(identical(a.MyClass, b.MyClass)); // true
```

Dart не дублирует библиотеки — один экземпляр библиотеки в пределах изолята.

### show/hide

Это **compile-time** ограничение, не runtime. `hide` не удаляет код из программы — он просто недоступен по имени. Для реального treeshaking нужен AOT-компилятор.

---

## 9. Производительность и ресурсы

**Эффективность:**
- `deferred` реально уменьшает размер initial JS-бандла на web
- `show` помогает IDE и анализатору быстрее резолвить имена

**Узкие места:**
- Сотни `import` на уровне одного файла нарушают архитектуру — признак отсутствия слоёв
- Circular imports (`a.dart` импортирует `b.dart`, `b.dart` импортирует `a.dart`) — ошибка компиляции в большинстве случаев; исправляется выделением общего третьего файла

---

## 10. Частые ошибки и антипаттерны

**1. Импорт `src/` напрямую из другого пакета:**
```dart
// НЕВЕРНО — нарушает публичный API контракт пакета
import 'package:some_package/src/internal_class.dart';

// ВЕРНО — только публичный API
import 'package:some_package/some_package.dart';
```

**2. Использование `part`/`part of` вручную:**
```dart
// УСТАРЕЛО для нового кода — не делайте так
part 'my_helper.dart';

// ВЕРНО — обычные файлы с import
import 'my_helper.dart';
```

**3. Конфликт имён без псевдонима:**
```dart
// НЕВЕРНО — два Response класса — компилятор выберет непредсказуемо
import 'package:dio/dio.dart';
import 'package:http/http.dart';

// ВЕРНО — псевдонимы
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;
```

**4. Экспорт внутренних деталей:**
```dart
// НЕВЕРНО — утекает детали реализации
export 'src/_internal_cache.dart';

// ВЕРНО — только публичный контракт
export 'src/public_api.dart';
```

---

## 11. Сравнение с альтернативами

| Аспект | Dart | Java | TypeScript | Kotlin |
|---|---|---|---|---|
| Единица приватности | Файл (библиотека) | Класс / пакет | Модуль | Файл / пакет |
| Namespace | `import as` | Пакеты | `import * as` | Пакеты |
| Ленивая загрузка | `deferred as` | Нет | Dynamic import | Нет встроенной |
| Круговые зависимости | Ошибка | Допустимо | Предупреждение | Допустимо |
| Приватный `_` | Уровень файла | `private` = класс | `private` = класс | `private` = класс |

**Особенность Dart:** `_` приватность на уровне _файла_, а не класса — это мощнее для инкапсуляции в рамках модуля, но нужна дисциплина.

---

## 12. Когда НЕ стоит использовать deferred imports

- **Нативный Flutter (iOS/Android)** — никакого эффекта, AOT компилирует всё
- **Маленькие утилиты** — накладные расходы на `await loadLibrary()` не оправданы
- **Hot path** — библиотеки, нужные сразу при старте приложения

---

## 13. Краткое резюме

1. **`_` = приватность на уровне файла** (библиотеки), не класса — это уникальная модель Dart.
2. **`export` в одном фасадном файле** — стандартный паттерн для пакетов; пользователю не видна внутренняя структура `src/`.
3. **`as` псевдонимы** решают конфликты имён — обязательны при одновременном использовании нескольких HTTP-клиентов, HTML/IO библиотек.
4. **`show`/`hide`** — точный контроль над импортируемым пространством имён, помогает IDE и уменьшает когнитивную нагрузку.
5. **`deferred as`** — только для Flutter/Dart web, бессмысленно в нативных AOT-бинарниках.
6. **`part`/`part of` только для кодогенерации** — вручную не использовать, это паттерн инструментов (`freezed`, `json_serializable`).
7. **Circular imports — ошибка**: при появлении рефакторить немедленно — выделить общий контракт в третий файл.
