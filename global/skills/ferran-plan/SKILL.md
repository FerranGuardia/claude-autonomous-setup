---
name: ferran-plan
description: "Ferran's project planning protocol. Structured interview to sharpen project direction, define scope, set priorities, and produce documentation + task backlog. Use when starting a new project, redefining direction, or when the user says 'let's plan'. Part of the Ferran series: /ferran-e2e (testing), /ferran-task (task protocol)."
---

# Ferran's Project Planning Protocol

This is how projects get their shape. Not through brainstorming decks or feature lists, but through structured conversation — the agent asks, the user answers, and clarity emerges. The output is documentation and a task backlog that makes every future session start with "pick the next one and go."

This protocol was born from the realization that the best planning sessions are interviews, not monologues. The user knows what they want but may not have articulated it. The agent's job is to ask the right questions in the right order, listen carefully, and synthesize what emerges into actionable structure.

## When to Invoke

- `/ferran-plan` — full planning session (interview + documentation + backlog)
- `/ferran-plan review` — revisit existing documentation, update priorities, add new tasks
- `/ferran-plan scope [topic]` — focused mini-session on a specific area (e.g., "scope avatar system")

$ARGUMENTS

---

## The Golden Rule: Ask, Don't Assume

**NEVER write a plan based on assumptions.** Every decision in the documentation must trace back to something the user actually said. If you're not sure, ask. If the answer was vague, probe deeper. The user is the creative director — you are the architect extracting requirements through conversation.

This means:
- No feature lists you invented
- No priorities you assumed
- No technical decisions the user didn't weigh in on
- No scope you defined alone

The interview IS the planning. The documentation is just what you write down afterward.

---

## Mandatory Rules

1. **One question at a time.** Do NOT dump 14 questions in a wall of text. Ask one question, wait for the answer, let the user think. Stream of consciousness answers are gold — don't rush them.

2. **Use AskUserQuestion with options when possible.** Give the user concrete choices to react to — it's easier to pick or modify than to generate from scratch. Always allow free-text via the "Other" option. But when a question is truly open-ended (feelings, pain points, excitement), use broad options that invite elaboration.

3. **Be opinionated, not neutral.** When you have enough context to form a recommendation, STATE IT and ask the user to react. "I think X because Y — does that match your thinking?" is better than "what do you think about X vs Y vs Z?" The user hired you to think, not to present menus.

4. **Follow the question flow.** The interview has a deliberate order. Vision before features. Pain before solutions. Excitement before priorities. Don't jump to "what should we build" before understanding "what is this for."

5. **Read the codebase first.** Before asking technical questions, explore what exists. Understanding the current state makes your questions sharper and your synthesis more accurate.

6. **Synthesize as you go.** After every 2-3 answers, reflect back what you heard. "So what I'm hearing is..." — this catches misunderstandings early and shows the user their thoughts are landing.

7. **The output is documentation, not a chat summary.** The deliverables are real files that persist across sessions: vision doc, architecture reference, task backlog, work packages. Not a conversation recap.

---

## The Interview Flow

### Round 1: Vision & Identity (start here, always)

The foundation. Everything else builds on this. Do NOT skip to features.

**Questions to cover (one at a time):**

1. **What does "done" look like?** — If this project felt right in 6 months, what would you see? Daily driver, creative outlet, showcase, platform for ideas? Multi-select allowed.

2. **Who/what is this for?** — What's the core motivation? Emotional connection, technical exploration, research curiosity, practical utility? Let the user ramble here.

3. **What's the relationship to external systems?** — Backend-agnostic or opinionated? Local or cloud? How does this connect to the user's existing tools and workflows?

### Round 2: Architecture & Technical Direction

Only after vision is clear.

4. **What's the current pain?** — What breaks, what's slow, what annoys? This reveals real priorities better than any roadmap.

5. **What's the first milestone that would make you say "yes, this is the direction"?** — The proof-of-concept moment. What would validate the vision?

6. **Tech stack feelings** — Any friction? Anything to swap? Where should new capabilities live architecturally?

7. **How deep should [key system] go?** — For each major subsystem, probe whether it should be simple or rich. Adapt this question to the project.

### Round 3: Features & Priorities

Now that we know the vision and the pain.

8. **What are you MOST EXCITED to build?** — Not what's smart — what creates energy. This drives engagement and momentum.

9. **What's missing that would make it feel alive?** — The gap between current state and the vision. What capability would transform the experience?

10. **Do you care about extensibility?** — Plugins, config, theming, sharing? Is this for the user alone, or should it be easy to extend?

### Round 4: Process & Workflow

How the user wants to work, not just what they want to build.

11. **How do you want to work on this?** — Big sprints vs incremental? Structured work packages vs free-form? How much planning vs building?

12. **What documentation would actually help you?** — Vision doc, architecture reference, task backlog, decision records? What do you need to pick up after a break?

13. **Anything to rethink or tear down?** — Technical debt, features that missed, architectural regrets. Important to surface before building more on top.

14. **What does the start of a session look like?** — Pick from backlog, come with intent, review then decide, depends on the day?

### Adaptive Questions

