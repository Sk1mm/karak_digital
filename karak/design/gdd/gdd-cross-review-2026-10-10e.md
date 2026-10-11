# Cross-GDD Review Report — 6-й прогон

**Date**: 2026-10-10
**GDDs Reviewed**: 18
**Verdict**: **FAIL**

---

## Blocking Issues (8)

### G-01 — ItemDatabase: Overview стейл — magic_charge_no_discard → MAGIC_ATTACK (должно быть TELEPORT)

**Severity**: BLOCKING
**GDD**: `item-database.md` → Overview
**Проблема**: Overview (строка 10) содержит стейл-текст:
```
«Флаг magic_charge_no_discard Волшебника (ClassSystem) применяется именно к свиткам MAGIC_ATTACK
— они не сбрасываются после использования»
```
Это прямо противоречит Rule 4, EC-03, Formula 2 и CombatSystem. По всем остальным GDD:
`magic_charge_no_discard` применяется **только** к `scroll_teleport`; `scroll_magic_attack` расходуется нормально для всех классов включая Волшебника.

**Исправление**: ItemDatabase Overview — заменить «применяется именно к свиткам `MAGIC_ATTACK`» на «применяется только к `scroll_teleport` — Волшебник использует Свиток телепорта неограниченное число раз; `scroll_magic_attack` расходуется нормально для всех классов».

---

### G-02 — ItemDatabase + MonsterDatabase: математическая ошибка минимального bonus для победы над Драконом

**Severity**: BLOCKING — баланс-баг в документации
**GDDs**: `item-database.md` → Formulas (примечание под Формулой 1); `monster-database.md` → AC-07, Tuning Knobs

**Проблема**: Оба GDD утверждают «минимальный `Σ effective_combat_bonus` для победы над Драконом = 3». Это математически неверно из-за строгого `>` в условии победы (CombatSystem Rule 8: `attack_total > difficulty`):

```
Дракон difficulty = 15
dice_max = 12
12 + 3 = 15
15 > 15 = FALSE  ← поражение, не победа
```

Один топор (+3) при максимальном броске даёт ничью (поражение без урона), не победу.

**Правильный минимум**: bonus ≥ 4 чтобы существовал хотя бы один исход WIN (dice=12: 12+4=16 > 15 = true, вероятность 1/36 = 2.8%).

Затронуто:
- `item-database.md` Formulas примечание: «Против Дракона (difficulty=15) гарантированная победа при `Σ effective_combat_bonus ≥ 3`» → неверно дважды: (1) ≥3 не даёт WIN, нужно ≥4; (2) это не «гарантированная победа», а минимум для возможности победы.
- `monster-database.md` AC-07: «дракон непобедим без снаряжения (минимальный `combat_bonus` для возможности победы = 3)» → правильный минимум = 4.
- `monster-database.md` Tuning Knobs: `MIN_COMBAT_BONUS_FOR_DRAGON = 3` → должно быть 4.

**Исправление**:
- ItemDatabase Formulas: примечание → «минимальный bonus для любого исхода WIN = 4 (dice=12, 12+4=16 > 15); "гарантированная победа" недостижима фиксированным bonus без зависимости от кубика — удалить фразу».
- MonsterDatabase AC-07 и Tuning Knobs: заменить `= 3` на `= 4`.

---

### G-03 — HUD: VP-дисплей игроков отсутствует — нарушение Pillar 4

**Severity**: BLOCKING — функциональный дизайн-баг
**GDD**: `hud.md` → Detailed Design Rule 3, структура нод

**Проблема**: HUD GDD не содержит VP-счётчика для игроков. WinCondition Player Fantasy явно говорит: «Победа не приходит внезапно. Каждый убитый Призрак, каждый открытый сундук — шаг к финалу, который **игрок видит в счётчике VP**». HUD Player Fantasy говорит: «Живое "табло": взгляд на экран в **любой момент** даёт полную картину».

Без VP на экране игрок не может принять обоснованное решение об атаке Дракона — не знает ни свой прогресс, ни прогресс соперников. Это нарушает Pillar 4 («Честная случайность»: проигрыш не должен ощущаться как «компьютер нечестный»).

