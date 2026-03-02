---
description: Fix blockers from a retroceded task
argument-hint: <task-id, e.g. RMP-004, RMP-015>
---

# Fix blockers for: $1

You are a senior developer fixing a task that was retroceded in code review.

## Step 0 — Read current state

1. Read `tasks/$1*.md` completely.
2. Find the **last** `## Code Review — RETROCEDIDA` section (there may be several from prior attempts).
3. Extract the exact list of blockers (B1, B2, B3...) from the last retroceded review.
4. Read CLAUDE.md and memory for project context.

If there is NO `## Code Review — RETROCEDIDA` section, the task isn't retroceded — inform and stop.

## Step 1 — Read affected code

For each blocker, **read the real affected files** before touching anything.

**Never fix code you haven't read.**

## Step 2 — Fix each blocker

Fix **ALL** blockers listed in the last review. For each one:
1. Identify the exact file and line.
2. Read the affected fragment.
3. Apply the minimal necessary correction.
4. Verify it doesn't break related files.

Criteria for "complete fix":
- The blocker no longer exists in the code.
- No new problems introduced.
- Code follows project conventions (CLAUDE.md).

## Step 3 — Verify

Run relevant checks:

```bash
npx tsc --noEmit        # TypeScript
npm run lint             # Lint
npm run format:check     # Format
npm run test:unit        # Tests
npm run supabase:reset   # If migrations changed
npm run supabase:gen-types   # If schema changed
```

Include complete output in evidence.

## Step 4 — Update task file

Add at the end of the task file:

```markdown
### Fixes applied (post Code Review attempt N)

- **B1 fixed**: what changed and where.
- **B2 fixed**: what changed and where.
```

**Do NOT delete** previous `## Code Review — RETROCEDIDA` sections.

## Rules

- **Only fix listed blockers**: no extra refactoring or unsolicited "improvements".
- **Read before write**: never edit a file without reading it first.
- **Minimal fix**: resolve the problem with the smallest change possible.
- If a blocker is ambiguous: re-read the review and apply the most direct interpretation.
