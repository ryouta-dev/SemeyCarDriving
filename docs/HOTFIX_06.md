# Hotfix 06 — заголовки классов и UID

Исправляет ошибку предыдущего патча: const был вставлен перед class_name. Все глобальные объявления классов теперь стоят перед объявлениями тела скрипта. Удалён скопированный UID из scenes/main.tscn; Godot назначит сцене отдельный UID при импорте. UID исходной демонстрационной сцены GEVP сохранён.

Патч накопительный для мобильного полного архива 0.0.3: содержит также все изменённые файлы hotfix 05. Закрыть Godot, распаковать в папку с project.godot с заменой файлов, удалить только кеш .godot и открыть project.godot снова. Старые hotfix 05 и более ранние поверх НЕ применять.

## Android build-tools — настройка компьютера, не исходников

1. В Android Studio открыть SDK Manager. Установить Android SDK Build-Tools, Android SDK Platform-Tools, Android SDK Command-line Tools и SDK Platform для версии, которую требует ваш Godot.
2. Проверить, что в корне установленного SDK действительно есть build-tools/<версия>/ и platform-tools/. Версию согласовать с документацией вашей версии Godot; патч не устанавливает SDK и не проверяет конкретную версию.
3. В Godot Editor Settings → Export → Android указать Android SDK Path именно на корень SDK, не на build-tools, platform-tools или sdkmanager. Указать Java SDK Path на корень требуемого JDK (для прежней конфигурации CI использовался JDK 17; требования вашей версии движка проверять отдельно).
4. Типовые корни: Windows %LOCALAPPDATA%\Android\Sdk; macOS ~/Library/Android/sdk; Linux ~/Android/Sdk. Реальный путь смотреть в SDK Manager.
5. Установить export templates той же версии, что и сам Godot, и повторить debug export.

Если ошибка сохраняется: нужны версия Godot, ОС компьютера и путь Android SDK, указанный в редакторе. Пароли/ключи отправлять не нужно.

Здесь выполнялись только Python-проверки исходников/ресурсов/геометрии и ZIP CRC. Godot-компиляция и Android SDK-проверка НЕ выполнялись: движок и SDK отсутствуют.
