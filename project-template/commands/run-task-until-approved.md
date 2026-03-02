---
description: Execute a task in loop with QA until approved (max 3 fix cycles)
argument-hint: <task-id, e.g. RMP-004, RMP-015>
---

# Execute task with QA loop: $1

Orchestrate execution of task `$1`: run-task → qa-review → if rejected: fix-task → qa-review → repeat (max 3 fix cycles).

## Instructions

You are the coordinator. ALL real work is delegated to sub-agents. You only read results and decide next steps.

---

### Step A — run-task (first attempt)

Read `.claude/commands/run-task.md` completely. Launch Opus agent (foreground):
- `subagent_type`: `"general-purpose"`, `model`: `"opus"`
- `description`: `"run-task $1"`
- `prompt`: Content of run-task.md with `$1` substituted.

Wait for completion.

---

### Step B — QA review

Read `.claude/commands/qa-review.md` completely. Launch Opus agent (foreground):
- `subagent_type`: `"general-purpose"`, `model`: `"opus"`
- `description`: `"qa-review $1 — cycle N"`
- `prompt`: Content of qa-review.md with `$1` substituted.

Wait for completion.

#### Read verdict

Read the task file `.claude/tasks/$1*.md` yourself and find the LAST `## Code Review` section:

**If `## Code Review — APROBADA`**:
- Report: `✓ $1 approved (cycle N)`
- Stop.

**If `## Code Review — RETROCEDIDA`**:
- Extract exact blockers from the task file (copy them literally).
- If fix_cycle < 3: execute **Step C**.
- If fix_cycle = 3: report `✗ $1 exhausted 3 fix→QA cycles.` List blockers. Stop and request manual intervention.

---

### Step C — fix-task (when QA rejects)

Read the task file yourself and extract exact blockers from the last `## Code Review — RETROCEDIDA`.

Read `.claude/commands/fix-task.md` completely. Build the prompt with explicit blockers:

```
[Content of fix-task.md with $1 substituted]

## BLOCKERS TO FIX (extracted from task file)

B1 — [exact description copied from task file]
B2 — [exact description copied from task file]
...
```

Launch Opus agent (foreground):
- `subagent_type`: `"general-purpose"`, `model`: `"opus"`
- `description`: `"fix-task $1 — cycle N"`
- `prompt`: The prompt built with blockers included.

Wait for completion. Go back to **Step B**.

---

## Communication format

After each cycle:
```
── Cycle N ────────────────────────────────
  qa-review: RETROCEDIDA
  Blockers:
    B1 — description
    B2 — description
  → Launching fix-task...
───────────────────────────────────────────
```

On approval:
```
✓ Task $1 APPROVED in cycle N (run + N fixes)
```

On exhaustion:
```
✗ Task $1 not approved in 3 fix→QA cycles.
  Pending blockers: [list from task file]
  Manual intervention required.
```

## Rules

- Read the task file yourself before each Step C — don't use the agent's summary.
- Include blockers copied literally in the fix-task prompt.
- Never declare a task approved without reading the task file and confirming `## Code Review — APROBADA`.
- If a sub-agent fails with error: inform the user and stop.
