# Dart: Полное руководство для разработчика

> Целевая аудитория: junior+ разработчик без опыта написания кода на Dart.
> Версия Dart: 3.x

---

## Оглавление

### 1. [Установка и инструменты](01_installation/01_00_overview.md)

- [1.1 Установка SDK и редакторов](01_installation/01_01_sdk_editors.md)
- [1.2 Dart CLI и dartdev инструменты](01_installation/01_02_dart_cli.md)
- [1.3 pub и pubspec.yaml](01_installation/01_03_pub_pubspec.md)
- [1.4 Форматирование, анализ и линтеры](01_installation/01_04_formatting_analysis.md)

### 2. [Основы синтаксиса](02_syntax_basics/02_00_overview.md)

- [2.1 Hello World и структура программы](02_syntax_basics/02_01_hello_world.md)
- [2.2 Объявление переменных](02_syntax_basics/02_02_variables.md)
- [2.3 Типы и вывод типов](02_syntax_basics/02_03_types_inference.md)
- [2.4 const и final](02_syntax_basics/02_04_const_final.md)
- [2.5 Null Safety](02_syntax_basics/02_05_null_safety.md)

### 3. [Встроенные типы и литералы](03_builtin_types/03_00_overview.md)

- [3.1 Числа и операции](03_builtin_types/03_01_numbers.md)
- [3.2 Строки и интерполяция](03_builtin_types/03_02_strings.md)
- [3.3 Булевы значения](03_builtin_types/03_03_booleans.md)
- [3.4 Runes и Symbols](03_builtin_types/03_04_runes_symbols.md)

### 4. [Коллекции](04_collections/04_00_overview.md)

- [4.1 List — списки](04_collections/04_01_list.md)
- [4.2 Set — множества](04_collections/04_02_set.md)
- [4.3 Map — карты](04_collections/04_03_map.md)
- [4.4 Методы коллекций](04_collections/04_04_collection_methods.md)
- [4.5 Литералы с условиями и spread](04_collections/04_05_spread_conditional.md)

### 5. [Управление потоком](05_control_flow/05_00_overview.md)

- [5.1 if / else и тернарный оператор](05_control_flow/05_01_if_else_ternary.md)
- [5.2 switch и сопоставление с образцом](05_control_flow/05_02_switch_patterns.md)
- [5.3 Циклы: for, for-in, while](05_control_flow/05_03_loops.md)
- [5.4 assert и отладочные проверки](05_control_flow/05_04_assert.md)

### 6. [Функции и замыкания](06_functions/06_00_overview.md)

- [6.1 Синтаксис функций](06_functions/06_01_syntax.md)
- [6.2 Параметры: позиционные, именованные, опциональные](06_functions/06_02_parameters.md)
- [6.3 Замыкания и лексическая область](06_functions/06_03_closures.md)
- [6.4 Типы функций и typedef](06_functions/06_04_typedefs.md)

### 7. [Объектно-ориентированное программирование](07_oop/07_00_overview.md)

- [7.1 Классы и объекты](07_oop/07_01_classes_objects.md)
- [7.2 Конструкторы и именованные конструкторы](07_oop/07_02_constructors.md)
- [7.3 Геттеры и сеттеры](07_oop/07_03_getters_setters.md)
- [7.4 Наследование и super](07_oop/07_04_inheritance.md)
- [7.5 Абстрактные классы и интерфейсы](07_oop/07_05_abstract_interfaces.md)
- [7.6 Mixins и extension methods](07_oop/07_06_mixins_extensions.md)
- [7.7 Статические члены и фабричные конструкторы](07_oop/07_07_static_factory.md)

### 8. [Дженерики и типовая система](08_generics/08_00_overview.md)

- [8.1 Обобщённые классы и методы](08_generics/08_01_generic_classes_methods.md)
- [8.2 Ограничения (bounded generics)](08_generics/08_02_bounded_generics.md)
- [8.3 Ковариантность и контравариантность](08_generics/08_03_variance.md)
- [8.4 Type aliases и typedef](08_generics/08_04_type_aliases.md)

### 9. [Асинхронность и конкурентность](09_async/09_00_overview.md)

- [9.1 Futures и обработка результатов](09_async/09_01_futures.md)
- [9.2 async / await](09_async/09_02_async_await.md)
- [9.3 Streams и реактивные последовательности](09_async/09_03_streams.md)
- [9.4 Isolates и обмен сообщениями](09_async/09_04_isolates.md)
- [9.5 Цикл событий и микрозадачи](09_async/09_05_event_loop.md)

