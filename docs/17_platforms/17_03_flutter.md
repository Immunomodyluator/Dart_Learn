# 17.3 Flutter — краткий обзор

## 1. Формальное определение

**Flutter** — UI-фреймворк от Google, использующий Dart как единственный язык разработки. Flutter рисует UI через собственный графический движок (Impeller / Skia), не используя нативные виджеты платформы.

## 2. Связь Dart и Flutter

```
┌───────────── Dart во Flutter ─────────────────────┐
│                                                    │
│  Dart обеспечивает:                                │
│  ├── Язык программирования и типовая система      │
│  ├── async/await для реактивного UI               │
│  ├── AOT-компиляция → быстрый старт (мобайл)     │
│  ├── JIT-компиляция → hot reload (разработка)     │
│  ├── Isolate → тяжёлые вычисления без блокировки  │
│  └── Единый код для всех платформ                 │
│                                                    │
│  Flutter обеспечивает:                             │
│  ├── Widget-система для UI                        │
│  ├── Графический движок (Impeller)                │
│  ├── Платформенные каналы (Method Channels)       │
│  └── Инструменты (flutter CLI, DevTools)          │
│                                                    │
└────────────────────────────────────────────────────┘
```

## 3. Поддерживаемые платформы

| Платформа | Статус    | Компиляция          |
| --------- | --------- | ------------------- |
| Android   | Стабильно | AOT (ARM)           |
| iOS       | Стабильно | AOT (ARM)           |
| Web       | Стабильно | dart2js / dart2wasm |
| Windows   | Стабильно | AOT (x64)           |
| macOS     | Стабильно | AOT (ARM/x64)       |
| Linux     | Стабильно | AOT (x64)           |

## 4. Базовая структура Flutter-приложения

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Text(
          'Count: $_counter',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _counter++),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## 5. Ключевые концепции Flutter

### Виджеты — всё есть виджет

```dart
// StatelessWidget — без внутреннего состояния
class Greeting extends StatelessWidget {
  final String name;
  const Greeting({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Text('Hello, $name!');
  }
}

// StatefulWidget — с состоянием
class Counter extends StatefulWidget {
  const Counter({super.key});
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _count++),
      child: Text('Count: $_count'),
    );
  }
}
```

### Hot Reload

```
┌──────────── Hot Reload ──────────────────────────┐
│                                                   │
│  JIT-компиляция при разработке позволяет:         │
│  ├── Изменить код в редакторе                    │
│  ├── Ctrl+S → UI обновляется за ~1 секунду       │
│  ├── Состояние сохраняется                       │
│  └── Не нужен полный перезапуск                  │
│                                                   │
│  Это возможно благодаря Dart VM (JIT mode)        │
│                                                   │
└───────────────────────────────────────────────────┘
```

## 6. Управление состоянием

```dart
// Популярные подходы:
// ├── setState (встроенный, простой)
// ├── Provider / Riverpod (DI + reactive)
// ├── Bloc / Cubit (event-driven)
// └── GetX, MobX, и др.

// Пример с Riverpod:
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterProvider = StateProvider<int>((ref) => 0);

class CounterPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Text('Count: $count');
  }
}
```

## 7. Команды Flutter CLI

```bash
# Создание проекта
flutter create my_app

# Запуск
flutter run

# Сборка
flutter build apk          # Android
flutter build ios           # iOS
flutter build web           # Web
flutter build windows       # Windows

# Тесты
flutter test

# Анализ
flutter analyze
```

---

> **Назад:** [17.2 Dart для веба](17_02_web.md) · **Далее:** [17.4 CLI-приложения](17_04_cli.md)
