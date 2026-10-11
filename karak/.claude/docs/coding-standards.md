# Development Workflow

## Разделение труда

**Claude** реализует story через `/dev-story`, без запроса подтверждения:
- Весь GDScript-код (`scenes/`, `autoloads/`, `src/`)
- Все тесты (`tests/unit/`, `tests/integration/`)
- Task-файлы для Godot-редактора (`tasks/`) — только шаги в редакторе, без кода

**Пользователь** делает в Godot-редакторе (Inspector / Scene Tree / Project Settings):
- Настройка TileSet, TileMapLayer, Autoloads
- Привязка скриптов к нодам, @export поля в Inspector
- Создание .tscn сцен

## Цикл реализации

```
/dev-story [path]    ← код + тесты
/code-review [files] ← ревью
/playtest-story      ← плейтест
/story-done [path]   ← закрытие
```

## Task-файлы для Godot-редактора

Только когда story требует работы в редакторе — Claude создаёт `tasks/[epic]-[slug]-godot-editor.md`.
Task-файл содержит **только шаги в Godot-редакторе** — код пишет `/dev-story` напрямую.

Формат: `tasks/[epic-slug]-[short-description]-godot-editor.md`

Требования к task-файлу:
- Пронумерованные шаги (1, 2, 3...) — каждый шаг одно конкретное действие в Godot
- Скриншот-подсказки: «→ Inspector → TileSet → ...»
- Явное указание что нажать, куда перетащить, какое значение ввести
- Пункт проверки в конце каждого шага

---

# Coding Standards

- **Detailed comments are mandatory** in every implementation file created or modified.
  Follow the style of `src/gameplay/dungeon_generator.gd` as the reference:
  - Lines 1–2: `class_name Foo  # inline explanation` and `extends Bar  # inline explanation`
  - Section headers: `# ===...===` blocks separating logical groups
  - Public methods: `## Summary.\n## Contract / side effects / caller constraints.`
  - Inside functions: `# --- ШАГ N: description ---` blocks for each logical step
  - Inline comments on non-obvious lines: explain the *why*, Godot API quirks, ADR references
  This is not optional and does not require explicit user request — always apply when touching a file.
- All game code must include doc comments on public APIs
- Every system must have a corresponding architecture decision record in `docs/architecture/`
- Gameplay values must be data-driven (external config), never hardcoded
- All public methods must be unit-testable (dependency injection over singletons)
- Commits must reference the relevant design document or task ID
- **Verification-driven development**: Write tests first when adding gameplay systems.
  For UI changes, verify with screenshots. Compare expected output to actual output
  before marking work complete. Every implementation should have a way to prove it works.

# Design Document Standards

- All design docs use Markdown
- Each mechanic has a dedicated document in `design/gdd/`
- Documents must include these 8 required sections:
  1. **Overview** -- one-paragraph summary
  2. **Player Fantasy** -- intended feeling and experience
  3. **Detailed Rules** -- unambiguous mechanics
  4. **Formulas** -- all math defined with variables
  5. **Edge Cases** -- unusual situations handled
  6. **Dependencies** -- other systems listed
  7. **Tuning Knobs** -- configurable values identified
  8. **Acceptance Criteria** -- testable success conditions
- Balance values must link to their source formula or rationale

# Testing Standards

## Test Evidence by Story Type

All stories must have appropriate test evidence before they can be marked Done:

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| **Logic** (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** (animation, VFX, feel) | Screenshot + lead sign-off | `production/qa/evidence/` | ADVISORY |
| **UI** (menus, HUD, screens) | Manual walkthrough doc OR interaction test | `production/qa/evidence/` | ADVISORY |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

## Automated Test Rules

- **Naming**: `[system]_[feature]_test.[ext]` for files; `test_[scenario]_[expected]` for functions
- **Determinism**: Tests must produce the same result every run — no random seeds, no time-dependent assertions
- **Isolation**: Each test sets up and tears down its own state; tests must not depend on execution order
- **No hardcoded data**: Test fixtures use constant files or factory functions, not inline magic numbers
  (exception: boundary value tests where the exact number IS the point)
- **Independence**: Unit tests do not call external APIs, databases, or file I/O — use dependency injection

## What NOT to Automate

- Visual fidelity (shader output, VFX appearance, animation curves)
- "Feel" qualities (input responsiveness, perceived weight, timing)
- Platform-specific rendering (test on target hardware, not headlessly)
- Full gameplay sessions (covered by playtesting, not automation)

## CI/CD Rules

- Automated test suite runs on every push to main and every PR
- No merge if tests fail — tests are a blocking gate in CI
- Never disable or skip failing tests to make CI pass — fix the underlying issue
- Engine-specific CI commands:
  - **Godot**: `godot --headless --script tests/gdunit4_runner.gd`
  - **Unity**: `game-ci/unity-test-runner@v4` (GitHub Actions)
  - **Unreal**: headless runner with `-nullrhi` flag
