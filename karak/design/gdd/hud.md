# HUD

> **Status**: Designed (pending /design-review)
> **Author**: game-designer + user
> **Last Updated**: 2026-10-10 (retrofitted G-03, J-02)
> **Implements Pillar**: Pillar 2 «Сила ощутима», Pillar 4 «Честная случайность», Pillar 3 «Просто войти»

## Overview

HUD — постоянный информационный слой поверх игрового поля, отображающий в реальном времени состояние обоих игроков и текущего хода. Содержит три зоны: **блок игрока** (HP-полоска + VP-счётчик + слоты инвентаря × 2 игрока), **индикатор хода** (чья очередь + счётчик оставшихся шагов) и **статус нокаута** (иконка при пропуске хода). HUD подписывается на сигналы `PlayerState` (`hp_changed`, `vp_changed`, `item_added`, `item_removed`, `knocked_out`) и `TurnManager` (`turn_started`, `step_spent`, `turn_ended`, `turn_skipped`) — никогда не запрашивает данные напрямую, только реагирует на изменения.

Для игрока HUD — это живое «табло»: взгляд на экран в любой момент даёт полную картину. Ребёнок 6 лет читает чья очередь и сколько шагов осталось без объяснений (Pillar 3). Когда герой подбирает новый меч — слот инвентаря заполняется визуально, подтверждая что стало сильнее (Pillar 2). Когда HP падает — полоска меняется немедленно, без задержек (Pillar 4). HUD не отвлекает — он уточняет.

## Player Fantasy

HUD — это первый взгляд игрока после каждого боя и перед каждым решением. Не абстрактная панель статусов, а живое отражение состояния героя: большие сердечки HP (5 красных — здоров, 2 тусклых — надо осторожнее), иконки снаряжения с визуальным весом (топор выглядит тяжёлым, свиток — загадочным). Ребёнок не читает цифры — он считывает картинку.

Момент-якорь: герой подбирает мощный топор. Топор «падает» в слот крупной иконкой. Рядом горят 4 из 5 сердечек. Ребёнок одним взглядом понимает: «я сильный и почти здоров — иду на монстра». Это не интерфейс — это подтверждение того, что стало лучше. Каждый найденный предмет, каждый пропущенный удар немедленно виден на «табло» — именно поэтому решения ощущаются честными (Pillar 4) и сила ощущается заработанной (Pillar 2).

HUD активного игрока подсвечен ярко, неактивного — приглушён. Счётчик шагов убывает с каждым ходом, создавая дефицит, о котором говорит TurnManager: «2 шага осталось — рискую или нет?» Это ощущение, а не информация.

## Detailed Design

### Core Rules

1. HUD — `CanvasLayer` (layer=10) поверх игрового поля, присутствует всю партию.
2. Экран делится на три зоны: **блок P1** (левый край), **игровое поле** (центр, ~70% ширины), **блок P2** (правый край). Индикатор хода — полоска внизу по центру под полем.
3. **Блок каждого игрока** содержит сверху вниз:
   - Сердечки HP: 5 × иконка (заполненная / пустая). Фиксированный max=5.
   - VP-счётчик: иконка звезды + числовое значение (`vp: float`). Отображается для обоих игроков одновременно — видимость VP соперника обязательна для принятия решений (когда атаковать Дракона). Обновляется при `vp_changed(player)` от PlayerState.
   - Инвентарные слоты: 6 ячеек, GridContainer(columns=3):
     - Ряд 1: Оружие₀, Оружие₁, Ключ
     - Ряд 2: Свиток₀, Свиток₁, Свиток₂
   - Оверлей нокаута: скрыт по умолчанию (visible=false).
4. Слоты существуют всегда (6 штук). Меняется только содержимое — иконка предмета или пустая текстура. Ноды не создаются / не удаляются динамически.
5. **Индикатор хода**: имя/иконка активного игрока + 4 иконки шагов (убывают при `step_spent`).
6. Активный блок: `modulate = Color(1,1,1,1)`, рамка-подсветка видима. Неактивный блок: `modulate = Color(0.5,0.5,0.5,0.8)`, рамка скрыта.
7. HUD **только читает** состояние через сигналы. Никогда не изменяет PlayerState или TurnManager.
8. **Намеренно не отображает**: числовой урон, числовые статы атаки/защиты, названия предметов текстом, лог событий, счётчик золота. Правило: если элемент не отвечает на вопрос «что делать прямо сейчас» — он не в HUD.

### States and Transitions

#### Состояния панели игрока

