# Реестр сторонних ассетов (asset licence ledger)

Статус **RED** означает: происхождение/лицензия не подтверждены, ассет **нельзя**
включать в публичный релиз (APK/IPA в магазинах) до письменного подтверждения
прав. Ассеты остаются в репозитории по решению владельца проекта и помечены как
риск; публикация блокируется чек-листом в конце файла.

Проверка покрытия: `python tools/check_assets.py` (предупреждения),
`python tools/check_assets.py --strict` (ненулевой код при любом RED — для
релизной ветки/тега).

| Файл | Тип | Источник | Автор | Лицензия | Статус | Примечание |
|---|---|---|---|---|---|---|
| `lada_vaz_2110_rigged.glb` | 3D-модель | архив проекта, конвертация из `lada_vaz_2110.glb` | неизвестен | не подтверждена | RED | Права на модель не предоставлены |
| `lada_vaz_2110_rigged_low.glb` | 3D-модель (LOD) | производная от `lada_vaz_2110_rigged.glb` | неизвестен | наследует исходную | RED | Децимация glTF Transform; та же правовая неопределённость |
| `priora_rigged.glb` | 3D-модель | архив проекта | неизвестен | не подтверждена | RED | Права на модель не предоставлены |
| `priora_rigged_low.glb` | 3D-модель (LOD) | производная от `priora_rigged.glb` | неизвестен | наследует исходную | RED | Децимация glTF Transform |
| `icon.png` | иконка | архив проекта | неизвестен | не подтверждена | YELLOW | Заменить перед публикацией при необходимости |
| `bollard.glb` | окружение | OpenStreetMap Racer (вендоренная копия) | авторы апстрима | не предоставлена | RED | `THIRD_PARTY_NOTICES.txt`: лицензия апстрима не передана |
| `building_panel_5fl.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `building_panel_9fl.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `bus_stop.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `car.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `city_limit.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `city_props_pack.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `give_way.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `street_lamp-bent_mast.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `traffic_light.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `tree.glb` | окружение | OpenStreetMap Racer | авторы апстрима | не предоставлена | RED | То же |
| `triumph_mall.glb` | окружение | архив проекта (Blender) | неизвестен | не подтверждена | RED | landmark вместо процедурной застройки |
| `car_engine.mp3` | звук | Freesound #512558 (`modman34`) | modman34 | Freesound, не проверена | YELLOW | Указать конкретную CC-лицензию перед релизом |
| `dirt_driving.ogg` | звук | Freesound #268175 (`gis_sweden`) | gis_sweden | Freesound, не проверена | YELLOW | То же |
| `impact.wav` | звук | Freesound #682371 (`pnmcarrierailfan`) | pnmcarrierailfan | Freesound, не проверена | YELLOW | То же |
| `tire_screech.wav` | звук | Freesound #71737 (`audible-edge`) | audible-edge | Freesound, не проверена | YELLOW | То же |
| `rain_generated.wav` | звук | сгенерирован процедурно для патча | проект | собственная | GREEN | Детерминированный шум |
| `ambience_wind.wav` | звук | сгенерирован `tools/generate_ambience.py` | проект | собственная | GREEN | Процедурный ветер, CC0 по построению |
| `ambience_water.wav` | звук | сгенерирован `tools/generate_ambience.py` | проект | собственная | GREEN | Процедурная вода, CC0 по построению |
| `4000.wav` | звук | Godot Easy Vehicle Physics (GEVP) | авторы GEVP | MIT (см. `addons/gevp/LICENSE`) | GREEN | Проверить сохранение уведомления при релизе |
| `map.osm` | данные карты | OpenStreetMap contributors | OSM contributors | ODbL 1.0 | GREEN | Нужна атрибуция «© OpenStreetMap contributors» |
| `triumph_600m.osm` | данные карты | OpenStreetMap contributors | OSM contributors | ODbL 1.0 | GREEN | То же |

## Источники, не входящие в сборку

`source_assets/` (Blender-исходники, оригинальные GLB, текстуры машин) исключён из
экспорта через `.gdignore` и `exclude_filter`, но остаётся в репозитории как
исходный материал. Правовой статус тот же, что у производных выше.

## Чек-лист перед публичным релизом

- [ ] Подтвердить права на `lada_vaz_2110_*`, `priora_*` (или заменить модели).
- [ ] Подтвердить лицензию окружения OpenStreetMap Racer (или заменить ассеты).
- [ ] Указать конкретные лицензии Freesound для четырёх звуков.
- [ ] Проверить сохранение ODbL-атрибуции в экране «Авторы и лицензии».
- [ ] `python tools/check_assets.py --strict` завершается с кодом 0.
