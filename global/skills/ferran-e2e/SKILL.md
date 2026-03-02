---
name: ferran-e2e
description: "Ferran's E2E testing methodology for Playwright. Investigative debugging, self-cleaning data patterns, systematic issue classification. Part of the Ferran series: /ferran-task (task protocol), /ferran-plan (project planning)."
---

# Ferran's E2E Testing Best Practices

This is not a Playwright tutorial. This is a set of principles for building E2E tests that actually find bugs, born from painful iteration — 27 pages of issue reports, seed-dependency traps, agents pushing broken tests, and tests that passed for months while catching nothing.

The goal of E2E testing is NOT a green checkmark. It's confidence that your app works. If your tests pass but bugs reach production, your tests are decoration.

## The Golden Rule: Reporting and Fixing Are Separate Jobs

**NEVER run a test suite and fix failures in the same step.** These are two distinct phases with a hard boundary between them.

**Phase A — RUN AND REPORT (no code changes allowed)**

Run the suite. Produce a written report. List every failure, every skip, every flaky test — one by one. Include the test name, file, line number, and the exact error. That's it. Do not touch any code. Do not "quickly fix" anything. Do not retry flaky tests until they pass. The report is the deliverable of this phase.

**Phase B — INVESTIGATE AND FIX (only after the report is reviewed)**

Take one item from the report. Investigate it using the Three Diagnostic Questions. Fix it. Re-run. Update the report. Move to the next item. This phase only starts when the user has seen the report and decided what to work on.

Why this separation matters: agents instinctively want to help by fixing things immediately. But fixing without reporting first means the user never sees the full picture. They never learn that 3 tests were flaky, 7 were skipping, and the "fix" for test #4 actually weakened an assertion. The report is the user's window into what's really happening.

### A Failing Test Is a Victory

A test that finds a bug is working. It is doing exactly what it was built to do. Every failure caught in the test suite is a bug your client never has to report. Every skip investigated is a gap in coverage closed.

Do not treat failures as problems to eliminate. Treat them as discoveries to investigate. The agent's job is not to make the suite green — it's to make the suite honest.

## Core Principles

### 1. A test exists to catch a specific bug, not to be green

If you cannot name what bug a test would catch if it failed, that test has no reason to exist. Every test is a bet: "this behavior matters enough to verify on every run." If you can't articulate the bet, delete the test.

### 2. Understand before you fix

When a test fails or skips: STOP. Do not write code. Do not think about a fix yet.

1. Read the test. Describe the exact behavior it claims to verify.
2. Ask: why are we testing this? What breaks for the user if this behavior is wrong?
3. Check: does the test actually verify that behavior, or is it testing something else?
4. Only THEN decide: is the test wrong (TEST BUG) or is the app wrong (APP BUG)?
5. Only THEN write a fix.

This feels slow. It is not. It is faster than fixing the wrong thing, pushing, finding out later, and reverting.

### 3. Never change WHAT a test checks to make it pass

You can fix HOW a test checks something — a better selector, a proper wait, scoping to the right container. But if you weaken an assertion, broaden a matcher to match anything, or remove a check entirely to make green — you have removed a smoke detector from the building. The next fire goes undetected.

The line is: fixing the mechanism (how it checks) is fine. Changing the contract (what it checks) requires explicit justification and approval.

### 4. Tests must not depend on magic data

If a test only passes with a specific seed record with a specific UUID and specific field values, it's testing the seed, not the behavior. When the same flow runs against different data and breaks, the test was lying to you the whole time.

Tests must either:
- Create their own data (full isolation, data factory pattern)
- Explicitly document and justify any shared data dependencies

Seed data is acceptable for read-only tests that don't mutate state. For anything that creates, updates, or deletes — use the data factory. No exceptions.

### 5. Tests must leave zero artifacts

No leftover data, no side effects, no orphaned records for the next test to trip over. Every entity created during a test must be cleaned up — even if the test fails mid-execution.

If cleanup fails, that is a bug in your test infrastructure. Treat it with the same urgency as a failing test.

Verification: after cleanup, query the database for any entity with your test prefix. If anything remains, your cleanup is broken.

### 6. Skipped tests are lies

A skipped test tells the report "nothing to check here." In reality it means "I couldn't set up properly" or "the data wasn't ready." The test that was supposed to catch a bug didn't run. You have a gap in coverage and the report doesn't tell you.

