# 2.5 Null Safety

## 1. Формальное определение

**Null Safety** в Dart — система гарантий на уровне типов, при которой переменная **не может содержать `null`**, если её тип не помечен как nullable (`?`). Dart реализует **sound null safety**: если тип — `String`, в runtime **гарантированно** не будет `null`. Ошибки ловятся статически, до запуска.

Null Safety введён в Dart 2.12 и является обязательным с Dart 3.0.

**Уровень:** типизация / safety.

## 2. Зачем это нужно

- **NullPointerException — #1 ошибка** во всех языках. По данным Google, null-ошибки составляли значительную часть crash-ов в Flutter-приложениях до null safety.
- **Sound** означает: компилятор не просто предупреждает — он **гарантирует**. Если тип `String`, значение не может быть `null` ни при каких обстоятельствах.
- **Производительность** — компилятор может опустить null-проверки для non-nullable типов, генерируя более быстрый код.

## 3. Как это работает

### Nullable vs Non-nullable

```dart
// Non-nullable — НЕ может быть null
String name = 'Alice';
// name = null;         // ОШИБКА компиляции!

// Nullable — МОЖЕТ быть null
String? nickname = null;     // OK
nickname = 'Al';             // OK
nickname = null;             // OK
```

### Иерархия типов с null safety

```
        Object?              ← Nullable top type
       /       \
   Object      Null           ← Null — отдельный тип
  /   |   \
int  String  ...               ← Все non-nullable

        Never                  ← Bottom type
```

Каждый тип `T` имеет nullable-аналог `T?`. `T?` эквивалентен `T | Null` (union type).

### Операторы для работы с null

```dart
String? name;

// 1. ?. (null-aware access) — вызов метода, если не null
int? length = name?.length;     // null если name == null

// 2. ?? (if-null) — значение по умолчанию
String displayName = name ?? 'Anonymous';

// 3. ??= (null-aware assignment) — присвоить, если null
name ??= 'Default';

// 4. ! (null assertion / bang operator) — принудительный non-null
String forcedName = name!;      // Бросит TypeError если null!

// 5. ?.. (null-aware cascade)
name
  ?..trim()
  ..toUpperCase();

// 6. ?[] (null-aware index)
List<int>? items;
int? first = items?[0];
```

### Flow analysis (продвижение типа)

```dart
void greet(String? name) {
  // name — String? (nullable)

  if (name == null) {
    print('Hello, stranger!');
    return;
  }

  // name продвинут до String (non-nullable)
  print('Hello, ${name.toUpperCase()}!');  // OK — null уже исключён
}
```

Flow analysis работает с:

- `if (x == null) return;`
- `if (x != null) { ... }`
- `x ?? defaultValue`
- `assert(x != null)`
- Присваивание: `x = nonNullValue;`

### late — обещание non-null

```dart
class DatabaseConnection {
  // "Я обещаю, что инициализирую до использования"
  late final String connectionString;

  void configure(String url) {
    connectionString = url;
  }

  void query(String sql) {
    // Если не вызвали configure() — LateInitializationError
    print('Query on $connectionString: $sql');
  }
}
```

### required — обязательные именованные параметры

```dart
class User {
  final String name;
  final String email;
  final int? age;  // Необязательный (nullable)

  User({
    required this.name,   // Обязательный (non-nullable)
    required this.email,  // Обязательный
    this.age,             // Необязательный
  });
}

// Вызов:
User(name: 'Alice', email: 'alice@example.com');             // OK
User(name: 'Bob', email: 'bob@example.com', age: 30);        // OK
// User(name: 'Charlie');  // ОШИБКА: email обязателен
```

## 4. Минимальный пример

```dart
void main() {
  // Non-nullable
  String greeting = 'Hello';

  // Nullable
  String? name;

  // Null-aware access
  print(name?.length);    // null

  // Default value
  print(name ?? 'World'); // World

  // Flow analysis
  if (name != null) {
    print(name.length);   // OK — promoted to String
  }

  // Bang operator (используйте осторожно!)
  name = 'Dart';
  print(name!.length);    // 4
}
```

