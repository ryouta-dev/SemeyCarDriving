# Semey Car Driving

Мобильный автосимулятор-прототип на Godot 4.7: город Семей, собранный из
OpenStreetMap, гараж с тюнингом, три автомобиля, испытания и прототип трафика.

> **Статус: 0.0.4, тестовый кандидат.** Это исходный проект, а не собранный
> APK/IPA. Runtime-проверки выполняются в Godot 4.7.2; сборка под Android
> проверяется в CI, установка на устройство и профилирование ещё не проводились.

> **Идёт переработка (ветка `rework/m1`).** Контекст для нового чата и текущий
> план — [plan.md](plan.md); концепт вертикального среза — [docs/REWORK_M1.md](docs/REWORK_M1.md).
> Стабильная 0.0.4 остаётся в ветке `main`.

## Быстрый старт

1. Установить **Godot 4.7.2** (стандартная сборка, не .NET) и export templates
   той же версии.
2. Открыть `project.godot`, дождаться импорта (первый импорт GLB занимает
   несколько минут).
3. `F5` — запуск из гаража, `F6` — текущая сцена.

Проверки из командной строки:

```powershell
# Python (Windows: UTF-8 обязателен)
$env:PYTHONUTF8 = "1"
python -X utf8 -m unittest discover -s tests -p "test_*.py" -v

# Godot: чистый импорт и runtime-проверки
godot --headless --path . --editor --import --quit
godot --headless --path . --audio-driver Dummy --script res://tests/runtime_tests.gd
```

Полный чек-лист — [docs/TESTING.md](docs/TESTING.md), мобильная проверка —
[docs/MOBILE_TESTING.md](docs/MOBILE_TESTING.md).

## Управление

| Действие | ПК | Телефон |
|---|---|---|
| Газ / тормоз | W / S | педали справа |
| Руль | A / D | стрелки или виртуальный руль |
| Ручник | Space | кнопка «РУЧНИК» |
| Передачи | E / Q | «+» / «−», режим АКПП/МКПП |
| Камера | C / V | кнопка «КАМЕРА» |
| Обзор камерой | зажать ЛКМ/ПКМ и вести мышью | свайп пальцем по экрану |
| Вернуть машину | R | меню → «Вернуть машину» |
| Гараж | G / Escape | меню → «В гараж» |
| Погода / свет | F5 / F6 | меню |

Меню и редактор раскладки ставят игру на паузу.

## Что внутри

- **Город:** тайловый стриминг OSM (`data/triumph_600m.osm`), процедурные дороги,
  перекрёстки, здания, коллизии, день/ночь, дождь и мокрое сцепление.
- **Гараж:** покраска, стэнс (клиренс, развал, вылет, жёсткость), свап четырёх
  моторов, RWD/AWD, главная пара, три автомобиля (Muscle, ВАЗ-2110, Priora).
- **Качество:** `high` — полная модель, `balanced`/`low` — облегчённая копия
  (Lada: 428 858 → 128 549 треугольников, текстуры 2048 → 1024).
- **Геймплей:** Kudos, кредиты, испытания «спринт», «парковка», «дрифт».
- **Трафик:** экспериментальный, 2–4 простых машины, по умолчанию выключен.

## Структура

```
scripts/            геймплей, мир OSM, UI, тюнинг
addons/gevp/        физика автомобиля (форк Godot Easy Vehicle Physics)
addons/pro_vehicle_camera/
scenes/             garage.tscn, main.tscn, test_track.tscn
data/               OSM-данные и определения автомобилей
tests/              Python-проверки и Godot runtime-тесты
docs/               тестирование, остаточные ограничения, реестр лицензий
tools/              запекание тайлов, аудит ассетов, статистика GLB
source_assets/      исходники (Blender/оригинальные GLB), не входят в сборку
```

## Ограничения

Актуальный список — [docs/REMAINING.md](docs/REMAINING.md). Кратко: карта —
фрагмент ~600 м, а не весь Семей; геометрия колёс/масс требует калибровки;
трафик не соблюдает ПДД; ABS/TCS/ESP не подключены; APK/IPA не собраны;
производительность на реальном телефоне не измерена.

## Лицензии

- Код проекта — MIT, см. [LICENSE](LICENSE).
- Сторонние библиотеки и ассеты — [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt)
  и [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md).
- Карта: © OpenStreetMap contributors, ODbL 1.0.
- **Внимание:** права на модели автомобилей, часть звуков и ассеты окружения
  не подтверждены (статус RED). Публичный релиз блокируется чек-листом в реестре.

## Безопасность

Секреты не хранятся в репозитории: `.env` в `.gitignore`, история очищена от
старого `.env` (см. [docs/SECURITY_NOTES.md](docs/SECURITY_NOTES.md)). Токены —
только в GitHub Secrets.

## English summary

Semey Car Driving is a Godot 4.7 mobile driving prototype: an OSM-derived city
(Triumph Mall area of Semey, Kazakhstan), a garage with paint/stance/engine
tuning, three cars, time-of-day and rain, Kudos challenges and an experimental
traffic prototype. It ships as source only; Android is built in CI as a debug APK,
iOS exports an Xcode project. Code is MIT; third-party assets are listed in
`docs/ASSET_LICENSES.md` and several are still unlicensed (RED) — do not publish a
store build before resolving them. See `docs/REMAINING.md` for known gaps.
