# TileRevealVFX

> **Status**: Designed (retrofitted 2026-10-10)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10
> **Implements Pillar**: Pillar 1 — «Каждый тайл — маленькая история»

## Overview

TileRevealVFX — анимационная система раскрытия тайла. При входе игрока на нераскрытый тайл TileRevealVFX запускает анимацию переворота: тайл визуально «переворачивается» и открывает своё содержимое. Технически: подписывается на сигнал входа игрока (источник сигнала — `cell_entered` от MovementSystem или пост-routing сигнал EncounterDispatcher — определяется в Detailed Design); на каждый переворот запускает Tween-анимацию scale (сплющить → развернуть с новой текстурой → нормальный размер) с опциональными частицами. Дизайнерски: создаёт тот самый момент напряжения «что там?» из Pillar 1 — краткую паузу между «тайл закрыт» и «тайл раскрыт», которая превращает перемещение по карте в маленькое открытие.

TileRevealVFX не знает о результате встречи — он только анимирует переворот. Без этой системы игра работала бы, но тайлы менялись бы мгновенно: исчезла бы пауза предвкушения, делающая каждый ход «маленькой историей».

## Player Fantasy

Игрок нажимает на соседний тайл — и до того, как произойдёт что-то ещё, тайл переворачивается. Полсекунды. Ничего, кроме анимации. И ребёнок смотрит.

Это и есть момент TileRevealVFX: не «что там», а «сейчас узнаем». Переворот — это не переход между состояниями, это маленький ритуал открытия. Как перевернуть карту в настолке — только с движением, со звуком, с ощущением веса деревянного тайла.

Каждый ход содержит этот момент, и он никогда не тривиален: ребёнок не знает, что там. Монстр? Ключ? Пустой коридор? Полсекунды — это Pillar 1 в его самой чистой форме. TileRevealVFX не рассказывает историю — он создаёт паузу, в которую история может войти.

## Detailed Design

### Core Rules

1. **Триггер.** TileRevealVFX подписывается на `MovementSystem.cell_entered(player: PlayerState, pos: Vector2i)`. EncounterDispatcher подписывается НЕ на `cell_entered`, а на `TileRevealVFX.tile_reveal_complete(player: PlayerState, pos: Vector2i)` — встреча разрешается только после завершения анимации переворота. TileRevealVFX передаёт `player` из `cell_entered` напрямую в `tile_reveal_complete`.

2. **Условие запуска.** При `cell_entered(player, pos)`:
   - `TileSystem.is_revealed(pos) == false` → запустить анимацию flip.
   - `TileSystem.is_revealed(pos) == true` (знакомый тайл) → анимацию не запускать, эмитировать `tile_reveal_complete(player, pos)` немедленно.

3. **Анимация flip (Tween, три фазы):**
   - **Фаза 1** (0.15с): `scale.y` тайла `1.0 → 0.0` (сплющивание до невидимости)
   - **Смена текстуры** в момент `scale.y = 0` — мгновенно, игрок не видит скачка
   - **Фаза 2** (0.15с): `scale.y 0.0 → 1.0` (разворачивание с новой текстурой)
   - **Фаза 3, опциональная** (0.1с): micro-overshoot `scale.y 1.0 → 1.05 → 1.0` (физическое ощущение)
   - Итого: **0.3–0.4с** на переворот

4. **Смена текстуры.** В момент `scale.y = 0` TileRevealVFX обращается к TileSystem для получения спрайта раскрытого тайла и обновляет визуальное представление. Детали реализации — в ADR.

5. **Завершение.** По окончании Tween: `TileSystem.reveal_cell(pos)` — тайл помечается как раскрытый в данных. Затем: эмитировать `tile_reveal_complete(player: PlayerState, pos: Vector2i)`. EncounterDispatcher начинает маршрутизацию встречи. (Resolved B-14 2026-10-10)

6. **Единый стиль.** Одинаковая анимация flip для всех типов тайлов (MONSTER, CHEST, CORRIDOR, FOUNTAIN, PORTAL). Дифференциация содержимого — через спрайт раскрытого тайла и системы CombatUI/LootSystem.

### States and Transitions

| Состояние | Описание |
|-----------|----------|
| `IDLE` | Нет активной анимации; ожидает `cell_entered` |
| `FLIPPING(pos)` | Tween активен для тайла на `pos` |

