---
name: write-tests
description: "Writes unit or integration test files after /code-review passes APPROVED. Reads the story's QA Test Cases and AC, reads the implementation, follows existing project test patterns, and produces a ready-to-run test file."
argument-hint: "[story-file-path]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash, Write
agent: qa-tester
---

# Write Tests

This skill is called **after** `/code-review` returns APPROVED. It writes the test file
for the story, following project test patterns and GdUnit4 conventions.

**Workflow position**: implement → /code-review (APPROVED) → **/write-tests** → /story-done

---

## Phase 1: Find the Story

**If a story file path is provided** (e.g., `/write-tests production/epics/input-system/story-001-routing-core.md`):
read that file directly.

**If no argument is provided**:
read `production/session-state/active.md` and find the currently active story.
If not found, ask the user to provide the story path.

From the story file, extract:
- **Story Type** — Logic / Integration / Visual/Feel / UI / Config/Data
- **Implementation files** — the `.gd` files that were implemented
- **Required test file path** — from the `## Test Evidence` section
- **Acceptance Criteria** — the full list
- **QA Test Cases** — the full `## QA Test Cases` section

If Story Type is Config/Data → report "Config/Data story — no test file needed" and stop.

---

## Phase 2: Read Implementation and Existing Tests

1. Read the implementation file(s) in full.
2. Find one existing test file from the same layer (unit or integration) for pattern reference.
   - For unit tests: read any file from `tests/unit/` — prefer same epic if it exists
   - For integration tests: read any file from `tests/integration/`
3. Note the patterns used:
   - How `before_test()` / `after_test()` set up and tear down state
   - How external dependencies (Autoloads, singletons) are handled
   - How signals are monitored and asserted
   - How private methods are called directly
   - Cleanup patterns (`queue_free()`, `await get_tree().process_frame`)

---

## Phase 3: Plan Test Coverage

For each Acceptance Criterion and QA Test Case from Phase 1:

1. Map it to one or more `test_*` functions
2. Identify what needs to be mocked:
   - Autoloads (GSM, PlayerRegistry, etc.) — check if they can be accessed directly or need state manipulation
   - External nodes (TileMapLayer, etc.) — create inner `class Mock* extends *` with stub methods
3. Identify if signals need to be captured — use lambda connections, not monitor_signals (more reliable across GdUnit4 versions)
4. Note edge cases from the QA Test Cases not covered by AC

---

## Phase 4: Write the Test File

Write to the path from `## Test Evidence` in the story.

### File structure:

```
extends GdUnitTestSuite

# [Mock classes — one per external dependency that needs stubbing]
class Mock[Name] extends [BaseClass]:
    [only override methods actually called in tests]

# [Test suite variables]
var [system_under_test]: [ClassName]
var [mock_dependency]: Mock[Name]

func before_test() -> void:
    # Create fresh instances for each test
    # add_child() for nodes that need to be in the scene tree
    # Set up required state (e.g., GSM._current_state = GameState.X directly)

func after_test() -> void:
    # Reset global state (e.g., GSM._current_state = GameState.MAIN_MENU)
    # queue_free() nodes added in before_test
    # await get_tree().process_frame  ← always last, prevents orphan warnings

# [Test functions — one per AC / QA Test Case]
func test_[system]_[scenario]_[expected]() -> void:
    # Arrange: set up state
    # Act: call the method under test
    # Assert: verify outcome
```

### Naming rules (from test-standards.md):
- File: `[system]_[feature]_test.gd`
- Function: `test_[system]_[scenario]_[expected_result]`

### Signal capture pattern — ОБЯЗАТЕЛЬНО использовать Array, не примитивы

**ПРАВИЛО**: GDScript 4 lambda-замыкания НЕ мутируют value-типы (`int`, `float`, `bool`,
`Vector2i`, `Vector2` и т.д.) из внешнего scope — захватывается копия. Используй
`Array` (reference-тип) — захватывается по ссылке и мутируется корректно.

```gdscript
# ПРАВИЛЬНО — Array (reference type):
var signals: Array = []
system.signal_name.connect(func(arg: Vector2i) -> void: signals.append(arg))
system.some_method()
assert_int(signals.size()).is_equal(1)
assert_bool(signals[0] is Vector2i).is_true()

# НЕПРАВИЛЬНО — int/Vector2i (value types, НЕ обновляются в outer scope):
# var count: int = 0
# system.signal_name.connect(func(_arg): count += 1)  ← count всегда 0
# var received: Vector2i = Vector2i(-1, -1)
# system.signal_name.connect(func(arg): received = arg)  ← received не меняется
```

Также не использовать `assert_vector2i()` — нет в GdUnit4. Использовать:
- `assert_bool(val == expected).is_true()`
- `assert_int(signals.size()).is_equal(N)`

### State manipulation for Autoload singletons:
- Set `GSM._current_state` directly (no side effects from `_handle_transition`)
- Do NOT call `GSM.request_transition()` unless testing transition logic itself
- Reset to `GameState.MAIN_MENU` in `after_test()`

### Calling private methods:
- GDScript does not enforce private — call `handler._handle_tile_click()` directly
- This isolates tests from the input pipeline and makes them deterministic

### What NOT to test:
- Engine internals (`get_global_mouse_position()` accuracy — mock the transform layer instead)
- Methods belonging to a different story's scope — add a `# TODO: covered in Story NNN` comment

---

## Phase 5: Write the File

Ask: "May I write the test file to `[path]`?"

If yes, write the file. Report:
- Path written
- Number of test functions
- Which ACs are covered
- Which ACs are deferred (if any) and why

---

## Phase 6: Update Story Test Evidence

After writing, update the story's `## Test Evidence` section:
- Change `[ ] Не создан` to `[x] Создан — [path]`

Ask: "May I update the Test Evidence status in the story file?"

---

## Phase 7: Next Step

After tests are written:

```
Next: run /story-done [story-path] to close the story.
```

---

## Collaborative Protocol

- Never write tests for code that hasn't passed /code-review
- Never mark story Test Evidence as complete without actually writing the file
- If a test case requires refactoring the implementation (e.g., adding injection seams), flag it — do not silently skip the test case
- If Story Type is Config/Data — no tests needed, say so immediately
