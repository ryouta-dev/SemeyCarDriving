# 0.0.4 — tech-debt pass (no new gameplay)

- Repository hygiene: dropped vendored upstream copies, `.blend1`, job-runner
  leftovers (`run.json`, `jobs.json`, `get_jobs.ps1`) and three orphan `.uid`
  files; added `.gitattributes` (LF + binary markers) and a stricter `.gitignore`.
- Removed the 21 unrigged car images (`lada_vaz_2110_0..10`, `priora_0..9`) that
  belonged to the unrigged GLBs now kept in the ignored `source_assets/`. The
  `*_rigged_Image_*` files stay in the project: Godot extracted them from the GLB
  on import and the imported `.scn` references them directly.
- Vehicle visuals: `owner` is cleared before reparenting imported nodes (fixes six
  `owner ... inconsistent` warnings per launch), missing GLBs now degrade to the
  placeholder without losing mass/collider/tuning, and `visual_path_low` selects a
  decimated model for `balanced`/`low` quality.
- Two car variants: `lada_vaz_2110_rigged_low.glb` (128 549 tris, textures 1024)
  and `priora_rigged_low.glb` (43 820 tris), generated with glTF Transform.
- World boot: guarded every `await` against leaving mid-load, split the shared boot
  flow into hooks, and rebuilt `test_track.gd` on top of it (no more duplicated
  `_ready`).
- Removed eight unreferenced scripts (1 428 lines): camera shake, car paint dial
  cluster, driving assists, post-processing, speed blur, top-down camera, screenshot.
- Public APIs: `VehicleDefinition.visual_path_low`,
  `VehicleTuningApplicator.variant_for_quality()`, `Wheel.refresh_surface()`,
  `KudosTracker.reset_motion_state()`.
- Tests: UTF-8-safe Python suite (57 checks, was 43), Windows CI matrix, asset
  ledger gate, repo-hygiene and quality-variant suites; runtime checks now wait for
  async spawn and assert owner/variant behaviour.
- Docs: README, MIT licence for code, `docs/ASSET_LICENSES.md` (RED/YELLOW/GREEN),
  refreshed testing/remaining reports; history cleaned of `.env`.

# 0.0.3 — mobile UI test candidate

- All four previous hotfixes included: explicit material/collision types, correct OSMData return type, deferred focus-pause UI.
- Always-visible touchscreen camera switch, compact two-button top bar, scrollable paused menu.
- Phone-oriented touch targets; bounded left/right thumb zones; automatic/manual gear UI; reliable global release capture.
- Shared safe-area/viewport geometry for controls, compact speed gauge, minimap, session text and garage.
- Removed double-centred challenge panel and oversized fixed track instructions; challenges live in menu.
- HUD editor pauses game, disables underlying driving controls while dragging, resizes without rebuilding nodes, persists clamped offsets.
- Minimap visibility/audio mute saved independently; seat-height controls in menu.
- Resume overlay responsive; iOS project-only export points to Xcode ZIP; Android version code 2.
- Offline layout/source checks and additional (unexecuted here) Godot runtime checks. See docs/MOBILE_TESTING.md.
- Not engine-compiled, phone-tested or APK/IPA-built in this environment; wheel/car geometry remains an explicit visual test item.

# 0.0.2 — кандидат для тестирования

Основные исправления и добавления описаны в README_TEST.md.
Автономные проверки: docs/TEST_REPORT.md. Runtime/платформенные проверки не выполнялись.
Точный список изменений относительно очищенной базовой копии: docs/CHANGE_MANIFEST.json.

## Организация
- Оригинал сохранён отдельно и не изменён.
- Не включены секрет `.env`, `.godot`, результаты сборок и дубли исходников сторонних проектов.
- Активные лицензии сохранены; неиспользуемые исходные `.blend` и не-ригованные модели перемещены в `source_assets` с `.gdignore`.
- Старые TZ.md/ROADMAP.md оставлены как исходные требования, не как подтверждение реализации каждого пункта.
