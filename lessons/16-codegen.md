# Урок 16. Генерация кода и build_runner

> Охватывает подтемы: 16.1 build_runner, 16.2 json_serializable и freezed, 16.3 Кастомные генераторы

---

## 1. Формальное определение

**Кодогенерация** в Dart — создание Dart кода на основе аннотаций и существующего кода во время сборки:

- **`build_runner`** — движок сборки; запускает генераторы на файлах-источниках
- **`source_gen`** — фреймворк для написания генераторов (низкоуровневый API над `analyzer`)
- **Артефакты** генерируются в `.g.dart` и `.freezed.dart` файлы рядом с исходниками
- **One-time** (`build`) vs **watch** (`watch`) режимы

```yaml
dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.8.0
  freezed: ^2.5.0             # иммутабельные классы
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
```

---

## 2. Зачем это нужно

- **`json_serializable`** — устраняет ручное написание `fromJson`/`toJson` (скучно, error-prone)
- **`freezed`** — автоматически генерирует `==`, `hashCode`, `copyWith`, `toString`, sealed classes
- **DI генераторы** (injectable) — автоматически регистрируют зависимости
- Кодогенерация → нет reflection в production → безопасность и хорошая производительность AOT

---

## 3. build_runner команды (16.1)

```bash
# Однократная генерация
dart run build_runner build

# Генерация без кэша (если что-то пошло не так)
dart run build_runner build --delete-conflicting-outputs

# Watch режим — перегенерирует при изменении файлов
dart run build_runner watch

# Только для конкретного builder
dart run build_runner build --build-filter="lib/models/*.dart"

# Для Flutter проекта (аналогично)
flutter pub run build_runner build --delete-conflicting-outputs
```

### build.yaml — конфигурация генератора

```yaml
# build.yaml (в корне проекта)
targets:
  $default:
    builders:
      json_serializable:
        options:
          explicit_to_json: true     # вложенные объекты тоже через toJson
          include_if_null: false     # не включать null значения в JSON
          field_rename: snake_case   # camelCase → snake_case в JSON

      source_gen|combining_builder:
        options:
          ignore_for_file:
            - type=lint             # игнорировать lint в генерированных файлах
```

---

## 4. json_serializable (16.2)

```dart
// lib/models/user.dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';  // ОБЯЗАТЕЛЬНО — указывает куда генерировать

@JsonSerializable()
class User {
  final String id;
  final String name;
  
  @JsonKey(name: 'email_address')  // переименование поля
  final String emailAddress;
  
  @JsonKey(includeIfNull: false)   // не включать в JSON если null
  final String? bio;
  
  @JsonKey(fromJson: _dateFromJson, toJson: _dateToJson)
  final DateTime createdAt;
  
  const User({
    required this.id,
    required this.name,
    required this.emailAddress,
    this.bio,
    required this.createdAt,
  });
  
  // Генерируются автоматически
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);
  
  static DateTime _dateFromJson(String date) => DateTime.parse(date);
  static String _dateToJson(DateTime date) => date.toIso8601String();
}

// Вложенные объекты
@JsonSerializable(explicitToJson: true)
class Post {
  final String id;
  final String title;
  final User author;  // вложенный объект — тоже должен быть @JsonSerializable
  final List<Tag> tags;
  
  const Post({required this.id, required this.title, required this.author, required this.tags});
  
  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
  Map<String, dynamic> toJson() => _$PostToJson(this);
}

@JsonSerializable()
class Tag {
  final String name;
  const Tag({required this.name});
  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);
  Map<String, dynamic> toJson() => _$TagToJson(this);
}

// Enums в JSON
@JsonEnum(valueField: 'code')
enum Status {
  active(code: 'ACTIVE'),
  inactive(code: 'INACTIVE'),
  deleted(code: 'DELETED');

  final String code;
  const Status({required this.code});
}

@JsonSerializable()
class Account {
  final Status status;
  // ...
}
```