| Состояние блока | modulate | Подсветка | Нокаут-оверлей |
|----------------|----------|-----------|----------------|
| `ACTIVE` | `Color(1,1,1,1)` | Видима | Скрыт |
| `INACTIVE` | `Color(0.5,0.5,0.5,0.8)` | Скрыта | Скрыт |
| `KNOCKED_OUT` | `Color(0.5,0.5,0.5,0.3)` | Скрыта | Виден |

#### Таблица переходов

| Триггер | Результат |
|---------|-----------|
| `turn_started(player)` → TurnManager | `player.panel` → `ACTIVE`; другой игрок → `INACTIVE` |
| `knocked_out` → PlayerState | Панель игрока → `KNOCKED_OUT` |
| `knockout_cleared` → PlayerState | Панель игрока → `INACTIVE` (или `ACTIVE` если сейчас его ход) |
| `hp_changed(new_hp, _)` → PlayerState | Сердечки: `i < new_hp` → заполнено; `i >= new_hp` → пусто. При `new_hp==1` (активный игрок): сердечко мигает. |
| `item_added(item, slot_type)` → PlayerState | HUD вызывает `get_items_by_slot(slot_type)`, перерисовывает все слоты данного типа |
| `item_removed(item, slot_type)` → PlayerState | Аналогично: перечитать слоты типа, обновить отображение |
| `step_spent(n)` → TurnManager | Иконки шагов: первые `n` заполнены, остальные пусты |
| `turn_skipped(player)` → TurnManager | Кратковременная иконка пропуска поверх панели игрока (0.5с), затем убирается |
| `vp_changed(new_vp)` → PlayerState | VP-счётчик соответствующего игрока обновляется до `new_vp` |

### Interactions with Other Systems

| Система | Направление | Что передаётся |
|---------|-------------|----------------|
| PlayerState [×2] | ← подписан | `hp_changed`, `vp_changed`, `item_added`, `item_removed`, `knocked_out`, `knockout_cleared` |
| TurnManager | ← подписан | `turn_started`, `step_spent`, `turn_ended`, `turn_skipped` |
| WinCondition | ← подписан | `game_over(winner: PlayerState)` — HUD показывает экран результата |

HUD получает ссылки на `PlayerState[0]`, `PlayerState[1]`, `TurnManager`, `WinCondition` через `@export` и подключает сигналы в `_ready()`. Никаких EventBus — HUD является leaf-нодой и не является источником событий.

> **Техническое примечание (Provisional)**: Поскольку сигнал `item_added(item, slot_type)` не содержит `slot_index`, HUD перечитывает весь массив слотов данного типа через `get_items_by_slot(slot_type)` при каждом обновлении инвентаря. Если PlayerState GDD будет обновлён и добавит `slot_index` в сигнал — HUD упростит эту логику.

## Formulas

### Формула 1: Отображение сердечек HP

```
hearts_filled = current_hp
hearts_empty  = MAX_HP - current_hp
blink_active  = (current_hp == 1) AND (player == active_player)
```

| Переменная | Тип | Диапазон | Описание |
|-----------|-----|----------|----------|
| `current_hp` | `int` | 1–5 | Текущее HP из PlayerState |
| `MAX_HP` | `int` | 5 (константа) | Максимум HP (фиксирован для MVP) |
| `hearts_filled` | `int` | 0–5 | Количество заполненных сердечек |
| `hearts_empty` | `int` | 0–5 | Количество пустых сердечек |
| `blink_active` | `bool` | — | Мигание при критическом HP только у активного игрока |

**Инвариант:** `hearts_filled + hearts_empty == MAX_HP` всегда.
**Пример:** HP=2, MAX_HP=5 → 2 заполненных, 3 пустых.

---

### Формула 2: Иконки шагов

```
steps_filled = steps_remaining
steps_empty  = STEPS_PER_TURN - steps_remaining
```

| Переменная | Тип | Диапазон | Описание |
|-----------|-----|----------|----------|
| `steps_remaining` | `int` | 0–4 | Из TurnManager |
| `STEPS_PER_TURN` | `int` | 4 (константа) | Из TurnManager GDD |
| `steps_filled` | `int` | 0–4 | Заполненные иконки шагов |
| `steps_empty` | `int` | 0–4 | Пустые иконки шагов |

**Пример:** steps_remaining=2 → 2 заполненных, 2 пустых.

---

### Формула 3: Modulate состояний панели

```
modulate_active      = Color(1.0, 1.0, 1.0, 1.0)
modulate_inactive    = Color(0.5, 0.5, 0.5, 0.8)
modulate_knocked_out = Color(0.5, 0.5, 0.5, 0.3)
```

Все три значения — Tuning Knobs (не вычисляются, настраиваются). Применяются к корневому `PanelContainer` блока игрока через Tween (длительность перехода 0.3с).

## Edge Cases

