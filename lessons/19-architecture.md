# Урок 19. Архитектура кода и паттерны

> Охватывает подтемы: 19.1 Структура проекта, 19.2 Dependency Injection, 19.3 Иммутабельные данные, 19.4 Антипаттерны

---

## 1. Формальное определение

**Архитектура кода** — набор принципов и паттернов для организации кода таким образом, чтобы он был поддерживаемым, тестируемым и масштабируемым.

В контексте Dart:
- **Layered architecture**: presentation → domain → data
- **DI (Dependency Injection)**: зависимости инжектируются извне, не создаются внутри
- **Immutability**: предпочитать неизменяемые объекты (меньше багов, безопаснее для concurrency)
- **Антипаттерны**: распознавать и избегать типичные ошибки структуры кода

---

## 2. Структура проекта (19.1)

### Слоистая архитектура для CLI/серверного приложения

```
my_app/
├── lib/
│   ├── domain/              # Бизнес-логика, не зависит от инфраструктуры
│   │   ├── entities/        # Чистые данные (User, Order, Product)
│   │   ├── repositories/    # Интерфейсы репозиториев
│   │   ├── services/        # Бизнес-use-cases
│   │   └── exceptions/      # Доменные исключения
│   ├── data/                # Реализация инфраструктуры
│   │   ├── repositories/    # Impl: DatabaseUserRepository
│   │   ├── datasources/     # HTTP clients, DB connections
│   │   └── models/          # DTO с fromJson/toJson
│   ├── presentation/        # CLI, HTTP handlers, UI
│   │   ├── handlers/        # HTTP request handlers
│   │   └── cli/             # CLI команды
│   └── core/                # Общее: DI, config, utils
│       ├── di/
│       └── config/
├── bin/
│   └── server.dart          # Entry point
└── test/
    ├── domain/
    ├── data/
    └── presentation/
```

### Feature-first структура (для больших проектов)

```
lib/
├── features/
│   ├── auth/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   ├── users/
│   │   ├── domain/
│   │   ├── data/
│   │   └── presentation/
│   └── orders/
└── shared/
    ├── widgets/         (для Flutter)
    └── utils/
```

---

## 3. Dependency Injection (19.2)

### Ручной DI (simple apps)

```dart
// domain/repositories/user_repository.dart
abstract interface class UserRepository {
  Future<User?> findById(String id);
  Future<User> save(User user);
  Future<List<User>> findAll();
}

// domain/services/user_service.dart
class UserService {
  final UserRepository _repo;     // зависимость через интерфейс
  final EmailService _email;

  // Инжектируем через конструктор — явный контракт
  UserService(this._repo, this._email);

  Future<User> createUser(String name, String email) async {
    final user = User(id: generateId(), name: name, email: email);
    await _repo.save(user);
    await _email.sendWelcome(user);
    return user;
  }
}

// core/di/service_locator.dart — простой ручной DI контейнер
class AppContainer {
  final String dbUrl;
  
  AppContainer(this.dbUrl);
  
  // Lazy singletons
  DatabaseConnection? _db;
  DatabaseConnection get db => _db ??= DatabaseConnection(dbUrl);
  
  UserRepository? _userRepo;
  UserRepository get userRepo => _userRepo ??= DatabaseUserRepository(db);
  
  EmailService? _email;
  EmailService get email => _email ??= SmtpEmailService();
  
  UserService? _userService;
  UserService get userService => _userService ??= UserService(userRepo, email);
}

// bin/server.dart — точка входа (composition root)
void main() async {
  final container = AppContainer(
    Platform.environment['DATABASE_URL'] ?? 'postgres://localhost/mydb',
  );
  
  final server = await Server.start(container.userService);
}
```

### get_it — Service Locator

```dart
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupDI() {
  // Singleton
  getIt.registerSingleton<DatabaseConnection>(
    DatabaseConnection(dbUrl),
  );
  
  // Lazy singleton — создаётся при первом обращении
  getIt.registerLazySingleton<UserRepository>(
    () => DatabaseUserRepository(getIt<DatabaseConnection>()),
  );
  
  // Factory — новый экземпляр при каждом вызове
  getIt.registerFactory<UserService>(
    () => UserService(getIt<UserRepository>(), getIt<EmailService>()),
  );
  
  // Async factory
  getIt.registerSingletonAsync<ConfigService>(
    () async => ConfigService.load(),
  );
}

// Использование
final service = getIt<UserService>();
```

### injectable + get_it (с кодогенерацией)

```dart
import 'package:injectable/injectable.dart';

// Аннотация для генератора
@injectable          // factory
@lazySingleton       // lazy singleton
@singleton           // eager singleton
@environment('test') // только в test environment

@lazySingleton
class UserRepository implements UserRepository {
  final Database _db;
  
  UserRepository(this._db); // инжектируется автоматически
}

// Генерация: dart run build_runner build
// Создаёт injection.config.dart с кодом регистрации
```

