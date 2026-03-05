# 16.1 Структура проекта и модули

## 1. Формальное определение

**Модуль** в Dart — это библиотека (один или несколько файлов, связанных через `part`/`part of` или `export`). Каждый `.dart` файл — это библиотека. **Пакет** — это директория с `pubspec.yaml`, содержащая одну или несколько библиотек.

## 2. Зачем это нужно

- **Навигация** — разработчик быстро находит нужный код.
- **Масштабирование** — структура растёт предсказуемо.
- **Инкапсуляция** — `src/` скрывает реализацию, barrel-файл экспортирует API.
- **Тестируемость** — слои можно тестировать независимо.

## 3. Типовая структура

### Простое приложение

```
my_app/
├── bin/
│   └── main.dart                  ← точка входа
├── lib/
│   ├── my_app.dart                ← barrel-файл (API пакета)
│   └── src/
│       ├── models/
│       │   ├── user.dart
│       │   └── product.dart
│       ├── services/
│       │   ├── auth_service.dart
│       │   └── api_client.dart
│       └── utils/
│           └── validators.dart
├── test/
│   ├── models/
│   │   └── user_test.dart
│   └── services/
│       └── auth_service_test.dart
├── pubspec.yaml
└── analysis_options.yaml
```

### Слоёная архитектура

```
my_app/
├── lib/
│   └── src/
│       ├── data/                  ← Слой данных
│       │   ├── repositories/
│       │   │   └── user_repository_impl.dart
│       │   ├── data_sources/
│       │   │   ├── user_remote_ds.dart
│       │   │   └── user_local_ds.dart
│       │   └── models/
│       │       └── user_dto.dart
│       │
│       ├── domain/                ← Бизнес-логика
│       │   ├── entities/
│       │   │   └── user.dart
│       │   ├── repositories/
│       │   │   └── user_repository.dart  ← абстракция
│       │   └── usecases/
│       │       ├── get_user.dart
│       │       └── update_user.dart
│       │
│       └── presentation/         ← UI / CLI / API
│           ├── controllers/
│           │   └── user_controller.dart
│           └── views/
│               └── user_view.dart
```

### Монорепо

```
my_project/
├── packages/
│   ├── core/                     ← Общие модели, утилиты
│   │   ├── lib/
│   │   └── pubspec.yaml
│   ├── api_client/               ← HTTP-клиент
│   │   ├── lib/
│   │   └── pubspec.yaml
│   ├── auth/                     ← Аутентификация
│   │   ├── lib/
│   │   └── pubspec.yaml
│   └── app/                      ← Приложение
│       ├── lib/
│       └── pubspec.yaml
└── melos.yaml
```

## 4. Barrel-файлы и экспорт

```dart
// lib/my_package.dart — barrel-файл
// Единственный файл, который импортируют потребители

export 'src/models/user.dart';
export 'src/models/product.dart';
export 'src/services/auth_service.dart';
// НЕ экспортируем внутренние утилиты

// Условный экспорт
export 'src/platform/platform_io.dart'
    if (dart.library.js_interop) 'src/platform/platform_web.dart';
```

```dart
// Использование потребителем:
import 'package:my_package/my_package.dart';
// Получает доступ только к экспортированным классам
```

### show и hide

```dart
// Импорт конкретных символов
import 'package:my_package/my_package.dart' show User, Product;

// Импорт всего, кроме указанных
import 'package:my_package/my_package.dart' hide InternalHelper;

// Префикс для избежания конфликтов
import 'package:http/http.dart' as http;
final response = await http.get(uri);
```

## 5. Приватность в Dart

```dart
// _ делает символ приватным на уровне БИБЛИОТЕКИ (не класса)

// lib/src/models/user.dart
class User {
  final String name;
  final int _internalId;  // приватный для user.dart

  User(this.name, this._internalId);
}

class _Helper {  // приватный класс — виден только в user.dart
  static String format(String s) => s.trim();
}

// Другой файл в lib/src/ НЕ видит _internalId и _Helper
// (если не связан через part/part of)
```

## 6. Правила организации

```
┌──────────── Правила ──────────────────────────────┐
│                                                    │
│  1. Один класс/enum — один файл                    │
│     user.dart, product.dart (не models.dart)        │
│                                                    │
│  2. Имя файла = snake_case имени класса            │
│     UserRepository → user_repository.dart           │
│                                                    │
│  3. Тесты зеркалят структуру lib/                  │
│     lib/src/services/auth.dart                     │
│     → test/services/auth_test.dart                 │
│                                                    │
│  4. Не импортируйте из lib/src/ чужого пакета      │
│     Используйте только barrel-файл                 │
│                                                    │
│  5. Зависимости направлены внутрь                  │
│     presentation → domain ← data                   │
│     domain НЕ зависит от data и presentation       │
│                                                    │
└────────────────────────────────────────────────────┘
```

---

> **Назад:** [16.0 Обзор](16_00_overview.md) · **Далее:** [16.2 Dependency Injection](16_02_di.md)
