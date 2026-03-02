---
name: validate-setup
description: Verify that agents with their assigned skills correctly understand the project — no hallucination
---

# Validate Setup

You are a setup validator. After `setup-project` has generated `pipeline.yml` and installed skills, your job is to **verify that each agent role, with its assigned skills loaded, correctly understands the project.**

This is NOT a test suite. This is a comprehension audit. You spawn each agent role, give it the project context + its assigned skills, and check whether its understanding is **grounded in reality** — referencing real files, real patterns, real tech — or **hallucinated**.

## Step 0 — Read the setup

1. Read `.claude/pipeline.yml` in the target project
2. Read `CLAUDE.md` if it exists
3. Read `.claude/conventions.md` if it exists
4. Build the list of agent roles and their assigned skills from pipeline.yml

## Step 1 — Define comprehension probes per role

For each agent role, prepare **3 probes** (questions the agent must answer by reading the actual project):

### task-executor probes:
1. "What is the project's tech stack? List each technology and the file where you confirmed it."
2. "Describe the project's directory structure. Where do components live? Where do routes live? Where do database operations live?"
3. "If you had to add a new feature (e.g., a new page with a form that writes to the database), what files would you create and what patterns would you follow? Reference existing files as examples."

### qa-reviewer probes:
1. "What testing frameworks does this project use? Where are tests located? Show me an example test file."
2. "What security patterns does this project follow? (Auth, RLS, access control, input validation) — reference specific files."
3. "What are the merge gate requirements? What checks must pass before code can be merged?"

### code-simplifier probes:
1. "What coding conventions does this project follow? (Naming, file structure, import patterns) — reference specific files."
2. "Show me the project's component patterns. How are components organized? What's the relationship between server and client components?"
3. "What styling approach does this project use? Show me an example of how styles are applied."

### audit-security-auditor probes:
1. "How does this project handle authentication? Trace the auth flow from login to protected route."
2. "How is database access controlled? Are there RLS policies, middleware guards, or role checks?"
3. "Where are secrets and environment variables managed? What sensitive data exists in the project?"

## Step 2 — Spawn and probe each role

For each agent role that has skills assigned:

1. **Spawn the agent** with its skills loaded (read the skill files and include them in the prompt)
2. **Give it the project root** and ask it to read CLAUDE.md, pipeline.yml, and key project files
3. **Ask the 3 probes** one at a time
4. **Record the answers**

Use the Agent tool with `subagent_type: "Explore"` (read-only — we don't want agents changing anything).

The probe prompt template:

```
You are a {ROLE} for the project at {PROJECT_ROOT}.

Your assigned skills for this project:
{SKILL_CONTENTS}

Project configuration:
{PIPELINE_YML_CONTENTS}

TASK: Read the project's actual files and answer these questions.
For EVERY claim, cite the specific file and line where you found the evidence.
If you cannot find evidence for something, say "NOT FOUND — could not verify".
Do NOT make assumptions. Do NOT use general knowledge. Only report what you find in the actual project files.

Questions:
1. {PROBE_1}
2. {PROBE_2}
3. {PROBE_3}
```

## Step 3 — Grade the responses

For each agent's response, check:

### Grounding check (per claim)
- **GROUNDED**: The agent cited a real file that exists and the content matches
- **UNVERIFIABLE**: The agent made a claim but didn't cite a file, or the cited file doesn't exist
- **HALLUCINATED**: The agent stated something that contradicts what's actually in the project
- **SKILL MISMATCH**: The agent referenced patterns from a skill that don't apply to this project (e.g., mentioning React patterns in a Django project)

### Scoring
- **PASS**: All claims are GROUNDED, zero HALLUCINATED or SKILL MISMATCH
- **WARN**: Mostly GROUNDED, some UNVERIFIABLE (agent needs better file discovery, but isn't making things up)
- **FAIL**: Any HALLUCINATED or SKILL MISMATCH found (the skill wiring is wrong or the skill content misleads)

## Step 4 — Diagnosis for failures

For each FAIL or WARN:

1. **Identify the source**: Is the problem from the agent definition, the skill content, or missing project context?
2. **Classify the issue**:
   - **Wrong skill loaded**: A skill for tech X is loaded but the project uses tech Y → Remove from pipeline.yml
   - **Skill too generic**: The skill gives advice that doesn't match project patterns → Customize the skill for this project
   - **Missing context**: The agent couldn't find key files because they're in an unusual location → Update pipeline.yml docs paths
   - **Agent prompt issue**: The agent definition itself has hardcoded assumptions → Flag for agent update
3. **Propose fix**: Specific action to resolve each issue

## Step 5 — Report

```
## Setup Validation Report

### Summary
- Roles tested: N
- PASS: N
- WARN: N
- FAIL: N

### Results per role

#### task-executor: [PASS/WARN/FAIL]
- Probe 1: [summary of response + grounding verdict]
- Probe 2: [summary + verdict]
- Probe 3: [summary + verdict]
- Issues: [list or "none"]

#### qa-reviewer: [PASS/WARN/FAIL]
...

#### code-simplifier: [PASS/WARN/FAIL]
...

#### audit-security-auditor: [PASS/WARN/FAIL]
...

### Fixes needed
1. [Issue] → [Fix action]
2. ...

### Verdict
- ✅ READY: All roles pass — agents are grounded, skills are correctly matched
- ⚠️ NEEDS FIXES: Some roles have issues — apply fixes above, then re-validate
- ❌ NOT READY: Critical mismatches found — review skill assignments before proceeding
```

## Step 6 — Auto-fix loop (if user approves)

If the user wants to fix issues:
1. Apply each proposed fix (edit pipeline.yml, swap skills, add context paths)
2. Re-run validation ONLY for the roles that failed
3. Repeat until all roles pass or user decides to proceed with warnings

## RULES

1. **Read-only probing** — Agents must NOT modify any project files during validation
2. **Evidence required** — Every claim must cite a file. "I know Next.js uses..." is NOT acceptable — "I found in `next.config.mjs` at line 3..." IS acceptable
3. **Skills are the suspect** — When an agent hallucinates, check the loaded skill first. The skill may be injecting wrong patterns
4. **Don't test what doesn't exist** — If an agent role has zero skills assigned, skip it (it uses base knowledge only, which we can't control)
5. **Be honest about gaps** — If a role has skills but still shows weak understanding, flag it. Better to know now than during a real task
