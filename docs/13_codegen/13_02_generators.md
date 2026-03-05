# 13.2 Популярные генераторы: json_serializable и freezed

## 1. Формальное определение

**json_serializable** — генератор, создающий `fromJson`/`toJson` методы для классов, аннотированных `@JsonSerializable`. Пакет `json_annotation` содержит аннотации, а `json_serializable` — сам генератор.

**freezed** — генератор для создания неизменяемых (immutable) классов с `copyWith`, `==`, `hashCode`, `toString`, а также sealed union-типов с pattern matching. Заменяет сотни строк boilerplate одной аннотацией.

## 2. Зачем это нужно

- **json_serializable** — типобезопасная сериализация без ручного парсинга JSON.
- **freezed** — неизменяемые модели данных без ручного написания `==`, `hashCode`, `copyWith`.
- **Совместимость** — freezed и json_serializable работают вместе.
- **Надёжность** — генерированный код не содержит человеческих ошибок.

## 3. json_serializable

### Установка

```yaml
# pubspec.yaml
dependencies:
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
```

### Базовый пример

```dart
// lib/models/user.dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  final String name;
  final int age;
  final String? email;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  User({
    required this.name,
    required this.age,
    this.email,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) =>
      _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

```bash
dart run build_runner build
```

### Аннотации json_annotation

```dart
@JsonSerializable(
  // Не включать null-поля в JSON
  includeIfNull: false,

  // Переименование полей
  fieldRename: FieldRename.snake,  // camelCase → snake_case

  // Генерировать toJson для вложенных объектов
  explicitToJson: true,

  // Разрешить любые ключи (не бросать на лишние)
  disallowUnrecognizedKeys: false,

  // Создать только fromJson
  createToJson: false,
)
class User { ... }
```

### @JsonKey — настройка полей

```dart
class Product {
  // Переименование ключа
  @JsonKey(name: 'product_id')
  final String id;

  // Значение по умолчанию
  @JsonKey(defaultValue: 0)
  final int quantity;

  // Игнорировать при сериализации
  @JsonKey(includeToJson: false)
  final String? internalNote;

  // Игнорировать при десериализации
  @JsonKey(includeFromJson: false)
  final DateTime fetchedAt;

  // Кастомный конвертер
  @JsonKey(fromJson: _dateFromEpoch, toJson: _dateToEpoch)
  final DateTime createdAt;

  // Полностью игнорировать
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? cacheKey;

  Product({...});

  static DateTime _dateFromEpoch(int epoch) =>
      DateTime.fromMillisecondsSinceEpoch(epoch);

  static int _dateToEpoch(DateTime date) =>
      date.millisecondsSinceEpoch;
}
```

### Вложенные объекты

```dart
@JsonSerializable(explicitToJson: true)
class Order {
  final String id;
  final User customer;            // Вложенный объект
  final List<Product> items;      // Список объектов
  final Map<String, int> meta;    // Карта

  Order({
    required this.id,
    required this.customer,
    required this.items,
    required this.meta,
  });

  factory Order.fromJson(Map<String, dynamic> json) =>
      _$OrderFromJson(json);

  Map<String, dynamic> toJson() => _$OrderToJson(this);
}
```

### Enum-сериализация

```dart
@JsonEnum(valueField: 'code')
enum Status {
  @JsonValue('active')
  active('active'),

  @JsonValue('inactive')
  inactive('inactive'),

  @JsonValue('pending')
  pending('pending');

  final String code;
  const Status(this.code);
}

@JsonSerializable()
class Task {
  final String title;
  final Status status;  // Автоматически сериализуется в строку

  Task({required this.title, required this.status});

  factory Task.fromJson(Map<String, dynamic> json) =>
      _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);
}
```

### Конвертеры (JsonConverter)

```dart
// Переиспользуемый конвертер для DateTime ↔ ISO-строка
class DateTimeConverter implements JsonConverter<DateTime, String> {
  const DateTimeConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json);

  @override
  String toJson(DateTime object) => object.toIso8601String();
}

@JsonSerializable()
class Event {
  final String title;

  @DateTimeConverter()
  final DateTime startsAt;

  Event({required this.title, required this.startsAt});

  factory Event.fromJson(Map<String, dynamic> json) =>
      _$EventFromJson(json);
  Map<String, dynamic> toJson() => _$EventToJson(this);
}
```

## 4. freezed

### Установка

```yaml
dependencies:
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0 # Если нужен JSON

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.7.0 # Если нужен JSON
```

### Базовый пример

```dart
// lib/models/user.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';  // Если нужен JSON

