# 16.3 Immutable data и value objects

## 1. Формальное определение

**Неизменяемый объект (immutable)** — объект, чьё состояние нельзя изменить после создания. Любое «изменение» создаёт новый объект.

**Value Object** — объект, идентичность которого определяется его значениями, а не ссылкой. Два value object'а с одинаковыми полями считаются равными.

## 2. Зачем это нужно

- **Предсказуемость** — объект не изменится неожиданно из другого места.
- **Потокобезопасность** — immutable объекты безопасны для Isolate.
- **Кэширование** — можно свободно хранить и передавать.
- **Отладка** — проще отследить, где создаётся новое состояние.
- **Равенство** — value objects сравниваются по содержимому, не по ссылке.

## 3. Реализация в Dart

### Ручная реализация

```dart
class Money {
  final int amount;
  final String currency;

  const Money(this.amount, this.currency);

  Money add(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
    return Money(amount + other.amount, currency);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          amount == other.amount &&
          currency == other.currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => '$currency $amount';
}

// Использование
const price = Money(100, 'USD');
final discounted = price.add(Money(-20, 'USD'));
print(discounted); // USD 80

// Равенство по значению
Money(100, 'USD') == Money(100, 'USD'); // true
```

### С freezed (рекомендуемый способ)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'money.freezed.dart';

@freezed
class Money with _$Money {
  const Money._();

  const factory Money({
    required int amount,
    required String currency,
  }) = _Money;

  Money add(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Currency mismatch');
    }
    return copyWith(amount: amount + other.amount);
  }
}

// Автоматически получаем:
// - ==, hashCode
// - toString
// - copyWith
```

### Неизменяемые коллекции

```dart
import 'package:collection/collection.dart';

class Order {
  final String id;
  final List<String> _items;

  Order({required this.id, required List<String> items})
      : _items = List.unmodifiable(items);

  // Возвращаем unmodifiable — не скопировать, не изменить
  List<String> get items => _items;

  // «Изменение» создаёт новый Order
  Order addItem(String item) =>
      Order(id: id, items: [..._items, item]);

  Order removeItem(String item) =>
      Order(id: id, items: _items.where((i) => i != item).toList());
}
```

## 4. Паттерн copyWith

```dart
class AppState {
  final User user;
  final List<Product> cart;
  final bool isLoading;

  const AppState({
    required this.user,
    this.cart = const [],
    this.isLoading = false,
  });

  AppState copyWith({
    User? user,
    List<Product>? cart,
    bool? isLoading,
  }) {
    return AppState(
      user: user ?? this.user,
      cart: cart ?? this.cart,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Использование
final state = AppState(user: currentUser);
final loading = state.copyWith(isLoading: true);
final withCart = loading.copyWith(
  cart: [Product('Widget')],
  isLoading: false,
);
```

## 5. Когда использовать мутабельность

```
┌──────────── Immutable vs Mutable ─────────────────┐
│                                                    │
│  Immutable (предпочтительно):                      │
│  ├── Модели данных (User, Product, Order)          │
│  ├── Состояние приложения (State)                  │
│  ├── Конфигурация                                 │
│  ├── Value Objects (Money, Email, Address)         │
│  └── DTO (Data Transfer Objects)                   │
│                                                    │
│  Mutable (допустимо):                              │
│  ├── Builders (StringBuffer, ListBuilder)          │
│  ├── Внутренние кэши                              │
│  ├── Контроллеры с внутренним состоянием           │
│  └── Performance-критичные структуры               │
│                                                    │
└────────────────────────────────────────────────────┘
```

## 6. Распространённые ошибки

### ❌ Мутабельный объект с переопределённым ==

```dart
// Опасно! Если объект в Set/Map и его поля меняются —
// хэш изменится, объект «потеряется» в коллекции.
class User {
  String name;  // мутабельное поле!
  @override
  bool operator ==(Object other) =>
      other is User && name == other.name;
  @override
  int get hashCode => name.hashCode;
}

// Правило: если переопределяете == — делайте объект immutable
```

### ❌ Утечка мутабельных коллекций

```dart
// Плохо — вызывающий код может изменить внутренний список
class Cart {
  final List<Product> _items = [];
  List<Product> get items => _items;  // утечка ссылки!
}

// Хорошо — возвращаем неизменяемую копию
class Cart {
  final List<Product> _items = [];
  List<Product> get items => List.unmodifiable(_items);
}
```

---

> **Назад:** [16.2 Dependency Injection](16_02_di.md) · **Далее:** [16.4 Антипаттерны](16_04_antipatterns.md)