- **EC-HUD-01** — ЕСЛИ `knocked_out` (PlayerState) приходит когда панель в состоянии `ACTIVE`: немедленно → `KNOCKED_OUT`. Нет очереди, нет ожидания.

- **EC-HUD-02** — ЕСЛИ `hp_changed(0, _)` получен (defensive — PlayerState никогда не посылает 0, но защита обязательна): `push_error`, показать 0 заполненных сердечек.

- **EC-HUD-03** — ЕСЛИ `item_removed` + `item_added` для одного `slot_type` приходят последовательно: HUD делает два независимых вызова `get_items_by_slot()`. Оба корректны — читается *текущее* состояние, не дельта. Промежуточное пустое состояние слота возможно на один фрейм — приемлемо.

- **EC-HUD-04** — ЕСЛИ `turn_skipped(player)` приходит пока нокаут-оверлей ещё анимируется: `KnockoutOverlay.visible = false` немедленно (без анимации), затем иконка пропуска (0.5с). Оба оверлея не показываются одновременно.

- **EC-HUD-05** — ЕСЛИ партия завершена: HUD подписан на `WinCondition.game_over(winner)`. При получении → все сигналы TurnManager и PlayerState перестают влиять на HUD (ignore); HUD показывает экран результата (winner.display_name + итоговые VP всех игроков). Последнее состояние панелей заморожено под экраном результата.

- **EC-HUD-06** — ЕСЛИ ход прерван боем при `steps_remaining > 0` (шаги не израсходованы до нуля): иконки шагов остаются в промежуточном состоянии до `turn_started` следующего игрока. `turn_started(player)` → немедленный сброс иконок шагов до 4 заполненных (независимо от текущего счётчика).

- **EC-HUD-07** — ЕСЛИ MVP не содержит анимации слотов: EC не актуален. ЕСЛИ анимация слота добавлена: `tween.kill()` на слоте при новом сигнале, запуск нового Tween от текущего визуального состояния. Очереди анимаций нет — последний сигнал побеждает.

- **EC-HUD-08** — ЕСЛИ HUD инициализируется до PlayerState (null в `@export`): `assert(player_state_0 != null)`, `assert(player_state_1 != null)`, `assert(turn_manager != null)` в `_ready()`. Fail-fast — не silent null. Порядок создания объектов — ответственность GameController.

- **EC-HUD-09** — ЕСЛИ `knockout_cleared` приходит без знания активного игрока: HUD кэширует `active_player_id` при каждом `turn_started`. При `knockout_cleared` — ЕСЛИ `player.id == active_player_id` → `ACTIVE`, иначе → `INACTIVE`.

- **EC-HUD-10** — Семантика `step_spent(n)`: по TurnManager GDD AC-02, аргумент = `steps_remaining` (остаток после траты), не количество потраченных. `step_spent(2)` = «2 шага осталось». Формула 2 в Section D корректна.

## Dependencies

### Зависимости входящие (HUD зависит от)

| Система | Тип | Что нужно | Статус |
|---------|-----|-----------|--------|
| **PlayerState** | Жёсткая | Сигналы: `hp_changed`, `item_added`, `item_removed`, `knocked_out`, `knockout_cleared`; метод `get_items_by_slot(slot_type)` | Designed ✓ |
| **TurnManager** | Жёсткая | Сигналы: `turn_started(player)`, `step_spent(steps_remaining)`, `turn_ended(player)`, `turn_skipped(player)` | Designed ✓ |
| **WinCondition** | Жёсткая | Сигнал: `game_over(winner: PlayerState)` — переход в GAME_OVER, показ экрана результата | Designed ✓ |

### Зависимости исходящие (зависят от HUD)

Нет — HUD является leaf-нодой. Никакая система не зависит от HUD.

### Зависимости косвенные (ожидания от незавершённых систем)

| Система | Что ожидается | Статус |
|---------|--------------|--------|
| **ItemDatabase** | `ItemData.icon: Texture2D` — иконка предмета для слота инвентаря | Designed ✓ |
| **ClassSystem** | Не влияет на HUD в MVP (MAX_HP=5 фиксирован) | Not Started |

### Bidirectional check

- PlayerState GDD, Dependencies: «HUD ← подписан на `hp_changed`, `item_added`, `item_removed`» ✓
- TurnManager GDD, Interactions: «HUD ← слушает `turn_started`, `step_spent`, `turn_ended`, `turn_skipped`» ✓
- WinCondition GDD, Dependencies Downstream: «HUD ← сигнал `game_over(winner)`» ✓

## Tuning Knobs

