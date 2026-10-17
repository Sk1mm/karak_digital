# Sprint 01 — Foundation Completion
**2026-10-20 → 2026-10-31** (2 недели, 10 рабочих дней)

## Sprint Goal
Завершить Foundation layer (ItemDatabase + MonsterDatabase) и реализовать PlayerState с полным API состояния, сигналами и тестами. После спринта все autoloads и runtime-состояние игрока готовы — Core и Feature layers разблокированы.

## Capacity
- Всего дней: 10
- Буфер (20%): 2 дня
- Доступно: 8 дней

## Tasks

### Must Have — Critical Path

| ID | Task | Оценка | Зависимости | Acceptance Criteria |
|----|------|--------|-------------|---------------------|
| S01-1 | `/create-stories player-state` | 0.25 д | — | Story-файлы PlayerState созданы |
| S01-2 | PlayerState epic — все stories | 2.5 д | S01-1 | Все 6 TR-player-state покрыты; тесты зелёные; API: take_damage, heal_full, add_vp, set_position, retreat, add_item, remove_item, knockout/clear |
| S01-3 | `/create-stories item-database` | 0.1 д | — | Story-файлы ItemDatabase созданы |
| S01-4 | ItemDatabase epic — все stories | 1.0 д | S01-3 | 6 ItemData .tres-файлов; get_item(id) работает; Autoload зарегистрирован |

### Should Have

| ID | Task | Оценка | Зависимости | Acceptance Criteria |
|----|------|--------|-------------|---------------------|
| S01-5 | `/create-stories monster-database` | 0.1 д | — | Story-файлы MonsterDatabase созданы |
| S01-6 | MonsterDatabase epic — все stories | 1.0 д | S01-5 | 8 MonsterData .tres-файлов; get_monster(id) работает; Autoload зарегистрирован |

### Nice to Have

| ID | Task | Оценка | Зависимости | Acceptance Criteria |
|----|------|--------|-------------|---------------------|
| S01-7 | `/create-stories dice-system` + impl | 1.5 д | — | DiceSystem реализован; roll(n, sides) → Array[int] |

## Carryover из Sprint 00

| Task | Причина | Новая оценка |
|------|---------|-------------|
| Sprint plan → обновить статус "DONE" в sprint-00-scaffolding.md | Не было обновлено | 15 мин |

## Risks

| Риск | Вероятность | Impact | Mitigation |
|------|------------|--------|------------|
| PlayerState stories оказываются сложнее 6 штук | Средняя | Высокий | Should Have (MonsterDatabase) переносится в Sprint 02 |
| Godot Autoload registration требует ручной работы в редакторе | Высокая | Низкий | Для ItemDB и MonsterDB создать task-файл как для ClassRegistry |
| DiceSystem требует GDD-уточнения (формула roll) | Низкая | Средний | Читать design/gdd/dice-system.md перед /create-stories |

## Dependencies on External Factors
- PlayerState зависит от ClassRegistry ✅ (завершён — ClassRegistry epic DONE)
- ItemDatabase и MonsterDatabase независимы — можно параллельно

## Definition of Done

- [ ] Все Must Have tasks completed
- [ ] Все Logic-stories имеют проходящие тест-файлы
- [ ] PlayerState: take_damage не влияет на второй инстанс (изоляция)
- [ ] ItemDatabase: 6 предметов загружаются в _ready() без ошибок
- [ ] MonsterDatabase: 8 монстров загружаются в _ready() без ошибок
- [ ] sprint-00-scaffolding.md обновлён (статус DONE)
- [ ] Sprint status YAML создан
