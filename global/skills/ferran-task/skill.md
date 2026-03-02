---
name: ferran-task
description: "Ferran's task protocol. Creates well-structured, scoped task files — the atomic unit of work for one agent session. Part of the Ferran series: /ferran-e2e (testing), /ferran-plan (project planning)."
---

# Ferran's Task Protocol

One skill, one job: **create good task files.** A task file defines a single unit of work — clear enough that an agent (or a human) can pick it up cold and know exactly what to do, why, and how to verify it's done.

## When to invoke

- `/ferran-task new` — create a new task file
- `/ferran-task done` — mark a task as DONE (completion protocol)

> **Ferran series**: `/ferran-plan` creates the backlog that feeds tasks. `/ferran-e2e` handles testing methodology. Commit discipline lives in a separate skill.

$ARGUMENTS

---

## Rules

1. **Read before write.** Before creating a task, read the project's CLAUDE.md for conventions (prefix, tracking file path). Read the relevant source files. A task written blind is a task that misses context.

2. **One task = one sitting.** A task should be completable in a single agent session (~30min–3h). If it's bigger, break it up. If it's smaller, it might not need a task file.

3. **Scope is king.** The "Not in scope" section is as important as the "What" section. Ambiguity in scope is where tasks bloat.

4. **Validation = evidence.** Every validation item must be verifiable. When marking done, add an inline note after `—` explaining HOW it was satisfied, not just that it was.

5. **Track time.** Started when work begins, Finished when work ends. Use the system clock, never estimate. Unix: `date '+%Y-%m-%d %H:%M'` | Windows: `powershell -Command "Get-Date -Format 'yyyy-MM-dd HH:mm'"`

6. **Keep the INDEX current.** The project's task index (wherever it lives) must reflect the new task when created and its status when done.

---

## Project Conventions

Each project defines these in its `CLAUDE.md`. Read them before creating the first task:

- **Task ID prefix** (e.g., `ORG` for Organizacion, `RL` for Relcom)
- **Tracking file path** (e.g., `tasks/INDEX.md`, `BACKLOG.md`)
- **Task file location** (default: project's task directory)

---

## Task Template

```markdown
# {PREFIX}-NNN: Short imperative description

**Status:** PENDING
**Depends on:** {PREFIX}-XXX (reason) | None
**Tracking:** path/to/INDEX or backlog
**Started:** —
**Finished:** —

---

> **In plain English:** One paragraph explaining the task to a non-technical person.
> What are we doing, and why does it matter?

---

## What

Concrete deliverables. What gets created or changed.

- Item 1
- Item 2

## Why

Rationale. Why this task matters now. What gap does it fill?

## Where

- **Read:** Source files to consult before starting
- **Write:** Files to create or modify

## Output

Expected result — API response shape, file structure, behavior description.
Concrete enough that validation can check against it.

> Omit for small tasks where What already covers it.

## Validation

- [ ] Domain-specific check 1
- [ ] Domain-specific check 2
- [ ] ...
- [ ] INDEX updated
- [ ] Task file updated: Status → DONE, all items checked with evidence

---

## Not in scope

- What this task explicitly does NOT cover
- Cross-reference the task that handles it: (that's {PREFIX}-XXX)
```

---

## Completion Protocol (`/ferran-task done`)

When a task is finished:

1. **Read the system clock** → write `**Finished:** YYYY-MM-DD HH:MM`
2. **Set `**Status:** DONE`**
3. **Check off every validation item** (`- [x]`) with evidence note:
   ```markdown
   - [x] API returns JSON for all projects — tested with 6 project docs, all parsed correctly
   ```
4. **Update the INDEX** with status and completion date
5. **Verify** — re-read every `- [x]`. If any isn't genuinely satisfied, uncheck and fix first.