| Переход | Триггер |
|---------|---------|
| `IDLE → FLIPPING(pos)` | `cell_entered` + `!TileSystem.is_revealed(pos)` |
| `FLIPPING(pos) → IDLE` | Tween завершён → `reveal_cell(pos)` вызван → `tile_reveal_complete(player, pos)` эмитирован |
| `IDLE` (без перехода) | `cell_entered` + тайл уже раскрыт → немедленный `tile_reveal_complete(player, pos)` |

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| MovementSystem | ← подписан | `cell_entered(player, pos)` — триггер |
| TileSystem | ← читает | `is_revealed(pos): bool`, спрайт раскрытого тайла |
| TileSystem | ← вызывает | `reveal_cell(pos)` — по завершении flip-анимации, до `tile_reveal_complete` |
| EncounterDispatcher | → эмитирует | `tile_reveal_complete(player: PlayerState, pos: Vector2i)` — EncounterDispatcher подписан |

TileRevealVFX — промежуточная нода между MovementSystem и EncounterDispatcher. Не изменяет PlayerState, TurnManager, данные тайлов — только анимирует и передаёт управление.

## Formulas

### Формула 1: Временна́я шкала flip-анимации

```
t_total = t_squish + t_expand [+ t_overshoot]

t_squish    = 0.15с  (scale.y: 1.0 → 0.0)
t_expand    = 0.15с  (scale.y: 0.0 → 1.0)
t_overshoot = 0.10с  (scale.y: 1.0 → 1.05 → 1.0)  [опционально, Tuning Knob]
```

**Переменные:**

| Переменная | Символ | Тип | Диапазон | Описание |
|-----------|--------|-----|----------|----------|
| Фаза сплющивания | `t_squish` | float | 0.1–0.25с | Первая половина flip |
| Фаза разворачивания | `t_expand` | float | 0.1–0.25с | Вторая половина flip |
| Micro-overshoot | `t_overshoot` | float | 0.0–0.15с | 0.0 = отключён; >0 = включён |
| **Итоговая длительность** | `t_total` | float | 0.2–0.65с | Полная длительность анимации |

**Выходной диапазон:** 0.3с (без overshoot) до 0.4с (с overshoot). Значения > 0.5с ощущаются медленными; < 0.2с — слишком резко для ребёнка.

**Easing:** `t_squish` — `EASE_IN`; `t_expand` — `EASE_OUT`. Создаёт ощущение «разгона и торможения» деревянного тайла.

**Пример:** `t_squish=0.15, t_expand=0.15, t_overshoot=0.10` → `t_total = 0.40с`. Смена текстуры происходит при `t = 0.15с`.

---

### Формула 2: Момент смены текстуры

```
texture_swap_time = t_squish
```

Смена текстуры происходит ровно в момент `t = t_squish` — когда `scale.y == 0` и тайл визуально невидим. Не раньше (игрок увидит прыжок текстуры) и не позже (тайл развернётся со старой текстурой).

## Edge Cases

**EC-VFX-01 — Если `cell_entered` приходит пока предыдущий flip ещё не завершён:**
Hotseat — только один игрок ходит в любой момент. По архитектуре TurnManager не передаёт ход до завершения встречи. Второй `cell_entered` до `tile_reveal_complete` предыдущего — признак бага в TurnManager. TileRevealVFX логирует `push_error` и ставит новый flip в очередь (обрабатывается после завершения текущего).

**EC-VFX-02 — Если `cell_entered` для тайла без визуального узла (тайл вне сетки или ещё не создан):**
TileRevealVFX проверяет наличие визуального узла перед запуском Tween. Если узел не найден — `push_error`, эмитировать `tile_reveal_complete(player, pos)` немедленно (EncounterDispatcher не блокируется).

**EC-VFX-03 — Если игрок возвращается на уже раскрытый тайл:**
`TileSystem.is_revealed(pos) == true` → анимация не запускается, `tile_reveal_complete(player, pos)` эмитируется немедленно. Никакой задержки для EncounterDispatcher.

**EC-VFX-04 — Если `t_overshoot = 0.0` (overshoot отключён через Tuning Knob):**
`t_total = t_squish + t_expand`. Тайл остаётся на `scale.y = 1.0` после Фазы 2. `tile_reveal_complete` эмитируется по окончании Фазы 2, не ждёт несуществующую Фазу 3.

**EC-VFX-05 — Если сцена меняется или нода уничтожается пока Tween активен:**
Godot автоматически освобождает Tween при удалении ноды. Никакой специальной обработки не требуется — `tile_reveal_complete` не будет эмитирован (нода мертва), EncounterDispatcher не получит триггер.

