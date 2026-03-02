# Issue Report Template

<!-- Standard format for documenting every E2E test issue found. -->
<!-- Copy this template for each new issue. -->

## Issue #N: [Short Description]

**Test:** `[test name from describe/test block]`
**File:** [filename.spec.ts:LINE](path/to/file.spec.ts#LXXX)
**Status:** investigating / fixed
**Type:** TEST BUG / APP BUG / APP BUG (Accessibility) / INFRA BUG

> **In plain English:** [Explain to someone who doesn't code.
> What was broken? What did we fix? What does the user see differently?]

### Error

```
[exact error message, copy-pasted]
```

### Root Cause

[Why it fails. Be specific and technical.]

### Fix Applied

**File:** [path/to/fixed/file]

```typescript
// Before (broken)

// After (fixed)
```

### Does this extend to other tests?

[Yes/No. If yes, list affected files, test names, and line numbers.]

### Results After Fix

| Before | After |
|--------|-------|
| X passed | Y passed |
| X skipped | Y skipped |
| X failed | Y failed |
