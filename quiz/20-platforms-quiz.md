# Квиз: 20. Платформенные применения

> 4 вопроса • Уровень: Junior–Middle • [Урок →](../lessons/20-platforms.md)

---

### Вопрос 1 (20.1): Backend с Shelf

Как правильно скомпоновать middleware и handler в Shelf?

```dart
final handler = const Pipeline()
    .???
    .???;
```

- A) `Pipeline().use(logger).build(myHandler)`
- B) `Pipeline().addMiddleware(logRequests()).addHandler(myHandler)`
- C) `Pipeline().with(logRequests).serve(myHandler)`
- D) `Pipeline([logRequests()], myHandler)`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `Pipeline().addMiddleware(logRequests()).addHandler(myHandler)`**

Shelf использует паттерн Builder: `addMiddleware` добавляет промежуточные обработчики (logger, CORS, auth) в цепочку, `addHandler` устанавливает финальный обработчик запроса. Middleware выполняются в порядке добавления. `logRequests()` — встроенный middleware из `package:shelf`.
</details>

---

### Вопрос 2 (20.2): Компиляция для Web

Какой флаг `dart compile js` включает максимальную оптимизацию для продакшна?

- A) `dart compile js -O2 main.dart`
- B) `dart compile js -O4 --minify -o build/app.js main.dart`
- C) `dart compile wasm --release main.dart`
- D) `dart build web --production main.dart`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `dart compile js -O4 --minify -o build/app.js main.dart`**

`-O4` — максимальный уровень оптимизации dart2js: включает tree shaking, inlining, type inference. `--minify` убирает пробелы и переименовывает переменные. Без флагов оптимизации выходной JS значительно больше и медленнее. Для Flutter web аналогичный результат даёт `flutter build web --release`.
</details>

---

### Вопрос 3 (20.3): Flutter рендеринг

Как Flutter отображает UI на разных платформах?

- A) Flutter использует нативные виджеты (UIKit на iOS, Android Views на Android)
- B) Flutter рендерит все UI-компоненты самостоятельно через собственный движок (Skia или Impeller), рисуя прямо на Canvas — нативные виджеты платформы не используются
- C) Flutter транслирует виджеты в HTML/CSS для web и в нативные View для мобильных
- D) Flutter использует React Native-подобный bridge к нативным компонентам

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Flutter рендерит все UI-компоненты самостоятельно через Skia/Impeller**

В отличие от React Native или WebView-подходов, Flutter владеет каждым пикселем: движок рисует виджеты на Low-level Canvas. Это гарантирует pixel-perfect одинаковый вид на всех платформах и 60/120 fps независимо от платформы, но означает, что Flutter-приложения не выглядят «нативно» автоматически.
</details>

---

### Вопрос 4 (20.4): CLI-приложения

Какой пакет используется для разбора аргументов командной строки с поддержкой subcommands в Dart?

- A) `dart:io` — встроенный парсинг через `Platform.executableArguments`
- B) `package:args` — предоставляет `ArgParser` с поддержкой флагов, опций и subcommands через `addCommand`
- C) `package:cli_util` — единственный официальный CLI-пакет
- D) `package:commander` — аналог npm commander для Dart

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `package:args` — `ArgParser` с поддержкой флагов, опций и subcommands**

`package:args` — официальный пакет Dart для CLI. `addFlag` добавляет булевые флаги (`--verbose`), `addOption` — значения (`--output=file.txt`), `addCommand` — подкоманды (`git commit`, `git push`). Встроенный `dart:io` даёт только сырой список `List<String>` без разбора.
</details>