После генерации `user.g.dart` будет содержать реализацию `_$UserFromJson` и `_$UserToJson`.

---

## 5. freezed — иммутабельные классы (16.2)

```dart
// lib/models/auth_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_state.freezed.dart';  // для freezed
part 'auth_state.g.dart';        // для json_serializable (если нужен)

// Иммутабельный data class с copyWith, ==, toString
@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String name,
    @Default('') String bio,      // значение по умолчанию
    @JsonKey(name: 'avatar_url')
    String? avatarUrl,
  }) = _UserProfile;
  
  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

// Sealed class через freezed (ADT)
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = Unauthenticated;
  const factory AuthState.loading() = Loading;
  const factory AuthState.authenticated({required UserProfile user}) = Authenticated;
  const factory AuthState.error({required String message}) = AuthError;
}

// Использование
void main() {
  final profile = UserProfile(id: '1', name: 'Alice');
  
  // copyWith — изменить отдельные поля без мутации
  final updated = profile.copyWith(name: 'Bob', bio: 'Developer');
  print(profile.name);  // Alice (исходный не изменился)
  print(updated.name);  // Bob
  
  // == и hashCode генерируются
  print(profile == UserProfile(id: '1', name: 'Alice')); // true
  
  // Pattern matching на sealed class
  AuthState state = Authenticated(user: profile);
  
  String message = switch (state) {
    Unauthenticated() => 'Please log in',
    Loading() => 'Loading...',
    Authenticated(user: final u) => 'Welcome, ${u.name}',
    AuthError(message: final m) => 'Error: $m',
  };
}
```

---

## 6. Кастомный генератор (16.3)

```yaml
# pubspec.yaml нового генератора
name: my_generator
dependencies:
  build: ^2.4.0
  source_gen: ^1.5.0
  analyzer: ^6.4.0
```

```dart
// lib/src/my_generator.dart
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:analyzer/dart/element/element.dart';

// Аннотация пользователя
class GenerateToString {
  final bool includeNull;
  const GenerateToString({this.includeNull = false});
}

// Генератор
class ToStringGenerator extends GeneratorForAnnotation<GenerateToString> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@GenerateToString can only be applied to classes',
        element: element,
      );
    }
    
    final includeNull = annotation.read('includeNull').boolValue;
    final className = element.name;
    
    // Получаем все поля класса
    final fields = element.fields
        .where((f) => !f.isStatic && f.name != 'hashCode')
        .toList();
    
    final buffer = StringBuffer();
    buffer.writeln('extension \$${className}ToString on $className {');
    buffer.write('  String toReadableString() => ');
    buffer.write("'$className(");
    
    final parts = fields.map((f) {
      if (!includeNull) {
        return '\${${f.name} != null ? "${f.name}: \$${f.name}" : ""}';
      }
      return '"${f.name}: \$${f.name}"';
    }).join(', ');
    
    buffer.write(parts);
    buffer.writeln(")';");
    buffer.writeln('}');
    
    return buffer.toString();
  }
}

// Регистрация builder
Builder toStringBuilder(BuilderOptions options) =>
    LibraryBuilder(
      ToStringGenerator(),
      generatedExtension: '.toString.dart',
    );
```

```yaml
# build.yaml (в пакете генератора)
builders:
  to_string_builder:
    target: ":my_generator"
    import: "package:my_generator/builder.dart"
    builder_factories: ["toStringBuilder"]
    build_extensions: {".dart": [".toString.dart"]}
    auto_apply: dependents
    build_to: source

# Или регулируется через pubspec.yaml пакета (для auto_apply)
```

---

## 7. Практический пример: API DTO

