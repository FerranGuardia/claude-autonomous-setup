---
description: QA review of a completed task
argument-hint: <task-id, e.g. RMP-004, RMP-015>
---

# QA Review: $1

You are a senior developer doing code review on a completed task.
Your role: verify the implementation is correct, complete, secure, and follows clean code.

## Step 0 — Locate the task

Search `.claude/tasks/` for a file matching `$1`. If not found, list available files and ask.

## Step 1 — Deep read

1. Read the task file completely (objective, DoD, dependencies, evidence).
2. Read ALL files listed as references inside the task.
3. Read CLAUDE.md and memory for project context.
4. Read EVERY file created or modified by the task (listed in the evidence section).
5. If the task has dependencies, read those tasks too for upstream context.

## Step 2 — Review checklist

Evaluate each deliverable against ALL these criteria:

### Correctness
- Logic matches what the DoD asks — no shortcuts or simplifications.
- Data flows correctly between components (migration → types → client → UI).
- Edge cases handled (nulls, empty states, unauthorized access).
- State machines follow documented transitions exactly.

### Completeness
- Every DoD checkbox has a verifiable deliverable.
- No missing files, functions, migrations, tests, or docs.
- Cross-references between documents are consistent.

### Security (CRITICAL)
- **RLS policies enforced at DB level** — not just frontend filtering.
- Access tiers enforced server-side.
- No sensitive data exposed to unauthorized roles.
- Supabase client uses `anon` key for public, `service_role` only server-side.
- No SQL injection — all queries parameterized.
- Auth state handled correctly (no stale closures, no remount on token refresh).
- File uploads respect access control (Supabase Storage RLS).

### Supabase-specific
- `onAuthStateChange` does NOT cause page remounts or form state loss.
- No direct Supabase queries from UI components without a data layer.
- RLS policies tested with ALL roles.
- Migrations are idempotent and reversible where possible.
- Types regenerated after schema changes (`supabase gen types`).

### Clean code
- No magic strings or numbers — uses enums/constants.
- No duplicated code.
- Descriptive, non-misleading names.
- Files have clear responsibility and reasonable size.
- No TODOs, FIXMEs, or commented-out code without justification.

### Tests
- Tests exist and can be executed.
- Cover DoD scenarios (happy path + edge cases).
- Assertions are specific (not just "no error").
- If no tests and DoD requires them → BLOCKING.

## Step 3 — Classify findings

**Every finding is blocking. There is no "non-blocking" category.**

If something is wrong, incomplete, or improvable within the task scope — the task does not pass.

### Blockers (B)
Any defect that prevents the task from being correct, complete, and production-ready:
- Incorrect logic producing wrong results
- Missing DoD deliverables
- Security vulnerabilities (especially data leaks across access tiers)
- Tests that fail or don't exist when DoD requires them
- RLS policies missing or not tested with all roles
- Sensitive data exposed to wrong access tier
- Auth state bugs (stale closures, remount on focus)

The only non-blocking items are improvements outside the task scope (features from future tasks).

## Step 4 — Verdict

### If blockers found → RETROCEDER

1. Present full summary with DoD table and findings.
2. **Write the review in the task file**, adding `## Code Review — RETROCEDIDA` at the end:
   - List of blockers (B1, B2...) with file, line, description, required action.
3. Do NOT mark the task as completed.

### If NO blockers → APROBAR

1. Present full summary.
2. **Write the review in the task file**, adding `## Code Review — APROBADA`:
   - Confirmation all DoD items pass.
   - Date of approval.

## Rules

- Never approve a task with blockers — no exceptions.
- Read ALL code before opining — don't assume from file names.
- Verify evidence: code is NOT evidence that something works. Real command output is.
- **Never trust the task file changelog** ("B1 resolved", etc.) — always read the actual code.
- Security is non-negotiable: if RLS is missing or untested, it's a blocker.
