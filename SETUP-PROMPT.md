# Setup Prompt for macOS

Copy-paste this into a Claude Code session on your Mac to set everything up automatically.

---

## PROMPT (copy everything below this line):

```
I need you to set up my autonomous task loop system for Claude Code. I have a folder called `claude-autonomous-setup` on my Desktop with all the files. Please do the following:

## Step 1 — Global settings

Copy the global config to ~/.claude/:

1. Copy `~/Desktop/claude-autonomous-setup/global/settings.json` to `~/.claude/settings.json`
2. Create skill directories and copy files:
   - `~/.claude/skills/ferran-task/skill.md` ← from `global/skills/ferran-task/skill.md`
   - `~/.claude/skills/ferran-plan/SKILL.md` ← from `global/skills/ferran-plan/SKILL.md`
   - `~/.claude/skills/ferran-e2e/SKILL.md` ← from `global/skills/ferran-e2e/SKILL.md`
   - `~/.claude/skills/ferran-e2e/templates/issue-report.md` ← from `global/skills/ferran-e2e/templates/issue-report.md`
3. Create commands directory and copy:
   - `~/.claude/commands/org.md` ← from `global/commands/org.md`

## Step 2 — Verify

After copying, read back each file to confirm it was placed correctly:
- `~/.claude/settings.json`
- `~/.claude/skills/ferran-task/skill.md`
- `~/.claude/skills/ferran-plan/SKILL.md`
- `~/.claude/skills/ferran-e2e/SKILL.md`
- `~/.claude/commands/org.md`

List all files under `~/.claude/` to show the final structure.

## Step 3 — Report

Tell me:
1. What was installed
2. What slash commands are now available (/ferran-task, /ferran-plan, /ferran-e2e, /org)
3. Remind me that for each PROJECT I need to:
   - Create `.claude/commands/` in the project root
   - Copy the 5 command files from `project-template/commands/` into it
   - Create `.claude/settings.json` from the template (and customize paths)
   - Create `.claude/tasks/INDEX.md` for the task registry
   - Copy `scripts/validate-merge.sh` into the project
   - Add `"validate:merge": "bash scripts/validate-merge.sh"` to package.json scripts
   - Create a CLAUDE.md with project conventions

That's it. Do not modify any file content — just copy them to the right places.
```
