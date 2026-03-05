# 12.4 Работа с зависимостями и конфликты

## 1. Формальное определение

**Зависимость (dependency)** — это внешний пакет, который использует ваш проект. Dart различает несколько категорий зависимостей в `pubspec.yaml`:

| Секция                 | Назначение                     | Попадает в итоговую сборку |
| ---------------------- | ------------------------------ | -------------------------- |
| `dependencies`         | Основные зависимости           | Да                         |
| `dev_dependencies`     | Тесты, генерация кода, линтеры | Нет                        |
| `dependency_overrides` | Принудительная подмена версии  | Зависит от контекста       |

**Разрешение зависимостей (dependency resolution)** — алгоритм, которым `pub` подбирает совместимые версии всех прямых и транзитивных зависимостей.

## 2. Зачем это нужно

- **Совместимость** — десятки пакетов должны работать вместе без конфликтов.
- **Воспроизводимость** — `pubspec.lock` фиксирует точные версии для стабильных сборок.
- **Безопасность** — контроль того, какой код попадает в проект.
- **Масштаб** — большие проекты используют сотни транзитивных зависимостей.

## 3. Как это работает

### Типы зависимостей

```yaml
# pubspec.yaml
dependencies:
  # С pub.dev (основной способ)
  http: ^1.2.0
  path: ^1.9.0

  # Git-зависимость
  my_utils:
    git:
      url: https://github.com/user/my_utils.git
      ref: main # ветка, тег или коммит
      path: packages/utils # путь внутри репозитория

  # Локальная зависимость (для разработки монорепо)
  shared_models:
    path: ../shared_models

dev_dependencies:
  test: ^1.25.0
  lints: ^4.0.0
  build_runner: ^2.4.0
  mockito: ^5.4.0
```

### Транзитивные зависимости

```
┌─────────── Ваш проект ───────────┐
│                                   │
│  Прямая зависимость: http ^1.2.0  │
│         │                         │
│         ├── http_parser ^4.0.0    │ ← транзитивная
│         ├── async ^2.11.0         │ ← транзитивная
│         └── meta ^1.9.0           │ ← транзитивная
│                                   │
│  Прямая зависимость: shelf ^1.4.0 │
│         │                         │
│         ├── http_parser ^4.0.0    │ ← общая транзитивная
│         ├── path ^1.9.0           │ ← транзитивная
│         └── stream_channel ^2.1.0 │ ← транзитивная
│                                   │
└───────────────────────────────────┘
```

### Просмотр дерева зависимостей

```bash
# Компактный вид
dart pub deps --style=compact

# Полное дерево
dart pub deps --style=tree

# Пример вывода:
# my_app 1.0.0
# ├── http 1.2.1
# │   ├── async 2.11.0
# │   ├── http_parser 4.0.2
# │   └── meta 1.11.0
# └── shelf 1.4.1
#     ├── http_parser 4.0.2  (shared)
#     └── path 1.9.0
```

## 4. pubspec.lock

Файл `pubspec.lock` автоматически генерируется `pub` и фиксирует точные версии:

```yaml
# pubspec.lock (автогенерируемый)
packages:
  async:
    dependency: transitive
    description:
      name: async
      sha256: "947bfcf187f74dbc5e146c9eb9c0f10c9f8b30743e341481c1e2ed3ecc18c20c"
    source: hosted
    version: "2.11.0"
  http:
    dependency: "direct main"
    description:
      name: http
      sha256: "761a297c042f89b76..."
    source: hosted
    version: "1.2.1"
```

### Правила работы с pubspec.lock

```
┌──────────────── pubspec.lock ────────────────────┐
│                                                   │
│  Приложение (bin/, web/):                         │
│    ✅ Коммитить в git                             │
│    → Гарантирует одинаковые версии у всех         │
│                                                   │
│  Библиотечный пакет (lib/):                       │
│    ❌ НЕ коммитить в git                          │
│    → Потребители сами решают версии               │
│    → Добавить в .gitignore                        │
│                                                   │
└───────────────────────────────────────────────────┘
```