**Исправление**: Добавить в HUD GDD (Rule 3, структура нод):
- VP-счётчик активного игрока (крупно, рядом с HP)
- VP-счётчики всех остальных игроков (компактно, например панель со списком игроков)
- Обновляется при каждом `vp_changed(player)` сигнале (PlayerState)

---

### G-04 — LootSystem: AC-13 противоречит EC-03 → потенциальный дедлок для GHOST/DRAGON

**Severity**: BLOCKING — функциональный дедлок
**GDD**: `loot-system.md` → AC-13 vs EC-03

**Проблема**:

| Место | Текст |
|-------|-------|
| EC-03 | «Если `monster_id` отсутствует в таблице дропа (GHOST, DRAGON) — LootSystem **обязан** испустить `emit_signal("item_acquired", player, null)`» |
| AC-13 | «`item_dropped` с `monster_id = "GHOST"` → LootSystem **ничего не делает**» |

AC-13 буквально противоречит EC-03. Если разработчик реализует AC-13 как написано, `item_acquired` не эмитируется → TurnManager застрянет в `AWAITING_LOOT` навсегда → **дедлок**.

Сценарий с правильным порядком сигналов (F-05 fix):
```
1. emit combat_resolved(true, false) → TurnManager: AWAITING_LOOT
2. emit item_dropped(player, "GHOST") → LootSystem
3. [AC-13 literal: ничего] → item_acquired НИКОГДА не приходит → DEADLOCK
```

**Исправление**: LootSystem AC-13 → добавить обязательное постусловие:
```
AC-13: item_dropped с monster_id = "GHOST" →
  - item не выдаётся (GHOST нет в таблице дропа)
  - emit item_acquired(player, null) [ОБЯЗАТЕЛЬНО для завершения хода]
```

Аналогично для DRAGON в отдельном AC или в примечании к AC-13.

---

### G-05 — TurnManager: поведение в GAME_OVER при получении item_acquired не определено

**Severity**: BLOCKING — undefined behavior
**GDD**: `turn-manager.md` → состояния, EC-04

**Проблема**: При победе над Драконом CombatSystem эмитирует сигналы в порядке (Rule 9):
```
1. emit combat_resolved(true, false)
   → TurnManager: AWAITING_COMBAT → AWAITING_LOOT

2. emit dragon_killed(player)
   → WinCondition: vp += 1.5 → если vp >= target: emit game_over(winner)
   → TurnManager: AWAITING_LOOT → GAME_OVER  [синхронно]

3. emit item_dropped(player, "DRAGON")
   → LootSystem: DRAGON нет в drop table → emit item_acquired(player, null)
   → TurnManager: [уже в GAME_OVER] получает item_acquired
   → поведение НЕ ОПРЕДЕЛЕНО
```

TurnManager EC-04 описывает только `push_error` для AWAITING_COMBAT. Что происходит с `item_acquired` в `GAME_OVER` — не документировано. Если TurnManager бросает ошибку или игнорирует — поведение разработчик выбирает самостоятельно без контракта.

**Исправление**: TurnManager EC (добавить новый, после EC-04):
```
EC-XX — ЕСЛИ TurnManager в GAME_OVER получает item_acquired:
Сигнал игнорируется. Игра уже завершена; item не добавляется в инвентарь.
Логика в _on_item_acquired: guard-check if state == GAME_OVER: return.
```

---

### G-06 — PlayerState: стейл-статусы в Dependencies

**Severity**: BLOCKING
**GDD**: `player-state.md` → Dependencies Upstream

**Проблема**: Два upstream с неверными статусами:
```
ClassSystem  → «Не спроектирована (provisional)»
ItemDatabase → «Не спроектирована»
```

Оба GDD полностью спроектированы (status: Designed). Стейл-статусы вводят в заблуждение разработчиков о готовности интерфейсов.

**Исправление**: PlayerState Dependencies → оба статуса → «Спроектирована ✓».

---

### G-07 — MonsterDatabase: стейл-статусы для всех downstream зависимостей