## 5. Практический пример

### Безопасная обработка JSON-ответа

```dart
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;    // Может отсутствовать
  final DateTime? lastLogin;  // Может отсутствовать

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.lastLogin,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
    );
  }

  String get displayAvatar => avatarUrl ?? 'https://default-avatar.png';

  String get lastLoginFormatted =>
      lastLogin?.toIso8601String() ?? 'Никогда не входил';
}

void main() {
  final json = {
    'id': 'u-001',
    'name': 'Alice',
    'email': 'alice@example.com',
    'avatar_url': null,       // Аватар отсутствует
    // 'last_login' — ключ отсутствует
  };

  final user = UserProfile.fromJson(json);
  print(user.displayAvatar);       // https://default-avatar.png
  print(user.lastLoginFormatted);  // Никогда не входил
}
```

**Архитектурная корректность:**

- Обязательные поля (`id`, `name`, `email`) — non-nullable. Конструктор гарантирует их наличие.
- Опциональные поля (`avatarUrl`, `lastLogin`) — nullable. Есть fallback-значения.
- Нет `!` (bang operator) — вся работа с null через `??` и `?.`.
- JSON-поле может быть `null` или отсутствовать — обрабатываются оба случая.

## 6. Что происходит под капотом

### Sound null safety vs unsound

```
Sound (Dart):
  String name = ...;
  // Dart VM ЗНАЕТ: name != null
  // → Компилятор не вставляет null-check перед вызовом метода
  print(name.length);  // Прямой вызов, без проверки

Unsound (TypeScript strict mode):
  name: string = ...;
  // TS компилятор не гарантирует → runtime может получить null
  // Из-за type assertions, any, или FFI-границ
```

### AOT-оптимизации

```dart
String process(String input) {
  return input.trim().toUpperCase();
}
```

AOT-компилятор знает, что `input` не может быть `null`. Он генерирует:

- Прямой вызов `String.trim()` без null-check
- Прямой вызов `String.toUpperCase()` без null-check

Для nullable-типа `String?` компилятор вставит проверку:

```
if (input == null) throw TypeError;
// ... прямой вызов
```

### Bang operator (!) внутри

```dart
String? name = getName();
print(name!);

// Компилятор генерирует:
// if (name == null) throw TypeError('Null check operator used on a null value');
// print(name);
```

`!` — это **runtime cast** из `T?` в `T`. Эквивалентен `name as String` с проверкой на null.

### Nullable в памяти

```
Non-nullable String:
  Ссылка → String object (гарантированно не null)

Nullable String?:
  Ссылка → String object ИЛИ null
  null = специальное значение (tagged pointer в VM)
```

`null` в Dart VM — единственный экземпляр класса `Null`. Проверка `x == null` — это сравнение указателей, O(1).

## 7. Производительность и ресурсы

| Аспект          | Non-nullable                    | Nullable                     |
| --------------- | ------------------------------- | ---------------------------- |
| Вызов метода    | Прямой (без check)              | + null-check (~1 инструкция) |
| Размер в памяти | Идентичен                       | Идентичен                    |
| `!` operator    | 0 если не null; throw если null | —                            |
| `??`            | 1 сравнение                     | —                            |
| `?.`            | 1 сравнение + branch            | —                            |

**Null safety улучшает производительность**: компилятор убирает ненужные null-check'и для non-nullable типов. До null safety Dart вставлял проверки повсюду «на всякий случай».

## 8. Частые ошибки и антипаттерны

### ❌ Злоупотребление ! (bang operator)

```dart
// Плохо: ! маскирует проблему, crash в runtime
String name = getUserName()!;

// Хорошо: обработать null явно
String name = getUserName() ?? 'Unknown';

// Или через flow analysis:
final rawName = getUserName();
if (rawName == null) {
  throw ArgumentError('User name is required');
}
// rawName продвинут до String (non-nullable)
String name = rawName;
```