### 10. [Обработка ошибок и безопасный код](10_error_handling/10_00_overview.md)

- [10.1 try / catch / finally](10_error_handling/10_01_try_catch.md)
- [10.2 Пользовательские исключения](10_error_handling/10_02_custom_exceptions.md)
- [10.3 Практики ретраев и компенсации](10_error_handling/10_03_retry_compensation.md)
- [10.4 Логирование и мониторинг ошибок](10_error_handling/10_04_logging.md)

### 11. [Тестирование](11_testing/11_00_overview.md)

- [11.1 Unit-тесты с пакетом test](11_testing/11_01_unit_tests.md)
- [11.2 Mocking и stubbing](11_testing/11_02_mocking.md)
- [11.3 Интеграционные и E2E тесты](11_testing/11_03_integration_tests.md)
- [11.4 Покрытие кода и CI-интеграция](11_testing/11_04_coverage_ci.md)

### 12. [Публикация и управление пакетами](12_packages/12_00_overview.md)

- [12.1 Структура пакета и документация](12_packages/12_01_package_structure.md)
- [12.2 Публикация на pub.dev](12_packages/12_02_publishing.md)
- [12.3 Семантическое версионирование](12_packages/12_03_semver.md)
- [12.4 Работа с зависимостями и конфликты](12_packages/12_04_dependencies.md)

### 13. [Генерация кода и build_runner](13_codegen/13_00_overview.md)

- [13.1 build_runner: основы](13_codegen/13_01_build_runner.md)
- [13.2 json_serializable, freezed](13_codegen/13_02_json_freezed.md)
- [13.3 Создание собственного генератора](13_codegen/13_03_custom_generator.md)

### 14. [Interop: FFI и Web](14_interop/14_00_overview.md)

- [14.1 Dart FFI](14_interop/14_01_ffi.md)
- [14.2 JS interop для веба](14_interop/14_02_js_interop.md)
- [14.3 Рефлексия и ограничения](14_interop/14_03_reflection.md)

### 15. [Производительность и профилирование](15_performance/15_00_overview.md)

- [15.1 Профайлинг с DevTools](15_performance/15_01_devtools.md)
- [15.2 Оптимизация аллокаций](15_performance/15_02_allocations.md)
- [15.3 Асинхронные узкие места](15_performance/15_03_async_bottlenecks.md)
- [15.4 Память и сборщик мусора](15_performance/15_04_gc_memory.md)

### 16. [Архитектура кода и паттерны](16_architecture/16_00_overview.md)

- [16.1 Структура проекта и модули](16_architecture/16_01_project_structure.md)
- [16.2 Dependency Injection](16_architecture/16_02_di.md)
- [16.3 Immutable data и value objects](16_architecture/16_03_immutable_data.md)
- [16.4 Антипаттерны и чистый код](16_architecture/16_04_antipatterns.md)

### 17. [Платформенные применения Dart](17_platforms/17_00_overview.md)

- [17.1 Dart на сервере](17_platforms/17_01_server.md)
- [17.2 Dart для веба](17_platforms/17_02_web.md)
- [17.3 Flutter — краткий обзор](17_platforms/17_03_flutter.md)
- [17.4 CLI-приложения на Dart](17_platforms/17_04_cli.md)

### 18. [CI/CD и развёртывание](18_cicd/18_00_overview.md)

- [18.1 Настройка CI](18_cicd/18_01_ci_setup.md)
- [18.2 Статический анализ в CI](18_cicd/18_02_static_analysis_ci.md)
- [18.3 Контейнеризация и деплой](18_cicd/18_03_docker_deploy.md)
- [18.4 Автоматическая публикация пакетов](18_cicd/18_04_auto_publish.md)

### 19. [Безопасность и защита кода](19_security/19_00_overview.md)

- [19.1 Валидация входных данных](19_security/19_01_input_validation.md)
- [19.2 Управление секретами](19_security/19_02_secrets.md)
- [19.3 Безопасность при взаимодействии с нативом/JS](19_security/19_03_native_js_security.md)

### 20. [Переход к продвинутым темам](20_advanced/20_00_overview.md)

- [20.1 Глубокое изучение типов и компиляции](20_advanced/20_01_types_compilation.md)
- [20.2 Вклад в экосистему и OSS](20_advanced/20_02_oss.md)
- [20.3 Практические проекты и портфолио](20_advanced/20_03_portfolio.md)