## 5. Конфликты зависимостей

### Причина конфликтов

```
Ваш проект
├── package_a: требует foo ^1.0.0  (>=1.0.0 <2.0.0)
└── package_b: требует foo ^2.0.0  (>=2.0.0 <3.0.0)

→ Конфликт! Нет версии foo, удовлетворяющей обоим.
```

### Диагностика

```bash
# pub покажет ошибку при разрешении:
dart pub get

# Because package_a 1.0.0 depends on foo ^1.0.0
# and package_b 2.0.0 depends on foo ^2.0.0,
# package_a 1.0.0 is incompatible with package_b 2.0.0.
```

### Способы разрешения

#### 1. Обновить зависимость

```yaml
# Если package_a выпустил новую версию с foo ^2.0.0
dependencies:
  package_a: ^2.0.0 # обновлённый, теперь тоже foo ^2.0.0
  package_b: ^2.0.0
```

#### 2. dependency_overrides (временное решение)

```yaml
dependencies:
  package_a: ^1.0.0
  package_b: ^2.0.0

# Принудительно использовать конкретную версию
dependency_overrides:
  foo: ^2.0.0
```

> ⚠️ **Внимание**: `dependency_overrides` обходит проверку совместимости. package_a может сломаться, если foo 2.x несовместим с ожиданиями package_a. Используйте только как временную меру.

#### 3. Форк зависимости

```yaml
dependencies:
  # Используем свой форк с исправленными зависимостями
  package_a:
    git:
      url: https://github.com/your-fork/package_a.git
      ref: fix-foo-version
```

#### 4. Связаться с мейнтейнером

```bash
# Открыть issue в репозитории package_a
# с просьбой обновить зависимость foo до ^2.0.0
```

## 6. Команды управления зависимостями

```bash
# Получить зависимости (по pubspec.yaml)
dart pub get

# Обновить до последних совместимых версий
dart pub upgrade

# Обновить конкретный пакет
dart pub upgrade http

# Обновить с мажорными версиями
dart pub upgrade --major-versions

# Показать устаревшие зависимости
dart pub outdated

# Пример вывода dart pub outdated:
# ┌──────────┬─────────┬───────────┬────────┬────────┐
# │ Package  │ Current │ Upgradable│ Resolvable│ Latest│
# ├──────────┼─────────┼───────────┼────────┼────────┤
# │ http     │ 1.1.0   │ 1.2.1     │ 1.2.1  │ 2.0.0  │
# │ test     │ 1.24.0  │ 1.25.2    │ 1.25.2 │ 1.25.2 │
# └──────────┴─────────┴───────────┴────────┴────────┘

# Использовать минимально допустимые версии
dart pub downgrade

# Добавить зависимость из командной строки
dart pub add http
dart pub add test --dev
dart pub add my_pkg --git-url=https://github.com/user/my_pkg.git

# Удалить зависимость
dart pub remove http
```

## 7. dev_dependencies vs dependencies

```yaml
dependencies:
  # Попадают в итоговый бинарник / доступны потребителям пакета
  http: ^1.2.0
  path: ^1.9.0

dev_dependencies:
  # Только для разработки — не влияют на потребителей
  test: ^1.25.0 # Тестирование
  lints: ^4.0.0 # Линтер
  build_runner: ^2.4.0 # Генерация кода
  mockito: ^5.4.0 # Моки
  coverage: ^1.7.0 # Покрытие
```

```
┌────────── Правило размещения ──────────────────┐
│                                                 │
│  Нужен при компиляции / runtime?                │
│    → dependencies                               │
│                                                 │
│  Нужен только при разработке / тестировании?    │
│    → dev_dependencies                           │
│                                                 │
│  Перенос из dev в main → MINOR bump             │
│  Перенос из main в dev → MAJOR bump             │
│  (потребители теряют транзитивный доступ)        │
│                                                 │
└─────────────────────────────────────────────────┘
```