**EC-VFX-06 — Если движение через портал попадает на раскрытый тайл:**
Portал destination уже раскрыт → `is_revealed = true` → немедленный `tile_reveal_complete`, анимации нет. Два одновременных `cell_entered` невозможны (hotseat). Этот сценарий безопасен.

## Dependencies

### Зависимости входящие (TileRevealVFX зависит от)

| Система | Тип | Что нужно | Статус |
|---------|-----|-----------|--------|
| **MovementSystem** | Жёсткая | Сигнал `cell_entered(player, pos)` — единственный триггер | Designed ✓ |
| **TileSystem** | Жёсткая | `is_revealed(pos): bool` — условие запуска; спрайт раскрытого тайла — для смены текстуры | Designed ✓ |

### Зависимости исходящие (зависят от TileRevealVFX)

| Система | Что ожидает | Статус |
|---------|-------------|--------|
| **EncounterDispatcher** | Сигнал `tile_reveal_complete(player: PlayerState, pos: Vector2i)` — встреча разрешается только после флипа | Designed ✓ |

### Bidirectional check

- **EncounterDispatcher GDD**, Upstream: подписан на `TileRevealVFX.tile_reveal_complete(player: PlayerState, pos: Vector2i)` — Aligned ✓ (resolved B-04 2026-10-10)
- **MovementSystem GDD** должен упоминать TileRevealVFX как получателя `cell_entered` — проверить при следующем review.

## Tuning Knobs

| Параметр | Значение | Безопасный диапазон | Что ломается за пределами |
|----------|----------|---------------------|--------------------------|
| `FLIP_SQUISH_DURATION` | 0.15с | 0.1–0.25с | <0.1: слишком резко, не «деревянный тайл»; >0.25: темп хода замедляется |
| `FLIP_EXPAND_DURATION` | 0.15с | 0.1–0.25с | Аналогично squish |
| `FLIP_OVERSHOOT_DURATION` | 0.10с | 0.0–0.15с | 0.0 = отключён; >0.15: overshoot становится заметным подпрыгиванием |
| `FLIP_OVERSHOOT_SCALE` | 1.05 | 1.0–1.10 | ≤1.0 = эффект отсутствует; >1.10 = тайл заметно «выпрыгивает» из сетки |

## Visual/Audio Requirements

### Тайл: рубашка (unrevealed state)

- Фон: `#1A1A2E` (тёмный синий, согласован с HUD/CombatUI)
- Рамка: 2–3px `#3A3A5E` — тонкая, почти сливается с фоном (загадочность)
- Текстура рубашки: каменный узор или руны в духе "Storybook Dungeon" — тёмное, нейтральное

### Анимация flip

- `scale.y` анимация — только по Y-оси (имитация переворота плоского тайла)
- Нет rotation — плоский 2D-стиль board game, без 3D-эффекта
- Easing: `EASE_IN` на squish, `EASE_OUT` на expand — встроенные Godot easing кривые

### Тайл: лицо (revealed state)

- Каждый тип тайла имеет свой спрайт (определяется TileSystem/TileMapLayer):
  - `CORRIDOR`: нейтральный каменный пол, `#2A2A3E`
  - `ROOM (MONSTER)`: иконографический монстр + характерный фон
  - `ROOM (CHEST)`: сундук + золотое свечение
  - `FOUNTAIN`: символ воды/лечения
  - `PORTAL`: символ телепортации
- Все спрайты: жирный outline 2px `#1A0A00`, тёплые акценты gold `#C0A060`–`#FFD700`
- Стиль: «Storybook Dungeon» — детский, читаемый с первого взгляда (Pillar 3)

### Приоритеты VFX для MVP

| Приоритет | Элемент | MVP |
|-----------|---------|-----|
| P0 обязательно | flip scale.y анимация (squish + expand) | Да |
| P0 обязательно | Смена текстуры в момент scale.y=0 | Да |
| P1 важно | Micro-overshoot (`FLIP_OVERSHOOT_DURATION > 0`) | Желательно |
| P2 polish | Звук переворота тайла | После MVP |
| P3 nice-to-have | Частицы пыли/искры при reveal | После MVP |

### Аудио

| Событие | Звук | Длительность | Характер |
|---------|------|--------------|----------|
| Tile flip (unrevealed→revealed) | Деревянный «шлёп» — переворот деревяшки | 0.2–0.3с | Тактильный, как настолка |

> **📌 Asset Spec** — Visual/Audio требования определены. После утверждения арт-библии запустить `/asset-spec system:tile-reveal-vfx` для per-asset спецификаций и промптов генерации.

