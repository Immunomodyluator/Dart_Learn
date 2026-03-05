# 13.3 Создание собственного генератора

## 1. Формальное определение

**Собственный генератор** — это пакет, реализующий интерфейс `Builder` из пакета `build` и регистрирующий его через `build.yaml`. Генератор анализирует исходный код (AST) с помощью пакета `analyzer` и генерирует новые файлы.

Два основных подхода:

- **Generator** (из `source_gen`) — упрощённый API для генерации кода по аннотациям.
- **Builder** (из `build`) — низкоуровневый API для произвольной генерации.

## 2. Зачем это нужно

- **Устранение boilerplate** — автоматизация повторяющегося кода, специфичного для вашего проекта.
- **Консистентность** — генератор всегда создаёт код по одному шаблону.
- **Валидация** — генератор может проверять аннотации и выдавать понятные ошибки.
- **Проектные нужды** — готовые генераторы не всегда покрывают специфичные задачи.

## 3. Архитектура генератора

```
┌──────────────────────────────────────────────────────┐
│  Пакет генератора                                    │
│                                                      │
│  lib/                                                │
│  ├── annotations.dart       ← Аннотации (dependency) │
│  └── src/                                            │
│      └── generator.dart     ← Логика генерации       │
│                                                      │
│  build.yaml                 ← Регистрация Builder'а  │
│  pubspec.yaml                                        │
│                                                      │
│  Зависимости:                                        │
│  ├── build: ^2.4.0                                   │
│  ├── source_gen: ^1.5.0                              │
│  └── analyzer: ^6.0.0                                │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## 4. Пример: генератор toString

Создадим генератор, который по аннотации `@AutoToString()` генерирует метод `toString()`.

### Шаг 1: Аннотация

```dart
// lib/annotations.dart
/// Аннотация для автоматической генерации toString().
class AutoToString {
  /// Если true, включает приватные поля.
  final bool includePrivate;

  const AutoToString({this.includePrivate = false});
}
```

### Шаг 2: Генератор

```dart
// lib/src/to_string_generator.dart
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../annotations.dart';

class ToStringGenerator extends GeneratorForAnnotation<AutoToString> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Проверяем, что аннотация на классе
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@AutoToString can only be applied to classes.',
        element: element,
      );
    }

    final className = element.name;
    final includePrivate = annotation.read('includePrivate').boolValue;

    // Собираем поля
    final fields = element.fields.where((f) {
      if (f.isStatic) return false;
      if (!includePrivate && f.isPrivate) return false;
      return true;
    });

    // Генерируем toString
    final fieldStrings = fields.map((f) {
      final name = f.name;
      return '$name: \${$name}';
    }).join(', ');

    return '''
extension ${className}ToString on $className {
  String toAutoString() {
    return '$className($fieldStrings)';
  }
}
''';
  }
}
```

### Шаг 3: Регистрация Builder

```dart
// lib/builder.dart
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/to_string_generator.dart';

Builder autoToStringBuilder(BuilderOptions options) =>
    SharedPartBuilder(
      [ToStringGenerator()],
      'auto_to_string',  // Имя части (суффикс .g.dart)
    );
```

### Шаг 4: build.yaml

```yaml
# build.yaml
builders:
  auto_to_string:
    import: "package:my_generator/builder.dart"
    builder_factories: ["autoToStringBuilder"]
    build_extensions: { ".dart": [".auto_to_string.g.part"] }
    auto_apply: dependents
    build_to: cache
    applies_builders: ["source_gen|combining_builder"]
```

### Шаг 5: pubspec.yaml генератора

```yaml
name: my_generator
version: 1.0.0
description: Auto-generates toString for annotated classes.

environment:
  sdk: ^3.0.0

dependencies:
  build: ^2.4.0
  source_gen: ^1.5.0
  analyzer: ^6.0.0

dev_dependencies:
  build_runner: ^2.4.0
  test: ^1.25.0
  build_test: ^2.2.0
```

### Шаг 6: Использование

```dart
// В проекте-потребителе:

// pubspec.yaml
// dependencies:
//   my_generator:       ← для аннотаций
// dev_dependencies:
//   build_runner: ^2.4.0
//   my_generator:       ← для генератора

// lib/models/product.dart
import 'package:my_generator/annotations.dart';

part 'product.g.dart';

@AutoToString()
class Product {
  final String name;
  final double price;
  final int quantity;

  Product({
    required this.name,
    required this.price,
    required this.quantity,
  });
}