### ❌ Nullable everywhere (перестраховка)

```dart
// Плохо: всё nullable "на всякий случай"
class User {
  String? name;    // Имя точно есть у каждого пользователя!
  String? email;   // Email обязателен!
  int? age;        // Возраст действительно может отсутствовать
}

// Хорошо: nullable только где действительно может быть null
class User {
  String name;
  String email;
  int? age;

  User({required this.name, required this.email, this.age});
}
```

### ❌ Использование late вместо nullable

```dart
// Плохо: late + не инициализировано = crash
late String apiKey;
// ... забыли вызвать init()
print(apiKey);  // LateInitializationError!

// Лучше: nullable с явной проверкой
String? apiKey;
void init() { apiKey = loadFromEnv(); }
void use() {
  final key = apiKey;
  if (key == null) throw StateError('API key not configured');
  callApi(key);
}
```

### ❌ Double-null-check

```dart
// Плохо: проверяем null дважды
if (user.name != null) {
  // user.name может стать null между проверкой и использованием
  // (если name — getter или mutable поле)
  print(user.name!.length);  // Всё равно нужен !
}

// Хорошо: присвоить в локальную переменную
final name = user.name;
if (name != null) {
  print(name.length);  // OK — local variable promoted
}
```

## 9. Сравнение с альтернативами

| Аспект             | Dart      | Kotlin    | TypeScript       | Swift        | Java               |
| ------------------ | --------- | --------- | ---------------- | ------------ | ------------------ |
| Null safety        | Sound     | Sound     | Unsound (strict) | Sound        | ❌ (@Nullable)     |
| Syntax             | `String?` | `String?` | `string \| null` | `String?`    | `@Nullable String` |
| Null-aware access  | `?.`      | `?.`      | `?.`             | `?.`         | ❌                 |
| Elvis              | `??`      | `?:`      | `??`             | `??`         | ❌                 |
| Not-null assertion | `!`       | `!!`      | `!`              | `!`          | ❌                 |
| Smart cast         | ✅        | ✅        | ✅ (narrowing)   | ✅ (binding) | ❌                 |
| Default parameters | ✅        | ✅        | ✅               | ✅           | ❌                 |

**Dart и Kotlin** — наиболее близки по null safety. Главное отличие: Dart использует `??`, Kotlin — `?:` (Elvis operator).

## 10. Когда НЕ стоит использовать

- **`!` (bang) как затычка** — если вы пишете `!` чаще, чем раз в 50 строк, вероятно, API спроектирован с лишними nullable-типами.
- **`late` для простых значений** — если значение может быть вычислено в конструкторе, не нужен `late`. Используйте `late` только когда инициализация объективно откладывается (lifecycle, DI).
- **Nullable для обязательных полей** — если поле всегда должно иметь значение, используйте `required` + non-nullable тип. Nullable — только для действительно опциональных данных.

## 11. Краткое резюме

1. **Sound null safety** — если тип `String`, переменная **гарантированно** не `null` в runtime. Не «предупреждение», а «гарантия».
2. **`String?`** — nullable тип. `String` — non-nullable. Каждый тип имеет оба варианта.
3. **`?.`, `??`, `??=`, `!`** — операторы для работы с null. `??` и `?.` — безопасны; `!` — потенциальный crash.
4. **Flow analysis** продвигает тип: после `if (x != null)` переменная `x` становится non-nullable.
5. **`required`** — делает именованный параметр обязательным. Без `required` nullable-параметры получают значение `null` по умолчанию.
6. **`late`** — обещание: «Я инициализирую до использования». Если не сдержали — `LateInitializationError`.
7. **Избегайте `!`**: предпочитайте `??`, `?.`, flow analysis. `!` — это `assert != null` в runtime, маскирующий ошибки проектирования.

---

> **Назад:** [Обзор раздела](02_00_overview.md) · **Далее:** [3. Встроенные типы и литералы](../03_builtin_types/03_00_overview.md)
