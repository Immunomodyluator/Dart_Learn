# 14.3 Ограничения статической и динамической рефлексии

## 1. Формальное определение

**Рефлексия (reflection)** — способность программы анализировать и модифицировать свою структуру во время выполнения: просматривать классы, методы, аннотации, создавать объекты по имени.

В Dart есть `dart:mirrors` — библиотека рефлексии, но она:

- Работает **только** в JIT-режиме (Dart VM).
- **Не поддерживается** в AOT-компиляции (Flutter, нативные бинарники).
- **Не поддерживается** при компиляции в JavaScript.
- Считается **deprecated** для большинства применений.

## 2. Зачем это важно знать

- **Tree shaking** — AOT-компилятор удаляет неиспользуемый код; рефлексия не совместима с этим.
- **Производительность** — рефлексия создаёт overhead; генерация кода — нулевой overhead.
- **Платформы** — Flutter и Web не поддерживают `dart:mirrors`, нужны альтернативы.
- **Экосистема** — большинство Dart-пакетов используют кодогенерацию вместо рефлексии.

## 3. dart:mirrors (JIT only)

```dart
// ⚠️ Работает ТОЛЬКО в Dart VM (JIT)
// НЕ работает в Flutter, AOT, Web

import 'dart:mirrors';

class User {
  String name;
  int age;
  User(this.name, this.age);
  String greet() => 'Hi, I am $name';
}

void main() {
  final user = User('Alice', 30);

  // Получение зеркала объекта
  final mirror = reflect(user);

  // Чтение поля по имени
  final name = mirror.getField(#name).reflectee;
  print(name); // Alice

  // Установка поля
  mirror.setField(#name, 'Bob');

  // Вызов метода
  final result = mirror.invoke(#greet, []).reflectee;
  print(result); // Hi, I am Bob

  // Анализ класса
  final classMirror = reflectClass(User);
  for (final decl in classMirror.declarations.entries) {
    print('${decl.key}: ${decl.value}');
  }
}
```

## 4. Почему рефлексия ограничена в Dart

```
┌──────────────────────────────────────────────────────┐
│  Проблемы runtime-рефлексии в Dart:                  │
│                                                      │
│  1. Tree shaking невозможен                          │
│     Если код может быть вызван по имени (строке),    │
│     компилятор не может безопасно удалять классы     │
│     → Большие бинарники                             │
│                                                      │
│  2. AOT-компиляция                                   │
│     AOT не может предсказать, какие типы будут       │
│     рефлексированы → нужна вся метаинформация       │
│     → Медленный старт, большой размер               │
│                                                      │
│  3. Компиляция в JS/Wasm                             │
│     JavaScript и Wasm не имеют механизма             │
│     метаданных, совместимого с dart:mirrors          │
│                                                      │
│  4. Производительность                               │
│     Рефлексия медленнее прямых вызовов в 10-100x    │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## 5. Альтернативы рефлексии

### Кодогенерация (основной подход)

```dart
// Вместо runtime-анализа аннотаций — build_runner генерирует код

// Рефлексия (не работает в AOT):
// for (var field in reflect(user).type.declarations)
//   json[field.name] = reflect(user).getField(field).reflectee;

// Кодогенерация (работает везде):
@JsonSerializable()
class User {
  final String name;
  final int age;
  User({required this.name, required this.age});
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

### Ручная регистрация (Service Locator)

```dart
// Вместо автоматического обнаружения классов —
// явная регистрация в DI-контейнере

final getIt = GetIt.instance;

void setup() {
  getIt.registerSingleton<ApiClient>(ApiClient());
  getIt.registerFactory<UserRepository>(() => UserRepository(getIt()));
  getIt.registerFactory<AuthService>(() => AuthService(getIt()));
}
```

### Аннотации + кодогенерация (injectable)

```dart
// Аннотации анализируются build_runner, не runtime
@injectable
class UserRepository {
  final ApiClient _client;
  UserRepository(this._client);
}

@module
abstract class AppModule {
  @singleton
  ApiClient get apiClient => ApiClient();
}

// build_runner генерирует код регистрации
// без рефлексии
```

### Pattern matching (Dart 3)

```dart
// Вместо рефлексии для проверки типов:
void process(Object obj) {
  switch (obj) {
    case User(:final name, :final age):
      print('User: $name, $age');
    case Product(:final price):
      print('Product: \$$price');
    default:
      print('Unknown: $obj');
  }
}
```

## 6. Сравнение подходов

```
┌─────────────────────────────────────────────────────────────┐
│  Подход          │ AOT │ Web │ Производит. │ Tree-shaking  │
├──────────────────┼─────┼─────┼─────────────┼───────────────┤
│  dart:mirrors    │  ❌ │  ❌ │  Медленно   │  ❌            │
│  Кодогенерация   │  ✅ │  ✅ │  Быстро     │  ✅            │
│  Ручная рег-ция  │  ✅ │  ✅ │  Быстро     │  ✅            │
│  Pattern match   │  ✅ │  ✅ │  Быстро     │  ✅            │
└──────────────────┴─────┴─────┴─────────────┴───────────────┘
```

## 7. package:reflectable (ограниченная рефлексия)

`reflectable` — пакет, использующий кодогенерацию для создания ограниченного зеркального API, работающего в AOT:

```dart
import 'package:reflectable/reflectable.dart';

class MyReflectable extends Reflectable {
  const MyReflectable() : super(invokingCapability);
}

const myReflectable = MyReflectable();

@myReflectable
class User {
  String name;
  User(this.name);
  String greet() => 'Hi, $name';
}

void main() {
  initializeReflectable(); // Сгенерированная функция

  final mirror = myReflectable.reflect(User('Alice'));
  print(mirror.invoke('greet', [])); // Hi, Alice
}
```

> **Примечание**: `reflectable` генерирует код на этапе сборки, поэтому это кодогенерация с API, похожим на рефлексию. Не настоящая runtime-рефлексия.

## 8. Рекомендации

```
┌──────────── Выбор подхода ──────────────────────────┐
│                                                      │
│  Сериализация JSON     → json_serializable / freezed │
│  DI-контейнер          → get_it / injectable         │
│  Роутинг               → auto_route / go_router      │
│  Маппинг объектов      → кодогенерация               │
│  Тестовые моки         → mockito (build_runner)      │
│  Анализ кода           → analyzer (compile-time)     │
│                                                      │
│  Общее правило:                                      │
│  Всё, что нужно знать о типах — делайте на этапе    │
│  компиляции через кодогенерацию, а не в runtime.     │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

> **Назад:** [14.2 JS interop](14_02_js_interop.md) · **Далее:** [15.0 Производительность и профилирование](../15_performance/15_00_overview.md)