---

## 4. Иммутабельные данные (19.3)

```dart
// Иммутабельный value object
@immutable  // аннотация из package:meta — lint предупреждает о мутируемых полях
class Money {
  final int cents;
  final String currency;

  const Money(this.cents, this.currency);

  // Операции возвращают новый объект
  Money add(Money other) {
    assert(currency == other.currency, 'Currency mismatch');
    return Money(cents + other.cents, currency);
  }

  Money subtract(Money other) => Money(cents - other.cents, currency);
  Money multiply(double factor) => Money((cents * factor).round(), currency);

  @override
  bool operator ==(Object other) =>
      other is Money && cents == other.cents && currency == other.currency;

  @override
  int get hashCode => Object.hash(cents, currency);

  @override
  String toString() => '${(cents / 100).toStringAsFixed(2)} $currency';
}

// copyWith паттерн без freezed
class UserProfile {
  final String id;
  final String name;
  final String? bio;

  const UserProfile({required this.id, required this.name, this.bio});

  UserProfile copyWith({String? id, String? name, String? bio}) => UserProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    bio: bio ?? this.bio,
  );
}

// Иммутабельные коллекции
import 'package:collection/collection.dart';

class AppState {
  final IList<User> users;     // из fast_immutable_collections
  final IMap<String, Order> orders;
  
  const AppState({required this.users, required this.orders});
  
  AppState addUser(User user) => AppState(
    users: users.add(user),    // возвращает новый IList
    orders: orders,
  );
}
```

---

## 5. Паттерны Repository и Service Layer

```dart
// Repository — только CRUD, без бизнес-логики
abstract interface class OrderRepository {
  Future<Order?> findById(String id);
  Future<List<Order>> findByUserId(String userId, {int limit = 20, int offset = 0});
  Future<Order> save(Order order);
  Future<void> delete(String id);
}

// Service — бизнес-логика
class OrderService {
  final OrderRepository _orders;
  final UserRepository _users;
  final PaymentGateway _payments;
  final NotificationService _notifications;

  OrderService(this._orders, this._users, this._payments, this._notifications);

  Future<Order> createOrder(String userId, List<OrderItem> items) async {
    // Бизнес-правила
    final user = await _users.findById(userId);
    if (user == null) throw NotFoundException('user/$userId');
    if (!user.isVerified) throw DomainException('User not verified');

    final total = items.fold<int>(0, (sum, i) => sum + i.price * i.quantity);
    if (total <= 0) throw DomainException('Order total must be positive');

    // Создание
    final order = Order(
      id: generateId(),
      userId: userId,
      items: items,
      total: Money(total, 'USD'),
      status: OrderStatus.pending,
      createdAt: DateTime.now(),
    );

    // Транзакция (концептуально)
    final payment = await _payments.charge(user.paymentMethod, order.total);
    final savedOrder = await _orders.save(order.copyWith(
      status: OrderStatus.paid,
      paymentId: payment.id,
    ));

    await _notifications.notifyOrderConfirmed(savedOrder);
    return savedOrder;
  }
}
```

---

## 6. Event-driven паттерн

```dart
// Domain events — что произошло в домене
sealed class DomainEvent {
  final DateTime occurredAt;
  const DomainEvent(this.occurredAt);
}

final class UserRegistered extends DomainEvent {
  final String userId;
  final String email;
  const UserRegistered(this.userId, this.email, DateTime occurredAt)
      : super(occurredAt);
}

final class OrderPlaced extends DomainEvent {
  final String orderId;
  final String userId;
  final int totalCents;
  const OrderPlaced(this.orderId, this.userId, this.totalCents, DateTime occurredAt)
      : super(occurredAt);
}

// Event bus
class DomainEventBus {
  final Map<Type, List<Function>> _handlers = {};

  void on<E extends DomainEvent>(Future<void> Function(E) handler) {
    _handlers.putIfAbsent(E, () => []).add(handler);
  }

  Future<void> publish(DomainEvent event) async {
    final handlers = _handlers[event.runtimeType] ?? [];
    await Future.wait(handlers.map((h) => h(event) as Future<void>));
  }
}
```

---

## 7. Антипаттерны (19.4)

### God Object

```dart
// ПЛОХО — UserManager всё знает и всё умеет
class UserManager {
  void createUser() { ... }
  void sendEmail() { ... }
  void generateReport() { ... }
  void handlePayment() { ... }
  void updateCache() { ... }
  // 50+ методов...
}

// ХОРОШО — разделяйте ответственности
class UserService { void createUser() { ... } }
class EmailService { void sendEmail() { ... } }
class ReportService { void generateReport() { ... } }
```