| Параметр | Значение | Безопасный диапазон | Что ломается за пределами | Влияет на |
|----------|----------|---------------------|--------------------------|-----------|
| `MODULATE_ACTIVE` | `Color(1,1,1,1)` | — | Изменение ломает читаемость активного состояния | Визуальная иерархия |
| `MODULATE_INACTIVE` | `Color(0.5,0.5,0.5,0.8)` | alpha: 0.5–0.9 | <0.5: данные соперника нечитаемы; >0.9: нет разницы с активным | Читаемость данных неактивного игрока |
| `MODULATE_KNOCKED_OUT` | `Color(0.5,0.5,0.5,0.3)` | alpha: 0.2–0.4 | <0.2: блок почти невидим; >0.4: нокаут не отличается от inactive | Восприятие нокаута как значимого события |
| `TRANSITION_DURATION_MS` | 300 | 150–500 | <150: игрок не замечает смену хода; >500: ощущается как тормоза | Плавность смены хода |
| `TURN_SKIP_ICON_DURATION_MS` | 500 | 300–800 | <300: ребёнок не успевает увидеть; >800: задержка перед следующим ходом | Понимание пропуска хода |
| `BLINK_RATE_HZ` | 1 | 0.5–2 | <0.5: не привлекает внимание; >2: раздражает | Предупреждение при критическом HP |
| `STEPS_PER_TURN` | 4 | — | Источник истины: TurnManager GDD — не переопределять в HUD | Количество иконок шагов |
| `MAX_HP` | 5 | — | Источник истины: PlayerState GDD — не переопределять в HUD | Количество сердечек |

## Visual/Audio Requirements

### Стиль блока игрока

- **Фон:** тёмный синий-серый (`#1A1A2E`–`#2A2A4A`), alpha 0.85–0.9 («деревянная рамка манускрипта»)
- **Рамка:** жирная 3–4px, закруглённые углы (radius 8px), цвет — по игроку (см. ниже)
- **Drop shadow наружу:** 4–6px, `#00000066` — отделяет HUD от игрового поля
- **Запреты:** нет тонких углов, нет inner shadow, нет мультицветных градиентных фонов
- **Контраст:** минимум WCAG AA (4.5:1) для всех элементов — аудитория 6 лет

### Иконки предметов в слотах

- **Размер иконки:** 48×48px; слот: 56×56px (закругление 6px); иконка занимает 80% слота
- **Stroke:** 2–3px, тёплый тёмный (`#1A0A00`)

| Тип | Цвет (dominant) | Характер |
|-----|-----------------|----------|
| Оружие | `#8B6914` + `#C0A060` | Сталь + дерево, вес |
| Ключ | `#FFD700` + `#B8860B` | Золото, ценность |
| Свиток | `#F5DEB3` + `#4A5FA0` | Пергамент + рунический синий |

- **Пустой слот:** outline `#4A4A6A` 1px + тонкий крест/ромб по центру (не серый прямоугольник)
- **Заполненный:** full opacity + drop shadow 2px тёплый; пустой: 40% opacity, без shadow

### Сердечки HP

| Состояние | Заливка | Stroke | Прочее |
|-----------|---------|--------|--------|
| Полное | `#E8403A` (тёплый красный) | 2px `#7A1010` | Highlight-блик 1–2px `#FFFFFF80` в верхнем-левом |
| Пустое | `#2A2A4A` («впадина») | 1.5px `#4A4A6A` | Форма сохраняется, «потухшая» |
| Критическое (1/5) | `#FF6060` ↔ `#7A1010` | — | Мигает только заливка/stroke, не весь элемент |

- **Размер:** 32×32px

### Иконки шагов

- **Форма:** след ноги (flat, 5 пальцев) — читается ребёнком 6 лет без пояснений
- **Заполненный:** `#E8A020` (тёплый золотой) + stroke 2px `#5A3000`; 24×24px
- **Потраченный:** `#2A2A4A` («впадина») + stroke 1px `#4A4A6A` — единый язык с пустыми сердечками
- **Порядок убывания:** 4 иконки слева направо, тратятся с правого края

### Нокаут-оверлей

- **Иконка:** 3 звёздочки (5-конечные, flat, жёлтые `#FFD700` stroke `#5A4000`) — cartoon «оглушён», не «zzz»
- **Фон:** тёмный полупрозрачный круг `#00000066` radius 24px, поверх блока
- **Размер оверлея:** 48×48px, центрируется над HP-полоской
- **z_index:** выше блока (visible при modulate `KNOCKED_OUT = 0.3`)

### Идентификация игроков

| Элемент | Player 1 (синий) | Player 2 (оранжевый) |
|---------|-----------------|----------------------|
| Цвет рамки блока | `#4A80D0` | `#E07020` |
| Glow активного блока | `#6AAAF0`, 6–8px | `#F0A040`, 6–8px |
| Иконка в индикаторе хода | modulate `#8080FF` | modulate `#FFB040` |

