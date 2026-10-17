# Sprint 00 — Scaffolding

**Статус**: DONE (завершён 2026-10-17)  
**Цель**: Создать работающий Godot-проект, подключить тест-фреймворк, убедиться что CI зелёный. Zero feature code.  
**Продолжительность**: 1–2 дня  
**Фаза**: Pre-Production

---

## Цель спринта

Этот спринт не про фичи — он про то, чтобы первый коммит с кодом имел работающий фундамент. После Sprint 00: есть проект, есть тест, CI зелёный, Autoloads зарегистрированы.

---

## Stories

### S00-1 — Godot Project Init

**Тип**: Config  
**Приоритет**: P0 — всё остальное блокировано  
**Размер**: XS (15 минут в редакторе)

**Задача**: Создать `project.godot` и базовую структуру директорий.

**Шаги в Godot-редакторе:**
1. File → New Project → указать `/Users/vlad/Documents/code/karak` как папку проекта
2. Project name: `Karak Digital`
3. Renderer: **Compatibility** (2D, PC target — см. technical-preferences.md)
4. Создать папки в FileSystem: `src/`, `assets/`, `scenes/`, `autoloads/`
5. Project → Project Settings → Application → Run → Main Scene: оставить пустым пока

**Проверка**: Godot открывает проект без ошибок.

---

### S00-2 — GdUnit4 Install

**Тип**: Config  
**Приоритет**: P0 — тесты блокированы без этого  
**Размер**: XS (10 минут)

**Задача**: Установить GdUnit4 через AssetLib.

**Шаги в Godot-редакторе:**
1. AssetLib → поиск "GdUnit4" → Download & Install
2. Project → Project Settings → Plugins → GdUnit4 ✓ (Enable)
3. Restart editor
4. Проверка: `res://addons/gdunit4/` существует

**Проверка**: Вкладка "GdUnit4" появилась в нижней панели редактора.

---

### S00-3 — Autoloads Registration

**Тип**: Config  
**Приоритет**: P1 — Foundation layer блокирован  
**Размер**: S (30 минут код + редактор)

**Задача**: Создать stub-файлы для трёх Autoloads и зарегистрировать их.

**Код** (Claude пишет stub-файлы, пользователь регистрирует в Project Settings):

Файлы для создания:
- `autoloads/class_registry.gd` — заглушка `ClassRegistry`
- `autoloads/item_database.gd` — заглушка `ItemDatabase`
- `autoloads/monster_database.gd` — заглушка `MonsterDatabase`

Порядок регистрации (ADR-0001 — именно такой порядок):
1. Project → Project Settings → Autoload
2. Добавить: `res://autoloads/class_registry.gd` → имя `ClassRegistry`
3. Добавить: `res://autoloads/item_database.gd` → имя `ItemDatabase`
4. Добавить: `res://autoloads/monster_database.gd` → имя `MonsterDatabase`

**Проверка**: Проект запускается без ошибок (`F5`).

---

### S00-4 — First Passing Test

**Тип**: Test  
**Приоритет**: P1 — подтверждает, что GdUnit4 работает  
**Размер**: S

**Задача**: Написать один тест, убедиться что он проходит.

Тест: `test_game_enums_direction_count` — проверяет что есть хотя бы 4 направления движения (N/E/S/W). Также включает smoke-test для `Dictionary[Vector2i, SomeResource]` typed syntax (закрывает вопрос TD concern: typed Dictionary в Godot 4.7.2).

Файл: `tests/unit/foundation/class_registry_test.gd`

**Запуск**: GdUnit4 panel → Run All Tests  
**Проверка**: зелёный.

---

### S00-5 — CI Green

**Тип**: DevOps  
**Приоритет**: P2  
**Размер**: XS

**Задача**: Push в main, убедиться что `.github/workflows/tests.yml` отрабатывает без ошибок.

**Зависимость**: S00-4 должна быть зелёной.

**Проверка**: GitHub Actions → `Automated Tests` → ✅

---

## Open Questions из gate-check

| ID | Вопрос | Нужно решить до |
|----|--------|-----------------|
| OQ-TD-1 | `Dictionary[Vector2i, DungeonCell]` typed syntax — работает в 4.7.2? | S00-4 (тест включает проверку) |
| OQ-TD-2 | `project.godot` — структура autoloads корректна? | S00-3 |

---

## Definition of Done

- [ ] `project.godot` существует, проект открывается в Godot 4.7.2
- [ ] GdUnit4 установлен и включён
- [ ] 3 Autoloads зарегистрированы в правильном порядке
- [ ] Один тест существует и проходит локально
- [ ] CI зелёный (GitHub Actions pass)
- [ ] Нет кода фич — только scaffolding

---

## Следующий спринт

После Sprint 00: `/create-control-manifest` → `/create-epics layer: foundation` → Sprint 01 (Foundation layer: ClassRegistry, ItemDatabase, MonsterDatabase).