// После генерации можно использовать:
// final p = Product(name: 'Widget', price: 9.99, quantity: 5);
// print(p.toAutoString());
// → Product(name: Widget, price: 9.99, quantity: 5)
```

## 5. Работа с ConstantReader

`ConstantReader` позволяет читать значения аннотаций:

```dart
@override
String generateForAnnotatedElement(
  Element element,
  ConstantReader annotation,
  BuildStep buildStep,
) {
  // Простые типы
  final name = annotation.read('name').stringValue;
  final count = annotation.read('count').intValue;
  final flag = annotation.read('flag').boolValue;
  final ratio = annotation.read('ratio').doubleValue;

  // Nullable значения
  final maybeName = annotation.peek('name')?.stringValue;

  // Списки
  final items = annotation.read('items').listValue
      .map((e) => e.toStringValue()!)
      .toList();

  // Enum
  final mode = annotation.read('mode').revive();

  // Вложенная аннотация
  final nested = annotation.read('config');
  final nestedValue = nested.read('timeout').intValue;

  // ...
}
```

## 6. Работа с Element API (analyzer)

```dart
void analyzeClass(ClassElement element) {
  // Имя класса
  final name = element.name;

  // Поля
  for (final field in element.fields) {
    print('${field.type} ${field.name}');
    print('  isPrivate: ${field.isPrivate}');
    print('  isFinal: ${field.isFinal}');
    print('  isStatic: ${field.isStatic}');
  }

  // Методы
  for (final method in element.methods) {
    print('${method.returnType} ${method.name}()');
    for (final param in method.parameters) {
      print('  ${param.type} ${param.name}');
    }
  }

  // Конструкторы
  for (final ctor in element.constructors) {
    print('${element.name}.${ctor.name}');
    for (final param in ctor.parameters) {
      print('  ${param.name}: ${param.type} '
            '(required: ${param.isRequired})');
    }
  }

  // Суперкласс и интерфейсы
  final supertype = element.supertype;
  final interfaces = element.interfaces;
  final mixins = element.mixins;

  // Аннотации на классе
  for (final meta in element.metadata) {
    print('Annotation: ${meta.element?.name}');
  }
}
```

## 7. SharedPartBuilder vs PartBuilder vs LibraryBuilder

```
┌──────────────────────────────────────────────────────┐
│  SharedPartBuilder                                   │
│  → Несколько генераторов пишут в ОДИН .g.dart файл  │
│  → Рекомендуемый подход                             │
│  → Используется json_serializable, freezed          │
│                                                      │
│  PartBuilder                                         │
│  → Генерирует отдельный part файл (.my_gen.dart)    │
│  → Каждый генератор — свой файл                     │
│                                                      │
│  LibraryBuilder                                      │
│  → Генерирует standalone файл (не part)             │
│  → Для генерации новых библиотек                     │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## 8. Тестирование генератора

```dart
// test/to_string_generator_test.dart
import 'package:build_test/build_test.dart';
import 'package:my_generator/builder.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('ToStringGenerator', () {
    test('generates toString for simple class', () async {
      final input = '''
        import 'package:my_generator/annotations.dart';
        part 'input.g.dart';

        @AutoToString()
        class User {
          final String name;
          final int age;
          User({required this.name, required this.age});
        }
      ''';

      final output = '''
        extension UserToString on User {
          String toAutoString() {
            return 'User(name: \${name}, age: \${age})';
          }
        }
      ''';

      await testBuilder(
        autoToStringBuilder(BuilderOptions.empty),
        {'my_pkg|lib/input.dart': input},
        outputs: {'my_pkg|lib/input.g.dart': decodedMatches(contains('toAutoString'))},
      );
    });

    test('throws on non-class annotation', () async {
      final input = '''
        import 'package:my_generator/annotations.dart';
        part 'input.g.dart';

        @AutoToString()
        void someFunction() {}
      ''';

      expect(
        () => testBuilder(
          autoToStringBuilder(BuilderOptions.empty),
          {'my_pkg|lib/input.dart': input},
        ),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    });
  });
}
```

## 9. Распространённые ошибки

### ❌ Забыли applies_builders в build.yaml

```yaml
# Плохо — SharedPartBuilder не будет объединять части
builders:
  my_builder:
    import: "package:my_gen/builder.dart"
    builder_factories: ["myBuilder"]
    build_extensions: {".dart": [".my_gen.g.part"]}

# Хорошо — указываем combining_builder
builders:
  my_builder:
    import: "package:my_gen/builder.dart"
    builder_factories: ["myBuilder"]
    build_extensions: {".dart": [".my_gen.g.part"]}
    auto_apply: dependents
    build_to: cache
    applies_builders: ["source_gen|combining_builder"]
```

### ❌ Не экранированный $ в шаблоне

```dart
// Плохо — Dart интерпретирует $name как интерполяцию
return 'String get display => "$name: $value";';

// Хорошо — используем \$ или raw-строки
return 'String get display => "\$name: \$value";';
```

---

> **Назад:** [13.2 Популярные генераторы](13_02_generators.md) · **Далее:** [14.0 Interop: FFI и Web](../14_interop/14_00_overview.md)