**Severity**: BLOCKING
**GDD**: `monster-database.md` → Dependencies Downstream

**Проблема**: Четыре downstream помечены «Не спроектирована»:
```
CombatSystem        → «Не спроектирована»
WinCondition        → «Не спроектирована»
LootSystem          → «Не спроектирована»
EncounterDispatcher → «Не спроектирована»
```

Все четыре GDD спроектированы. MonsterDatabase — Foundation layer: стейл в нём особенно критичен.

**Исправление**: MonsterDatabase Dependencies → все четыре → «Спроектирована ✓».

---

### G-08 — DiceSystem и TileSystem: стейл-статусы в Dependencies

**Severity**: BLOCKING
**GDDs**: `dice-system.md` → Dependencies; `tile-system.md` → Dependencies

**Проблема**:

DiceSystem:
```
CombatSystem → «Не спроектирована»
```

TileSystem:
```
DungeonGenerator    → «Не спроектирована»
MovementSystem      → «Не спроектирована»
EncounterDispatcher → «Не спроектирована»
WinCondition        → «Не спроектирована»
```

Все пять систем спроектированы. Оба являются Foundation/Core layer — стейл затрагивает все зависимые системы.

Дополнительно: TileSystem некорректно включает WinCondition в свои downstream-потребители (WinCondition не читает TileSystem, только слушает `dragon_killed` от CombatSystem) — это собственный баг, не просто стейл-статус.

**Исправление**:
- DiceSystem: CombatSystem → «Спроектирована ✓»
- TileSystem: DungeonGenerator, MovementSystem, EncounterDispatcher → «Спроектирована ✓»
- TileSystem: строку WinCondition **удалить** из downstream (WinCondition не является потребителем TileSystem API)

---

## Warning Issues (8)

**W-01** — MovementSystem / ClassSystem: несогласованный контракт `is_first_step`. ClassSystem EC-17: «MovementSystem обязана передавать `is_first_step: bool` в CombatSystem». Но CombatSystem EC-06 и AC-14 реализуют через `TurnManager.steps_taken == 1`. Два разных механизма задокументированы для одного требования. **Исправить**: ClassSystem EC-17 — привести в соответствие с CombatSystem: «CombatSystem читает `TurnManager.steps_taken == 1` напрямую».

**W-02** — WinCondition: CombatSystem не указан в таблице Upstream Dependencies. `dragon_killed` сигнал приходит от CombatSystem, но в Dependencies-таблице он отсутствует (только упоминается в тексте Обратных ссылок). **Исправить**: WinCondition Dependencies Upstream → добавить строку CombatSystem.

**W-03** — KnockoutSystem: ClassSystem не указан в Upstream Dependencies. KnockoutSystem читает `player.knockout_no_turn_skip` — флаг, принадлежащий ClassSystem, — но ClassSystem не задокументирован как upstream. **Исправить**: KnockoutSystem Dependencies → добавить ClassSystem как Upstream.

**W-04** — TurnManager: переменная `add_step_total` используется в инварианте формулы, но нигде не определена и не хранится в полях. Инвариант нетестируем. **Исправить**: убрать `add_step_total` из инварианта или добавить поле в PlayerState/TurnManager с явным определением.

**W-05** — TileSystem: WinCondition некорректно включена в downstream (уже зафиксировано в G-08). Помимо стейл-статуса — сам факт включения WinCondition как читателя TileSystem API неверен.

**W-06** — Ghost difficulty spike: при типичном снаряжении (+3 combat_bonus) переход от Короля скелетов (difficulty=10, P(WIN)≈17%) до Призрака (difficulty=12, P(WIN)≈3%) — резкий обрыв, а не кривая. При этом Призрак даёт VP=1.0, что создаёт «VP trap»: игрок идёт за очками и проигрывает с 97% вероятностью. Противоречит Pillar 4. **Рекомендуется**: рассмотреть снижение difficulty Призрака до 10–11, или добавить в CombatUI предупреждение-риск для монстров с high difficulty.

