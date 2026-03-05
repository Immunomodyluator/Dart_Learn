# Квиз: 21. CI/CD

> 4 вопроса • Уровень: Junior–Middle • [Урок →](../lessons/21-cicd.md)

---

### Вопрос 1 (21.1): GitHub Actions для Dart

Какой action устанавливает Dart SDK в GitHub Actions pipeline?

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: ???
    with:
      sdk: stable
```

- A) `uses: actions/setup-dart@v1`
- B) `uses: dart-lang/setup-dart@v1`
- C) `uses: google/dart-action@v2`
- D) `uses: flutter/setup-sdk@v1`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) `uses: dart-lang/setup-dart@v1`**

Официальный action от команды Dart — `dart-lang/setup-dart`. Он устанавливает указанную версию SDK (stable, beta, dev, или конкретный номер), настраивает `PATH` и кеширует инсталляцию. `actions/setup-dart` не существует как официальный action.
</details>

---

### Вопрос 2 (21.2): Статический анализ в CI

Что произойдёт при запуске `dart analyze --fatal-infos`, если анализатор найдёт только INFO-предупреждение?

- A) Команда завершается с кодом 0 (успех), INFO игнорируется
- B) Команда завершается с ненулевым кодом (неудача), что прерывает CI pipeline
- C) Команда выводит предупреждение, но не останавливает CI
- D) Флаг `--fatal-infos` не существует в Dart

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Команда завершается с ненулевым кодом, что прерывает CI pipeline**

По умолчанию `dart analyze` завершается с ошибкой только при ERROR-диагностиках. `--fatal-infos` повышает порог: теперь INFO (самый низкий уровень) тоже считается fatal. Это полезно для строгих проектов, где даже подсказки аналитика обязательны к исправлению. Аналогично работает `--fatal-warnings`.
</details>

---

### Вопрос 3 (21.3): Docker для Dart-сервера

Зачем использовать multi-stage Dockerfile для Dart-приложения?

```dockerfile
# Stage 1: Build
FROM dart:stable AS builder
WORKDIR /app
COPY . .
RUN dart pub get && dart compile exe bin/server.dart -o server

# Stage 2: Runtime
FROM debian:bookworm-slim
COPY --from=builder /app/server /server
ENTRYPOINT ["/server"]
```

- A) Multi-stage нужен только для Flutter приложений
- B) Финальный образ содержит только скомпилированный бинарник без Dart SDK (~5–15 MB вместо ~500+ MB с SDK) — меньше уязвимостей, быстрее деплой
- C) Dart SDK нельзя удалить из образа, multi-stage не даёт преимуществ
- D) Это устаревший паттерн, сейчас используется `dart:slim`

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Финальный образ содержит только скомпилированный бинарник без Dart SDK**

`dart compile exe` создаёт self-contained исполняемый файл, который содержит Dart runtime внутри себя. Второй stage копирует только этот бинарник в минимальный образ Debian. Финальный образ не содержит Dart SDK, pub-кеша, исходников — только рантайм и бинарник. Размер образа уменьшается с ~500 MB до ~10–30 MB.
</details>

---

### Вопрос 4 (21.4): OIDC публикация на pub.dev

В чём преимущество публикации пакета через OIDC (Trusted Publishers) перед токеном?

- A) OIDC публикация работает быстрее
- B) Не нужно хранить долгоживущие секреты в GitHub Secrets: OIDC выдаёт краткосрочный токен для конкретного запуска workflow через `permissions: id-token: write`
- C) OIDC позволяет публиковать пакет без аутентификации
- D) OIDC поддерживается только в GitLab CI

<details>
<summary>Правильный ответ</summary>

**Ответ: B) Не нужно хранить долгоживущие секреты в GitHub Secrets**

Trusted Publishers (OIDC) — это безопасная альтернатива хранению `PUB_CREDENTIALS` в секретах. GitHub Actions запрашивает краткосрочный OIDC-токен у pub.dev для конкретного запуска; если workflow изменят злоумышленники — старый токен не утечёт. Требуется настройка доверенного издателя в pub.dev и `permissions: id-token: write` в YAML.
</details>
