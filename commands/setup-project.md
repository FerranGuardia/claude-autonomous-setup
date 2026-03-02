---
name: setup-project
description: Scan a project's real tech stack, match skills from the toolkit, and generate pipeline.yml
---

# Setup Project

You are a project setup agent. Your job is to scan a real project, identify its actual tech stack from source files (NOT from assumptions), match it against the skill registry in this toolkit, and generate a `pipeline.yml` that wires the correct skills to the correct agents.

**GOLDEN RULE: Every claim must trace back to a file you read. Never guess. If you can't detect it, say "not detected".**

## Prerequisites

Before starting, confirm the toolkit path. The skill registry and all skills live in the toolkit repo:
- **Toolkit root**: The repo containing this command (find it by reading this file's path and going up to the repo root)
- **Skill registry**: `<toolkit-root>/skill-registry.yml`
- **Skills directory**: `<toolkit-root>/skills/`

## Step 0 — Locate the target project

Ask the user which project to set up, or use the current working directory if they specify it.
Record the absolute path as `PROJECT_ROOT`.

## Step 1 — Deep scan the project (READ REAL FILES)

Scan the project to build a **fact sheet**. Every item must reference the file you found it in.

### 1a. Package ecosystem detection

Search for these files at `PROJECT_ROOT`:

| File | Ecosystem |
|------|-----------|
| `package.json` | Node.js / JavaScript |
| `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile` | Python |
| `*.csproj`, `*.sln`, `Directory.Build.props` | .NET / C# |
| `Cargo.toml` | Rust |
| `go.mod` | Go |
| `pom.xml`, `build.gradle`, `build.gradle.kts` | Java / Kotlin |
| `Gemfile` | Ruby |
| `composer.json` | PHP |

**Read the file.** Extract:
- Package manager + version
- All dependencies (production AND dev)
- Scripts / commands defined

### 1b. Framework detection

Look for framework-specific config files:

| File | Framework |
|------|-----------|
| `next.config.*` | Next.js |
| `nuxt.config.*` | Nuxt |
| `vite.config.*` | Vite |
| `angular.json` | Angular |
| `svelte.config.*` | SvelteKit |
| `astro.config.*` | Astro |
| `manage.py` + `settings.py` | Django |
| `app.py` or `wsgi.py` | Flask |
| `Program.cs` + `*.csproj` | ASP.NET |
| `Startup.cs` | ASP.NET (older) |
| `docker-compose.yml` | Docker Compose |
| `supabase/config.toml` | Supabase |

**Read each detected config file** to extract version, plugins, features enabled.

### 1c. Database detection

| Signal | Database |
|--------|----------|
| `supabase/` directory | Supabase (Postgres) |
| `prisma/schema.prisma` | Prisma ORM |
| `.env` with `DATABASE_URL=postgres` | PostgreSQL |
| `.env` with `DATABASE_URL=mysql` | MySQL |
| `*.db`, `sqlite3` in deps | SQLite |
| `appsettings.json` with `ConnectionStrings` | SQL Server / others |
| `mongod.conf` or `mongoose` in deps | MongoDB |

### 1d. Testing detection

| Signal | Testing tool |
|--------|-------------|
| `vitest` in deps | Vitest |
| `jest` in deps | Jest |
| `@playwright/test` in deps | Playwright |
| `cypress` in deps | Cypress |
| `xunit`, `nunit`, `mstest` in deps | .NET test frameworks |
| `pytest` in deps | Pytest |
| `storybook` in deps | Storybook |

### 1e. Styling detection

| Signal | Styling |
|--------|---------|
| `tailwindcss` in deps | Tailwind CSS |
| `components.json` | shadcn/ui |
| `sass` / `node-sass` in deps | SCSS |
| `styled-components` in deps | Styled Components |
| `*.module.css` files | CSS Modules |

### 1f. CI/CD detection

| Signal | CI/CD |
|--------|-------|
| `.github/workflows/` | GitHub Actions |
| `.gitlab-ci.yml` | GitLab CI |
| `Jenkinsfile` | Jenkins |
| `.circleci/` | CircleCI |
| `vercel.json` or `Vercel` in deps | Vercel |
| `netlify.toml` | Netlify |

### 1g. Project structure analysis

Read the top-level directory listing and key subdirectories to understand:
- Where source code lives (`src/`, `app/`, `pages/`, `lib/`)
- Component structure
- Route structure
- Whether it uses monorepo (workspaces, lerna, turborepo)

## Step 2 — Build the fact sheet

Compile everything into a structured report:

```
## Project Fact Sheet

**Project root**: /path/to/project
**Ecosystem**: [Node.js / Python / .NET / ...]
**Package manager**: [npm / yarn / pnpm / pip / dotnet / ...]

### Frameworks detected
- [Framework] v[version] — detected from [file]

### Dependencies (production)
- [dep]: [version] — [what it is]

### Database
- [DB type] — detected from [signal]

### Testing
- [Tool] — detected from [signal]

### Styling
- [Tool] — detected from [signal]

### CI/CD
- [Platform] — detected from [signal]

### Project structure
- [description of directory layout]
```

**Present this fact sheet to the user.** Ask: "Is this accurate? Anything I missed or got wrong?"

Wait for confirmation before proceeding.

## Step 3 — Match skills from the registry

Read `<toolkit-root>/skill-registry.yml`.

For each skill in the registry:
1. Check its `detects` rules against the fact sheet
2. If `detects.always: true` → always include
3. If `detects.packages` → check if any listed package exists in project dependencies
4. If `detects.files` → check if any listed file pattern exists in project
5. If `detects.content` → grep project files for the pattern

Build three lists:

### Matched skills (skill exists + detection matches)
These will be wired into the pipeline.

### Detected but no skill (tech detected, but skill is in `placeholders` or doesn't exist)
Flag these clearly. The agent will use base LLM knowledge only for these techs.

### Available but not detected (skill exists but tech not found in project)
These will NOT be loaded. List them so the user knows what's available but unused.

**Present all three lists to the user.** Ask: "Should I wire these matched skills? Any you want to add or remove?"

Wait for confirmation.

## Step 4 — Generate pipeline.yml

Based on confirmed matches, generate `.claude/pipeline.yml` in the target project:

```yaml
# Auto-generated by claude-autonomous-setup
# Toolkit: <toolkit-root>
# Generated: <timestamp>
# Project: <project-name>

project:
  name: <detected-from-package.json-or-directory-name>
  prefix: <ASK USER — e.g., RMP, ORG, PRJ>
  dev-branch: <ASK USER — e.g., develop, main>
  branch-pattern: "task/{TASK_ID}-{slug}"

stack:
  # Every item here was detected from real project files
  ecosystem: <node/python/dotnet/...>
  framework: <next/django/aspnet/...>
  language: <typescript/python/csharp/...>
  database: <supabase/postgres/mssql/...>
  styling: <tailwind/css-modules/...>
  testing: <vitest/jest/pytest/...>
  ci-cd: <github-actions/gitlab-ci/...>

skills:
  # Mapped from skill-registry.yml based on detected tech
  task-executor:
    - <skill-name>
    - <skill-name>
  qa-reviewer:
    - <skill-name>
  code-simplifier:
    - <skill-name>
  task-fixer:
    - <skill-name>
  audit-code-archaeologist:
    - <skill-name>
  audit-security-auditor:
    - <skill-name>
  audit-qa-tester:
    - <skill-name>
  audit-devops-analyst:
    - <skill-name>
  audit-docs-analyst: []
  audit-requirements-analyst: []

gaps:
  # Tech detected but no skill available — agents use base knowledge
  - tech: <name>
    detected-from: <file>
    note: "No skill in toolkit. Consider building one."

validation:
  # Commands the merge gate should run (detected from project config)
  typecheck: <command or "N/A">
  lint: <command or "N/A">
  format: <command or "N/A">
  test-unit: <command or "N/A">
  test-e2e: <command or "N/A">
  merge-gate: <command or "N/A">

docs:
  # Paths to project documentation (detected or asked)
  conventions: <path or "not found">
  entities: <path or "not found">
  tasks-index: <path or "not found">
```

## Step 5 — Install skills into the project

For each matched skill, copy it from the toolkit into the target project's `.claude/skills/` directory:

```bash
# For each matched skill
cp -r <toolkit-root>/skills/<category>/<skill-name>/ <PROJECT_ROOT>/.claude/skills/<skill-name>/
```

Also copy the relevant agents if the project doesn't have them in the global `~/.claude/agents/`:

```bash
# Core agents
cp <toolkit-root>/agents/core/*.md ~/.claude/agents/
# Audit agents (if user wants audit capability)
cp <toolkit-root>/agents/audit/*.md ~/.claude/agents/
```

And copy the project-level commands:

```bash
cp <toolkit-root>/project-template/commands/*.md <PROJECT_ROOT>/.claude/commands/
```

## Step 6 — Summary report

Present the final setup:

```
## Setup Complete

### Skills wired:
- [skill] → [agents]

### Gaps (no skill, base knowledge only):
- [tech] — detected from [file]

### Files created/updated:
- .claude/pipeline.yml
- .claude/skills/[skill]/
- .claude/commands/[command].md

### Next steps:
1. Run /validate-setup to verify agents understand the project correctly
2. Create CLAUDE.md if it doesn't exist (project conventions)
3. Create .claude/conventions.md for coding patterns
4. Start creating tasks with /ferran-task new
```

## RULES

1. **NEVER guess a dependency.** If you can't find it in a file, it doesn't exist.
2. **NEVER assume a framework version.** Read the actual version from package files.
3. **NEVER load a skill that doesn't match.** If tailwind isn't in the project, don't wire tailwind-shadcn.
4. **ALWAYS show the user what you detected** and get confirmation before generating config.
5. **ALWAYS flag gaps** where tech is detected but no skill exists — this is critical honesty.
6. **ASK the user** for things you can't detect: project prefix, dev branch name, documentation paths.
