# claude-autonomous-setup

Portable toolkit for autonomous [Claude Code](https://docs.anthropic.com/en/docs/claude-code) task execution. Drop it into any project, scan the real tech stack, wire the right skills to the right agents, and let them work.

It carries **14 specialized agents**, a **skill library**, **slash commands**, and a **registry-based detection system** — so agents only load knowledge that matches your actual codebase. No hallucinated frameworks, no phantom dependencies.

## How it works

```
┌─────────────────────────────────┐
│  This repo (portable toolkit)   │
│                                 │
│  agents/  skills/  commands/    │
└──────────────┬──────────────────┘
               │
    /setup-project  ← scan real files
               │
┌──────────────▼──────────────────┐
│  Your project                   │
│                                 │
│  package.json → detect deps     │
│  next.config  → detect framework│
│  tsconfig     → detect TS       │
│  supabase/    → detect DB       │
└──────────────┬──────────────────┘
               │
    Match skills from skill-registry.yml
               │
┌──────────────▼──────────────────┐
│  Generated pipeline.yml         │
│                                 │
│  task-executor:                 │
│    - tailwind-shadcn ✓          │
│    - typescript-advanced ✓      │
│    - react-patterns ✗ (gap)     │
└──────────────┬──────────────────┘
               │
    /validate-setup  ← probe agents
               │
    ✅ Agents understand the project
    ❌ Skill mismatch → fix before working
```

### The core principle: no hallucination

- Skills only load if the tech is **detected in real project files**
- Gaps are **flagged honestly** — "no skill for X, agent uses base knowledge"
- Validation **probes each agent** to verify it references real files, not guesses

## What's inside

```
claude-autonomous-setup/
├── skill-registry.yml              ← maps skills to tech detection rules
│
├── agents/                         ← 14 agent definitions
│   ├── core/                       ← task-executor, qa-reviewer, task-fixer, code-simplifier
│   └── audit/                      ← architect, skeptic, scoper, writer + 6 analysts
│
├── skills/                         ← skill library by category
│   ├── frontend/                   ← tailwind-shadcn, typescript-advanced
│   ├── backend/                    ← aspnet-mvc5, entity-framework-6, sql-server-dapper, and more
│   ├── security/                   ← security-hardening (OWASP, auth, headers, secrets)
│   └── devops/                     ← ci-cd-pipelines (GitHub Actions, GitLab CI)
│
├── global/                         ← one-time install → ~/.claude/
│   ├── settings.json               ← global permissions
│   ├── skills/                     ← ferran-task, ferran-plan, ferran-e2e
│   └── commands/                   ← /org (multi-project tracker)
│
├── commands/                       ← orchestrator commands
│   ├── setup-project.md            ← scan project → match skills → generate pipeline
│   └── validate-setup.md           ← probe agents for comprehension
│
├── project-template/               ← per-project scaffolding → <project>/.claude/
│   ├── settings.json
│   └── commands/                   ← run-task, run-all-tasks, qa-review, fix-task, etc.
│
├── templates/
│   └── pipeline.yml.template       ← skeleton for generated pipeline
│
├── scripts/
│   └── validate-merge.sh           ← merge gate (6-point local CI)
│
└── SETUP-PROMPT.md                 ← copy-paste prompt for quick setup
```

## Agent roles

### Core pipeline (task execution)

| Agent | What it does |
|---|---|
| **task-executor** | Implements tasks end-to-end with dynamically loaded skills |
| **qa-reviewer** | Reviews completed tasks against acceptance criteria |
| **task-fixer** | Fixes QA blockers with context from the review |
| **code-simplifier** | Simplifies code after implementation — removes over-engineering |

### Audit pipeline (project-wide analysis)

| Agent | What it does |
|---|---|
| **code-archaeologist** | Dead code, broken references, structural issues |
| **security-auditor** | Auth, data exposure, secrets, RLS policies |
| **qa-tester** | Broken flows, UI bugs, accessibility |
| **devops-analyst** | Build health, CI/CD, dependencies |
| **docs-analyst** | Stale, missing, contradictory documentation |
| **requirements-analyst** | Feature gaps, spec drift |
| **architect** | Synthesizes analyst reports into a prioritized backlog |
| **skeptic** | Red-teams the architect's backlog — challenges assumptions |
| **task-scoper** | Validates task sizing and dependency chains |
| **task-writer** | Converts scoped backlog into executable task files |

## Skill registry

The `skill-registry.yml` is the brain. Each skill declares what tech it covers and how to detect it:

```yaml
- name: tailwind-shadcn
  category: frontend
  description: "Tailwind CSS + shadcn/ui patterns"
  applies-to: [tailwindcss, shadcn-ui, react, nextjs]
  detects:
    packages: [tailwindcss, "@shadcn/ui"]
    files: ["tailwind.config.*", "components.json"]
  agents: [task-executor, qa-reviewer, code-simplifier]
```

When `/setup-project` runs, it scans your project files against these rules and only wires skills that actually match. If something is detected but no skill exists, you get an honest gap report:

```
GAPS (detected but no skill available):
- nextjs v14 — detected from next.config.mjs
  → Agent uses base LLM knowledge. Consider building skills/frontend/nextjs-patterns/
```

### Adding a new skill

1. Create `skills/<category>/<name>/SKILL.md`
2. Add a detection entry to `skill-registry.yml`
3. Run `/setup-project` to pick it up

## Setup

### Step 1 — Global install (once per machine)

```bash
git clone https://github.com/FerranGuardia/claude-autonomous-setup.git ~/claude-autonomous-setup

# Copy global config
mkdir -p ~/.claude/agents ~/.claude/skills ~/.claude/commands
cp ~/claude-autonomous-setup/global/settings.json ~/.claude/settings.json
cp -r ~/claude-autonomous-setup/global/skills/* ~/.claude/skills/
cp -r ~/claude-autonomous-setup/global/commands/* ~/.claude/commands/
cp ~/claude-autonomous-setup/agents/core/*.md ~/.claude/agents/
cp ~/claude-autonomous-setup/agents/audit/*.md ~/.claude/agents/
cp ~/claude-autonomous-setup/commands/*.md ~/.claude/commands/
```

### Step 2 — Per project

Open Claude Code in your project and run:

```
/setup-project
```

This scans your project, matches skills, and generates the pipeline config.

### Step 3 — Validate

```
/validate-setup
```

Spawns each agent and probes it with factual questions about your project. Catches hallucination before it causes damage.

### Step 4 — Work

```
/ferran-plan            # plan the project, create task backlog
/ferran-task new        # create individual task files
/run-all-tasks          # execute tasks autonomously
/run-task RMP-001       # execute a single task
/run-task-until-approved RMP-001  # execute + QA loop (max 3 cycles)
```

## Included skills

| Category | Skill | Detects |
|---|---|---|
| Frontend | `tailwind-shadcn` | tailwindcss, shadcn/ui, components.json |
| Frontend | `typescript-advanced` | typescript, tsconfig.json |
| Backend | `aspnet-mvc5-webapi2` | ASP.NET MVC 5 + Web API 2 |
| Backend | `entity-framework-6` | EF6 Code-First |
| Backend | `sql-server-dapper` | SQL Server + Dapper + ADO.NET |
| Backend | `unity-di` | Unity 5.x DI container |
| Backend | `quartz-scheduling` | Quartz.NET job scheduling |
| Backend | `hmac-auth` | HMAC-SHA256 custom auth |
| Backend | `dotnet-logging` | log4net + ELMAH |
| Security | `security-hardening` | Any web project (OWASP, auth, headers) |
| DevOps | `ci-cd-pipelines` | GitHub Actions, GitLab CI, Jenkins |
| Methodology | `ferran-task` | Always loaded — task file protocol |
| Methodology | `ferran-plan` | Always loaded — project planning |
| Methodology | `ferran-e2e` | Always loaded — E2E testing |

## Disclaimer

> **Use with caution.** This toolkit automates code generation, task execution, and project analysis using AI agents. It is designed to assist developers, not replace them.
>
> - **It does not substitute manual testing.** Always review generated code, run your own tests, and validate agent outputs before merging into production.
> - **It does not substitute code review.** A human should review all changes, especially those touching auth, security, data handling, or business logic.
> - **Agents can make mistakes.** Skills reduce hallucination in their covered domains, but gaps exist. The system flags them — pay attention to the gap reports.
> - **You are responsible for what gets merged.** The merge gate (`validate-merge.sh`) catches obvious issues, but it is not a substitute for judgment.
>
> Think of this as power tools for a carpenter — they make you faster, but you still need to measure twice and cut once.

## License

MIT