@freezed
class User with _$User {
  const factory User({
    required String name,
    required int age,
    String? email,
    @Default(false) bool isActive,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) =>
      _$UserFromJson(json);
}
```

```bash
dart run build_runner build
```

### Что генерирует freezed

```dart
// Автоматически получаем:
final user = User(name: 'Alice', age: 30);

// 1. copyWith — неизменяемое обновление
final updated = user.copyWith(age: 31);
// User(name: 'Alice', age: 31, email: null, isActive: false)

// 2. == и hashCode — сравнение по значению
User(name: 'Alice', age: 30) == User(name: 'Alice', age: 30); // true

// 3. toString — читаемое представление
print(user);  // User(name: Alice, age: 30, email: null, isActive: false)

// 4. fromJson / toJson (если настроен json_serializable)
final json = user.toJson();
final fromJson = User.fromJson(json);
```

### Union-типы (sealed classes)

```dart
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(User user) = Authenticated;
  const factory AuthState.error(String message) = AuthError;
}
```

```dart
// Использование с pattern matching (Dart 3)
String describeState(AuthState state) => switch (state) {
  AuthInitial()       => 'Начальное состояние',
  AuthLoading()       => 'Загрузка...',
  Authenticated(:final user) => 'Привет, ${user.name}!',
  AuthError(:final message)  => 'Ошибка: $message',
};

// Или через when / map (freezed API)
String describeState2(AuthState state) => state.when(
  initial:       () => 'Начальное состояние',
  loading:       () => 'Загрузка...',
  authenticated: (user) => 'Привет, ${user.name}!',
  error:         (message) => 'Ошибка: $message',
);
```

### Кастомные методы и геттеры

```dart
@freezed
class Temperature with _$Temperature {
  const Temperature._();  // ← Приватный конструктор для кастомных методов

  const factory Temperature.celsius(double value) = _Celsius;
  const factory Temperature.fahrenheit(double value) = _Fahrenheit;

  // Кастомный геттер
  double get inCelsius => switch (this) {
    _Celsius(:final value)     => value,
    _Fahrenheit(:final value)  => (value - 32) * 5 / 9,
  };

  // Кастомный метод
  String get display => '${inCelsius.toStringAsFixed(1)}°C';
}
```

### Deep copy (вложенные структуры)

```dart
@freezed
class Company with _$Company {
  const factory Company({
    required String name,
    required Address address,
  }) = _Company;
}

@freezed
class Address with _$Address {
  const factory Address({
    required String city,
    required String street,
  }) = _Address;
}

// Deep copy через copyWith
final company = Company(
  name: 'Acme',
  address: Address(city: 'Moscow', street: 'Main St'),
);

final moved = company.copyWith.address(city: 'London');
// Company(name: 'Acme', address: Address(city: 'London', street: 'Main St'))
```

## 5. Совместное использование

```dart
// Полный пример: freezed + json_serializable
import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_response.freezed.dart';
part 'api_response.g.dart';

@freezed
class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse.success(T data) = ApiSuccess<T>;
  const factory ApiResponse.error(String message, int code) = ApiError<T>;
  const factory ApiResponse.loading() = ApiLoading<T>;
}

@freezed
class UserDto with _$UserDto {
  const factory UserDto({
    required int id,
    required String name,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @Default([]) List<String> roles,
  }) = _UserDto;

  factory UserDto.fromJson(Map<String, dynamic> json) =>
      _$UserDtoFromJson(json);
}
```

## 6. Настройки в build.yaml

```yaml
# build.yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          include_if_null: false
          field_rename: snake
          explicit_to_json: true
      freezed:
        options:
          # Отключить генерацию when/map (если используете Dart 3 patterns)
          map: false
          when: false
          # Формат toString
          to_string: true
          # Генерация equal и hashCode
          equal: true
          # Копирование
          copy_with: true
```

## 7. Распространённые ошибки

### ❌ Нет part directive для freezed

```dart
// Плохо — нужны ОБА part файла
part 'user.freezed.dart';   // ← обязательно для freezed
// part 'user.g.dart';      // ← забыли! Нужен для JSON

// Хорошо
part 'user.freezed.dart';
part 'user.g.dart';
```

### ❌ Мутируемый freezed-класс

```dart
// freezed создаёт НЕИЗМЕНЯЕМЫЕ классы
// Нельзя:
user.name = 'Bob';  // Ошибка компиляции

// Можно:
final updated = user.copyWith(name: 'Bob');
```

### ❌ Забыли \_$ClassName mixin

```dart
// Плохо
@freezed
class User {  // ← нет mixin!
  const factory User({required String name}) = _User;
}

// Хорошо
@freezed
class User with _$User {  // ← обязательный mixin
  const factory User({required String name}) = _User;
}
```

---

> **Назад:** [13.1 build_runner](13_01_build_runner.md) · **Далее:** [13.3 Создание собственного генератора](13_03_custom_generator.md)