## 8. Монорепо и локальные зависимости

Для проектов с несколькими пакетами в одном репозитории:

```
my_monorepo/
├── packages/
│   ├── core/
│   │   └── pubspec.yaml
│   ├── api_client/
│   │   └── pubspec.yaml      ← зависит от core
│   └── app/
│       └── pubspec.yaml      ← зависит от core и api_client
└── melos.yaml                ← инструмент для монорепо
```

```yaml
# packages/api_client/pubspec.yaml
dependencies:
  core:
    path: ../core # Локальная зависимость
```

### Melos — инструмент для монорепо

```yaml
# melos.yaml
name: my_monorepo
packages:
  - packages/**

scripts:
  analyze:
    run: dart analyze .
    exec:
      concurrency: 5
  test:
    run: dart test
    exec:
      concurrency: 5
  publish:
    run: melos publish --no-dry-run
```

```bash
# Установка melos
dart pub global activate melos

# Bootstrap — связать все пакеты
melos bootstrap

# Запустить тесты во всех пакетах
melos run test

# Запустить анализ
melos run analyze
```

## 9. Hosted dependencies и альтернативные источники

```yaml
dependencies:
  # Стандартный hosted (pub.dev)
  http: ^1.2.0

  # Приватный pub-сервер
  internal_utils:
    hosted:
      name: internal_utils
      url: https://pub.mycompany.com
    version: ^1.0.0

  # SDK-зависимость
  flutter:
    sdk: flutter
```

```bash
# Настройка токена для приватного сервера
dart pub token add https://pub.mycompany.com
```

## 10. Распространённые ошибки

### ❌ Забытый dart pub get после изменения pubspec.yaml

```bash
# Изменили pubspec.yaml, но не обновили зависимости
# → Ошибки импорта, несоответствие версий
dart pub get  # Всегда после изменений!
```

### ❌ Коммит pubspec.lock для библиотеки

```gitignore
# .gitignore для библиотечного пакета
pubspec.lock   # НЕ коммитим — потребители решают сами
```

### ❌ dependency_overrides в опубликованном пакете

```yaml
# dependency_overrides игнорируются при публикации!
# Они работают только локально.
# Не полагайтесь на них в production-коде.
```

### ❌ Циклические зависимости

```
package_a → package_b → package_a  ← ОШИБКА!

# Решение: выделить общий код в третий пакет
package_a → shared
package_b → shared
```

### ❌ Слишком много прямых зависимостей

```yaml
# Каждая зависимость — это риск:
# - Обновления могут сломать код
# - Больше поверхность для уязвимостей
# - Дольше разрешение версий

# Периодически проверяйте:
dart pub deps --style=compact
# Убирайте неиспользуемые зависимости
```

## 11. Полезные команды (сводка)

```bash
# Основные
dart pub get                    # Установить зависимости
dart pub upgrade                # Обновить до последних совместимых
dart pub upgrade --major-versions  # + мажорные обновления
dart pub downgrade              # Минимальные допустимые версии
dart pub outdated               # Показать устаревшие

# Управление
dart pub add <pkg>              # Добавить зависимость
dart pub add <pkg> --dev        # Добавить dev-зависимость
dart pub remove <pkg>           # Удалить зависимость

# Диагностика
dart pub deps                   # Дерево зависимостей
dart pub deps --style=compact   # Компактный вид
dart pub cache repair           # Починить кэш
dart pub cache clean            # Очистить кэш

# Приватные серверы
dart pub token add <url>        # Аутентификация
dart pub token list             # Список токенов
dart pub token remove <url>     # Удалить токен
```

---

> **Назад:** [12.3 Семантическое версионирование](12_03_semver.md) · **Далее:** [13.0 Генерация кода и build_runner](../13_codegen/13_00_overview.md)