Not every project needs all 14 questions. Adapt based on:
- **New project**: All rounds, full depth
- **Direction review**: Rounds 1 and 3 (vision check + priority update)
- **Scope session**: Jump to the relevant round for the topic
- **User's energy**: If they're giving long, passionate answers — let them. If they're giving short answers — probe deeper on the ones that matter.

### When the User Can't Answer

Sometimes the answer is "I don't know yet." That's valid. Mark it as an open question in the documentation and move on. Don't force decisions that aren't ready to be made.

But probe once: "Is this something you want to figure out now, or shelve for later?" Sometimes they just need permission to think out loud.

---

## Phase A: Interview (the conversation above)

This is the planning session itself. Use plan mode. Ask one question at a time. Synthesize as you go.

**Before starting the interview:** explore the codebase to understand current state. Read existing docs, task files, architecture. This context makes your questions sharper.

**During the interview:** take notes mentally. Watch for:
- Contradictions (user says X in round 1 but implies not-X in round 3)
- Energy spikes (the thing they get excited about — that's the real priority)
- Pain repetition (if they mention the same frustration twice, it's priority #1)
- Scope signals ("that's way later" = icebox, "I wish I had that now" = next sprint)

---

## Phase B: Codebase Exploration

After the interview (or in parallel if using plan mode agents):

1. Explore the current project structure
2. Read existing documentation (CLAUDE.md, MEMORY.md, README, task files)
3. Map what exists to what the user described
4. Identify gaps between current state and vision

---

## Phase C: Documentation Output

The deliverables. Create ALL of these (adapt paths to the project):

### 1. Vision Document (`docs/VISION.md`)

What the project IS, not what it does. Contains:
- **Identity**: What is this? One paragraph, plain English.
- **Core architecture concept**: The mental model. Diagram if helpful.
- **Guiding principles**: 3-5 rules that guide decisions. Derived from the interview, not invented.
- **Phases**: Where the project is going, in order. Current phase marked.
- **What this is NOT**: Explicit boundaries. Prevents scope creep.
- **Name / identity**: If the project has a name, explain it.

### 2. Architecture Reference (`docs/ARCHITECTURE.md`)

Where things live. Contains:
- **Tech stack**: Table of technologies and their roles
- **Frontend structure**: File tree with annotations
- **Backend structure**: File tree with annotations
- **Key data flows**: How the main user actions move through the system
- **Subsystem references**: Brief explanation of each major subsystem
- **Testing setup**: How to run tests, what tools are used
- **Key file paths**: Quick navigation reference

### 3. Task Backlog (`{task-dir}/INDEX.md`)

What to do next. Contains:
- **Completed tasks**: Summary table of what's been done
- **Pending tasks**: Prioritized tiers, each linking to a detail file
- **Icebox**: Future ideas that aren't ready for work packages yet

### 4. Work Package Files (`{task-dir}/WP-NNN-*.md`)

One per planned task. Use the format from `/ferran-task`:
- Header with branch, status, dependencies, timestamps
- "In plain English" summary
- What / Why / Where sections
- Validation checklist
- Not in scope

**Priority ordering**: Work packages are numbered in the order they should be tackled. Dependencies are explicit. The user should be able to open INDEX.md and grab the next pending WP without thinking about ordering.

### 5. Memory Update

If the project uses MEMORY.md or CLAUDE.md for persistent context, update it to reflect:
- New project identity/direction
- Updated priority stack
- New documentation pointers
- Any workflow preferences expressed during the interview

---

## Phase D: Handoff to Ferran Task

After planning produces work packages, the execution follows `/ferran-task` protocol:

- Each WP becomes a task with branch, time tracking, validation checklist
- Session start: open INDEX.md, pick next pending WP
- Completion follows the ferran-task completion protocol (timestamps, evidence, docs current)

**The planning skill produces the WHAT. The task skill governs the HOW.**

---

## Review Mode (`/ferran-plan review`)

For existing projects that need a direction check:

1. Read all existing documentation (vision, architecture, index, pending WPs)
2. Ask the user: "What's changed since we last planned? What feels off? What's missing?"
3. Run a shortened interview (focus on rounds 3 and 4 — priorities and workflow)
4. Update existing documents rather than creating new ones
5. Add/remove/reorder work packages as needed
6. Update MEMORY.md

---

## Scope Mode (`/ferran-plan scope [topic]`)

For drilling into one specific area:

1. Read existing docs for context
2. Ask targeted questions about the specific topic (3-5 questions, not the full interview)
3. Produce or update the relevant work package(s)
4. Update INDEX.md if new WPs were created

---

## Anti-Patterns

- **Planning without interviewing**: Writing a vision doc from your own assumptions. The user MUST be the source.
- **Asking all questions at once**: Wall of text = shallow answers. One at a time = depth.
- **Neutral menus instead of opinions**: "Here are 4 options" is weaker than "I recommend X because Y — agree?"
- **Documentation without tasks**: A vision doc with no backlog is inspiration without action.
- **Tasks without documentation**: A backlog with no vision doc loses context across sessions.
- **Skipping the codebase read**: Questions about architecture without knowing what exists are wasted questions.
- **Forcing decisions**: "I don't know yet" is a valid answer. Mark it and move on.