## UI Requirements

TileRevealVFX не создаёт UI-элементов. Анимация применяется к визуальным узлам тайлов на игровом поле (TileMapLayer или аналог). Отдельного экрана, панели или HUD-компонента нет.

Единственное взаимодействие с UI-слоем: `tile_reveal_complete(player, pos)` — сигнал, на который EncounterDispatcher реагирует и затем может открыть CombatUI или другой UI-компонент. Открытие UI-компонентов — ответственность EncounterDispatcher, не TileRevealVFX.

## Acceptance Criteria

Gate: ADVISORY — скриншот или ручной walkthrough (VFX не автотестируется полностью).
Gate: **BLOCKING** (Logic) — сигнальные контракты тестируются в `tests/unit/tile_reveal_vfx/`.

**AC-VFX-01** `Logic · BLOCKING`
GIVEN тайл не раскрыт, WHEN `cell_entered(player, pos)`, THEN Tween запущен; `reveal_cell(pos)` НЕ вызывается до завершения Tween (тайл остаётся HIDDEN пока идёт анимация). (Resolved B-14 2026-10-10)

**AC-VFX-02** `Logic · BLOCKING`
GIVEN Tween запущен, WHEN `t = t_squish (scale.y == 0)`, THEN текстура тайла сменилась; до `t_squish` — рубашка, после `t_squish` — спрайт раскрытого тайла.

**AC-VFX-03** `Logic · BLOCKING`
GIVEN Tween завершён, THEN `TileSystem.reveal_cell(pos)` вызван; `tile_reveal_complete(player, pos)` эмитирован ровно один раз с тем же `player`, что пришёл в `cell_entered`. (Resolved B-14 2026-10-10)

**AC-VFX-04** `Logic · BLOCKING`
GIVEN тайл уже раскрыт (`is_revealed == true`), WHEN `cell_entered(player, pos)`, THEN Tween НЕ запущен; `tile_reveal_complete(player, pos)` эмитирован немедленно (не с задержкой).

**AC-VFX-05** `Logic · BLOCKING`
GIVEN `FLIP_OVERSHOOT_DURATION = 0.0`, WHEN flip завершён, THEN `scale.y = 1.0`; `tile_reveal_complete` эмитирован после Фазы 2.

**AC-VFX-06** `Logic · BLOCKING`
GIVEN `FLIP_OVERSHOOT_DURATION > 0.0`, WHEN flip завершён, THEN `scale.y = 1.0` (overshoot завершился); `tile_reveal_complete` эмитирован после Фазы 3.

**AC-VFX-07** `Logic · BLOCKING` *(EC-VFX-02)*
GIVEN тайл без визуального узла на `pos`, WHEN `cell_entered(player, pos)`, THEN `push_error` в лог; `tile_reveal_complete(player, pos)` эмитирован немедленно (EncounterDispatcher не блокируется).

**AC-VFX-08** `UI · ADVISORY`
GIVEN flip анимация (`t_squish=0.15, t_expand=0.15`), THEN на экране видно: тайл сплющивается → мгновенно меняет спрайт → разворачивается с новым содержимым. Скачка текстуры не видно.

**AC-VFX-09** `UI · ADVISORY`
GIVEN `FLIP_OVERSHOOT_SCALE=1.05, t_overshoot=0.10`, THEN тайл кратко выпрыгивает на 5% и возвращается — micro-bounce заметен, но не агрессивен.

**AC-VFX-10** `UI · ADVISORY`
GIVEN тайлы рядом на поле, THEN тайл под флипом не перекрывает соседние тайлы; scale применяется только к содержимому, сетка поля остаётся читаемой.

## Open Questions

| # | Вопрос | Владелец | Блокирует |
|---|--------|----------|-----------|
| OQ-VFX-01 | ~~RESOLVED (2026-10-10)~~ `TileSystem.is_revealed(pos)` подтверждён — добавлен при retrofit TileSystem (C-06). | — | — |
| OQ-VFX-02 | Как именно TileRevealVFX получает спрайт раскрытого тайла? Через `TileMapLayer` напрямую, через `TileSystem.get_tile_sprite(pos)`, или через `TileData`? Решается в ADR при реализации. | ADR (архитектура) | Core Rule 4 |
| OQ-VFX-03 | Нужен ли `tile_reveal_complete` для тайлов, которые раскрываются не движением игрока (например, если DungeonGenerator раскрывает стартовые тайлы при инициализации)? | DungeonGenerator GDD | EC-VFX-03 edge |