### Service Locator вместо DI

```dart
// ПЛОХО — скрытые зависимости; трудно тестировать
class UserService {
  void createUser(String name) {
    final db = ServiceLocator.get<Database>(); // hidden dependency!
    db.insert(name);
  }
}

// ХОРОШО — явные зависимости через конструктор
class UserService {
  final Database _db;
  UserService(this._db); // visible dependency!
  void createUser(String name) => _db.insert(name);
}
```

### Primitive Obsession

```dart
// ПЛОХО — примитивы без семантики
void transfer(String fromId, String toId, int cents) { ... }
transfer(toId, fromId, 1000); // перепутали параметры — нет ошибки компилятора!

// ХОРОШО — domain types
extension type UserId(String id) {}
extension type AmountCents(int value) {}

void transfer(UserId from, UserId to, AmountCents amount) { ... }
transfer(toId, fromId, amount); // если типы перепутать — ошибка компилятора
```

### Анемичная доменная модель

```dart
// ПЛОХО — модель без поведения; вся логика в сервисах
class Order {
  String id = '';
  String status = 'pending';
  int totalCents = 0;
}

class OrderService {
  bool canShip(Order order) => order.status == 'paid'; // логика снаружи
}

// ХОРОШО — поведение в модели
class Order {
  final String id;
  final OrderStatus status;
  final Money total;

  bool get canBeShipped => status == OrderStatus.paid;
  Order confirm() => copyWith(status: OrderStatus.confirmed);
}
```

### Shotgun Surgery

```dart
// ПЛОХО — одно изменение требует правок в 10 местах
// Признак: дублирование логики по всему коду

// ХОРОШО — Single Responsibility; знание об N хранится в одном месте
const kMaxRetries = 3;
const kRequestTimeout = Duration(seconds: 30);
```

---

## 8. Практический пример: Clean Architecture сервер

```dart
// domain/entities/product.dart
@immutable
class Product {
  final String id;
  final String name;
  final Money price;
  final int stockQuantity;

  const Product({...});

  bool get isAvailable => stockQuantity > 0;
  Product reserve(int quantity) => copyWith(stockQuantity: stockQuantity - quantity);
}

// domain/repositories/product_repository.dart
abstract interface class ProductRepository {
  Future<Product?> findById(String id);
  Future<List<Product>> findAvailable();
  Future<Product> save(Product product);
}

// domain/services/checkout_service.dart
class CheckoutService {
  final ProductRepository _products;
  final OrderRepository _orders;
  final PaymentGateway _payments;

  CheckoutService(this._products, this._orders, this._payments);

  Future<Order> checkout(String productId, int quantity, String userId) async {
    final product = await _products.findById(productId);
    if (product == null) throw NotFoundException('product/$productId');
    if (!product.isAvailable) throw DomainException('Out of stock');
    if (product.stockQuantity < quantity) {
      throw DomainException('Only ${product.stockQuantity} available');
    }

    final total = product.price.multiply(quantity.toDouble());
    final payment = await _payments.charge(userId, total);

    await _products.save(product.reserve(quantity));

    return await _orders.save(Order(
      id: generateId(),
      userId: userId,
      productId: productId,
      quantity: quantity,
      total: total,
      paymentId: payment.id,
    ));
  }
}

// presentation/handlers/checkout_handler.dart  
class CheckoutHandler {
  final CheckoutService _service;
  CheckoutHandler(this._service);

  Future<Response> handle(Request request) async {
    final body = jsonDecode(await request.readAsString());
    
    try {
      final order = await _service.checkout(
        body['product_id'] as String,
        body['quantity'] as int,
        request.headers['user-id']!,
      );
      return Response.ok(jsonEncode(order.toJson()));
    } on NotFoundException catch (e) {
      return Response.notFound(jsonEncode({'error': e.message}));
    } on DomainException catch (e) {
      return Response(400, body: jsonEncode({'error': e.message}));
    }
  }
}
```

---

## 9. Краткое резюме

1. **Слоистая архитектура**: domain (бизнес) → data (инфраструктура) → presentation (интерфейс)
2. **DI через конструктор** — явные зависимости, легко тестировать; Service Locator скрывает зависимости
3. **Иммутабельные объекты** + `copyWith` — меньше багов, безопаснее в concurrent коде
4. **Repository** — только CRUD; **Service** — бизнес-логика; разделяйте ответственности
5. **Anti GodObject**: разбивайте классы с большим количеством методов
6. **Extension types для domain types** — `UserId`, `Money`, `Email` вместо `String`/`int`
7. **Анемичная модель** — антипаттерн; логика должна быть в сущностях, не только в сервисах
8. **Composition Root** — создавайте все зависимости в одном месте (обычно `main()`)