**Правило:** цвет игрока = контейнер (рамка + glow), НЕ содержимое (иконки, сердечки, шаги).

### Аудио-события

| Событие | Звук | Длительность | Характер |
|---------|------|--------------|----------|
| HP упало | глухой удар/«ох» | 0.2–0.3с | Низкий, мягкий, не резкий |
| HP критично (1/5, старт мигания) | тихий тревожный пульс (loop) | ∞ пока HP=1 | Тревога без паники |
| HP восстановлено | мелодичный звон | 0.2с | Высокий, тёплый |
| Предмет добавлен | «шлепок» тяжёлого предмета | 0.2–0.3с | Ощущение физического веса |
| Предмет удалён | тихий «свист» | 0.1–0.2с | Мягкий, нейтральный |
| Шаг потрачен | тихий «топот» / клик | 0.1с | Не отвлекает |
| Смена хода (`turn_started`) | небольшой мажорный аккорд | 0.3с | «Твой ход» |
| Нокаут | cartoon «удар звёздочками» | 0.3–0.5с | Мультяшный, не страшный |
| Пропуск хода | тихое «ой» / comical | 0.2с | Ребёнок смеётся |

**Ограничения:** все HUD-звуки = 60–70% от громкости боя; нет резких alarm-звуков; аудитория 5–10 лет.

## UI Requirements

### Раскладка экрана

```
[  P1 Block  ] [          Game Board (~70%)          ] [  P2 Block  ]
               [                                      ]
               [   Turn Indicator (bottom center)     ]
```

### Структура нод (Godot 4.7)

```
CanvasLayer (layer=10)
└── HUD (Control, anchors=full_rect)
    ├── PlayerPanel_0 (PanelContainer, anchor=left)
    │   └── VBoxContainer
    │       ├── HeartsRow (HBoxContainer)          ← 5 × TextureRect
    │       ├── VPRow (HBoxContainer)              ← TextureRect(star_icon) + Label(vp_value)
    │       ├── InventoryGrid (GridContainer, columns=3)  ← 6 × SlotPanel
    │       ├── InventoryButton (TextureButton, 44×44px)  ← bag icon; visible/enabled только в ACTIVE
    │       ├── KnockoutOverlay (Control, visible=false)
    │       └── ActiveHighlight (Panel, z_index=top)
    ├── PlayerPanel_1 (PanelContainer, anchor=right)
    │   └── ... (зеркальная структура)
    └── TurnPanel (HBoxContainer, anchor=bottom_center)
        ├── TurnIndicator (TextureRect + Label)
        └── StepsRow (HBoxContainer)               ← 4 × TextureRect
```

### Размеры элементов

| Элемент | Размер | Обоснование |
|---------|--------|-------------|
| Сердечко HP | 32×32px | Ребёнок считает, не читает |
| VP-иконка (звезда) | 24×24px | Читается без пояснений |
| VP-счётчик (Label) | ширина авто | Числовой; формат: «2.5» или «3» |
| Слот инвентаря | 56×56px | Минимум для кликабельности (44px + padding) |
| Иконка предмета | 48×48px | Визуальный вес согласно art-bible |
| InventoryButton | 44×44px | Минимум hit-zone (Basic accessibility tier) |
| Иконка шага | 24×24px | Не главный элемент, дополнительный |
| Нокаут-оверлей | 48×48px | Заметен поверх приглушённого блока |

### Анимации (Tween)

| Событие | Анимация | Длительность | Easing |
|---------|----------|--------------|--------|
| Смена хода | modulate на PanelContainer | 0.3с | Linear |
| HP упало | сердечко scale 1.0→0.8→1.0 + micro shake блока ±4px | 0.15–0.3с | EASE_OUT |
| Предмет добавлен | иконка slide_in сверху + slot pulse scale | 0.2с | EASE_OUT |
| Предмет удалён | fade-out иконки | 0.15с | Linear |
| Шаг потрачен | иконка scale 1.0→0.85 | 0.2с | EASE_OUT |
| Нокаут-оверлей | scale bounce 0.8→1.2→1.0 | 0.3с | EASE_OUT |

**Правило:** все анимации HUD ≤ 0.5с. При конкуренции анимаций — `tween.kill()` + новый Tween.

### Кликабельность

- Слоты инвентаря: кликабельны → показывают tooltip с названием предмета и бонусом
- Сердечки HP: НЕ кликабельны
- Блок игрока: не перехватывает клики по игровому полю (`mouse_filter = MOUSE_FILTER_PASS`)
- `KnockoutOverlay`: `mouse_filter = MOUSE_FILTER_IGNORE`