**W-07** — Разбойница доминирует Воительницу по bypass. `can_bypass_monster_free` (Разбойница, бесплатно) vs `can_bypass_monster_cost` (Воительница, -2 шага, -1 HP). Обе имеют bypass как ключевую способность, но Разбойница не несёт издержек. ClassSystem Player Fantasy: «классы не имеют доминирующего выбора» — нарушается. **Рекомендуется**: дать Воительнице дополнительное преимущество (например, bypass без штрафа HP при первом шаге), или сделать bypass Разбойницы ситуационным (только если шагов > 1).

**W-08** — EncounterDispatcher: не упоминает LootSystem в разделе Обратных ссылок, хотя является upstream (эмитирует `loot_started`). Односторонняя асимметрия — LootSystem указывает EncounterDispatcher как upstream, обратного нет. **Исправить**: EncounterDispatcher Обратные ссылки → добавить LootSystem.

---

## Info Issues (7)

**I-01** — CombatSystem AC-15: условие `steps_taken > 0` включает первый шаг (`steps_taken == 1`), что противоречит AC-14 (первый шаг имеет бонус). Должно быть `steps_taken > 1`. **Исправить**: AC-15 → заменить `> 0` на `> 1`.

**I-02** — DiceSystem OQ-03 («нужен ли сигнал `dice_rolled`?») остаётся открытым, хотя CombatSystem Visual/Audio Requirements уже ссылается на него. Требует закрытия как RESOLVED перед реализацией DiceSystem.

**I-03** — MovementSystem: порядок обработки `cell_entered` между TileRevealVFX и LootSystem не задокументирован. Если ключ лежит на тайле монстра — LootSystem подберёт его независимо от EncounterDispatcher. Требует явного уточнения в LootSystem или MovementSystem.

**I-04** — systems-index.md: последний зафиксированный прогон ревью — `gdd-cross-review-2026-10-10c` (4-й прогон). Трекер отстаёт на 2 прогона. **Обновить после закрытия G-01..G-08**.

**I-05** — Волшебник имеет неявное экономическое преимущество: `scroll_teleport` не расходуется → бесконечный ресурс мобильности при нескольких открытых порталах. Намеренная фича, но не задокументирована как balancing decision с объяснением why.

**I-06** — LootSystem OQ-04 / CombatSystem Formulas: суммирование weapon bonuses (`attack_bonus = sum(оружий)`) — поведение очевидно из CombatSystem Formulas, но в Open Questions не помечено как RESOLVED. Рискует остаться открытым к моменту реализации PlayerState.

**I-07** — ClassSystem OQ-04 (Оракул): из какого пула выбираются 2 токена? Если из всего `event_token_pool` — Оракул видит «невозможные» события. Требует разрешения перед реализацией EncounterDispatcher.

---

## Cross-System Scenario Issues

### Сценарий: Победа над GHOST → завершение хода

**Участвующие системы**: CombatSystem → LootSystem → TurnManager

| Шаг | Действие | Проблема |
|-----|----------|---------|
| 1 | attack_total > 12 → WIN | — |
| 2 | emit `combat_resolved(true, false)` → TurnManager: AWAITING_LOOT | — (F-05 fix ✓) |
| 3 | emit `item_dropped(player, "GHOST")` → LootSystem | — |
| 4 | EC-03: GHOST → emit `item_acquired(player, null)` | **G-04**: AC-13 противоречит EC-03 → дедлок |

**Статус**: G-04 закрывает этот сценарий при исправлении AC-13.

---

### Сценарий: Победа над Dragon → конец игры

**Участвующие системы**: CombatSystem → WinCondition → TurnManager → LootSystem

| Шаг | Действие | Проблема |
|-----|----------|---------|
| 1 | attack_total > 15 (requires bonus ≥ 4) → WIN | **G-02**: документация некорректна (min bonus = 3 вместо 4) |
| 2 | emit `combat_resolved` → TurnManager: AWAITING_LOOT | — |
| 3 | emit `dragon_killed` → WinCondition: VP += 1.5 → emit `game_over` → TurnManager: GAME_OVER | — |
| 4 | emit `item_dropped(player, "DRAGON")` → LootSystem → emit `item_acquired(null)` | **G-05**: TurnManager в GAME_OVER получает `item_acquired` — поведение не определено |