```dart
// Полный пример: API DTO с сериализацией
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'api_models.freezed.dart';
part 'api_models.g.dart';

@freezed
class PaginatedResponse<T> with _$PaginatedResponse<T> {
  const factory PaginatedResponse({
    required List<T> items,
    required int total,
    required int page,
    required int pageSize,
    @Default(false) bool hasMore,
  }) = _PaginatedResponse<T>;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) fromJsonT,
  ) => _$PaginatedResponseFromJson(json, fromJsonT);
}

@freezed
class ApiError with _$ApiError {
  const factory ApiError({
    required String code,
    required String message,
    Map<String, dynamic>? details,
  }) = _ApiError;

  factory ApiError.fromJson(Map<String, dynamic> json) =>
      _$ApiErrorFromJson(json);
}

@freezed
sealed class ApiResponse<T> with _$ApiResponse<T> {
  const factory ApiResponse.success({required T data}) = ApiSuccess<T>;
  const factory ApiResponse.error({required ApiError error}) = ApiResponseError<T>;
}

// Использование
Future<ApiResponse<PaginatedResponse<User>>> fetchUsers(int page) async {
  try {
    final response = await httpGet('/users?page=$page');
    final json = jsonDecode(response.body);
    return ApiResponse.success(
      data: PaginatedResponse.fromJson(
        json,
        (item) => User.fromJson(item as Map<String, dynamic>),
      ),
    );
  } on NetworkException catch (e) {
    return ApiResponse.error(error: ApiError(code: 'NETWORK', message: e.message));
  }
}
```

---

## 8. Под капотом

### Как build_runner работает

1. Читает `pubspec.yaml` и `build.yaml` для обнаружения builders
2. Строит граф зависимостей файлов
3. Запускает генераторы в правильном порядке (топологическая сортировка)
4. Кэширует артефакты в `.dart_tool/build/generated/`
5. В `watch` режиме: следит за изменениями через `dart:io` FileSystemWatcher

### Incremental builds

Build runner кэширует результаты через хэши файлов → перегенерация только изменившихся файлов. Первый запуск медленнее последующих.

---

## 9. Производительность

- **`--delete-conflicting-outputs`** медленнее — всё перегенерируется
- **Кэш** в `.dart_tool/build/generated/` — храните между CI запусками (ускоряет)
- Модели с freezed генерируют много кода → умеренно используйте для критичных к размеру пакетов
- В AOT production коде — нет reflection overhead; весь код известен на compile time

---

## 10. Частые ошибки

**1. Забыть `part 'file.g.dart'`:**
```dart
// ОШИБКА: _$UserFromJson не существует
@JsonSerializable()
class User {
  // part 'user.g.dart'; — ЗАБЫЛИ
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

**2. Не запустить build_runner после изменений:**
```bash
# Аннотации изменили — нужно перегенерировать!
dart run build_runner build --delete-conflicting-outputs
```

**3. Committing generated files vs .gitignore:**
```gitignore
# Вариант 1: Не коммитить (рекомендуется для библиотек)
*.g.dart
*.freezed.dart

# Вариант 2: Коммитить (для приложений — стабильность CI)
# Ничего не добавляем в .gitignore
```

**4. `@Default` с mutable объектами:**
```dart
// ОПАСНО — один экземпляр на все объекты
@freezed
class Bad with _$Bad {
  const factory Bad({@Default([]) List<String> items}) = _Bad; // OK — freezed делает const
}
```

---

## 11. Краткое резюме

1. **`build_runner`** — движок; запускает генераторы аннотаций; нужен `dart run build_runner build`
2. **`part 'file.g.dart'`** обязателен рядом с `part of 'source.dart'` в генерированном файле
3. **`json_serializable`** — автоматический `fromJson`/`toJson`; `@JsonKey` для кастомизации
4. **`freezed`** — `copyWith`, `==`, `hashCode`, `toString`, sealed ADT — основной data class генератор
5. **`--delete-conflicting-outputs`** при конфликтах кэша
6. **Watch mode** (`build_runner watch`) для разработки — автоматическая перегенерация
7. Кастомные генераторы через `source_gen` — `GeneratorForAnnotation<YourAnnotation>`