### Инициализация

- HUD получает `PlayerState[0]`, `PlayerState[1]`, `TurnManager` через `@export`
- `_ready()`: assert на все три ссылки, затем connect() на все сигналы
- Начальное состояние: P1 блок = ACTIVE (до первого `turn_started`); все сердечки заполнены; все слоты пусты; шаги = 4 заполненных

> **📌 UX Flag — HUD**: Этот раздел содержит UI требования. Перед написанием epic-ов запустить `/ux-design` для создания UX-спека HUD-экрана.

## Acceptance Criteria

Gate: **BLOCKING** (Logic) — автотест в `tests/unit/hud/` обязателен до Done.
Gate: ADVISORY — скриншот + sign-off или ручной walkthrough в `production/qa/evidence/`.

### Core Rules

**AC-HUD-CR-01** `Logic` · **BLOCKING**
GIVEN запущена игровая сцена с двумя игроками
WHEN сцена полностью инициализирована
THEN `CanvasLayer` с HUD существует в scene tree, `layer == 10`, `visible == true`

**AC-HUD-CR-02** `UI` · ADVISORY
GIVEN открыт экран игры на 1920×1080
WHEN HUD отрисован
THEN `PlayerPanel_0` у левого края, `PlayerPanel_1` у правого, центральная зона ≥65% ширины, `TurnPanel` снизу по центру

**AC-HUD-CR-03** `Logic` · **BLOCKING**
GIVEN HUD инициализирован
WHEN инспектируются `PlayerPanel_0` и `PlayerPanel_1`
THEN каждый блок содержит ровно 5 нод `TextureRect` в `HeartsRow`, ровно 6 нод `SlotPanel` в `InventoryGrid`, `KnockoutOverlay` с `visible=false`

**AC-HUD-CR-04** `Logic` · **BLOCKING**
GIVEN `PlayerPanel_0` инициализирован с 0 предметами
WHEN PlayerState P1 испускает `item_added` три раза подряд
THEN количество дочерних нод в `InventoryGrid` P1 = 6 до, во время и после; меняется только `texture` внутри SlотPanel

**AC-HUD-CR-05** `Logic` · **BLOCKING**
GIVEN HUD инициализирован
WHEN инспектируется `TurnPanel`
THEN содержит `TurnIndicator` и `StepsRow` с ровно 4 иконками шагов

**AC-HUD-CR-06** `Logic` · **BLOCKING**
GIVEN HUD инициализирован
WHEN `PlayerPanel_0` переходит последовательно: `ACTIVE` → `INACTIVE` → `KNOCKED_OUT`
THEN после `ACTIVE`: `modulate == Color(1,1,1,1)`; после `INACTIVE`: `Color(0.5,0.5,0.5,0.8)`; после `KNOCKED_OUT`: `Color(0.5,0.5,0.5,0.3)` — проверяется после завершения Tween

**AC-HUD-CR-07** `Logic` · **BLOCKING**
GIVEN HUD подключён к PlayerState[0], PlayerState[1], TurnManager
WHEN HUD получает любой сигнал и обрабатывает его
THEN ни одна публичная переменная PlayerState (hp, inventory, is_knocked_out) и TurnManager (current_player, steps_remaining) не изменяется; HUD не вызывает методов на этих объектах, кроме `get_items_by_slot()`

**AC-HUD-CR-08** `UI` · ADVISORY
GIVEN HUD полностью заполнен данными
WHEN визуально инспектируется весь HUD
THEN в HUD отсутствуют: числовые значения урона, числа атаки/защиты, текстовые названия предметов в слотах, лог событий, счётчик золота

**AC-HUD-CR-09** `Logic` · **BLOCKING**
GIVEN HUD инициализирован, PlayerState P1.vp == 0
WHEN PlayerState P1 испускает `vp_changed(1.5)`
THEN VPRow P1: Label отображает «1.5»

**AC-HUD-CR-10** `Logic` · **BLOCKING**
GIVEN оба блока инициализированы с vp=0
WHEN PlayerState P2 испускает `vp_changed(2.0)`
THEN VPRow P2 показывает «2.0»; VPRow P1 не изменился (по-прежнему «0»)

**AC-HUD-CR-11** `Logic` · **BLOCKING**
GIVEN PlayerPanel_0 в состоянии `ACTIVE`
WHEN инспектируется InventoryButton P1
THEN `InventoryButton.visible == true`, `InventoryButton.disabled == false`; размер hit-zone ≥ 44×44px

**AC-HUD-CR-12** `Logic` · **BLOCKING**
GIVEN PlayerPanel_0 в состоянии `INACTIVE` или `KNOCKED_OUT`
WHEN инспектируется InventoryButton P1
THEN `InventoryButton.visible == false`

