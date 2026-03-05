# 16.4 Антипаттерны и практики чистого кода

## 1. Формальное определение

**Антипаттерн** — повторяющееся решение, которое кажется правильным, но ведёт к проблемам: плохой читаемости, сложности поддержки, багам. **Чистый код** — код, который легко читать, понимать и изменять.

## 2. Антипаттерны в Dart

### God Class — класс, который делает всё

```dart
// ❌ Плохо — класс на 2000 строк
class AppManager {
  void login() { ... }
  void logout() { ... }
  void fetchProducts() { ... }
  void addToCart() { ... }
  void processPayment() { ... }
  void sendNotification() { ... }
  void generateReport() { ... }
  void updateUI() { ... }
}

// ✅ Хорошо — разделение ответственности
class AuthService { void login() {} void logout() {} }
class ProductRepository { Future<List<Product>> fetchAll() async => []; }
class CartService { void add(Product p) {} }
class PaymentService { Future<void> process(Order o) async {} }
```

### Primitive Obsession — примитивы вместо value objects

```dart
// ❌ Плохо — email везде как String
void sendEmail(String email, String subject, String body) {
  // А если email невалидный? Проверяем каждый раз?
}

// ✅ Хорошо — value object с валидацией
class Email {
  final String value;

  Email(this.value) {
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
      throw FormatException('Invalid email: $value');
    }
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      other is Email && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

void sendEmail(Email email, String subject, String body) {
  // email гарантированно валиден
}
```

### Boolean parameters

```dart
// ❌ Плохо — непонятно, что означает true/false
loadData(true, false, true);

// ✅ Хорошо — именованные параметры
loadData(
  useCache: true,
  forceRefresh: false,
  includeArchived: true,
);

// ✅ Или enum вместо bool
enum CachePolicy { useCache, skipCache, forceRefresh }

loadData(cachePolicy: CachePolicy.useCache);
```

### Callback hell

```dart
// ❌ Плохо — вложенные callback'и
fetchUser(userId, (user) {
  fetchOrders(user.id, (orders) {
    fetchProducts(orders.first.productId, (product) {
      updateUI(user, orders, product);
    });
  });
});

// ✅ Хорошо — async/await
final user = await fetchUser(userId);
final orders = await fetchOrders(user.id);
final product = await fetchProducts(orders.first.productId);
updateUI(user, orders, product);
```

### Stringly typed — строки вместо типов

```dart
// ❌ Плохо — статус как строка
class Order {
  String status = 'pending';

  void process() {
    if (status == 'pending') {  // Опечатка 'pnding' не поймается
      status = 'processing';
    }
  }
}

// ✅ Хорошо — enum
enum OrderStatus { pending, processing, shipped, delivered, cancelled }

class Order {
  OrderStatus status = OrderStatus.pending;

  void process() {
    if (status == OrderStatus.pending) {
      status = OrderStatus.processing;
    }
  }
}
```

### Magic numbers

```dart
// ❌ Плохо — что значит 30? 86400? 5?
if (retryCount > 5) throw Exception('Too many retries');
final timeout = Duration(seconds: 30);
final expiresIn = Duration(seconds: 86400);

// ✅ Хорошо — именованные константы
const maxRetries = 5;
const requestTimeout = Duration(seconds: 30);
const tokenTtl = Duration(hours: 24);

if (retryCount > maxRetries) throw Exception('Too many retries');
```

## 3. Практики чистого кода

### Именование

```dart
// Классы — PascalCase, существительные
class UserRepository {}
class PaymentService {}

// Методы — camelCase, глаголы
Future<User> fetchUser(String id) async { ... }
bool isValid(String input) { ... }
void processPayment(Order order) { ... }

// Булевы переменные — вопрос
bool isLoading = false;
bool hasError = false;
bool canSubmit = true;

// Списки — множественное число
List<User> users = [];
Set<String> activeIds = {};

// Приватные — с _
final _cache = <String, Object>{};
void _validate() { ... }
```

### Маленькие функции

```dart
// ❌ Плохо — функция на 80 строк, делает всё
Future<void> processOrder(Order order) async {
  // валидация (15 строк)
  // расчёт стоимости (20 строк)
  // проверка складских остатков (15 строк)
  // создание платежа (15 строк)
  // отправка уведомления (15 строк)
}

// ✅ Хорошо — декомпозиция
Future<void> processOrder(Order order) async {
  _validateOrder(order);
  final total = _calculateTotal(order);
  await _checkInventory(order.items);
  await _createPayment(order, total);
  await _notifyCustomer(order);
}
```

### Early return

```dart
// ❌ Плохо — глубокая вложенность
String? getUserName(Map<String, dynamic>? data) {
  if (data != null) {
    final user = data['user'];
    if (user != null) {
      final name = user['name'];
      if (name is String) {
        return name;
      }
    }
  }
  return null;
}

// ✅ Хорошо — ранний выход
String? getUserName(Map<String, dynamic>? data) {
  if (data == null) return null;
  final user = data['user'];
  if (user == null) return null;
  final name = user['name'];
  return name is String ? name : null;
}
```

### Предпочитайте выражения

```dart
// ❌ Плохо — многословно
String getLabel(Status status) {
  String label;
  switch (status) {
    case Status.active:
      label = 'Активен';
      break;
    case Status.inactive:
      label = 'Неактивен';
      break;
    case Status.banned:
      label = 'Заблокирован';
      break;
  }
  return label;
}

// ✅ Хорошо — switch expression (Dart 3)
String getLabel(Status status) => switch (status) {
  Status.active => 'Активен',
  Status.inactive => 'Неактивен',
  Status.banned => 'Заблокирован',
};
```

## 4. SOLID в Dart

```dart
// S — Single Responsibility
// Каждый класс — одна причина для изменения

// O — Open/Closed
// Расширяйте через наследование/миксины, не модификацию
abstract class Discount {
  double apply(double price);
}
class PercentDiscount extends Discount { ... }
class FixedDiscount extends Discount { ... }

// L — Liskov Substitution
// Подклассы заменяют базовые без нарушения поведения

// I — Interface Segregation
// Маленькие интерфейсы лучше одного большого
abstract class Readable { Future<String> read(); }
abstract class Writable { Future<void> write(String data); }
class File implements Readable, Writable { ... }
class ReadOnlyFile implements Readable { ... }

// D — Dependency Inversion
// Зависимость от абстракций, не от реализаций
class OrderService {
  final PaymentGateway _gateway;  // абстракция
  OrderService(this._gateway);
}
```

## 5. Линтер-правила для чистого кода

```yaml
# analysis_options.yaml
include: package:lints/recommended.yaml

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - prefer_final_locals
    - prefer_final_fields
    - avoid_print
    - avoid_dynamic
    - prefer_single_quotes
    - sort_constructors_first
    - unawaited_futures
    - unnecessary_lambdas
    - prefer_expression_function_bodies
```

---

> **Назад:** [16.3 Immutable data](16_03_immutable.md) · **Далее:** [17.0 Платформенные применения](../17_platforms/17_00_overview.md)
