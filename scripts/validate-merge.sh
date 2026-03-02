#!/usr/bin/env bash
# =============================================================================
# Local CI — Merge Gate
# Run this before merging any task branch. It checks everything.
# Usage: npm run validate:merge
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; WARN=$((WARN + 1)); }

# Detect current task from branch name (task/RMP-NNN-...)
BRANCH=$(git branch --show-current)
TASK_ID=$(echo "$BRANCH" | grep -oE 'RMP-[0-9]+' || true)

echo -e "\n${BOLD}═══════════════════════════════════════${NC}"
echo -e "${BOLD}  Local CI — Merge Gate${NC}"
echo -e "${BOLD}  Branch: ${BRANCH}${NC}"
echo -e "${BOLD}  Task:   ${TASK_ID:-none detected}${NC}"
echo -e "${BOLD}═══════════════════════════════════════${NC}\n"

# ─── 1. DOCUMENTATION ───────────────────────────────────────────────────────
echo -e "${BOLD}[1/6] Documentation${NC}"

if [ -n "$TASK_ID" ]; then
  TASK_FILE=$(find .claude/tasks -name "${TASK_ID}*" -type f 2>/dev/null | head -1)

  if [ -z "$TASK_FILE" ]; then
    fail "Task file not found for ${TASK_ID}"
  else
    # Check Started timestamp (matches **Started:** followed by a date like 2026-02-25)
    if grep -qE '\*\*Started:\*\*.*[0-9]{4}-[0-9]{2}-[0-9]{2}' "$TASK_FILE"; then
      pass "Started timestamp recorded"
    else
      fail "Started timestamp missing in ${TASK_FILE}"
    fi

    # Check Finished timestamp
    if grep -qE '\*\*Finished:\*\*.*[0-9]{4}-[0-9]{2}-[0-9]{2}' "$TASK_FILE"; then
      pass "Finished timestamp recorded"
    else
      fail "Finished timestamp missing (still shows '—')"
    fi

    # Check Status is DONE
    if grep -qE '\*\*Status:\*\*.*DONE' "$TASK_FILE"; then
      pass "Status set to DONE"
    else
      fail "Status not set to DONE"
    fi

    # Check unchecked validation items
    UNCHECKED=$(grep -c '^\- \[ \]' "$TASK_FILE" 2>/dev/null || echo "0")
    CHECKED=$(grep -c '^\- \[x\]' "$TASK_FILE" 2>/dev/null || echo "0")
    if [ "$UNCHECKED" -gt 0 ]; then
      fail "${UNCHECKED} validation items still unchecked (${CHECKED} checked)"
    else
      pass "All validation items checked (${CHECKED} items)"
    fi

    # Check INDEX.md reflects status
    if grep -q "${TASK_ID}.*✅" .claude/tasks/INDEX.md 2>/dev/null; then
      pass "INDEX.md shows task as completed"
    else
      fail "INDEX.md not updated (should show ✅ for ${TASK_ID})"
    fi
  fi
else
  warn "No task ID detected from branch name — skipping doc checks"
fi

# ─── 2. TYPE CHECK ──────────────────────────────────────────────────────────
echo -e "\n${BOLD}[2/6] TypeScript${NC}"
if npx tsc --noEmit 2>&1; then
  pass "Type check passed"
else
  fail "Type check failed"
fi

# ─── 3. LINT ─────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}[3/6] Lint${NC}"
if npx next lint --quiet 2>&1; then
  pass "ESLint passed"
else
  fail "ESLint found errors"
fi

# ─── 4. FORMAT ───────────────────────────────────────────────────────────────
echo -e "\n${BOLD}[4/6] Formatting${NC}"
if npx prettier --check "src/**/*.{ts,tsx}" --ignore-unknown 2>&1; then
  pass "Prettier check passed"
else
  fail "Files not formatted (run: npm run format)"
fi

# ─── 5. SPELLING ─────────────────────────────────────────────────────────────
echo -e "\n${BOLD}[5/6] Spelling${NC}"
if npx cspell "src/**/*.{ts,tsx}" --quiet 2>&1; then
  pass "No spelling errors"
else
  warn "Spelling issues found (non-blocking)"
fi

# ─── 6. TESTS ────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}[6/6] Tests${NC}"

# Unit tests
if npx vitest run --project unit 2>&1; then
  pass "Unit tests passed"
else
  fail "Unit tests failed"
fi

# E2E / integration — only if test files exist
if find src -name "*.e2e.ts" -o -name "*.integration.ts" 2>/dev/null | grep -q .; then
  if npx vitest run --project e2e 2>&1; then
    pass "E2E/integration tests passed"
  else
    fail "E2E/integration tests failed"
  fi
else
  warn "No E2E/integration tests found (skipped)"
fi

# ─── SUMMARY ─────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}═══════════════════════════════════════${NC}"
echo -e "  ${GREEN}✓ ${PASS} passed${NC}  ${RED}✗ ${FAIL} failed${NC}  ${YELLOW}! ${WARN} warnings${NC}"

if [ "$FAIL" -gt 0 ]; then
  echo -e "\n  ${RED}${BOLD}BLOCKED — fix ${FAIL} failure(s) before merging${NC}\n"
  exit 1
else
  echo -e "\n  ${GREEN}${BOLD}READY TO MERGE${NC}\n"
  exit 0
fi