Treat skips with the SAME urgency as failures. A suite with 40 passed and 10 skipped is NOT "40 passed." It's "40 passed, 10 unknown."

MANDATORY: When reporting test results, ALWAYS include the skip count. Never report only pass/fail. The full picture is passed / failed / skipped. Hiding skips is hiding risk.

### 7. One failure at a time

Do not batch-fix 50 failures. Fix one. Re-run the full suite. Document the delta (before/after table). Then find the next failure.

This feels painfully slow. It is the fastest path because:
- Patterns emerge (the same root cause behind 23 tests, not 23 separate bugs)
- Root causes surface (fix one thing, 12 other failures disappear)
- You avoid cascading bad fixes (fixing test A wrong breaks test B's fix)
- Total work goes DOWN, not up

### 8. Full isolation is expensive but honest

Shared state between tests is cheap to write and hides bugs. Full isolation (each test creates its own org, event, judges, pilots) is expensive but deterministic.

Pick your cost consciously. If you choose shared state, document exactly what is shared, why, and what the risks are. Don't stumble into seed dependency because it was faster to write.

The cost of full isolation is front-loaded (writing the setup). The runtime cost can be managed by choosing WHEN to run the full suite (production pushes) vs a lighter subset (development).

### 9. The test suite is not done — it's maintained

Requirements change. UI gets refactored. New features break old assumptions. Tests need the same care as production code. They are production code — they protect the product.

Budget for test maintenance. A test written 3 months ago might be testing a selector that no longer exists, an assertion against text that was reworded, or a flow that has an extra step now. Bit rot is real.

### 10. Document the WHY, not just the fix

A fix without context is a mystery for future-you. Every issue gets:
- Classification (TEST BUG / APP BUG)
- Root cause (why it actually failed, not just what you changed)
- Plain English explanation (what was broken, in terms a non-developer understands)
- Before/after results table

The issue report IS the deliverable. The code fix is a side effect.

### 11. "Previously passing" is not a quality guarantee

A test that passed for 6 months might have been:
- Silently skipping due to bad setup
- Matching the wrong element and asserting something trivially true
- Depending on seed data that happened to satisfy the assertion
- Never actually running the code path it claimed to test

Before committing or pushing ANY test — new or existing — verify it actually tests what it claims. "It was already there" and "it was passing before" are not reasons to keep broken behavior. If your name is on the commit, you own it.

### 12. "CI passes" is not permission to merge

When running locally, there IS no CI gate. The agent saying "CI passes, ready to merge" when there is no CI running is a lie. Even when CI does exist, a green pipeline only means "the checks we configured didn't fail." It doesn't mean:
- Skipped tests were investigated
- Test quality was reviewed
- New tests actually test what they claim
- Existing tests weren't weakened to achieve green

Green CI is the minimum bar, not the finish line. The finish line is: every test in the suite has been understood, the results are fully reported (including skips), and no test behavior was weakened to achieve the pass.

## The Three Diagnostic Questions

MANDATORY for every failing or skipping test. Answer these BEFORE writing any fix:

1. **Is this a test bug or an app bug?** Read the test, read the component. Is the test checking the right thing in the wrong way (test bug)? Or is the test correct and the app is broken (app bug)?

2. **What bug are we trying to catch?** What would go wrong for a real user if this test didn't exist? If you can't answer this, the test might be pointless — or you don't understand it yet.

3. **Does this extend to other tests?** Is this a one-off problem or a systemic pattern? Search the suite for the same anti-pattern. If you find it in 3 files, it's probably in 10.

## Quick Reference

- For the anti-pattern catalog, see [anti-patterns.md](anti-patterns.md)
- For data isolation patterns, see [data-isolation.md](data-isolation.md)
- For the investigation workflow, see [investigation-workflow.md](investigation-workflow.md)
- For selector strategy, see [selectors.md](selectors.md)
- For the issue report template, see [templates/issue-report.md](templates/issue-report.md)

## When Invoked

### Phase A: Run and Report (DEFAULT — no fixing allowed)

When asked to run tests, the ONLY output is a report. Do NOT fix anything. Do NOT write new tests. Do NOT touch any code. The report is the ONLY deliverable.

**This is not optional. This is not a suggestion. This is a hard requirement.**

An agent that runs the suite and fixes things in the same step has violated the most important rule. The user MUST see the full picture before any code changes happen. Every time.

1. Run the E2E test suite (full or targeted)
2. Save a report file to `.claude/tasks/` with the naming pattern: `TS-XXX E2E REPORT [date].md`
3. The report MUST follow this exact structure — no improvisation, no "summary cards", no marketing-style tables:

```markdown
# E2E Test Suite Report — [date] [suite name]

## Summary

| Passed | Failed | Skipped | Flaky (retried) | Total |
|--------|--------|---------|-----------------|-------|
| X      | X      | X       | X               | X     |

**The numbers MUST add up.** Passed + Failed + Skipped + Flaky = Total. If they don't, something was hidden. Investigate before reporting.

## Failed Tests

Every single failure. No grouping, no summarizing, no "7 pre-existing failures." Each one gets its own row.

| # | Test Name | File:Line | Error (exact first line) |
|---|-----------|-----------|--------------------------|
| 1 | `test name from describe/test block` | path/to/file.spec.ts:42 | Error: exact error message copy-pasted |
| 2 | ... | ... | ... |

If 0 failures: write "None."

## Skipped Tests

Every single skip. Skips are NOT "fine." They are tests that didn't run — gaps in coverage.

| # | Test Name | File:Line | Skip Reason |
|---|-----------|-----------|-------------|
| 1 | `test name` | path/to/file.spec.ts:18 | count was 0 / setup failed / test.skip() / etc |

If 0 skips: write "None."

## Flaky Tests (passed on retry)

Every test that failed at least once but passed on retry. These are ticking time bombs.

| # | Test Name | File:Line | Retries needed |
|---|-----------|-----------|----------------|
| 1 | `test name` | path/to/file.spec.ts:55 | 2 |

If 0 flaky: write "None."

## Notes

[Anything unusual observed during the run — slow tests, console errors, timeouts, infrastructure issues, etc.]
```

4. **Every section is mandatory.** Do NOT skip any section. Do NOT merge sections. Do NOT replace the table format with prose.
5. **Every failure/skip/flaky gets its own row.** No grouping like "7 simulation failures." No "3 flaky retried." Each test gets a name, a file:line, and the specific error or reason.
6. **No dismissals.** Do NOT label anything as "pre-existing", "known issue", or "not introduced by this change." The report is a snapshot of reality, not a diff.
7. **No fixes.** Do NOT auto-fix anything. Do NOT retry flaky tests to make them pass. Do NOT "quickly adjust" a selector. Zero code changes.
8. **Present the report. STOP.** Wait for the user to review it and decide what to tackle. The user picks the next step, not the agent.

### Why this format exists

This is the same format used in TS-027 issue reports (Admin, Live, Judge) which found 14 real issues — including 4 app bugs, 1 database seeding bug, and 1 accessibility violation — by following this exact process. The format works because it forces honesty: every test accounted for, every failure visible, every skip questioned.

### Phase B: Investigate (only when user asks)

When the user picks an item from the report to investigate:

1. Read the failing test file — understand what it claims to verify
2. Read the component/page it tests — understand the actual behavior
3. Answer the Three Diagnostic Questions OUT LOUD in your response:
   - "This is a **TEST BUG / APP BUG** because..."
   - "The bug this test catches is..."
   - "I searched for the same pattern and found it in X other files / this is isolated"
4. Propose a fix with before/after code
5. Ask: "Is there a better way to test this behavior?" — consider alternatives
6. Do NOT apply the fix until the user approves

### Phase C: Fix and Verify (only after investigation is approved)

1. Apply the approved fix
2. Re-run the full suite (not just the fixed test)
3. Produce an updated report showing the delta:

```markdown
## Fix Applied: Issue #N — [short description]
| Metric | Before | After |
|--------|--------|-------|
| Passed | X | Y |
| Failed | X | Y |
| Skipped | X | Y |
```

4. If new failures appeared, add them to the report. Do NOT auto-fix them.

### Before Committing or Pushing

1. Produce a final full report (Phase A format)
2. Every test in the commit must have been understood — not just "it passes"
3. Confirm zero test artifacts remain in the database
4. The report MUST show 0 failed, 0 skipped, 0 flaky. If not, do not push.
5. Never use "CI passes" or "tests were already like that" as justification
6. Never claim "ready to merge" — that is the user's decision, not the agent's

$ARGUMENTS
