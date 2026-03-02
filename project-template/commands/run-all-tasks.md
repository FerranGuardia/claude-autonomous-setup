---
description: Execute all pending tasks sequentially with QA loop (full autopilot)
argument-hint: [start-task-id, e.g. RMP-004] — optional, defaults to first pending
---

# Execute all pending tasks

Orchestrate sequential execution of all pending tasks. For each: run-task → qa-review → if fail: fix-task → qa-review → (retry up to 3 times) → next task.

If `$1` is provided (e.g. `RMP-004`), start from that task. Otherwise, determine the first pending task automatically.

## Step 0 — Build execution list

1. List all files in `.claude/tasks/RMP-*.md` sorted by task number.
2. For each task, read the file and determine status:
   - **DONE**: contains `Status: DONE` or `## Code Review — APROBADA`
   - **PENDING**: no evidence of approved completion
   - **RETROCEDIDA**: last `## Code Review` is `RETROCEDIDA`
3. Build ordered list of PENDING and RETROCEDIDA tasks.
4. If `$1` was specified, filter to start from that task (inclusive).
5. **Check dependency chain**: for each task, verify its dependencies are DONE. Skip tasks with unresolved deps (report them).
6. Report to user: "Completed: [list]. To execute: [list]." Wait for explicit confirmation before proceeding.

## Step 1 — Main loop: for each task

Process tasks **sequentially** (one at a time — dependencies require it).

### Announce
Report: `▶ Starting $TASK_ID — <task title>`

### Flow per task: run-task → qa → [fix → qa]* (max 3 fix→qa cycles)

#### Step A — Execute task (first attempt only)

Read `.claude/commands/run-task.md` completely. Build prompt substituting `$1` with the task ID.

Launch Opus agent (foreground):
- `subagent_type`: `"general-purpose"`, `model`: `"opus"`
- `description`: `"run-task $TASK_ID"`
- `prompt`: The run-task prompt built above.

Wait for completion.

#### Step B — QA review (after run-task or fix-task)

Read `.claude/commands/qa-review.md` completely. Launch Opus agent (foreground):
- `subagent_type`: `"general-purpose"`, `model`: `"opus"`
- `description`: `"qa-review $TASK_ID — attempt N"`
- `prompt`: The qa-review prompt built above.

Wait for completion.

#### Read verdict

Read the task file `.claude/tasks/$TASK_ID*.md` yourself and find the LAST `## Code Review`:

**If `## Code Review — APROBADA`**:
- Report: `✓ $TASK_ID approved (attempt N)`
- Move to next task.

**If `## Code Review — RETROCEDIDA`**:
- Read and extract exact blockers from task file.
- Show blockers.
- If fix_cycle < 3: execute **Step C** (fix-task).
- If fix_cycle = 3:
  - Report: `✗ $TASK_ID exhausted 3 fix→QA cycles.`
  - List pending blockers (from task file).
  - **Stop ALL execution** and request manual intervention.

#### Step C — fix-task (only when QA rejects)

BEFORE launching the agent, read `.claude/tasks/$TASK_ID*.md` yourself and extract exact blockers from the last `## Code Review — RETROCEDIDA`.

Read `.claude/commands/fix-task.md` completely. Build prompt with explicit blockers:

```
## BLOCKERS TO FIX (extracted from task file .claude/tasks/$TASK_ID*.md)

B1 — [file:line if applicable] — [exact description copied from task file]
B2 — [file:line if applicable] — [exact description copied from task file]
...
```

Launch Opus agent (foreground):
- `subagent_type`: `"general-purpose"`, `model`: `"opus"`
- `description`: `"fix-task $TASK_ID — cycle N"`
- `prompt`: The fix-task prompt with blockers included.

Wait for completion. Go back to **Step B** (QA review).

## Step 2 — Final summary

When all tasks are processed (or stopped on failure):

```
═══════════════════════════════════════════
  EXECUTION SUMMARY
═══════════════════════════════════════════
  ✓ TASK-002 — already completed (prior)
  ✓ TASK-004 — approved attempt 2
  ✗ TASK-005 — blocked (manual intervention)
═══════════════════════════════════════════
```

Run `npm run validate:merge` as final gate.

## Unbreakable rules

- **Sequential only**: never launch two tasks in parallel.
- **Never skip a failed task**: if a task fails 3 attempts, stop completely.
- **Read the task file yourself** before each attempt — don't trust the prior agent's summary.
- **Include exact blockers in the prompt** of re-execution — copied from task file, not paraphrased.
- **Never declare approved** without reading task file and confirming `## Code Review — APROBADA`.
- **User confirmation before starting**: show pending task list and wait for explicit OK.
- If a sub-agent fails or returns unexpected error: inform user and stop.
- **Merge gate**: run `npm run validate:merge` after last task before declaring success.