**AC-HUD-CR-13** `Logic` · **BLOCKING**
GIVEN PlayerPanel_0 в состоянии `ACTIVE`, InventoryButton видим и активен
WHEN игрок кликает InventoryButton
THEN InventoryUI открывается для P1; InventoryButton переходит в pressed state

---

### Formulas

**AC-HUD-FM-01** `Logic` · **BLOCKING**
GIVEN HUD инициализирован, MAX_HP=5
WHEN PlayerState P1 испускает `hp_changed(n)` для n ∈ {1,2,3,4,5}
THEN для каждого n: заполненных сердечек = n, пустых = 5−n, сумма = 5

**AC-HUD-FM-02** `Logic` · **BLOCKING**
GIVEN P1 показывал 5 заполненных сердечек
WHEN PlayerState P1 испускает `hp_changed(2)`
THEN ровно 2 сердечка — filled-текстура, ровно 3 — empty-текстура

**AC-HUD-FM-03** `Logic` · **BLOCKING**
GIVEN P1 является активным игроком (`ACTIVE`)
WHEN PlayerState P1 испускает `hp_changed(1)`
THEN сердечко P1 мигает с частотой ≈ 1 Гц (период 1с ± 0.1с)

**AC-HUD-FM-04** `Logic` · **BLOCKING**
GIVEN P2 находится в состоянии `INACTIVE`
WHEN PlayerState P2 испускает `hp_changed(1)`
THEN сердечко P2 НЕ мигает; отображается как статичное filled-сердечко

**AC-HUD-FM-05** `Logic` · **BLOCKING**
GIVEN HUD инициализирован, STEPS_PER_TURN=4
WHEN TurnManager испускает `step_spent(n)` для n ∈ {3,2,1,0}
THEN для каждого n: заполненных иконок = n, пустых = 4−n, сумма = 4

**AC-HUD-FM-06** `Logic` · **BLOCKING**
GIVEN HUD показывает 4 заполненных иконки шагов
WHEN TurnManager испускает `step_spent(2)`
THEN ровно 2 иконки (левые) — filled, ровно 2 (правые) — empty

**AC-HUD-FM-07** `Visual/Feel` · ADVISORY
GIVEN HUD инициализирован
WHEN PlayerPanel_0 получает `turn_started(P1)`
THEN modulate начинает интерполяцию к `Color(1,1,1,1)` и достигает его через 300мс ± 50мс

---

### State Transitions

**AC-HUD-ST-01** `Logic` · **BLOCKING**
GIVEN оба блока инициализированы
WHEN TurnManager испускает `turn_started(P1)`
THEN PlayerPanel_0 → ACTIVE (`modulate = Color(1,1,1,1)`, подсветка видима); PlayerPanel_1 → INACTIVE (`Color(0.5,0.5,0.5,0.8)`, подсветка скрыта)

**AC-HUD-ST-02** `Logic` · **BLOCKING**
GIVEN StepsRow показывает 2 заполненных иконки
WHEN TurnManager испускает `turn_started(P2)`
THEN все 4 иконки шагов немедленно заполненные

**AC-HUD-ST-03** `Logic` · **BLOCKING**
GIVEN PlayerPanel_0 в состоянии ACTIVE
WHEN PlayerState P1 испускает `knocked_out`
THEN PlayerPanel_0 → KNOCKED_OUT немедленно: `modulate = Color(0.5,0.5,0.5,0.3)`, `KnockoutOverlay.visible = true`, подсветка `visible = false`

**AC-HUD-ST-04** `Logic` · **BLOCKING**
GIVEN PlayerPanel_0 в KNOCKED_OUT; active_player_id кэш = P2 (последний `turn_started(P2)`)
WHEN PlayerState P1 испускает `knockout_cleared`
THEN PlayerPanel_0 → INACTIVE (`Color(0.5,0.5,0.5,0.8)`), `KnockoutOverlay.visible = false`

**AC-HUD-ST-05** `Logic` · **BLOCKING**
GIVEN PlayerPanel_0 в KNOCKED_OUT; active_player_id кэш = P1
WHEN PlayerState P1 испускает `knockout_cleared`
THEN PlayerPanel_0 → ACTIVE (`Color(1,1,1,1)`, подсветка видима), `KnockoutOverlay.visible = false`

**AC-HUD-ST-06** `Logic` · **BLOCKING**
GIVEN PlayerPanel_0 показывает 5 заполненных сердечек
WHEN PlayerState P1 испускает `hp_changed(3)`
THEN сердечки 0,1,2 (индексы) — filled; сердечки 3,4 — empty; без задержки