**Статус**: G-02 и G-05 закрывают этот сценарий.

---

## Статус верификации — предыдущие Issues

### Retrofit-кампания #5 (F-01..F-05)

| Issue | Статус | Проверено |
|-------|--------|-----------|
| F-01 — ClassSystem downstream стейл | **CLOSED ✓** | Все 5 статусов → «Спроектирована ✓» |
| F-02 — CombatSystem Rule 5, EC-09, AC-10, AC-11 — Wizard/scroll_magic_attack | **CLOSED ✓** | scroll_magic_attack расходуется для всех |
| F-03 — ItemDatabase Rule 4, EC-03 — только scroll_teleport | **CLOSED ✓** | Rule 4 и EC-03 корректны |
| F-04 — CombatSystem AC-14 steps_taken=0 | **CLOSED ✓** | AC-14 → `steps_taken==1` |
| F-05 — CombatSystem Rule 9 — порядок сигналов | **CLOSED ✓** | combat_resolved ДО item_dropped |

### Warnings из 5-го прогона

| Warning | Статус |
|---------|--------|
| W-01 (is_first_step контракт) | **OPEN** → переносится как W-01 в этот отчёт |
| W-02 (combat_resolved сигнатура) | CLOSED ✓ — сигнатура унифицирована |
| W-03 (TileSystem фонтан) | INFO — не критично |
| W-04 (PlayerState ↔ ClassSystem) | **PARTIAL** → G-06 (стейл-статус) |
| W-05 (LootSystem item_acquired null) | **ESCALATED → G-04** (blocking) |
| W-06 (WinCondition ↔ CombatSystem) | **OPEN** → W-02 в этом отчёте |
| W-07 (EncounterDispatcher is_cleared) | CLOSED ✓ — метод присутствует в TileSystem API |
| W-08 (DiceSystem ↔ TurnManager) | INFO — indirect dependency |
| W-09 (KnockoutSystem ↔ ClassSystem) | **OPEN** → W-03 в этом отчёте |
| W-10 (MovementSystem ↔ ClassSystem) | CLOSED ✓ — ClassSystem указан в upstream |

---

## Статус по кампаниям

| Кампания | Дата | Блокеры | Закрыто |
|----------|------|---------|---------|
| 1-я (C-01..C-11, D-01..D-03) | 2026-10-09 | 14 | 14 ✓ |
| 2-я (B-01..B-14) | 2026-10-10 | 14 | 14 ✓ |
| 3-я (C-01..C-09, D-01..D-03) | 2026-10-10 | 12 | 12 ✓ |
| 4-я (E-01..E-03, D-01) | 2026-10-10 | 4 | 4 ✓ |
| 5-я (F-01..F-05) | 2026-10-10 | 5 | 5 ✓ |
| **6-я (G-01..G-08)** | **2026-10-10** | **8** | **0 (в работе)** |

---

## Рекомендуемые исправления (в порядке приоритета)

1. **G-04** — LootSystem AC-13: добавить `item_acquired(player, null)` как обязательное постусловие
2. **G-05** — TurnManager: добавить EC для GAME_OVER + item_acquired (игнорировать)
3. **G-01** — ItemDatabase Overview: исправить MAGIC_ATTACK → TELEPORT
4. **G-02** — ItemDatabase + MonsterDatabase: исправить min bonus 3 → 4; убрать «гарантированная победа»
5. **G-03** — HUD: добавить VP-дисплей для всех игроков
6. **G-06** — PlayerState Dependencies: обновить статусы → «Спроектирована ✓»
7. **G-07** — MonsterDatabase Dependencies: обновить 4 статуса → «Спроектирована ✓»
8. **G-08** — DiceSystem + TileSystem Dependencies: обновить статусы + удалить WinCondition из TileSystem downstream

После закрытия G-01..G-08: запустить 7-й прогон для финальной верификации.
