---
description: Execute a single task
argument-hint: <task-id, e.g. RMP-004, RMP-015>
---

# Execute task $1

You are a senior developer executing a task end-to-end.

## Step 0 — Preparation

1. Read `CLAUDE.md` for project conventions, merge gate, and key commands.
2. Read the task file `.claude/tasks/$1*.md` completely — objective, DoD, dependencies, references.
3. Read ALL reference files listed in the task's "Read" section.
4. Read `docs/ENTITIES.md` and `docs/FLOWS.md` if the task touches domain logic.
5. Check dependency tasks are DONE (read their task files).

**IMPORTANT — Tech stack alignment:**
Read CLAUDE.md to understand the actual tech stack. If the task file mentions tools not used in this project, adapt to the actual stack.

## Step 1 — Branch setup

```bash
git checkout develop
git pull origin develop
git checkout -b task/$1-<short-name>
```

Record the **Started** timestamp immediately:
```bash
date '+%Y-%m-%d %H:%M'
```
Write it to the task file and commit:
```bash
git add .claude/tasks/$1*.md
git commit -m "$1: record start timestamp"
```

## Step 2 — Implement

Follow the task file's "What" section. For each deliverable:

1. **Read before writing** — always read existing files before modifying them.
2. **Follow project conventions** — check CLAUDE.md for formatting, linting, and style rules.
3. **i18n** — All user-facing strings go through the i18n system if the project uses one.
4. **Security** — RLS policies at DB level for any new tables. Never expose sensitive data to wrong roles.
5. **No magic numbers/strings** — use constants/enums.

### If the task involves database changes:
```bash
npx supabase migration new <descriptive-name>
# Write the SQL migration
npm run supabase:reset    # Apply migration
npm run supabase:gen-types  # Regenerate types
```

### If the task involves new pages/components:
- Use the existing layout and routing patterns in `src/app/`
- Add Storybook stories if the task creates UI components

## Step 3 — Verify

Run ALL checks:

```bash
npx tsc --noEmit              # TypeScript
npm run lint                   # ESLint
npm run format                 # Auto-fix formatting
npm run format:check           # Verify formatting
npm run test:unit              # Unit tests
```

If migrations changed:
```bash
npm run supabase:reset
npm run supabase:gen-types
```

**All checks must pass before proceeding.**

## Step 4 — Write tests

- Unit tests with Vitest for utilities, helpers, and logic.
- Component tests if UI was created.
- Test file naming: `*.test.ts` or `*.test.tsx` next to the source file.

## Step 5 — Update task file

1. Mark all validation checkboxes `[x]` with evidence (command output, not just "works").
2. Add a `## Evidence` section with actual command outputs.
3. Set `Status: DONE`.
4. Record the **Finished** timestamp:
   ```bash
   date '+%Y-%m-%d %H:%M'
   ```
5. Update `.claude/tasks/INDEX.md` if it exists — mark task as done.

## Step 6 — Final commit

```bash
git add <all relevant files>
git commit -m "$1: <concise description of what was done>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

## Step 7 — Merge gate

```bash
npm run validate:merge
```

**If it fails, fix the issues and re-run until it passes.**

## Rules

- **Read before write** — never edit a file without reading it first.
- **Adapt to actual stack** — read CLAUDE.md and existing code to understand tools used.
- **Timestamps are mandatory** — record Started and Finished immediately.
- **All checks must pass** — TypeScript, lint, format, tests.
- **No extra refactoring** — only implement what the task asks for.
- **Security first** — RLS policies for every new table, parameterized queries, no data leaks.
