# Accessibility Requirements: Karak Digital

> **Status**: Committed
> **Author**: producer / ux-designer
> **Last Updated**: 2026-10-11
> **Accessibility Tier Target**: Basic
> **Platform(s)**: PC (Steam / itch.io)
> **External Standards Targeted**:
> - WCAG 2.1 Level A (partial — board game context)
> - Game Accessibility Guidelines (basic tier)
> - Xbox / PlayStation: N/A (PC-only release)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/gdd/hud.md`, `design/gdd/combat-ui.md`, `design/gdd/inventory-ui.md`

---

## Accessibility Tier Definition

### This Project's Commitment

**Target Tier**: Basic

**Rationale**: Karak Digital — пошаговая настольная игра на PC. Жанр устраняет основной моторный барьер (нет быстрых последовательностей, нет удержаний, нет тайминга). Целевая аудитория — родители с детьми 5–10 лет; аудитория небольшая, проект личный, публичного релиза пока нет. Basic tier охватывает реальные риски этой аудитории:
- Дети — нестандартный зрительный диапазон и моторика мыши → нужны читаемые шрифты и кликабельные зоны достаточного размера.
- Нет озвучки, нет голосового диалога → субтитры не требуются на данном этапе.
- Нет онлайн-матчей → CVAA не применяется.
- Standard tier (colorblind режимы, масштабирование UI) — перспектива после первого публичного релиза, не сейчас.

**Features explicitly in scope (Basic)**:
- Remapping мыши — все игровые действия (клик на тайл, кнопки действий)
- Независимые регуляторы громкости (Music / SFX)
- Яркость/гамма в настройках
- Предупреждение о фотосенсибилизации (экран-заставка)
- Аудит «цвет как единственный индикатор» — визуальный резерв для каждого цветового сигнала
- Пауза в любой момент

**Features explicitly out of scope (deferred)**:
- Colorblind режимы — Standard tier, после MVP
- Масштабирование текста — Standard tier, после MVP
- Субтитры — нет озвучки в текущем scope
- Motor accessibility (hold-to-toggle) — жанр не требует
- Полное меню настроек accessibility — Comprehensive tier

---

## Visual Accessibility (Basic)

| Feature | Status | Implementation Notes |
|---------|--------|---------------------|
| Minimum text size — HUD | Not Started | 20px минимум при 1080p. HP, VP — критическая информация. |
| Minimum text size — UI / кнопки | Not Started | 18px минимум для всех кликабельных меток. |
| Минимальный контраст текста | Not Started | 4.5:1 для body text (WCAG AA). Применить к HUD, CombatUI, InventoryUI. |
| Brightness / gamma controls | Not Started | В настройках графики. Диапазон: –50% до +50%. Калибровочный паттерн. |
| Цвет не единственный индикатор | Not Started | См. аудит ниже — каждый цветовой сигнал должен иметь резерв. |
| Предупреждение фотосенсибилизации | Not Started | Экран при запуске до главного меню. TileRevealVFX: проверить < 3 вспышки/сек. |

### Color-as-Only-Indicator Audit

| Место | Цветовой сигнал | Что сообщает | Резерв (не цвет) | Статус |
|-------|----------------|-------------|-----------------|--------|
| HUD — полоска HP | Красный при низком HP | Игрок близок к knockout | Числовое значение HP + иконка черепа при ≤ 2 HP | Not Started |
| InventoryUI — бейдж предмета | Цвет типа (оружие/свиток/ключ) | Тип предмета | Иконка типа (sword/scroll/key) + текстовая метка | Not Started |
| CombatUI — кубики | Цвет подсветки при успехе/неудаче | Результат броска | Иконка ✓ / ✗ + текст «Победа» / «Поражение» | Not Started |
| TileRevealVFX | Цвет типа тайла после открытия | Что на тайле (монстр/сундук/пусто) | Иконка поверх тайла + звук разного тона | Not Started |

---

## Motor Accessibility (Basic)

| Feature | Status | Implementation Notes |
|---------|--------|---------------------|
| Mouse click remapping | Not Started | Все игровые действия — клик на тайл, кнопки подтверждения/отмены в CombatUI, инвентарь — должны быть rebindable. Нет keyboard-only gameplay requirement, но все кнопки мыши должны быть перепривязываемы. |
| Кликабельные зоны | Not Started | Минимальный размер hit-zone для тайлов и кнопок — 44×44px (Apple HIG / WCAG 2.5.5). Актуально для детей с менее точной моторикой. |
| Нет тайминга в игровых действиях | PASS — By Design | Пошаговая механика. Нет быстрых вводов, нет удержаний, нет QTE. Мотор-барьер устранён жанром. |

---

## Cognitive Accessibility (Basic)

| Feature | Status | Implementation Notes |
|---------|--------|---------------------|
| Pause anywhere | Not Started | Пауза доступна в любом состоянии: ход игрока, бой, анимация тайла. TurnManager: `pause_game()` при ESC в любом FSM-состоянии. |
| Аудио — независимые регуляторы | Not Started | Music / SFX — два независимых слайдера 0–100%. Сохранять в player profile. Доступны из главного меню и паузы. |

---

## Auditory Accessibility (Basic)

| Feature | Status | Implementation Notes |
|---------|--------|---------------------|
| Субтитры | N/A — нет озвучки | В текущем scope нет voice acting. Добавить при появлении любого voiced контента. |
| Визуальные индикаторы для аудио | Not Started | Аудит: каждый игровой звуковой сигнал должен иметь визуальный эквивалент. Список ниже. |

### Gameplay-Critical SFX Audit

| Звук | Что сообщает | Визуальный резерв | Статус |
|------|-------------|-----------------|--------|
| Победный звук в бою | Исход боя — победа | «ПОБЕДА» текст + анимация в CombatUI | Not Started |
| Звук провала в бою | Исход боя — поражение | «ПОРАЖЕНИЕ» текст + анимация в CombatUI | Not Started |
| Звук открытия тайла | Тайл открылся | TileRevealVFX анимация всегда присутствует | PASS — By Design |
| Звук knockout | Игрок нокаутирован | KnockoutSystem: иконка черепа на HUD + всплывающий текст | Not Started |
| Звук конца хода | Ход перешёл к следующему игроку | HUD: анимация смены имени активного игрока | Not Started |

---

## Per-Feature Accessibility Matrix

| Система | Визуальные риски | Моторные риски | Когнитивные риски | Статус |
|---------|----------------|---------------|-----------------|--------|
| HUD | Размер шрифта; контраст; цвет HP | Нет | Одновременный трекинг HP, VP, шагов | Not Started |
| CombatUI | Цвет результата кубиков | Нет (пошаговый) | Трекинг бонусов, дайс-стейта | Not Started |
| InventoryUI | Цветовые бейджи предметов | Нет | Сравнение предметов (4 параметра max) | Not Started |
| TileRevealVFX | Скорость флипа / вспышка | Нет | Нет | Not Started |
| TurnManager | Нет | Нет | Индикатор «чей ход» | Not Started |
| CombatSystem | Нет | Нет | Отслеживание бонусов класса | Not Started |
| WinCondition | Нет | Нет | Финальный экран VP | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Почему не включено | Риск | Митигация |
|---------|--------------|-------------------|------|-----------|
| Colorblind режимы | Standard | Личный проект, нет публичного релиза сейчас | ~8% потенциальных пользователей (дальтонизм) не смогут различать некоторые цветовые сигналы | Аудит «цвет не единственный индикатор» покрывает все случаи; добавить в первый публичный патч |
| Масштабирование текста | Standard | Scope MVP | Пользователи с нарушением зрения | Фиксированный размер шрифта ≥ 18px как минимальный барьер |
| Screen reader | Comprehensive | Godot AccessKit + custom spatial требует отдельной системы | Слабовидящие и слепые | N/A для текущей аудитории (personal project) |

---

## Accessibility Test Plan (Basic)

| Проверка | Метод | Критерий прохождения | Статус |
|---------|-------|---------------------|--------|
| Контраст текста | Automated — contrast analyzer на скриншотах UI | Весь body text ≥ 4.5:1 | Not Started |
| Цвет-не-единственный-индикатор | Manual — скриншоты в grayscale | Все элементы идентифицируемы без цвета | Not Started |
| Размер кликабельных зон | Manual — 44×44px измерение | Все тайлы и кнопки ≥ 44×44px | Not Started |
| Пауза | Manual — нажать ESC в каждом FSM-состоянии | Пауза работает в любом состоянии | Not Started |
| Регуляторы громкости | Manual | Music и SFX независимы, 0–100%, persist | Not Started |
| Предупреждение фотосенсибилизации | Manual | Экран появляется до главного меню при каждом запуске | Not Started |

---

## Open Questions

| Вопрос | Ответственный | Дедлайн | Решение |
|--------|--------------|---------|---------|
| Какой минимальный размер тайла на 1080p при текущем масштабе поля? Укладывается в 44px? | gameplay-programmer | TileSystem sprint | Не решено |
| TileRevealVFX: частота вспышки при анимации флипа — нужен замер против порога 3 вспышки/сек | godot-shader-specialist | TileRevealVFX sprint | Не решено |

---

## Revision History

| Дата | Изменение |
|------|-----------|
| 2026-10-11 | Создан — тир Basic, Pre-Production gate-check blocker закрыт |
