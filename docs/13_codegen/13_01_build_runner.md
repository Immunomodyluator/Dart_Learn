# 13.1 build_runner: основы

## 1. Формальное определение

**build_runner** — пакет Dart, предоставляющий CLI для запуска **Builder**'ов — модулей, которые читают исходные файлы и генерируют новые. Это стандартный механизм кодогенерации в экосистеме Dart.

**Builder** — объект, реализующий интерфейс `Builder` из пакета `build`. Он получает на вход `BuildStep` с доступом к исходному файлу и записывает результат в выходной файл (обычно `.g.dart` или `.freezed.dart`).

## 2. Зачем это нужно

- **Без рефлексии** — Dart не поддерживает `dart:mirrors` в AOT-режиме; генерация кода — основная альтернатива.
- **Типобезопасность** — сгенерированный код проверяется компилятором.
- **Производительность** — нет overhead'а runtime-рефлексии.
- **Стандартизация** — единый инструмент для всех генераторов.

## 3. Как это работает

### Установка

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.4.0
  # + конкретный генератор, например:
  json_serializable: ^6.7.0
  json_annotation: ^4.9.0 # часто нужен в dependencies
```

```bash
dart pub get
```

### Основные команды

```bash
# Однократная генерация
dart run build_runner build

# С удалением конфликтующих файлов
dart run build_runner build --delete-conflicting-outputs

# Watch-режим: пересобирает при изменении файлов
dart run build_runner watch

# Очистка всех сгенерированных файлов
dart run build_runner clean
```

### Процесс работы

```
┌─────────────────────────────────────────────────────┐
│                  build_runner                        │
│                                                     │
│  1. Сканирует файлы проекта                        │
│  2. Находит файлы, соответствующие фильтрам Builder │
│  3. Передаёт каждый файл соответствующему Builder   │
│  4. Builder читает AST / аннотации                  │
│  5. Builder генерирует выходной файл (.g.dart)      │
│  6. build_runner записывает результат               │
│                                                     │
│  user.dart ──► [json_serializable] ──► user.g.dart  │
│  state.dart ─► [freezed]          ──► state.freezed │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Пример: json_serializable

```dart
// lib/models/user.dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';  // ← Указывает на сгенерированный файл

@JsonSerializable()
class User {
  final String name;
  final int age;
  final String? email;

  User({required this.name, required this.age, this.email});

  // Фабричный конструктор — вызывает сгенерированную функцию
  factory User.fromJson(Map<String, dynamic> json) =>
      _$UserFromJson(json);

  // Метод сериализации — вызывает сгенерированную функцию
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

```bash
# Генерация
dart run build_runner build
```

```dart
// lib/models/user.g.dart (сгенерирован автоматически)
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

User _$UserFromJson(Map<String, dynamic> json) => User(
      name: json['name'] as String,
      age: (json['age'] as num).toInt(),
      email: json['email'] as String?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'name': instance.name,
      'age': instance.age,
      'email': instance.email,
    };
```

## 4. Конфигурация build.yaml

Файл `build.yaml` в корне проекта позволяет настроить генераторы:

```yaml
# build.yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          # Не включать поля со значением null
          include_if_null: false
          # Использовать snake_case для ключей JSON
          field_rename: snake
          # Генерировать toJson для вложенных объектов
          explicit_to_json: true
```

### Общие настройки

```yaml
targets:
  $default:
    builders:
      # Указать какие файлы обрабатывать
      some_builder:
        generate_for:
          include:
            - lib/models/**
          exclude:
            - lib/models/legacy/**
        options:
          # Опции конкретного builder'а
          option_name: value
```

## 5. part и part of

Сгенерированный код связывается через `part`/`part of`:

```dart
// lib/models/user.dart
library;

import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';         // ← Сгенерированный файл — часть этой библиотеки

@JsonSerializable()
class User {
  // ...
}
```

```dart
// lib/models/user.g.dart (сгенерирован)
part of 'user.dart';        // ← Указывает на основной файл

// Сгенерированный код имеет доступ к приватным членам user.dart
```

## 6. Watch-режим

```bash
# Запуск watch-режима
dart run build_runner watch

# Ограничить наблюдение конкретной папкой
dart run build_runner watch --build-filter="lib/models/**"

# С удалением конфликтов
dart run build_runner watch --delete-conflicting-outputs
```

```
┌───────── Watch-режим ─────────────────────────────┐
│                                                    │
│  $ dart run build_runner watch                     │
│  [INFO] Generating build script completed          │
│  [INFO] Setting up file watchers completed         │
│  [INFO] Running build completed, took 1.2s         │
│                                                    │
│  ─── Вы изменяете user.dart ───                    │
│                                                    │
│  [INFO] Running build completed, took 0.3s         │
│  ← Автоматически пересобирает user.g.dart          │
│                                                    │
└────────────────────────────────────────────────────┘
```

## 7. .gitignore и сгенерированные файлы

Два подхода:

### Подход 1: Коммитить сгенерированные файлы (рекомендуется)

```gitignore
# Не добавляем *.g.dart в .gitignore
# Плюсы: CI не нужен build_runner, быстрее клонирование
```

### Подход 2: Не коммитить (генерировать в CI)

```gitignore
# .gitignore
*.g.dart
*.freezed.dart
```

```yaml
# CI pipeline
steps:
  - run: dart pub get
  - run: dart run build_runner build --delete-conflicting-outputs
  - run: dart test
```

## 8. Распространённые ошибки

### ❌ Забыли part directive

```dart
// Плохо — нет part, генерация не работает
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class User { ... }

// Хорошо
import 'package:json_annotation/json_annotation.dart';
part 'user.g.dart';  // ← обязательно!

@JsonSerializable()
class User { ... }
```

### ❌ Конфликтующие выходные файлы

```bash
# Ошибка: "Conflicting outputs"
# Решение:
dart run build_runner build --delete-conflicting-outputs
```

### ❌ Редактирование .g.dart файлов

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND
// ← Этот комментарий не просто так!
// Файл перезапишется при следующей генерации.
```

### ❌ Медленная генерация

```bash
# Ограничить область генерации
dart run build_runner build --build-filter="lib/models/**"

# Или настроить в build.yaml
targets:
  $default:
    builders:
      json_serializable:
        generate_for:
          include:
            - lib/models/**
```

## 9. Отладка генерации

```bash
# Подробный вывод
dart run build_runner build --verbose

# Показать граф зависимостей
dart run build_runner build --log-performance

# Если генератор не срабатывает — проверить:
# 1. Правильная аннотация (@JsonSerializable, @freezed и т.д.)
# 2. Есть part directive
# 3. Генератор в dev_dependencies
# 4. Аннотации — в dependencies (json_annotation)
```

---

> **Назад:** [13.0 Обзор](13_00_overview.md) · **Далее:** [13.2 Популярные генераторы](13_02_generators.md)