**AC-HUD-ST-07** `Logic` · **BLOCKING**
GIVEN слот Weapon_0 — empty-текстура
WHEN PlayerState P1 испускает `item_added(axe_item, SLOT_TYPE_WEAPON)` и `get_items_by_slot("weapon")` возвращает `[axe_item]`
THEN SlotPanel Weapon_0 показывает `axe_item.icon`

**AC-HUD-ST-08** `Logic` · **BLOCKING**
GIVEN SlotPanel Weapon_0 показывает axe_item.icon
WHEN PlayerState P1 испускает `item_removed(axe_item, SLOT_TYPE_WEAPON)` и `get_items_by_slot("weapon")` возвращает `[]`
THEN SlotPanel Weapon_0 показывает empty-текстуру

**AC-HUD-ST-09** `Logic` · **BLOCKING**
GIVEN StepsRow показывает 4 заполненных иконки
WHEN TurnManager испускает `step_spent(3)` (аргумент = остаток = 3)
THEN заполненных = 3, пустых = 1; аргумент интерпретируется как `steps_remaining`

**AC-HUD-ST-10** `UI` · ADVISORY
GIVEN PlayerPanel_1 в любом состоянии
WHEN TurnManager испускает `turn_skipped(P2)`
THEN иконка пропуска появляется над блоком P2 и исчезает через 500мс ± 50мс; состояние блока после этого не изменяется

---

### Edge Cases

**AC-HUD-EC-01** `Logic` · **BLOCKING**
GIVEN PlayerPanel_0 в ACTIVE, выполняется Tween смены хода
WHEN PlayerState P1 испускает `knocked_out`
THEN Tween прерывается немедленно; `modulate = Color(0.5,0.5,0.5,0.3)`, `KnockoutOverlay.visible = true`

**AC-HUD-EC-02** `Logic` · **BLOCKING**
GIVEN HUD инициализирован
WHEN PlayerState P1 испускает `hp_changed(0)` (невалидное)
THEN `push_error(...)` в Godot output; все 5 сердечек пусты; HUD не крашится

**AC-HUD-EC-03** `Logic` · **BLOCKING**
GIVEN Weapon_0 показывает sword.icon
WHEN PlayerState P1 испускает `item_removed(sword, WEAPON)`, затем `item_added(axe, WEAPON)`, `get_items_by_slot()` возвращает `[axe]`
THEN Weapon_0 показывает axe.icon; нод в InventoryGrid по-прежнему 6

**AC-HUD-EC-04** `Logic` · **BLOCKING**
GIVEN KnockoutOverlay P2 виден и анимируется
WHEN TurnManager испускает `turn_skipped(P2)`
THEN KnockoutOverlay.visible = false немедленно; иконка пропуска появляется и исчезает через 500мс; одновременно не виден ни один из двух оверлеев

**AC-HUD-EC-06** `Logic` · **BLOCKING**
GIVEN StepsRow показывает 1 заполненную иконку
WHEN TurnManager испускает `turn_started(P2)` (без предварительного `step_spent(0)`)
THEN все 4 иконки шагов — filled немедленно

**AC-HUD-EC-08** `Logic` · **BLOCKING**
GIVEN HUD добавлен в сцену без назначения `player_state_0` через @export
WHEN сцена запускается, вызывается `_ready()`
THEN Godot выбрасывает assert-fail или push_error; HUD не продолжает инициализацию молча

**AC-HUD-EC-09** `Logic` · **BLOCKING**
GIVEN `turn_started(P1)` был последним (active_player_id кэш = P1); PlayerPanel_0 перешёл в KNOCKED_OUT
WHEN PlayerState P1 испускает `knockout_cleared`
THEN PlayerPanel_0 → ACTIVE (не INACTIVE)

**AC-HUD-EC-10** `Logic` · **BLOCKING**
GIVEN StepsRow показывает 4 заполненных иконки
WHEN TurnManager испускает `step_spent(1)` (остаток = 1, не «потрачено 1»)
THEN заполненных = 1, пустых = 3

## Open Questions

| # | Вопрос | Владелец | Блокирует |
|---|--------|----------|-----------|
| OQ-01 | ~~RESOLVED (2026-10-10 — J-02)~~: HUD подписывается на `WinCondition.game_over(winner)` напрямую (Option A). Экран результата — ответственность HUD, не отдельного GameController. |
| OQ-02 | Нужна ли анимация иконки при `item_added` в слот (slide-in) в MVP, или достаточно мгновенной смены текстуры? | MVP scope | EC-HUD-07 актуальность |
| OQ-03 | ~~RESOLVED (2026-10-10 — ItemDatabase retrofit C-07)~~: `@export var icon: Texture2D` добавлен в ItemData. |
