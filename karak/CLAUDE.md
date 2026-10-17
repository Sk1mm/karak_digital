# Claude Code Game Studios — Game Studio Agent Architecture

## Language

**Always respond in Russian.** All agent responses, explanations, questions, and communications must be in this language, regardless of the language used by the user.

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.7.2
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Project Structure

@.claude/docs/directory-structure.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**Разделение труда: Claude пишет код через `/dev-story`, пользователь работает в редакторе.**

### Claude пишет самостоятельно (без запроса подтверждения)

- Весь код игры: `scenes/`, `autoloads/`, `src/`
- Все тесты: `tests/unit/`, `tests/integration/`
- Task-файлы для редактора: `tasks/`
- Production-файлы: stories, sprint-status, session-state, code-reference

### Цикл реализации story

```
/dev-story [path]       ← Claude пишет код + тесты через субагентов
/code-review [files]    ← ревью кода
/playtest-story         ← плейтест и ручная проверка
/story-done [path]      ← закрытие story
```

Если story требует работы в редакторе — дополнительно:
```
/create-task [path]     ← инструкции ТОЛЬКО для редактора (не код)
```

### Claude спрашивает перед записью

- Дизайн-документы (GDD, ADR) — показать черновик, получить одобрение
- Деструктивные изменения (удаление файлов, переименование) — подтвердить

### Pipeline — остановка после каждого скилла

**После завершения любого скилла — остановиться и ждать команды пользователя.**

```
/dev-story → [СТОП, ждать] → /code-review → [СТОП, ждать] → /story-done → [СТОП, ждать]
```

### Рекомендация новой сессии

Когда следующий шаг — запуск скилла в тяжёлом контексте (прочитано много файлов, долгая сессия), **явно указывать**:

> ⚠ Следующий шаг: `/skill-name` — рекомендуется **новая сессия** (контекст перегружен).

Критерии для рекомендации новой сессии:
- Прочитано 5+ крупных файлов (GDD, architecture docs) в текущей сессии
- Следующий скилл будет перечитывать часть тех же файлов
- Сессия длится долго и контекст приближается к 60–70% (см. Context Management)

### Коммиты

- Коммит после каждой завершённой задачи с файлами
- Только по инструкции пользователя

## Development Workflow

@.claude/docs/dev-workflow.md

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
