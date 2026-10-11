# Cross-GDD Review Report #4

**Date**: 2026-10-10
**Прогон**: 4-й (после retrofit-кампании #3 — закрыты C-01–C-09, D-01, D-03)
**GDDs рассмотрены**: 18 системных GDD + game-concept.md + systems-index.md
**Entity Registry**: отсутствует — consistency checks на основе полного чтения GDDs

---

## Системы охвачены

PlayerState, ClassSystem, TileSystem, DiceSystem, MonsterDatabase, ItemDatabase,
DungeonGenerator, TurnManager, MovementSystem, EncounterDispatcher, CombatSystem,
LootSystem, KnockoutSystem, WinCondition, HUD, CombatUI, TileRevealVFX, InventoryUI

---

## Верификация 12 недавних фиксов (все подтверждены ✓)

| Fix | Статус |
|-----|--------|
| C-01: CombatSystem пропускает add_vp для is_dragon | ✓ VERIFIED |
| C-02: MonsterDatabase Formula 1 → strict `>` | ✓ VERIFIED |
| C-03: ClassSystem bypass 2 шага + 1 HP | ✓ VERIFIED |
| C-04: TileSystem EC-06/07 фонтан только при «да» | ✓ VERIFIED |
| C-05: TurnManager AC-09 clear_knockout() вызван для Воина | ✓ VERIFIED |
| C-06: CombatSystem EC-08 → combat_resolved(false, false) | ✓ VERIFIED |
| C-07: EncounterDispatcher Rule 4 → is_cleared | ✓ VERIFIED |
| C-08: TileSystem AC-06 reveal_cell не тянет token | ✓ VERIFIED |
| C-09: CombatUI → combat_resolved(bool, bool) | ✓ VERIFIED |
| D-01: TurnManager AWAITING_LOOT переход добавлен | ✓ VERIFIED |
| D-03: DungeonGenerator OQ-04 документирует Dragon/Ghost | ✓ VERIFIED |

---

## Consistency Issues

### Blocking (должны быть исправлены до начала архитектуры)

#### 🔴 E-01: MonsterDatabase — стейл-комментарий `>=` после фикса C-02
**Файлы**: `monster-database.md`, Rule 2 (код) vs Formula 1

Комментарий к коду в Rule 2 говорит:
```gdscript
@export var difficulty: int  # порог броска: attack_total >= difficulty → победа
```
Formula 1 (исправленная в C-02) говорит `player_wins = attack_total > difficulty` (строгое `>`).

Комментарий остался из до-C-02 эпохи. Разработчик, читающий только код-комментарий, реализует `>=` вместо `>`.

**Требуется**: в MonsterDatabase Rule 2 исправить комментарий с `>=` на `>`.

---

#### 🔴 E-02: TurnManager зависает в AWAITING_LOOT после победы над Ghost или Dragon
**Файлы**: `turn-manager.md`, `loot-system.md`, `combat-system.md`

**Сценарий (Ghost):**
1. combat_resolved(won=true, six_rolled=false) → TurnManager → AWAITING_LOOT
2. CombatSystem эмитирует `item_dropped(player, "ghost")`
3. LootSystem EC-03: monster_id "ghost" отсутствует в таблице дропа → **игнорирует**
4. `item_acquired` **никогда не испускается**
5. TurnManager остаётся в AWAITING_LOOT **бесконечно**

Dragon аналогично: no drop entry → no `item_acquired` → deadlock.

**Корень**: D-01 fix добавил переход `AWAITING_COMBAT → AWAITING_LOOT` при `combat_resolved(won=true)`, но не учёл монстров без дропа.

**Требуется**: LootSystem должен **всегда** испускать `item_acquired(player, null)` при получении `item_dropped`, даже если таблица дропа пуста (null = нет предмета, ход завершён). Это уже является паттерном в LootSystem для сундуков без ItemData.

---

#### 🔴 E-03: Oracle first_step_bonus никогда не активируется
**Файлы**: `combat-system.md` EC-06, `class-system.md` EC-17, `movement-system.md`

CombatSystem EC-06:
```
first_step_bonus = 1 если TurnManager.steps_taken == 0 при получении сигнала combat_started
```

Но последовательность событий в MovementSystem Rule 2:
1. `TurnManager.spend_step()` → `steps_taken = 1`
2. `PlayerState.set_position(new_pos)`
3. `cell_entered(player, pos)` → TileRevealVFX → EncounterDispatcher → `combat_started`

К моменту получения `combat_started` `steps_taken` уже равно 1, а не 0. Бонус **никогда не активируется**.

ClassSystem EC-17 уже указывает на это: «MovementSystem обязана передавать `is_first_step: bool` в CombatSystem».

**Требуется**: Исправить условие в CombatSystem EC-06 с `steps_taken == 0` на `steps_taken == 1` (первый шаг уже потрачен) **или** MovementSystem должен передавать `is_first_step: bool` как часть параметров encounter.

---

### Warnings (следует исправить)

#### ⚠️ W-01: KnockoutSystem — стейл в Overview vs Rule 2
`knockout-system.md` Overview: «CombatSystem уже отступил игрока на предыдущий тайл (retreat())»
Rule 2 правильно говорит: retreat() пропускается при is_knocked_out() == true — игрок остаётся на тайле монстра.

#### ⚠️ W-02: PlayerState — Interactions table говорит TurnManager слушает `knocked_out`
`player-state.md` Interactions: «TurnManager ← подписан на сигнал: knocked_out → пропустить ход»
Но TurnManager не подписан на `knocked_out`. Подписан KnockoutSystem. TurnManager только проверяет `is_knocked_out()` при переключении хода.

#### ⚠️ W-03: PlayerState — Formula 2 неверная
`player-state.md` Formula 2: `dice_roll` range указан как `1–6` (должно быть `2–12` — это 2d6, не 1d6). Также отсутствуют `hp_bonus` и `first_step_bonus`.

#### ⚠️ W-04: KnockoutSystem — Downstream Dependencies включают `clear_knockout()`
`knockout-system.md` Downstream: `PlayerState: Вызовы set_position(), heal_full(), clear_knockout()`
Но KnockoutSystem явно **не вызывает** `clear_knockout()` (Rule 3 подтверждает). Это делает TurnManager.

#### ⚠️ W-05: systems-index.md — зависимость TileRevealVFX указана неверно
`systems-index.md` Dependency Map: `TileRevealVFX — depends on: EncounterDispatcher`
Должно быть: зависит от MovementSystem (cell_entered) + TileSystem. EncounterDispatcher, наоборот, зависит от TileRevealVFX (tile_reveal_complete).

#### ⚠️ W-06: WinCondition — открытые вопросы OQ-01, OQ-02, OQ-03 не закрыты
- OQ-01: «dragon_killed сигнал в CombatSystem» — давно реализован в CombatSystem. Пометить RESOLVED.
- OQ-02: «PlayerState ещё не спроектирован» — PlayerState спроектирован с `vp` и `add_vp()`. Пометить RESOLVED.
- OQ-03 (game-concept стейл): уже исправлено в ходе D-03 retrofit. Пометить RESOLVED.

#### ⚠️ W-07: ClassSystem — Dependencies статусы все "Не спроектирована"
`class-system.md` Dependencies: практически все downstream системы перечислены как «Не спроектирована» — все давно Designed ✓.

#### ⚠️ W-08: TurnManager — EC-04 некорректен для сценария Мечника+6
`turn-manager.md` EC-04: `item_acquired получен в PLAYER_TURN → push_error, игнорируется`
Но это **корректная** ситуация для Мечника с `six_rolled=true`: TurnManager остаётся в PLAYER_TURN, LootSystem обрабатывает дроп и эмитирует `item_acquired`. push_error — ложная тревога. Нужна отдельная ветка: при Мечнике+6 игнорировать без push_error.

#### ⚠️ W-09: EncounterDispatcher — FOUNTAIN_SECONDARY initial state не определён
`encounter-dispatcher.md` Rule 5: вызывает `clear_cell(pos)` для фонтана.
Стартовый FOUNTAIN стартует как `CLEARED` (корректно), но у FOUNTAIN_SECONDARY `initial state` нигде явно не указан — HIDDEN (в пуле) или CLEARED сразу?

#### ⚠️ W-10: VP_PER_CHEST — три разных имени в трёх GDDs
`loot-system.md` TK: `VP_PER_CHEST = 1`
`win-condition.md` TK: `VP_CHEST = 1.0 (Владелец: LootSystem)`
`tile-system.md` TK-03: `CHEST_VP = 1`
Три имени для одного значения. Авторитетный источник — LootSystem. Остальные должны ссылаться на него.

#### ⚠️ W-11: PlayerState — Rule 6 не упоминает DRAW case
`player-state.md` Rule 6: «При поражении (roll + attack_bonus < difficulty)...»
Не упоминает что при DRAW (attack_total == difficulty) урон **не** наносится.

#### ⚠️ W-12: KnockoutSystem — не документировано где не-Воин оказывается после clear_knockout
После нокаута не-Воин остаётся на тайле монстра. TurnManager вызывает `clear_knockout()` + `turn_skipped`. Где игрок физически окажется в начале своего следующего реального хода? На тайле монстра с `is_cleared=true`? Нужно явно задокументировать.

#### ⚠️ W-13: PlayerState — Interactions говорит TurnManager слушает knocked_out
(Аналогично W-02 — дублируется для ясности как отдельный сигнал `knocked_out` vs проверка `is_knocked_out()`.)

---

## Game Design Issues

### Blocking

#### 🔴 D-01: Wizard — доминирующий класс (структурное преимущество)
**Файлы**: `class-system.md`, `item-database.md`, `combat-system.md`

Флаг `magic_charge_no_discard` применяется ко **всем** свиткам (ItemDatabase Rule 4 подтверждает явно). Волшебник с 3 свитками scroll_magic_attack получает **перманентный +3 к бою в каждом бою** — бесконечно, без расхода. Другие классы расходуют свитки единоразово.

Сравнение при идентичном снаряжении (2x Axe + 3 scrolls_magic_attack):
- Другие классы: +9 в первом бою, затем +6 для всех последующих
- Волшебник: +9 в **каждом** бою (свитки никогда не расходуются)

Против Дракона (difficulty 15): Волшебник с +9 нужен roll > 6 (P = 72%). Остальные после первого боя с +6 нужны roll > 9 (P = 28%).

Дополнительно: scroll_teleport (никогда не расходуется у Волшебника) + прохождение сквозь стены = непревзойдённая мобильность.

Это нарушает Pillar 4 («честная случайность») — преимущество структурное, не ситуационное.

**Варианты исправления**:
- (A) Ограничить `magic_charge_no_discard` только на scroll_teleport (не на scroll_magic_attack)
- (B) Позволить повторное использование scroll_magic_attack только 1 раз за бой (не накапливать между боями)
- (C) Принять как «сложный класс для опытных игроков» и задокументировать явно

---

### Warnings

#### ⚠️ DW-01: Воительница — слабейший класс
`class-system.md`
Обе способности Воительницы строго уступают другим классам: перебросок одного кубика (≪ Воин с обоими) и обход за 2 шага + 1 HP (≪ Разбойница с бесплатным обходом). Нет уникального сильного измерения. Мониторить в плейтестах.

#### ⚠️ DW-02: Разбойница может обходить Дракона — VP-фарм через сундуки
`class-system.md` EC-06 подтверждает: Воительница может обходить Дракона бесплатно и фокусироваться на ключах + сундуках. Это жизнеспособная альтернативная стратегия (не доминирующая — нужно всё равно побеждать Skeleton Key монстров difficulty 8). Мониторить в плейтестах.

#### ⚠️ DW-03: Warlock в бою — высокая когнитивная нагрузка для детей 5–10 лет
До 4 последовательных фаз решений (авто-перебросок → класс-перебросок → свиток → HP-расход). GDD отмечает: «взрослый принимает боевые решения, ребёнок бросает кубики» — это смягчает, но стоит проверить в плейтестах с целевой аудиторией.

#### ⚠️ DW-04: Ключевая экономика — высокая дисперсия VP от сундуков
12 Skeleton Key монстров + 10 сундуков в пуле из 53 токенов, перемешанных случайно, при лимите 1 ключ в инвентаре. Порядок появления ключей/сундуков сильно влияет на VP-трек. Честная случайность (Pillar 4), но может вызвать фрустрацию при неудачном распределении.

#### ⚠️ DW-05: Нет пространственного масштабирования сложности
DungeonGenerator OQ-04 (намеренно): Дракон/Призрак могут быть первым событием (~5.7%). Для взрослых — интересный риск. Для целевой аудитории детей 5–10 лет — потенциальная фрустрация с нокаутом на первом ходу. Проверить в плейтестах.

#### ⚠️ DW-06: Резкий разрыв difficulty 10 → 12
Skeleton King (10): P(win, +2 bonus) ≈ 27.8%. Ghost (12): P(win, +2 bonus) ≈ 2.8%. Разрыв 10× при отсутствии разницы в визуальном предупреждении. Игрок не знает, что Ghost потребует Axe (+3 минимум).

#### ⚠️ DW-07: Pillar 3 «Гонка, а не гринд» — слабое механическое принуждение
Нет явного таймера или эскалирующего давления. Игрок теоретически может избегать Дракона и фармить VP через сундуки + Призрака. В 2-player hotseat это само-корректируется (второй игрок может убить Дракона), но механического принуждения нет.

---

## Cross-System Scenario Issues

**Сценариев пройдено**: 5

### Blockers

#### 🔴 Сценарий 1: Победа над Ghost → TurnManager deadlock
**Системы**: TurnManager, CombatSystem, LootSystem

1. combat_resolved(won=true, six_rolled=false) → TurnManager → AWAITING_LOOT ✓
2. `item_dropped(player, "ghost")` → LootSystem → нет записи → **игнорирует** (EC-03)
3. `item_acquired` **не испускается**
4. TurnManager застрял в AWAITING_LOOT **бесконечно**

Аналогично для Dragon. Это E-02 подтверждён сценарием.

#### 🔴 Сценарий 4: Oracle first_step_bonus никогда не активируется
**Системы**: MovementSystem, TurnManager, CombatSystem

`spend_step()` инкрементирует `steps_taken` до 1 **прежде** чем `combat_started` достигает CombatSystem. EC-06 проверяет `steps_taken == 0` — условие никогда не выполняется. Это E-03 подтверждён сценарием.

### Warnings

#### ⚠️ Сценарий 5: Мечник+6 — ложный push_error в TurnManager
**Системы**: TurnManager, LootSystem, CombatSystem

После победы с six_rolled=true TurnManager в PLAYER_TURN. LootSystem получает `item_dropped` → обрабатывает → эмитирует `item_acquired`. TurnManager получает `item_acquired` в PLAYER_TURN → EC-04: **push_error** (ложная тревога). Предмет всё равно выдан (LootSystem записал в PlayerState до сигнала). Функционально корректно, но push_error засорит логи.

### Info

#### ℹ️ Сценарий 2: Открытие сундука — полный VP+loot flow
combat → loot_started → AWAITING_LOOT → item_acquired → конец хода. Корректен.

#### ℹ️ Сценарий 3: Нокаут Воина
take_damage → knocked_out → KnockoutSystem: set_position(start) + heal_full → is_knocked_out=true. CombatSystem пропускает retreat(). combat_resolved(false,false). TurnManager переключает. На следующем ходу Воина: clear_knockout() → ход нормальный. Корректен.

---

## GDDs для ревизии

| GDD | Причина | Тип | Приоритет |
|-----|---------|-----|-----------|
| monster-database.md | E-01: стейл-комментарий `>=` | Consistency | BLOCKING |
| loot-system.md | E-02: не эмитирует item_acquired при пустом дропе | Consistency | BLOCKING |
| turn-manager.md | E-02: AWAITING_LOOT deadlock + EC-04 false push_error (W-08) | Consistency | BLOCKING |
| combat-system.md | E-03: EC-06 wrong steps_taken check + W (Wizard пояснение E-03/DW-01) | Consistency | BLOCKING |
| class-system.md | D-01: Wizard доминирующий + DW-01 Воительница + dependency statuses | Design | BLOCKING |
| knockout-system.md | W-01, W-04, W-12: Overview стейл, clear_knockout, не-Воин позиция | Consistency | Warning |
| player-state.md | W-02, W-03, W-11: Interactions, Formula 2, Rule 6 | Consistency | Warning |
| win-condition.md | W-06: OQ-01/02/03 не закрыты | Consistency | Warning |
| systems-index.md | W-05: TileRevealVFX зависимость неверна | Consistency | Warning |

---

## Verdict: FAIL

**Блокеров**: 4 (E-01, E-02, E-03, D-01)
**Предупреждений**: 20
**Инфо**: 15

FAIL — четыре блокера должны быть исправлены перед архитектурой:

1. **E-01** (MonsterDatabase): код-комментарий `>=` противоречит исправленной формуле `>`
2. **E-02** (LootSystem/TurnManager): Ghost/Dragon победа = AWAITING_LOOT deadlock — игра зависает
3. **E-03** (CombatSystem): Oracle first_step_bonus никогда не активируется (wrong check)
4. **D-01** (ClassSystem): Wizard доминирующий класс — structural advantage нарушает Pillar 4

### Обязательные действия перед повторным запуском /review-all-gdds:

```
monster-database.md Rule 2 — исправить комментарий >= → >
loot-system.md — добавить emit item_acquired(player, null) при пустом дропе
turn-manager.md — исправить EC-04 для Мечник+6 сценария
combat-system.md EC-06 — исправить steps_taken == 0 → steps_taken == 1
class-system.md Wizard — уточнить magic_charge_no_discard scope
```
